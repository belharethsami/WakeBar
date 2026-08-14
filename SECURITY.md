# Security

WakeBar's standard mode executes only the fixed system binary
`/usr/bin/caffeinate`. User input is converted to numeric timeout arguments; it
is never evaluated by a shell. The app has no network client, analytics, or
updater.

Closed-Lid Mode is optional and requires one-time administrator authorization.
Its sudoers rule permits only these literal commands:

```text
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -a disablesleep 1
```

The account name is validated before the rule is generated, the rule is Base64
encoded before entering the authorization shell command, and `visudo` validates
the temporary file before an atomic install with root ownership and mode `0440`.
No arbitrary arguments, shell, script, or app binary receives root permission.

The unprivileged `WakeBarGuard` launch agent can only invoke the exact disable
command granted above. It restores normal sleep if an ownership marker remains
but WakeBar's heartbeat is stale for at least 90 seconds. WakeBar also restores
sleep during normal session shutdown and on its next launch after an unclean
exit.

Please report vulnerabilities privately to the repository owner before opening
a public issue. Include the WakeBar version, macOS version, reproduction steps,
and expected impact.

Release maintainers should sign distributable builds with a Developer ID
Application certificate and submit them to Apple's notarization service.
