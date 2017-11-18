# Test-SentryOneTarget

Tests a remote machine to make sure all the firewall ports, permissions, WMI, perfmon is accessible to allow SentryOne to monitor it.

Invoke the function with:

```
Test-SentryOneTarget
  -ServerName <String>
  [-InstanceName <String>]
  [-UserName <String>]
  [-Password <String>]
  [-SQLPort <Int>]
  [<CommonParameters>]
```

## Description

The function `Test-SentryOneTarget` is designed to test that the requirements are met for SentryOne to be able to connect to a SQL Server target in **Full Mode**. If the tests pass this means that Sentry One will be able to display and save both Windows performance metrics and SQL Server metrics.

If the SQLSysadmin test passes but others fail, then SentryOne will be able to connect in **Limited Mode** which means that the Windows performance metrics will not be gathered, only the SQL Server ones.

Requirements for **Full Mode**:

### [Permissions](https://cdn.sentryone.com/help/qs/webframe.html?Performance%20Advisor%20Required%20Ports.html#Performance_Advisor_Security_Requirements.html)

The Sentry One Service account and user running the Sentry One client needs to be

* Member of local Administrators group
* Member of the sysadmin fixed server role in each SQL Server instance on that host

### [Required ports](https://cdn.sentryone.com/help/qs/webframe.html?Performance%20Advisor%20Required%20Ports.html#Performance%20Advisor%20Required%20Ports.html)

* tcp 1433 (or whatever port is used by SQL Server of Azure SQL DB)
* tcp 445 (SMB, RPC/NP)
* tcp 135 (RPC) **and** the relevant dynamic ports - see Required Ports link above

## Examples

### Example 1: Test a default instance with Windows Authentication

```PowerShell
Test-SentryOneTarget -ServerName SQLSERVERBOX
```

This command tests the server called SQLSERVERBOX with Windows Authentication and assumes a default instance.

### Example 2: Test a named instance with Windows Authentication

```PowerShell
Test-SentryOneTarget -ServerName SQLSERVERBOX -InstanceName SQLSERVERBOX\A -SQLPort 2000
```

Tests the server called SQLSERVERBOX and the named instance SQLSERVERBOX\A listening on a static port 2000 using Windows Authentication. See the SQL Server documentation for information on how to configure static ports for named instances.

### Example 3: Test a named instance with SQL Authentication

```PowerShell
Test-SentryOneTarget -ServerName SQLSERVERBOX -InstanceName SQLSERVERBOX\A -UserName sentryoneuser -Password Sup3rStrongP@ssw0rd -SQLPort 2000
```

Connects to the server SQLSERVERBOX and named instance SQLSERVERBOX\A with SQL Authentication on port 2000.

## Outputs

**PSCustomObject**

A **PSCustomObject** with the following properties is returned

* **PerfmonTest**: True or False indicates whether perfmon counters can be gathered
* **ServerName**: the server name - useful when analysing a batch of servers from a json file.
* **InstanceName**: The named instance - useful when analysing a batch of servers from a json file.
* **IsPort135Open**: True or False
* **IsLocalAdmin**: True or False. The logged in account is a member of Administrators group on the target
* **IsPort445Open**: True or False
* **IsSQLSysAdmin**: True or False. Windows Auth: logged on account is in sysadmin role in SQL Server. SQL Auth: the **-UserName** login is in sysadmin role in SQL Server.
* **IsSqlPortOpen**: True or False
* **IpAddress**: xx.xx.xx.xx. Returns the IP Address of the **-ServerName** to make sure name resolution is working.
* **WMITest**: True or False. WMI is running and responding.

### Example output

```
PerfmonTest   : True
ServerName    : SQLSERVERBOX
InstanceName  : SQLSERVERBOX\A
IsPort135Open : True
IsLocalAdmin  : True
IsPort445Open : True
IsSQLSysAdmin : True
IsSqlPortOpen : True
IpAddress     : 10.0.12.64
WMITest       : True
```

## Notes

* This script depends on the **SQLServer** PowerShell module. Install it from the [PowerShell gallery](https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-ps-module) with:

```PowerShell
Install-Module -Name SqlServer
Import-Module SqlServer
```

* When testing named instances, if they are using dynamic ports, you will have to find out what port this is first by looking at the SQL Server error log, or SQL Server Configuration Manager manually. This tool cannot determine the dynamic port number remotely.
* Be careful with RPC dynamic ports for WMI access. Some intelligent firewalls fail to open the agreed port properly and require careful configuration.
* Using the **-Verbose** parameter will show detailed information as the script is running.

## Processing a list of servers

If you have a list of servers to process, then put them all in a JSON configuration file like the one supplied `serverlist.json` and then process it like so:

```PowerShell
$servers = Get-Content .\serverlist.json -Raw -Encoding UTF8 | ConvertFrom-Json

$servers.targets | foreach { Test-SentryOneTarget $_.ServerName $_.InstanceName $_.UserName $_.Password $_.SQLPort }
```

## Unit test samples

Some sample unit tests are available in `Test-SentryOneTarget.Tests.ps1` file.

These can be run with:

```PowerShell
Invoke-Pester .\Test-SentryOneTarget.Tests.ps1
```

you should see output similar to:

```
Describing Validate test json config
 [+] Should have 4 servers to test with 139ms
Describing Test Full sentry one targets
 [+] Should validate where json only contains servername 975ms
 [+] Should validate against named instance with SQL Authentication 497ms
 [+] Should validate against named instance with Windows Authentication 728ms
Describing Test Limited Sentry One Targets
Describing Unreachable Sentry One Targets
 [+] Should fail to validate an unreacheable server 21.16s
Tests completed in 23.5s
Passed: 5 Failed: 0 Skipped: 0 Pending: 0 Inconclusive: 0
```
## Windows versions

Tested against:

* Windows Server 2012 R2, Windows Server 2016
* Windows 10

It may work on earlier versions of Windows, but this hasn't been tested.
