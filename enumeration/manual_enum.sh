#!/usr/bin/env bash
#
# manual_enum.sh — Organized Linux privesc recon (run as unprivileged user)
# Output: stdout; pipe to a file for review: ./manual_enum.sh | tee ~/enum.txt
#

set -u

section() {
  # Print a visible section banner
  echo
  echo "=== $1 ==="
}

run_cmd() {
  # Echo the command, then run it (errors do not abort the script)
  echo "# $*"
  eval "$@" 2>&1 || true
  echo
}

section "IDENTITY"
run_cmd "id"
run_cmd "whoami"
run_cmd "groups"
run_cmd "hostname"
run_cmd "uname -a"

section "ENVIRONMENT"
run_cmd "env | sort"
run_cmd "echo PATH=\$PATH"
run_cmd "umask"

section "NETWORK"
run_cmd "ip -br a 2>/dev/null || ifconfig -a 2>/dev/null"
run_cmd "ss -tulpn 2>/dev/null || netstat -tulpn 2>/dev/null"
run_cmd "cat /etc/resolv.conf 2>/dev/null"

section "PROCESSES"
run_cmd "ps aux --sort=-%mem 2>/dev/null | head -20"

section "SUDO"
run_cmd "sudo -l"

section "SUID (setuid root, common paths first)"
run_cmd "find /usr /bin /sbin /opt /usr/local -perm -4000 -type f 2>/dev/null"
echo "# Full filesystem SUID scan (slow):"
run_cmd "find / -perm -4000 -type f 2>/dev/null | head -80"

section "SGID"
run_cmd "find /usr /bin /sbin /opt /usr/local -perm -2000 -type f 2>/dev/null"
run_cmd "find / -perm -2000 -type f 2>/dev/null | head -40"

section "CAPABILITIES"
run_cmd "getcap -r / 2>/dev/null | head -50"

section "CRON — current user"
run_cmd "crontab -l"

section "CRON — system"
run_cmd "ls -la /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly 2>/dev/null"
run_cmd "ls -la /var/spool/cron/crontabs 2>/dev/null"
run_cmd "grep -rEv '^#|^$' /etc/cron.d 2>/dev/null"

section "WRITABLE — sample sensitive locations"
run_cmd "find /etc -writable -type f 2>/dev/null | head -30"
run_cmd "find /usr/local/bin /opt /tmp -writable -type f 2>/dev/null | head -30"

section "INTERESTING FILES (readable)"
for f in /etc/passwd /etc/shadow /etc/sudoers /etc/group; do
  if [[ -r "$f" ]]; then
    run_cmd "ls -la $f"
  fi
done

section "HOME AND SSH"
run_cmd "ls -la ~/"
run_cmd "ls -la ~/.ssh 2>/dev/null"
run_cmd "find /home -name 'id_rsa' -o -name '*.pem' 2>/dev/null | head -20"

section "DOCKER / LXC hints"
run_cmd "id | grep -q docker && echo 'User in docker group' || true"
run_cmd "test -f /.dockerenv && echo 'Inside Docker container' || true"
run_cmd "systemd-detect-virt 2>/dev/null || true"

section "KERNEL"
run_cmd "cat /proc/version"
run_cmd "cat /etc/os-release 2>/dev/null"

echo "=== ENUM COMPLETE ==="
