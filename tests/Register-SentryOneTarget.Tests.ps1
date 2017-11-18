$moduleRoot = Split-Path $PSScriptRoot
$module = 'SentryOneTools'
Get-Module $module | Remove-Module -Force
Import-Module "$moduleRoot\$module.psm1" -Force
$sut = (Split-Path $moduleRoot) -replace '.Tests\.', '.'

$servers = Get-Content "$PSScriptRoot\serverlist.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$validationlist = Get-Content "$PSScriptRoot\validationlist.json" -Raw -Encoding UTF8 | ConvertFrom-Json

Describe "Testing all servers are unregistered first" {
    It "Should check that all servers are unregistered" {
        ($validationlist.tests | % { Test-SentryOneTargetIsWatched $_.ServerNameShouldBe $_.InstanceNameShouldBe $servers.SentryOneServer $servers.SentryOneDatabase | ? {$_.ServerIsRegistered}} ).Count | Should Be 0
    }
}

Describe "Registering and watching servers" {

    $servers.targets | % { 
        $SentryOneMode = (Test-SentryOneTarget $_.ServerName $_.InstanceName $_.UserName $_.Password).SentryOneMode
        Register-SentryOneTarget $_.ServerName $_.InstanceName $_.UserName $_.Password $servers.SentryOneServer $servers.SentryOneDatabase -SentryOneMode $SentryOneMode    
    }
    Start-Sleep -Seconds 30
    $watchedResult = $servers.targets | % {  Test-SentryOneTargetIsWatched $_.ServerName $_.InstanceName $servers.SentryOneServer $servers.SentryOneDatabase }
    
    It "Servers in list should be registered" {
        ($watchedResult | ? {$_.ServerIsRegistered}).Count | Should Be 4
    }

    It "Instances in list should be registered" {
        ($watchedResult | ? {$_.InstanceIsRegistered}).Count | Should Be 4
    }
    
    It "Instances in list should be watched by PerformanceAdvisor" {
        ($watchedResult | ?{$_.InstanceIsWatchedBy -match "PerformanceAdvisor"}).Count | Should Be 4
    }

    It "Instances in list should be watched by EventManager" {
        ($watchedResult | ?{$_.InstanceIsWatchedBy -match "EventManager"}).Count | Should Be 4
    }
    
}