# SUID / SGID Misconfiguration Lab

## Vulnerability description

When a binary has the **setuid** bit set and is owned by root, it executes with the **effective UID of the file owner** (root), not the invoking user. If the program invokes a shell, runs external commands with insufficient sanitization, or allows arbitrary file operations, a local user can obtain a root shell.

This lab installs a deliberately vulnerable helper binary that calls `/bin/sh` without dropping privileges safely.

## Prerequisites

- Root access to run `setup.sh`
- Low-privilege user `labuser` (or any non-root account) for `exploit.sh`
- `gcc` on the target system (setup compiles the binary)

## Reproduction steps

### Setup (as root)

```bash
cd suid-sgid
chmod +x setup.sh exploit.sh
sudo ./setup.sh
```

### Exploit (as labuser)

```bash
su - labuser
cd /path/to/privesc-linux/suid-sgid
./exploit.sh
```

## Expected output

**setup.sh:**

```
[*] Compiling vulnerable SUID binary...
[*] Installed: /usr/local/bin/privesc-suid-lab (mode 4755)
[*] Run exploit as non-root: ./exploit.sh
```

**exploit.sh:**

```
[*] Invoking SUID binary: /usr/local/bin/privesc-suid-lab
[*] Effective UID should become 0 (root)
# id
uid=0(root) gid=1000(labuser) groups=...
```

A root shell (`#` prompt) or `uid=0(root)` from `id` confirms success.

## Mitigation

- **Avoid SUID** where possible; use polkit, capabilities, or dedicated daemons with IPC
- **Audit SUID inventory** — `find / -perm -4000 -type f` on golden images; alert on changes
- **Strip SUID** from interpreters and utilities (`python`, `vim`, `find`, etc.) per vendor guidance
- **Code review** setuid programs for safe privilege separation (drop privileges immediately after needed operations)
- **Filesystem controls** — mount `/usr` with `nosuid` where compatible; use AppArmor/SELinux profiles
- **Remove lab artifact** — `rm -f /usr/local/bin/privesc-suid-lab` and delete `labuser` when finished
