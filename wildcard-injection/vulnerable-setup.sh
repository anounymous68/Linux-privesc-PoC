#!/usr/bin/env bash
#
# =============================================================================
#  WARNING — AUTHORIZED LAB / EDUCATIONAL USE ONLY
# =============================================================================
#  This script installs a deliberately vulnerable root cron job that runs
#  `tar ... *` on a world-writable directory. For isolated lab VMs only.
#  Do NOT deploy on production systems or shared hosts.
# =============================================================================

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[!] Run as root: sudo $0"
  exit 1
fi

STAGING_DIR="/var/lib/lab-wildcard-staging"
BACKUP_DIR="/var/backups"
BACKUP_FILE="${BACKUP_DIR}/lab-wildcard.tar.gz"
BACKUP_SCRIPT="/usr/local/sbin/lab-wildcard-backup.sh"
CRON_FILE="/etc/cron.d/lab-wildcard-backup"

echo "[*] Wildcard Injection lab — installing vulnerable backup job"

# World-writable staging directory (intentionally insecure for the lab)
mkdir -p "${STAGING_DIR}" "${BACKUP_DIR}"
chmod 1777 "${STAGING_DIR}"

# Seed with a benign file so tar has something to archive before exploitation
echo "lab placeholder data" > "${STAGING_DIR}/readme.txt"
chmod 644 "${STAGING_DIR}/readme.txt"

# -----------------------------------------------------------------------------
# Vulnerable backup script: cd into attacker-influenced dir and run tar with *
# Shell expands * BEFORE tar parses arguments — classic wildcard injection.
# -----------------------------------------------------------------------------
cat > "${BACKUP_SCRIPT}" <<EOF
#!/usr/bin/env bash
# Lab backup — intentionally vulnerable wildcard usage
set -e
cd "${STAGING_DIR}"
# BUG: unquoted * in world-writable directory
tar czf "${BACKUP_FILE}" *
EOF

chmod 755 "${BACKUP_SCRIPT}"
chown root:root "${BACKUP_SCRIPT}"

# Run every minute in the lab so students can wait for cron (exploit.sh also
# documents manual trigger via sudo for faster iteration)
cat > "${CRON_FILE}" <<EOF
# Lab wildcard injection demo — remove after practice
* * * * * root ${BACKUP_SCRIPT} >/var/log/lab-wildcard-backup.log 2>&1
EOF

chmod 644 "${CRON_FILE}"

echo "[+] Staging directory (world-writable): ${STAGING_DIR}"
echo "[+] Backup script: ${BACKUP_SCRIPT}"
echo "[+] Cron job: ${CRON_FILE} (runs every minute as root)"
echo ""
echo "Verify:"
echo "  ls -ld ${STAGING_DIR}"
echo "  cat ${BACKUP_SCRIPT}"
echo ""
echo "Next: as unprivileged user, run ./exploit.sh then wait for cron or run:"
echo "  sudo ${BACKUP_SCRIPT}"
