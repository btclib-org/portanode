# Electrum Scripts (Linux)

Linux launch scripts for Electrum. Each script differs by network and
whether it restricts connections to a local Electrum server only.

## Differences by script

- `mainnet.sh`: Mainnet, standard server connections.
- `testnet3.sh`: Testnet3, standard server connections.
- `testnet4.sh`: Testnet4, standard server connections.
- `regtest.sh`: Regtest, standard server connections (typically local).
- `mainnet-local-server-only.sh`: Mainnet, connects only to a local
  Electrum server.

## Prerequisites

- Electrum AppImage in `linux/bin/electrum.AppImage`, where
  `linux/scripts/utilities/update-electrum.sh` installs it. The name is
  fixed and carries no version, matching `Electrum.app` and
  `electrum.exe` on the other two platforms.
- Data directory in `electrum-datadir/`, the same tree the macOS and
  Windows launchers pass to Electrum. It is not per-platform, so a wallet
  created under one launcher is the wallet the others open.
- For local server mode, a local Electrum server must be running.
- The kernel's `/dev/fuse`, readable and writable by the user starting
  the launcher, and a mount that permits execution: both below.

## Running two mainnet launchers against the same datadir

`mainnet.sh` and `mainnet-local-server-only.sh` pass the same
`--dir electrum-datadir` and open the identical mainnet state kept at
the top level of that directory: the two are alternatives for the same
network, not scripts meant to run together. Measured on a GitHub
Actions `ubuntu-latest` runner (run `32940638366`, jobs `scenario-live`,
`scenario-closed`, `scenario-killed`): starting
`mainnet-local-server-only.sh` while `mainnet.sh`'s own process is
still running produces no process of its own. What does *not* block
it: a `daemon` file and a `daemon_rpc_socket` a terminated first
instance leaves behind — confirmed present, unremoved, after both a
`SIGTERM` and a `SIGKILL` of the first instance's whole process tree —
do not stop the second launcher from starting cleanly against them. So
what decides whether the other can start is whether the first one's
process is still running, not whether an old socket file of its is
still on disk.

## What the AppImage needs from the machine

An AppImage mounts its own filesystem before any of the program inside it
runs, and this one does that through the kernel's `/dev/fuse`. FUSE 2 is
not the dependency: measured on a GitHub Actions `ubuntu-latest` runner
against `electrum-4.8.1-x86_64.AppImage`, `ldd` reports it "not a dynamic
executable" and `strings` shows it links `squashfuse` statically, so no
`libfuse.so` is ever loaded and installing `libfuse2t64` changes nothing.

Each launcher tests `/dev/fuse` for read and write access and stops with
its own message. Left to the AppImage the same two failures read, on the
same runner with `/dev/fuse` removed and with its mode set to `000`:

```text
fuse: device not found, try 'modprobe fuse' first
fuse: failed to open /dev/fuse: Permission denied
```

and each is followed by the AppImage runtime's own closing block, whole:

```text
Cannot mount AppImage, please check your FUSE setup.
You might still be able to extract the contents of this AppImage
if you run it with the --appimage-extract option.
See https://github.com/AppImage/AppImageKit/wiki/FUSE
for more information
```

The exit code there is 127. Of that block the launchers keep the middle
and drop the end: extraction needs no privilege, where the FUSE page's
remedy is installing `libfuse2t64`, the library the paragraph above
measures this binary as never loading.

What a launcher names is `--appimage-extract-and-run` rather than the
`--appimage-extract` the runtime suggests, that being one step where the
suggestion is two, and it prints the whole command with the arguments it
would have passed, so that a reader has something to run rather than
something to assemble. Measured on the same runner with `/dev/fuse` moved
out of the way entirely,
`electrum.AppImage --appimage-extract-and-run --version` reached
Electrum's own code and answered
`Daemon not running; try 'electrum daemon -d'`. That is `--version` and
not a window: what it establishes is that the AppImage runs without the
device, not that a session does.

The launcher names that route rather than taking it. Unpacking the whole
AppImage into a temporary directory on every start is the slower path,
and a launcher that quietly chose it would leave a machine whose FUSE
setup is broken looking as though it were not — the setup being the thing
worth repairing. `update-electrum.sh` rejected an extracted *install* on
different grounds, the `__pycache__` files Python writes on first run
invalidating a checksum recorded at install time; that reasoning does not
reach a transient unpacking nothing records a checksum for, so the ground
here is its own.

The AppImage also has to be executable where it sits.
`update-electrum.sh` sets the bit after installing, but a copy made
another way may not carry it, and a volume mounted `noexec` refuses the
exec whichever bit is set — measured the same way, `test -x` answers
false and the exec fails with `Permission denied` and exit code 126 in
both cases, so the launchers' one test covers both. On the default
`exfat-fuse` mount measured here the test cannot fail: every file reads
`-rwxrwxrwx` whatever it carried before the copy, and `chmod` returns 0
without changing the mode, exFAT storing no POSIX mode to change. That
says nothing about an exFAT volume mounted `noexec`, or with a `umask` or
`fmask` that clears the bit, both of which the driver accepts; the
remount that would have measured one failed with the volume busy, so it
is untested rather than ruled out.

Electrum's graphical toolkit needs libraries of the machine's own, and
the launchers do not check for them. On a runner with no graphics stack
the AppImage mounts and Electrum starts, then exits reporting
`ImportError: libEGL.so.1: cannot open shared object file`; installing
`libegl1` and the Qt libraries beside it was enough for the same launcher
to run under `xvfb` with no Qt platform error. It is left unchecked
because that message names the missing library outright and needs nothing
added to it, where the FUSE one closes on a remedy that does not apply to
this binary.
