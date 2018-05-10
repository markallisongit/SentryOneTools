# Sentry One Tools

A set of functions to help automate Sentry One configuration and targets. Includes the following functions

## [Test-SentryOneTarget](docs/Test-SentryOneTarget.md)

Tests a remote machine to make sure all the firewall ports, permissions, WMI, perfmon is accessible to allow SentryOne to monitor it.

## [Register-SentryOneTarget](docs/Register-SentryOneTarget.md)

Registers a Sentry One Windows machine and SQL Server instance with Sentry One and then watches it.

## [Test-SentryOneTargetIsWatched](docs/TestSentryOneTargetIsWatched)

Connects to Sentry One and checks to see if the server and SQL Server instance are currently being watched.

