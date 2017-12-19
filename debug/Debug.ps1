# SentryOne module
Import-Module "C:\Program Files\SentryOne\11.0\Intercerve.SqlSentry.Powershell.psd1" -Force
Get-Module 
Get-Command -module 'Intercerve.SqlSentry.Powershell'
Connect-SQLSentry -ServerName CROCUS.DUCK.LOC -DatabaseName SentryOne
Get-SQLSentryConfiguration
Disconnect-SQLSentry









# Install the Sqlserver module so we have access to Invoke-SqlCmd
Install-Module -Name SqlServer -Scope CurrentUser












Set-Location C:\Repos\SentryOneTools
Import-Module .\SentryOneTools.psd1 -Force
Get-Command -Module SentryOneTools 








# test the servers can be monitored
$servers = Get-Content ".\tests\serverlist.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$servers.targets
$result = $servers.targets | % { Test-SentryOneTarget $_.ServerName $_.InstanceName $_.UserName $_.Password $_.SQLPort }
$result | ? {$_.SentryOneMode -ne "Full"}





# some logic
$servers.targets | % { Test-SentryOneTarget $_.ServerName $_.InstanceName $_.UserName $_.Password $_.SQLPort } | % { `
    if ($_.SentryOneMode -ne "Full") { 
        $_ | Export-Csv C:\temp\fail.csv -NoTypeInformation -Append -Force
    } else {
      $_ | Export-Csv C:\temp\Full.csv -NoTypeInformation -Append -Force
    }
}






# register and watch all the servers
$result = $servers.targets | % { Register-SentryOneTarget $_.ServerName $_.InstanceName $_.UserName $_.Password $servers.SentryOneServer $servers.SentryOneDatabase }



# which ones failed?
$result | ? { $_.WatchComputer -ne "Pass" -or $_.WatchConnection -ne "Pass"}






# wait for Sentry One to gather info then query it again
$result = $servers.targets | % { Test-SentryOneTargetIsWatched $_.ServerName $_.InstanceName $servers.SentryOneServer $servers.SentryOneDatabase }
$result | ? {$_.InstanceIsRegistered -ne $true }
$result | ? {$_.InstanceIsWatchedBy -notmatch "PerformanceAdvisor|EventManager"}


$validationlist = Get-Content ".\tests\validationlist.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$validationlist.tests | % { Test-SentryOneTargetIsWatched $_.ServerNameShouldBe $_.InstanceNameShouldBe $servers.SentryOneServer $servers.SentryOneDatabase } 
($validationlist.tests | % { Test-SentryOneTargetIsWatched $_.ServerNameShouldBe $_.InstanceNameShouldBe $servers.SentryOneServer $servers.SentryOneDatabase | ? {$_.ServerIsRegistered}} ).Count
$validationlist.tests | ? {$_.Test -eq "Should validate where json only contains servername" }


Invoke-Pester .\tests\Test-SentryOneTarget.Tests.ps1
Invoke-Pester .\tests\Register-SentryOneTarget.Tests.ps1


# unwatch everything need to delete manually (or use Stored Procs )
Get-Connection -ConnectionType SqlServer | Invoke-UnwatchConnection
Get-Computer -ComputerType Windows | Invoke-UnwatchComputer
