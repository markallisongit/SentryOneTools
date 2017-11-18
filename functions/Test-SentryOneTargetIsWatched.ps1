Function Test-SentryOneTargetIsWatched
{
<#
.SYNOPSIS 
Tests a SQL Server instance from the SentryOne monitoring server to make sure that it is watched

.DESCRIPTION
This function connects to Sentry One monitoring server and checks to make sure that the Windows host and SQL Server instance specified is being watched.

.PARAMETER ServerName
The host name where SQL Server is being hosted. FQDN.

.PARAMETER InstanceName
If a named instance then specify it here including the server name as FQDN, e.g. SERVER1.DOMAIN.COM\INSTANCEA

.PARAMETER SentryOneServerName
The instance name of the Sentry One database. Should be FQDN.

.PARAMETER SentryOneDatabaseName
The name of the SentryOne database.

.PARAMETER SentryOneInstallationPath
The path to the SentryOne binaries. This is used to find the PowerShell module for the automation.

.NOTES
Before running the function you will need to install and import the SQL Server module so you can connect to SQL Servers with: Import-Module SQLServer
See https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-ps-module

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

    [parameter(Mandatory=$true,Position=2)]
    [string] $SentryOneServerName,
    
    [parameter(Mandatory=$true,Position=3)]
    [string] $SentryOneDatabaseName,

    [parameter(Mandatory=$false,Position=4)]
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
}


process
{       
    if($ServerName -match $serverNameRegex)
    {
        if([string]::IsNullOrEmpty($InstanceName)) {
            $InstanceName = $ServerName
        }
        Write-Verbose "Checking if server $ServerName is registered ..."
        $ServerIsRegistered = $false
        try {
            $WatchComputer = Get-Computer -Name $ServerName
            if ($WatchComputer)
            {
                $ServerIsRegistered = $true
                Write-Verbose "Checking if instance $InstanceName is registered ..."
                $WatchConnection = Get-Connection -Name $InstanceName -NamedServerConnectionType SqlServer
                if ($WatchConnection)
                {
                    $InstanceIsRegistered = $true
                    $InstanceIsWatchedBy = $WatchConnection.WatchedBy
                } else {
                    $InstanceIsWatchedBy = "None"
                }                                
            } else {
                $ServerIsRegistered = $false
            }
        }
        catch {
            $ServerIsRegistered = $Error[0].Exception.Message
        }
    } else {
        Write-Warning "$Servername skipped because it is not a FQDN"
    }

    return  [PSCustomObject] @{
        ServerName = $ServerName
        InstanceName = $InstanceName
        ServerIsRegistered = $ServerIsRegistered
        InstanceIsRegistered = $InstanceIsRegistered
        InstanceIsWatchedBy = $InstanceIsWatchedBy
    }
}


end
{
    $Disconnected = Disconnect-SqlSentry
}
}
