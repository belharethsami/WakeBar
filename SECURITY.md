# Security

WakeBar executes only the fixed system binary `/usr/bin/caffeinate`. User input
is converted to numeric timeout arguments; it is never evaluated by a shell.
The app has no network client, analytics, updater, privileged helper, or
administrator requirement.

Please report vulnerabilities privately to the repository owner before opening
a public issue. Include the WakeBar version, macOS version, reproduction steps,
and expected impact.

Release maintainers should sign distributable builds with a Developer ID
Application certificate and submit them to Apple's notarization service.
