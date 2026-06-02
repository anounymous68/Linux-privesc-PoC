# Sudo Misconfiguration Lab

## Vulnerability description

`sudo` allows administrators to delegate commands to users. Common misconfigurations exploited in assessments include:

| Misconfiguration | Risk |
|------------------|------|
| `NOPASSWD` on editors or shells | Immediate command execution as root without password |
| `NOPASSWD: /usr/bin/find` (and similar) | GTFOBins-style escape to shell |
| `env_keep+=LD_PRELOAD` | Inject shared libraries into privileged sudo commands |
| `SETENV` / wildcards | Environment variable abuse |

This lab adds a **NOPASSWD** rule allowing `labuser` to run `/usr/bin/find` as root — a classic GTFOBins vector.

## Prerequisites

- Root to run `setup.sh`
- User `labuser` must exist (`useradd -m labuser`)
- `sudo` package installed

## Reproduction steps

### Setup (as root)

```bash
cd sudo-misconfig
chmod +x setup.sh exploit.sh
sudo ./setup.sh
```

### Exploit (as labuser)

```bash
su - labuser
cd /path/to/privesc-linux/sudo-misconfig
./exploit.sh
```

## Expected output

**setup.sh:**

```
[*] Creating sudoers drop-in: /etc/sudoers.d/99-privesc-lab-find
[*] Validating with visudo...
[*] labuser may run: sudo -l  →  NOPASSWD: /usr/bin/find
```

**exploit.sh:**

```
[*] Checking sudo -l for find...
User labuser may run ... NOPASSWD: /usr/bin/find
[*] Launching root shell via sudo find -exec ...
# id
uid=0(root) gid=0(root) groups=0(root)
```

## Additional vectors (study)

```bash
# Always enumerate
sudo -l

# env_keep abuse — see ld-preload module
sudo -l | grep -i env_keep
```

## Mitigation

- **Never grant NOPASSWD** to shells, interpreters, `find`, `vim`, `less`, `awk`, `python`, or wildcard paths
- **Use role-based sudoers** with fully qualified command arguments and `!` negation where supported
- **Remove `env_keep+=LD_PRELOAD`** and `SETENV` unless strictly required; prefer `Defaults !env_reset` policies per site standard
- **Centralize sudoers** in configuration management; run `visudo -c` in CI
- **Logging** — ship `/var/log/auth.log` to SIEM; alert on first-time `sudo` GTFOBins patterns
- **Cleanup** — remove `/etc/sudoers.d/99-privesc-lab-find` after the lab
