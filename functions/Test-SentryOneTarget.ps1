Function Test-SentryOneTarget 
{
<#
.SYNOPSIS 
Tests a remote machine to make sure all the firewall ports, permissions, WMI, perfmon is accessible to allow SentryOne to monitor it.

.DESCRIPTION
The function Test-SentryOneTarget is designed to test the requirements are met for SentryOne to be able to connect to a SQL Server target in Full Mode. If the tests Pass this means that Sentry One will be able to display and save both Windows performance metrics and SQL Server metrics.

If the SQLSysadmin test Passes but others fail, then SentryOne will be able to connect in **Limited Mode** which means that the Windows performance metrics will not be gathered, only the SQL Server ones.

.PARAMETER ServerName
The host name where SQL Server is being hosted.

.PARAMETER InstanceName
If a named instance then specify it here including the server name, e.g. SERVER1\INSTANCEA

.PARAMETER UserName
If this is specified then SQL Authentication will be used. If blank then Windows Authentication will be used

.PARAMETER Password
The SQL Authentication Password

.PARAMETER SQLPort
The port SQL Server is listening on. If none supplied, 1433 is tried.

.NOTES
Before running the function you will need to 
    * Install the SQL Server module so you can connect to SQL Servers with: Install-Module -Name SqlServer. See https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-ps-module
    * Install RSAT

Author: Mark Allison, Sabin.IO <mark.allison@sabin.io>

.EXAMPLE   
Test-SentryOneTarget -ServerName SQLSERVERBOX

#>    
    [cmdletbinding()]
    param (
        [parameter(Mandatory=$true,Position=0,ValueFromPipeline)]
        [string] $ServerName,
        
        [parameter(Mandatory=$false,Position=1)]
        [string] $InstanceName,

        [parameter(Mandatory=$false,Position=2)]
        [string] $UserName,

        [parameter(Mandatory=$false,Position=3)]
        [string] $Password,

        [parameter(Mandatory=$false,Position=4)]
        [int] $SQLPort
    )
    Process {
        if ([string]::IsNullOrEmpty($InstanceName)) {
            $InstanceName = $ServerName
        }

        if ($SQLPort -eq 0) {
            $SQLPort = 1433
        }
        <#
        if(-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
        {
            throw "This script must be run with Administrative privileges. Run as Administrator and try again."
        }
        #>
        $IsRSATInstalled = Test-IsRSATInstalled
        if(-not ($IsRSATInstalled)) {
            Write-Warning "This script requires Remote Server Administration Tools (RSAT) installed. Enumeration of permissions may be incorrect."
        }

        if((Get-Module -Name SqlServer -ListAvailable) -eq $null) {
            throw "This script requires the SqlServer module to be installed. Install with: Install-Module -Name SqlServer. Then try again."
        }

        # https://cdn.sentryone.com/help/qs/webframe.html?Performance%20Advisor%20Required%20Ports.html#Performance%20Advisor%20Required%20Ports.html#Performance%20Advisor%20Required%20Ports.html
        Write-Verbose "Resolving IP Address for host $ServerName ..."
        $ip = [string](Resolve-DnsName -Name "$ServerName" -ErrorAction 'Stop' -Verbose:$False).IPAddress

        # let's try connecting to the SQL Server Instance directly without testing the ports first
        # named instances can have dynamic ports so let's just try and connect.
        Write-Verbose "Enumerating Port in SQL Server ..."
        $SqlCmdArgs = @{
            ServerInstance = $InstanceName
            Query = @"
DECLARE @Ports TABLE (LogDate datetime, ProcessInfo nvarchar(30), Text nvarchar(max))
INSERT @Ports (LogDate, ProcessInfo, Text)
exec xp_readerrorlog 0, 1, N'Server is listening on', N'''any'' <ipv4>', NULL, NULL, N'asc'
select top 1 Text from @Ports ORDER BY LogDate
"@
            IncludeSqlUserErrors = $true
            ErrorAction = 'SilentlyContinue'
        }
        if (-not [string]::IsNullOrEmpty($UserName)) {
            $SqlCmdArgs += @{
                UserName = $UserName
                Password = $Password 
            }
        }
        try {
            $result = (Invoke-Sqlcmd @SqlCmdArgs).Text -match "\d{4,5}"
            if(-not [string]::IsNullOrEmpty($matches[0])) 
            {            
                $SQLPort = $matches[0]
                Write-Verbose "Discovered SQL Server is listening on port $SQLPort"
            }
        }
        catch {
            # swallow the exception
        }

        Write-Verbose "Testing SQL Port $SQLPort ..."
        $IsSqlPortOpen = "FAIL - Unknown error" 
        try {
            if (Test-TcpPort -ip $ip -port $SQLPort) {
                $IsSqlPortOpen = "Pass"
            }    
        }
        catch {
            $IsSqlPortOpen = $Error[0].Exception.InnerException.Message
        }

        Write-Verbose "Testing SMB/RPC Port 445 ..."
        $IsPort445Open = "FAIL"
        try {
            if (Test-TcpPort -ip $ip -port 445) { 
                $IsPort445Open = "Pass"
            }
        }
        catch {
            $IsPort445Open = $Error[0].Exception.InnerException.Message
        }
        
        Write-Verbose "Testing RPC Port 135 ..."
        $IsPort135Open = "FAIL"
        try {
            if (Test-TcpPort -ip $ip -port 135) { 
                $IsPort135Open = "Pass"
            }
        }
        catch {
            $IsPort135Open = $Error[0].Exception.InnerException.Message
        }

        # test SQL Connection has sysadmin role
        $IsSQLSysAdmin = "FAIL"
        if ($IsSqlPortOpen -eq "Pass")
        {
            Write-Verbose "Testing sysadmin rights in SQL Server ..."
            $SqlCmdArgs = @{
                ServerInstance = $InstanceName
                Query = "select is_srvrolemember('sysadmin') as IsSysAdmin"
                IncludeSqlUserErrors = $true
                ErrorAction = 'SilentlyContinue'
                ErrorVariable = 'SQLError'
            }
            if (-not [string]::IsNullOrEmpty($UserName)) {
                $SqlCmdArgs += @{
                    UserName = $UserName
                    Password = $Password 
                }
            }

            try {
                if ((Invoke-Sqlcmd @SqlCmdArgs).IsSysAdmin -eq 1) {
                    $IsSQLSysAdmin = "Pass"
                }
            }
            catch {
                if (-not [string]::IsNullOrEmpty($Error[0].Exception.InnerException.Message)) 
                {
                    $IsSQLSysAdmin = $Error[0].Exception.InnerException.Message
                }
            }
            # let's catch the uncatcheable
            if (-not [string]::IsNullOrEmpty($SQLError))
            {
                $IsSQLSysAdmin = $SQLError.Exception.Message
            }        
        }

        # testing WMI
        if ($IsSqlPortOpen -eq "Pass")
        {        
            Write-Verbose "Testing WMI Connection ..."
            $WMITest = "FAIL"
            try {
                if (-not ([string]::IsNullOrEmpty((Get-WmiObject -class Win32_OperatingSystem -computername $ServerName -ErrorAction SilentlyContinue -ErrorVariable WMIError).Caption)))
                {
                    $WMITest = "Pass"
                }
            }
            catch
            {
                $WMITest = $Error[0].Exception.Message
            }

            if(-not [string]::IsNullOrEmpty($WMIError))
            {
                $WMITest = $WMIError
            }
        }
        # test Windows connection is in local admins group over WMI
        if ($WMITest -eq "Pass")
        {
            Write-Verbose "Testing is Windows Local Admin using WMI ..."
            $IsLocalAdmin = "FAIL"
            try {
                $IsLocalAdmin = Test-IsLocalAdmin -ComputerName $ServerName
                if ($IsLocalAdmin) {
                    $IsLocalAdmin = "Pass"
                }            
            }
            catch
            {
                $IsLocalAdmin = $Error[0].Exception.Message
            }               
        }

        # test perfmon
        if ($IsSqlPortOpen -eq "Pass" -and $IsPort445Open -eq "Pass")
        {
            Write-Verbose "Testing Perfmon Counters (takes a while) ..."
            $PerfmonTest = "FAIL"
            try {
                if(((get-counter -ListSet Processor -ComputerName $ServerName -ErrorAction SilentlyContinue -ErrorVariable PerfmonError).Counter.Count) -gt 0)
                {
                    $PerfmonTest = "Pass"
                }
            }
            catch{
                $PerfmonTest = $Error[0].Exception.Message
            }
            # let's catch the uncatcheable
            if (-not [string]::IsNullOrEmpty($PerfmonError))
            {
                $PerfmonTest = $PerfmonError
            }
        }
        $SentryOneMode = "Not monitored"
        if (
            ($IsSQLSysadmin -eq "Pass") -and
            ($PerfmonTest -eq "Pass") -and 
            ($IsLocalAdmin -eq "Pass") -and
            ($WMITest -eq "Pass")
        )
        {
            $SentryOneMode = "Full"
        }

        if (
            ($IsSQLSysadmin -eq "Pass") -and
            (($PerfmonTest -ne "Pass") -or
            ($IsLocalAdmin -ne "Pass") -or
            ($WMITest -ne "Pass"))
        )
        {
            $SentryOneMode = "Limited"
        }

        return [PSCustomObject]@{
            ServerName = $ServerName
            InstanceName = $InstanceName
            IpAddress = $ip
            SentryOneMode = $SentryOneMode
            IsSqlPortOpen = $IsSqlPortOpen
            SQLPort = $SQLPort
            IsPort445Open = $IsPort445Open
            IsPort135Open = $IsPort135Open
            IsSQLSysAdmin = $IsSQLSysAdmin
            IsLocalAdmin = $IsLocalAdmin
            PerfmonTest = $PerfmonTest
            WMITest = $WMITest
        }
    }
}
