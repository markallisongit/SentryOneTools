Function Test-IsRSATInstalled
{
    if ((Get-WmiObject -Class Win32_OperatingSystem).Caption -match "Server")
    {
        return (Get-WindowsFeature -Name RSAT).Installed
    }
    else
    {
        return ((Get-WindowsOptionalFeature -online -FeatureName RSATClient).State -eq "Enabled")
    }
}