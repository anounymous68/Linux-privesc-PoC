#!/usr/bin/env bash
#
# setup.sh — Sudo env_keep LD_PRELOAD + compiles malicious.so (run as root)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SO_PATH="/tmp/privesc-lab.so"
SUDOERS_FILE="/etc/sudoers.d/99-privesc-lab-ldpreload"
LAB_USER="${LAB_USER:-labuser}"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[-] Run as root: sudo $0"
  exit 1
fi

if ! id "${LAB_USER}" &>/dev/null; then
  useradd -m -s /bin/bash "${LAB_USER}"
fi

echo "[*] Compiling malicious.so from malicious.c..."
gcc -shared -fPIC -o "${SO_PATH}" "${SCRIPT_DIR}/malicious.c" -nostartfiles
chmod 755 "${SO_PATH}"

echo "[*] Writing sudoers drop-in: ${SUDOERS_FILE}"
cat > "${SUDOERS_FILE}" <<EOF
# Privesc lab — INSECURE: LD_PRELOAD kept in sudo environment
Defaults env_keep += LD_PRELOAD
${LAB_USER} ALL=(ALL) NOPASSWD: /usr/bin/cat
EOF

chmod 440 "${SUDOERS_FILE}"
visudo -cf "${SUDOERS_FILE}"

echo "[*] Installed: ${SO_PATH}"
echo "[*] ${LAB_USER}: NOPASSWD /usr/bin/cat with env_keep+=LD_PRELOAD"
echo "[*] Cleanup: rm -f ${SUDOERS_FILE} ${SO_PATH}"
