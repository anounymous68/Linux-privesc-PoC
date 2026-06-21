# PATH Hijacking

## Overview

The `PATH` environment variable tells the shell and many programs where to look for executables. Directories are searched **in order**, left to right. When a privileged program (SUID binary, root cron job, or setuid wrapper script) invokes another command **without an absolute path**—for example `ls` instead of `/bin/ls`—the runtime resolves that name using the **current process environment**, including `PATH`.

If an attacker can control or prepend a writable directory to `PATH`, they can place a malicious binary with the same name as the expected command. When the privileged program runs, it executes the attacker's binary **with elevated privileges**.

This is not a kernel bug; it is a **misconfiguration** pattern seen in custom SUID utilities, legacy admin scripts, and third-party installers that shell out to common tools without hardening the environment.

**Lab scenario:** A SUID-root helper binary calls `ls` to list a directory. Because it never resets `PATH` or uses `/bin/ls`, a local user can hijack `ls` and run arbitrary code as root.

---

## Detection

### Static analysis

Look for relative command invocations in SUID binaries and privileged scripts:

```bash
# List SUID binaries
find / -perm -4000 -type f 2>/dev/null

# Search for shell-outs to common commands (non-exhaustive)
strings /path/to/suid_binary | grep -E '^ls$|^cat$|^service$|^id$|^grep$'

# Broader search for system()/exec* patterns in strings output
strings /path/to/suid_binary | grep -E 'system\(|exec|/bin/sh'
```

Red flags:

- Calls to `system("ls ...")`, `popen("cat ...")`, or `execvp("service", ...)` without a leading `/`
- Scripts that run `command` instead of `/usr/bin/command`
- SUID programs that do **not** sanitize `PATH`, `LD_*`, or other environment variables at startup

### Dynamic analysis

Trace library calls to see which binaries are executed:

```bash
# Requires ltrace; run as the unprivileged lab user
ltrace -f -e execve /usr/local/bin/lab-path-helper /some/dir 2>&1 | grep execve
```

If `execve` resolves to a path under `/tmp`, `/home`, or another user-writable location, the binary is likely vulnerable.

### Manual checks

```bash
# Compare resolved path when PATH is manipulated
PATH=/tmp:$PATH which ls
readlink -f "$(which ls)"

# Inspect SUID ownership and permissions
ls -la /usr/local/bin/lab-path-helper
```

---

## Exploitation

**Prerequisites:** A SUID (or otherwise privileged) program that executes a command by **name only**, and a writable directory you can prepend to `PATH`.

### Steps

1. **Identify the hijackable command** — e.g. the SUID binary calls `ls` (see Detection).
2. **Choose a writable directory** — `/tmp/path-hijack-lab`, your home directory, or a world-writable path.
3. **Create a malicious replacement** — a script or binary named exactly `ls` that performs your proof-of-concept (write a root-owned marker file, run `id`, etc.).
4. **Prepend the directory to PATH** — `export PATH=/tmp/path-hijack-lab:$PATH`.
5. **Trigger the vulnerable program** — run the SUID helper normally; it will invoke your `ls` as root.

### Lab usage

From this directory, on an **isolated VM** with root access for setup:

```bash
# As root — install the vulnerable SUID helper
sudo ./vulnerable-setup.sh

# As an unprivileged lab user — run the exploit
./exploit.sh
```

Successful exploitation creates `/tmp/path-hijack-proof` owned by root, demonstrating privilege escalation without destructive side effects.

---

## Mitigation

| Control | Description |
|--------|-------------|
| **Use absolute paths** | Always invoke `/bin/ls`, `/usr/bin/id`, etc. Never rely on `PATH` in privileged code. |
| **Sanitize the environment** | At the start of SUID programs and setuid scripts, reset `PATH` to a known-safe value (e.g. `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`) and clear dangerous variables (`LD_PRELOAD`, `LD_LIBRARY_PATH`, `IFS`, etc.). |
| **Avoid `system()` / shells in SUID code** | Prefer direct `execve()` with full paths; avoid passing user input to shell interpreters. |
| **Drop privileges when possible** | Use `setuid()` / `seteuid()` to drop to an unprivileged user before calling external commands. |
| **Principle of least privilege** | Do not make binaries SUID unless strictly necessary; use file capabilities or polkit instead where appropriate. |
| **Audit and test** | Use `strings`, source review, and dynamic tracing (`ltrace`, `strace`) during development and CI for privileged components. |

Example environment hardening in C before calling external programs:

```c
char *safe_path = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";
setenv("PATH", safe_path, 1);
unsetenv("LD_PRELOAD");
unsetenv("LD_LIBRARY_PATH");
```

---

## References

- [GTFOBins — limited shell / SUID abuse patterns](https://gtfobins.github.io/)
- MITRE ATT&CK: [T1574.007 — Path Interception by PATH Environment Variable](https://attack.mitre.org/techniques/T1574/007/)
- [Linux man pages: environ(7), execve(2), path_resolution(7)](https://man7.org/linux/man-pages/)
- Historical examples: vulnerable `service` helpers, custom backup SUID tools, and installer scripts that call `chmod`/`chown` without absolute paths
