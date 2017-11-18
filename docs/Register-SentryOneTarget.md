# Register-SentryOneTarget

Registers a Sentry One Windows machine and SQL Server instance with Sentry One and then watches it.

Invoke the function with:

```
Register-SentryOneTarget
  -ServerName <String>
  [-InstanceName <String>]
  [-UserName <String>]
  [-Password <String>]
  -SentryOneServerName <String>
  -SentryOneDatabaseName <String>
  [-SentryOneMode <String>]
  [-SentryOneSite <String>]
  [-SentryOneInstallationPath <String>]
  [<CommonParameters>]
```

## Description

The function `Register-SentryOneTarget` will connect to Sentry One and attempt to register the **ServerName** and **InstanceName** in Sentry One in Full or Limited mode. Fully qualified domain names need to be used to connect to Sentry One targets. If you need to use Limited mode then you must specify it with parameter **-SentryOneMode Limited**. Optionally the target can be placed in a Sentry One *Site*, if omitted the *Default Site* is used. 

## Examples

### Example 1: Register and watch a default instance with Windows Authentication

```PowerShell
Register-SentryOneTarget -ServerName SQLSERVERBOX.MYDOMAIN.LOCAL -SentryOneServerName SENTRYONE.MYDOMAIN.LOCAL -SentryOneDatabaseName SentryOne
```

This command registers the server called SQLSERVERBOX with Windows Authentication and assumes a default instance. Sentry One then starts watching it.

### Example 2: Register and watch a named instance with Windows Authentication in a *Site* called **Test**.

```PowerShell
Register-SentryOneTarget -ServerName SQLSERVERBOX.MYDOMAIN.LOCAL -InstanceName SQLSERVERBOX.MYDOMAIN.LOCAL\A -SentryOneServerName SENTRYONE.MYDOMAIN.LOCAL -SentryOneDatabaseName SentryOne -SentryOneSite Test
```

Registers the server called SQLSERVERBOX and the named instance SQLSERVERBOX\A using Windows Authentication. 

### Example 3: Register and watch a named instance with SQL Authentication in Limited Mode

```PowerShell
Register-SentryOneTarget -ServerName SQLSERVERBOX.MYDOMAIN.LOCAL -InstanceName SQLSERVERBOX.MYDOMAIN.LOCAL\A -UserName sentryoneuser -Password Sup3rStrongP@ssw0rd -SentryOneServerName SENTRYONE.MYDOMAIN.LOCAL -SentryOneDatabaseName SentryOne -SentryOneMode Limited
```

Registers and watches the server SQLSERVERBOX and named instance SQLSERVERBOX\A with SQL Authentication in **Limited** mode.

## Outputs

**PSCustomObject**

A **PSCustomObject** with the following properties is returned

* **ServerName**: the server name - useful when registering a batch of servers from a json file.
* **InstanceName**: The named instance - useful when registering a batch of servers from a json file.
* **RegisterComputer**: Pass or Fail. Registration of the machine.
* **RegisterConnection**: Pass or Fail. Registration of the instance (called a Connection in SentryOne).
* **WatchComputer**: Pass or Fail. The machine is now being watched.
* **WatchConnection**: Pass or Fail. The instance is now being watched.

### Example output

```
ServerName         : SQLSERVERBOX.MYDOMAIN.LOCAL
InstanceName       : SQLSERVERBOX.MYDOMAIN.LOCAL\A
RegisterComputer   : Pass
RegisterConnection : Pass
WatchComputer      : Pass
WatchConnection    : Pass
```

## Registering and watching a list of servers

If you have a list of servers to add to Sentryh One, then put them all in a JSON configuration file like the one supplied `serverlist.json` and then process it like so:

```PowerShell
$servers = Get-Content .\serverlist.json -Raw -Encoding UTF8 | ConvertFrom-Json

$servers.targets | % { Register-SentryOneTarget $_.ServerName $_.InstanceName $_.UserName $_.Password $servers.SentryOneServer $servers.SentryOneDatabase }
```

## Unit test samples

Some sample unit tests are available in `Register-SentryOneTarget.Tests.ps1` file.

These can be run with:

```PowerShell
Invoke-Pester .\Register-SentryOneTarget.Tests.ps1
```

you should see output similar to:

```
Describing Testing all servers are unregistered first
 [+] Should check that all servers are unregistered 199ms
Describing Registering and watching servers
 [+] Servers in list should be registered 209.6s
 [+] Instances in list should be registered 35ms
 [+] Instances in list should be watched by PerformanceAdvisor 27ms
 [+] Instances in list should be watched by EventManager 47ms
Tests completed in 209.91s
Passed: 5 Failed: 0 Skipped: 0 Pending: 0 Inconclusive: 0
```
## Windows versions

Tested against:

* Windows Server 2012 R2, Windows Server 2016
* Windows 10

It may work on earlier versions of Windows, but this hasn't been tested.
