#!/usr/bin/env bash
#
# setup.sh — Adds vulnerable sudo rule for labuser (run as root)
#

set -euo pipefail

SUDOERS_FILE="/etc/sudoers.d/99-privesc-lab-find"
LAB_USER="${LAB_USER:-labuser}"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[-] Run as root: sudo $0"
  exit 1
fi

if ! id "${LAB_USER}" &>/dev/null; then
  echo "[*] Creating user ${LAB_USER}..."
  useradd -m -s /bin/bash "${LAB_USER}" || true
fi

echo "[*] Writing sudoers drop-in: ${SUDOERS_FILE}"
# NOPASSWD on find is a well-documented unsafe pattern (GTFOBins)
cat > "${SUDOERS_FILE}" <<EOF
# Privesc lab — INSECURE: remove after training
${LAB_USER} ALL=(ALL) NOPASSWD: /usr/bin/find
EOF

chmod 440 "${SUDOERS_FILE}"

echo "[*] Validating with visudo..."
visudo -cf "${SUDOERS_FILE}"

echo "[*] ${LAB_USER} may run: sudo -l  →  NOPASSWD: /usr/bin/find"
echo "[*] Cleanup: rm -f ${SUDOERS_FILE}"
