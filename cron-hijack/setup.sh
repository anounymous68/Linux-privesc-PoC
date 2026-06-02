#!/usr/bin/env bash
#
# setup.sh — Root cron executing a labuser-writable script (run as root)
#

set -euo pipefail

CRON_FILE="/etc/cron.d/privesc-lab"
JOB_DIR="/opt/privesc-lab-cron"
JOB_SCRIPT="${JOB_DIR}/run.sh"
LAB_USER="${LAB_USER:-labuser}"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[-] Run as root: sudo $0"
  exit 1
fi

if ! id "${LAB_USER}" &>/dev/null; then
  useradd -m -s /bin/bash "${LAB_USER}"
fi

echo "[*] Creating job directory (intentionally group-writable)..."
mkdir -p "${JOB_DIR}"

# Benign script initially — labuser will overwrite via exploit
cat > "${JOB_SCRIPT}" <<'EOF'
#!/bin/bash
# Legitimate-looking backup stub
/usr/bin/logger -t privesc-lab-cron "cron job ran"
EOF

chmod 777 "${JOB_DIR}"
chmod 666 "${JOB_SCRIPT}"
chown root:"${LAB_USER}" "${JOB_SCRIPT}" 2>/dev/null || chmod 777 "${JOB_SCRIPT}"

echo "[*] Installing cron drop-in: ${CRON_FILE}"
cat > "${CRON_FILE}" <<EOF
# Privesc lab — runs every minute as root
* * * * * root ${JOB_SCRIPT}
EOF

chmod 644 "${CRON_FILE}"

echo "[*] Job script: ${JOB_SCRIPT} (writable by ${LAB_USER})"
echo "[*] Cron entry: ${CRON_FILE}"
echo "[*] Cleanup: rm -f ${CRON_FILE}; rm -rf ${JOB_DIR} /tmp/privesc-cron-root.txt"
