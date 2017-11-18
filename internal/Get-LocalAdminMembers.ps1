Function Get-LocalAdminMembers
{
    [cmdletbinding()]
    param (
        [parameter(Mandatory=$true)]$ComputerName
    )
    $admins = Gwmi win32_groupuser -computer $ComputerName  
    $admins = $admins | ? {$_.groupcomponent -like '*"Administrators"'}  
  
    return $admins | foreach {  
        $_.partcomponent -match ".+Domain\=(.+)\,Name\=(.+)$" > $nul  
        $matches[1].trim('"') + "\" + $matches[2].trim('"')  
    }  
}