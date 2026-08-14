# Contributing

Contributions are welcome. Please keep WakeBar dependency-free and avoid adding
network access or widening the two-command closed-lid privilege boundary unless
a proposal has first been discussed.

Before opening a pull request, run:

```sh
make test
make integration-test
```

Changes to session behavior should include a focused unit test. Changes to the
packaged app should preserve `LSUIElement`, the fixed caffeinate path, and the
parent-process watch that prevents orphaned assertions.

Closed-lid changes must also preserve exact sudoers arguments, `visudo`
validation, kernel-state verification, heartbeat cleanup, the battery floor,
and Low Power Mode cutoff.
