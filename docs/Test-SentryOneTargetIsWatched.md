# Test-SentryOneTargetIsWatched

Connects to Sentry One and checks to see if the server and SQL Server instance are currently being watched.

Invoke the function with:

```
Test-SentryOneTargetIsWatched
  -ServerName <String>
  [-InstanceName <String>]
  -SentryOneServerName <String>
  -SentryOneDatabaseName <String>
  [-SentryOneInstallationPath <String>]
  [<CommonParameters>]
```

## Description

The function `Test-SentryOneTargetIsWatched` will connect to Sentry One and determine if the **ServerName** and **InstanceName** in Sentry One is registered and watched. Fully qualified domain names need to be used to connect to Sentry One targets. The function does not connect to the targets.

Function is useful to run after you've registered a list of servers from a JSON file. Pipe the same JSON file to this function to check everything is working OK. 

## Examples

### Example 1: Test if a default instance is being watched

```PowerShell
Test-SentryOneTargetIsWatched -ServerName SQLSERVERBOX.MYDOMAIN.LOCAL -SentryOneServerName SENTRYONE.MYDOMAIN.LOCAL -SentryOneDatabaseName SentryOne
```

### Example 2: Test if a named instance is being watched

```PowerShell
Test-SentryOneTargetIsWatched -ServerName SQLSERVERBOX.MYDOMAIN.LOCAL -InstanceName SQLSERVERBOX.MYDOMAIN.LOCAL\A -SentryOneServerName SENTRYONE.MYDOMAIN.LOCAL -SentryOneDatabaseName SentryOne
```

## Outputs

**PSCustomObject**

A **PSCustomObject** with the following properties is returned

* **ServerName**: the server name - useful when analysing a batch of servers from a json file.
* **InstanceName**: The named instance - useful when analysing a batch of servers from a json file.
* **ServerIsRegistered**: Pass or Fail. Machine was found in Sentry One
* **InstanceIsRegistered**: Pass or Fail. Instance was found in Sentry One
* **InstanceIsWatchedBy**: EventManager,PerformanceAdvisor or Fail. The instance is now being watched by EventManager and/or PerformanceAdvisor.

### Example output

```
ServerName           : SQLSERVERBOX.MYDOMAIN.LOCAL
InstanceName         : SQLSERVERBOX.MYDOMAIN.LOCAL\A
ServerIsRegistered   : True
InstanceIsRegistered : True
InstanceIsWatchedBy  : EventManager, PerformanceAdvisor
```

## Registering and watching a list of servers

If you have a list of servers in Sentry One you want to check, then put them all in a JSON configuration file like the one supplied `serverlist.json` and then process it like so:

```PowerShell
$servers = Get-Content .\serverlist.json -Raw -Encoding UTF8 | ConvertFrom-Json

$servers.targets | % { Test-SentryOneTargetIsWatched $_.ServerName $_.InstanceName $servers.SentryOneServer $servers.SentryOneDatabase }
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
