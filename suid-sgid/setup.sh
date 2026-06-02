#!/usr/bin/env bash
#
# setup.sh — Creates a vulnerable SUID binary (MUST run as root)
#

set -euo pipefail

TARGET="/usr/local/bin/privesc-suid-lab"
SOURCE="/tmp/privesc-suid-lab.c"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[-] Run as root: sudo $0"
  exit 1
fi

echo "[*] Writing intentionally vulnerable C source..."

# Program sets effective UID to root via SUID bit, then execs a shell
cat > "${SOURCE}" <<'EOF'
#include <unistd.h>
#include <stdlib.h>

int main(void) {
    setuid(0);
    setgid(0);
    system("/bin/sh");
    return 0;
}
EOF

echo "[*] Compiling with gcc..."
gcc -o "${TARGET}" "${SOURCE}"
rm -f "${SOURCE}"

echo "[*] Setting owner root and SUID bit (4755)..."
chown root:root "${TARGET}"
chmod 4755 "${TARGET}"

echo "[*] Installed: ${TARGET} (mode 4755)"
echo "[*] Verify: ls -la ${TARGET}"
ls -la "${TARGET}"
echo "[*] Run exploit as non-root: ./exploit.sh"
echo "[*] Cleanup: rm -f ${TARGET}"
