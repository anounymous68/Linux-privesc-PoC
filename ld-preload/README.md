# LD_PRELOAD Injection Lab

## Vulnerability description

`LD_PRELOAD` forces the dynamic linker to load a specified shared library before others. When **sudo** is configured with `env_keep+=LD_PRELOAD` (or `SETENV`), a user can inject a malicious `.so` that runs **as root** when they execute an allowed sudo command.

The malicious library overrides `geteuid()` (and related checks) so the target program believes it is unprivileged while attacker code runs with elevated privileges, or spawns a root shell from a constructor (`__attribute__((constructor))`).

## Prerequisites

- Root for `setup.sh`
- `gcc`, `libpam0g-dev` not required — only standard libc
- User `labuser`
- Target command: `/usr/bin/cat` allowed via sudo with `env_keep`

## Reproduction steps

### Setup (as root)

```bash
cd ld-preload
chmod +x setup.sh exploit.sh
sudo ./setup.sh
```

This compiles `malicious.c` to `/tmp/privesc-lab.so` and configures sudoers.

### Exploit (as labuser)

```bash
su - labuser
cd /path/to/privesc-linux/ld-preload
./exploit.sh
```

## Expected output

**setup.sh:**

```
[*] Compiling malicious.so ...
[*] Sudoers: env_keep+=LD_PRELOAD, NOPASSWD /usr/bin/cat
```

**exploit.sh:**

```
[*] LD_PRELOAD=/tmp/privesc-lab.so sudo /usr/bin/cat /etc/shadow
# (or root shell from constructor, depending on libc/sudo version)
```

On success, `id` shows `uid=0(root)` or sensitive files become readable.

> **Note:** Behavior varies by sudo version, PAM, and secure linking. This lab documents the **concept**; some hardened systems block `LD_PRELOAD` for setuid/sudo binaries.

## Mitigation

- **Remove `env_keep+=LD_PRELOAD`** from `/etc/sudoers` and drop-ins
- **Defaults secure_path** and avoid `SETENV` on user-editable environments
- **Use `sudo -H`** and minimal `env_reset` (distribution defaults often reset env)
- **Hardening** — `NoNewPrivs`, seccomp, and recent sudo versions restrict library injection
- **Detection** — monitor for `LD_PRELOAD=` in process environments of sudo children
- **Cleanup** — `rm -f /etc/sudoers.d/99-privesc-lab-ldpreload /tmp/privesc-lab.so`
