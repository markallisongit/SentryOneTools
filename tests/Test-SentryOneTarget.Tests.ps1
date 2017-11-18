$moduleRoot = Split-Path $PSScriptRoot
$module = 'SentryOneTools'
Get-Module $module | Remove-Module -Force
Import-Module "$moduleRoot\$module.psm1" -Force
$sut = (Split-Path $moduleRoot) -replace '.Tests\.', '.'

$servers = Get-Content "$PSScriptRoot\serverlist.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$validationlist = Get-Content "$PSScriptRoot\validationlist.json" -Raw -Encoding UTF8 | ConvertFrom-Json

$ValidServerNameOnly = $validationlist.tests | ? {$_.Test -eq "Should validate where json only contains servername" }
$NamedInstanceSQLAuth = $validationlist.tests | ? {$_.Test -eq "Should validate against named instance with SQL Authentication" }
$NamedInstanceWindowsAuth = $validationlist.tests | ? {$_.Test -eq "Should validate against named instance with Windows Authentication" }
$LimitedTarget = $validationlist.tests | ? {$_.Test -eq "Limited target should validate against named instance with Windows Authentication" }
$UnreacheableTarget = $validationlist.tests | ? {$_.Test -eq "Should fail to validate an unreacheable server" }

Describe "Test sentry one targets" {
    It "Should validate where json only contains servername" {
        $result = $servers.targets | ? {$_.ServerName -eq $ValidServerNameOnly.InstanceNameShouldBe} | % { Test-SentryOneTarget $_.ServerName $_.InstanceName $_.UserName $_.Password $_.SQLPort}
        $result.ServerName | Should Be $ValidServerNameOnly.ServerNameShouldBe
        $result.InstanceName | Should Be $ValidServerNameOnly.InstanceNameShouldBe
        $result.IsPort135Open | Should Be $true
        $result.IsPort445Open | Should Be $true
        $result.IsSqlPortOpen | Should Be $true
        $result.IsLocalAdmin | Should Be $true
        $result.IsSQLSysAdmin | Should Be $true
        $result.WMITest | Should Be $true
        $result.PerfmonTest | Should Be $true
        $result.SentryOneMode | Should Be "Full"
    }

    It "Should validate against named instance with SQL Authentication" {
        $result = $servers.targets | ? {$_.InstanceName -eq $NamedInstanceSQLAuth.InstanceNameShouldBe } | % { Test-SentryOneTarget $_.ServerName $_.InstanceName $_.UserName $_.Password $_.SQLPort}
        $result.ServerName | Should Be $NamedInstanceSQLAuth.ServerNameShouldBe 
        $result.InstanceName | Should Be $NamedInstanceSQLAuth.InstanceNameShouldBe 
        $result.IsPort135Open | Should Be $true
        $result.IsPort445Open | Should Be $true
        $result.IsSqlPortOpen | Should Be $true
        $result.IsLocalAdmin | Should Be $true
        $result.IsSQLSysAdmin | Should Be $true
        $result.WMITest | Should Be $true
        $result.PerfmonTest | Should Be $true
        $result.SentryOneMode | Should Be "Full"
    }

    It "Should validate against named instance with Windows Authentication" {
        $result = $servers.targets | ? {$_.InstanceName -eq $NamedInstanceWindowsAuth.InstanceNameShouldBe } | % { Test-SentryOneTarget $_.ServerName $_.InstanceName $_.UserName $_.Password $_.SQLPort}
        $result.ServerName | Should Be $NamedInstanceWindowsAuth.ServerNameShouldBe
        $result.InstanceName | Should Be $NamedInstanceWindowsAuth.InstanceNameShouldBe
        $result.IsPort135Open | Should Be $true
        $result.IsPort445Open | Should Be $true
        $result.IsSqlPortOpen | Should Be $true
        $result.IsLocalAdmin | Should Be $true
        $result.IsSQLSysAdmin | Should Be $true
        $result.WMITest | Should Be $true
        $result.PerfmonTest | Should Be $true
        $result.SentryOneMode | Should Be "Full"
    }

    It "Limited target should validate against named instance with Windows Authentication" {
        $result = $servers.targets | ? {$_.InstanceName -eq $LimitedTarget.InstanceNameShouldBe} | % { Test-SentryOneTarget $_.ServerName $_.InstanceName $_.UserName $_.Password $_.SQLPort}
        $result.ServerName | Should Be $LimitedTarget.ServerNameShouldBe
        $result.InstanceName | Should Be $LimitedTarget.InstanceNameShouldBe
        $result.IsSqlPortOpen | Should Be $true
        $result.IsSQLSysAdmin | Should Be $true
        $result.SentryOneMode | Should Be "Limited"
    }
}

Describe "Unreachable Sentry One Targets" {
    It "Should fail to validate an unreacheable server" {
        try {
            $result = $servers.targets | ? {$_.ServerName -eq $UnreacheableTarget.InstanceNameShouldBe}  | % { Test-SentryOneTarget $_.ServerName $_.InstanceName $_.UserName $_.Password $_.SQLPort }
        } catch {
            $Error[0].Exception.InnerException.Message.StartsWith("A connection attempt failed because the connected party did not properly respond after a period of time, or established connection failed because connected host has failed to respond") | Should Be True
        }     
    }
}
