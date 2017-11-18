Function Test-IsLocalAdmin
{
    [cmdletbinding()]
    param (
        [parameter(Mandatory=$true)]$ComputerName
    )
    
    $IsLocalAdmin = $false
    $adminMembers = Get-LocalAdminMembers $ComputerName
    $adminMembers | % {if ($_ -eq "$($env:USERDOMAIN)\$($env:USERNAME)") {$IsLocalAdmin = $true } }
    if (-not $IsLocalAdmin)
    {
        # we didn't find a local admin account explicitly, so let's enumerate the groups one level down
        $userMembers = Get-ADPrincipalGroupMembership -Identity $env:USERNAME | % { "$($env:USERDOMAIN)\$($_.Name)" }
        $IsLocalAdmin = (($userMembers | ? { $adminMembers -contains $_}).Count -gt 0)
    }
    return $IsLocalAdmin
}