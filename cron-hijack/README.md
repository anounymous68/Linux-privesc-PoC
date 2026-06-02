# Cron Job Hijack Lab

## Vulnerability description

Scheduled tasks running as **root** are high-value targets. Common flaws:

- **World-writable scripts** referenced by cron
- **Relative paths** in cron entries without a fixed `PATH`
- **Overly permissive directories** under `/etc/cron.daily` or custom `/opt` job paths

This lab creates a root cron job that executes a script in a directory writable by `labuser`, allowing replacement of the script with a payload that runs as root on the next interval.

## Prerequisites

- Root for `setup.sh`
- User `labuser` for `exploit.sh`
- Cron daemon running (`systemctl status cron` or `crond`)

## Reproduction steps

### Setup (as root)

```bash
cd cron-hijack
chmod +x setup.sh exploit.sh
sudo ./setup.sh
```

### Exploit (as labuser)

```bash
su - labuser
cd /path/to/privesc-linux/cron-hijack
./exploit.sh
```

Wait up to one minute for the cron interval, or check logs.

## Expected output

**setup.sh:**

```
[*] Job script: /opt/privesc-lab-cron/run.sh (writable by labuser)
[*] Cron entry: /etc/cron.d/privesc-lab (every minute)
```

**exploit.sh:**

```
[*] Replacing run.sh with payload...
[*] Waiting for root cron execution (up to 90s)...
[+] Root shell marker created: /tmp/privesc-cron-root.txt
```

Verify:

```bash
cat /tmp/privesc-cron-root.txt
# uid=0(root) gid=0(root) groups=0(root)
```

## Mitigation

- **Cron scripts** must be owned by root, mode `755` or `750`, and **not** writable by group/other
- **Use absolute paths** in crontab; set explicit `PATH=` in cron file header
- **Avoid running** root jobs from world-writable directories (`/tmp`, `/var/tmp`)
- **File integrity monitoring** on `/etc/cron.d`, `/etc/crontab`, and `/var/spool/cron`
- **Principle of least privilege** — run services as dedicated users, not root, when possible
- **Cleanup** — `rm -f /etc/cron.d/privesc-lab; rm -rf /opt/privesc-lab-cron /tmp/privesc-cron-root.txt`
