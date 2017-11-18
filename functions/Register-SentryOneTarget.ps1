Function Register-SentryOneTarget {
<#
.SYNOPSIS 
Registers and watches a Sentry One computer and SQL instance.

.DESCRIPTION
Tries to register and watch a Sentry One Computer, then adds the default instance unless a named instance is specified.

.PARAMETER ServerName
The host name where SQL Server is being hosted. Must be FQDN.

.PARAMETER InstanceName
If a named instance then specify it here including the server name as FQDN, e.g. SERVER1.DOMAIN.COM\INSTANCEA

.PARAMETER UserName
If this is specified then SQL Authentication will be used. If blank then Windows Authentication will be used

.PARAMETER Password
The SQL Authentication Password

.PARAMETER SentryOneServerName
The instance name of the Sentry One database. Should be FQDN.

.PARAMETER SentryOneDatabaseName
The name of the SentryOne database.

.PARAMETER SentryOneSite
The name of the SentryOne site to place the server.

.PARAMETER SentryOneInstallationPath
The path to the SentryOne binaries. This is used to find the PowerShell module for the automation.

.NOTES
SentryOne must be insstalled to run this module. This function must be run on the Sentry One monitoring server. It can't be run on a workstation AFAIK.

Author: Mark Allison, Sabin.IO <mark.allison@sabin.io>

.EXAMPLE   
Register-SentryOneTarget -ServerName SQLSERVERBOX -SentryOneServerName crocus.duck.loc -SentryOneDatabaseName SentryOne

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

        [parameter(Mandatory=$true,Position=4)]
        [string] $SentryOneServerName,
        
        [parameter(Mandatory=$true,Position=5)]
        [string] $SentryOneDatabaseName,

        [parameter(Mandatory=$false,Position=6)]
        [string] $SentryOneMode="Full",        

        [parameter(Mandatory=$false,Position=7)]
        [string] $SentryOneSite="Default Site",

        [parameter(Mandatory=$false,Position=8)]
        [string] $SentryOneInstallationPath="C:\Program Files\SentryOne\11.0"   
    )     


    begin
    {
        Write-Verbose "Importing the SQLSentry PowerShell module ..."
        if (Test-Path ($SentryOneInstallationPath)){
            Import-Module "$SentryOneInstallationPath\Intercerve.SqlSentry.Powershell.psd1" -Force
        }
        else {
            throw "Cannot find the SQLSentry PowerShell module in path $SentryOneInstallationPath. Sentry One monitoring service must be installed first."
        }
        $Connected = Connect-SQLSentry -ServerName $SentryOneServerName -DatabaseName $SentryOneDatabaseName
        if($Connected -notmatch "Successful") {
            throw $Connected
        }
        $serverNameRegex = "^[\d\w]+\.[\d\w]+" # FQDN

        $TargetSite = (Get-Site -Name $SentryOneSite)
    }


    process
    {       
        if($ServerName -match $serverNameRegex)
        {
            if([string]::IsNullOrEmpty($InstanceName)) {
                $InstanceName = $ServerName
            }

            Write-Verbose "Adding server $ServerName to Sentry One ..."
            try {
                $RegisterComputer = Register-Computer -Name $ServerName -ComputerType Windows -TargetSite $TargetSite -AccessLevel $SentryOneMode
                if ($RegisterComputer.Name -eq $ServerName) {
                    $RegisterComputerResult = "Pass"
                }
            }
            catch {
                $RegisterComputerResult = $Error[0].Exception.Message
            }

            Write-Verbose "Adding instance $InstanceName to Sentry One ..."
            try {
                $RegisterConnectionParams = @{
                    ConnectionType = "SqlServer"
                    Name = $InstanceName
                }
                if(-not ([string]::IsNullOrEmpty($UserName))) {
                    Write-Verbose "Registering server with SQL Auth with user $UserName..."
                    $RegisterConnectionParams += @{
                        Login = $UserName
                        Password = $Password
                        UseIntegratedSecurity = 0
                    }
                }
                $RegisterConnection = Register-Connection @RegisterConnectionParams
                if ($RegisterConnection.Name -eq $InstanceName)
                {
                    $RegisterConnectionResult = "Pass"
                }
            }
            catch {
                $RegisterConnectionResult = $Error[0].Exception.Message
            }

            Write-Verbose "Watching server $ServerName ..."
            try {
                $WatchComputer = Get-Computer -Name $ServerName | Invoke-WatchComputer
                if (($WatchComputer | ? {$_.WatchResult -eq "Success"}).Count -eq 2)
                {
                    $WatchComputerResult = "Pass"
                } else {
                    $WatchComputerResult = $WatchComputer
                }
            }
            catch {
                $WatchComputerResult = $Error[0].Exception.Message
            }

            Write-Verbose "Watching instance $InstanceName ..."
            try {
                $WatchConnection = Get-Connection -Name $InstanceName -NamedServerConnectionType SqlServer | Invoke-WatchConnection
                if (($WatchConnection | ? { $_.WatchResult -eq "Success" }).Count -eq 2)
                {
                    $WatchConnectionResult = "Pass"
                } else {
                    $WatchConnectionResult = "Fail"
                }
            }
            catch {
                $WatchConnection = $Error[0].Exception.Message
            }
        } else {
            Write-Warning "$Servername skipped because it is not a FQDN"
        }

        return  [PSCustomObject] @{
            ServerName = $ServerName
            InstanceName = $InstanceName
            RegisterComputer = $RegisterComputerResult
            RegisterConnection = $RegisterConnectionResult
            WatchComputer = $WatchComputerResult
            WatchConnection = $WatchConnectionResult
        }
    }


    end
    {
        Disconnect-SqlSentry | Out-Null
    }
}
    