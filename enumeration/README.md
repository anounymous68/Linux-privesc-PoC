# Enumeration — Linux Privilege Escalation Recon

Systematic enumeration is the foundation of privilege escalation. This module covers automated scanning with **LinPEAS** and structured manual checks.

## Vulnerability description

Privilege escalation rarely starts with a single exploit command. Attackers (and defenders in purple-team exercises) map:

- **Identity and context** — current user, groups, `id`, home directory
- **Misconfigured binaries** — SUID/SGID, capabilities, world-writable paths
- **Sudo policy** — `sudo -l`, `NOPASSWD`, dangerous `env_keep`
- **Scheduled tasks** — user and system crontabs, writable cron directories
- **Secrets and configs** — readable `.env`, SSH keys, database creds in world-readable files

Enumeration does not exploit a flaw by itself; it **surfaces** misconfigurations documented in the other lab modules.

## Prerequisites

- Linux VM with network access to download LinPEAS (or copy script offline)
- Non-root user for realistic recon (`labuser` recommended)
- Optional: `curl`, `wget`, `find`, `grep`, `getcap`

## Reproduction steps

### 1. Automated — LinPEAS

```bash
# Download latest linpeas (verify checksum in production labs)
curl -L https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh -o /tmp/linpeas.sh
chmod +x /tmp/linpeas.sh

# Run as current user; redirect output for review
/tmp/linpeas.sh | tee ~/linpeas-$(hostname)-$(date +%Y%m%d).txt
```

**What to look for** in LinPEAS output (also trained by `manual_enum.sh`):

- Yellow/red **SUID** binaries not in default baselines
- **sudo** lines: `(ALL) NOPASSWD`, `SETENV`, `env_keep+=LD_PRELOAD`
- **Cron** jobs running as root with writable scripts
- **Capabilities** (`cap_setuid`, `cap_dac_override`, etc.)
- World-writable **`/etc/passwd`** or suspicious PATH directories

### 2. Manual — organized script

```bash
chmod +x manual_enum.sh
./manual_enum.sh | tee ~/manual-enum.txt
```

Review each section in the output file. Cross-reference findings with lab modules (`suid-sgid`, `sudo-misconfig`, etc.).

### 3. Targeted one-liners (reference)

```bash
# SUID binaries
find / -perm -4000 -type f 2>/dev/null

# SGID binaries
find / -perm -2000 -type f 2>/dev/null

# Sudo privileges
sudo -l 2>/dev/null

# Current user crontab
crontab -l 2>/dev/null

# System cron
ls -la /etc/cron.* /var/spool/cron/ 2>/dev/null

# Writable files owned by others in sensitive dirs (sample)
find /etc /usr/local/bin /opt -writable -type f 2>/dev/null | head -50

# Capabilities
getcap -r / 2>/dev/null
```

## Expected output

- **LinPEAS:** Colorized sections (PEASS-ng version dependent) highlighting "95% PE" style findings when misconfigs exist
- **manual_enum.sh:** Section headers (`=== IDENTITY ===`, `=== SUID ===`, etc.) with command output or `[empty]` / permission denied markers
- After running other lab `setup.sh` scripts, enumeration should **surface** the planted SUID binary, sudo rules, cron entries, and LD_PRELOAD vectors

Example snippet after SUID lab setup:

```
=== SUID (setuid root, sample paths) ===
/usr/local/bin/privesc-suid-lab
```

## Mitigation

- **Principle of least privilege** — remove unnecessary SUID/SGID binaries; use capabilities sparingly with documented justification
- **Sudo hardening** — avoid `NOPASSWD` for shells/editors; restrict `env_keep`; use `sudoers` versioning and `visudo` audits
- **Cron** — root jobs must reference absolute paths; scripts owned by root and not group-writable; audit `/etc/cron.*`
- **Filesystem** — deploy immutable baselines (AIDE, Tripwire) and periodic `find` audits for new SUID files
- **Detection** — monitor for LinPEAS-like script names, mass `find /` from user contexts, and anomalous `sudo -l` enumeration
- **Training** — run enumeration in CI/CD golden images to catch regressions before production
