#!/usr/bin/env bash
#
# =============================================================================
#  WARNING — AUTHORIZED LAB / EDUCATIONAL USE ONLY
# =============================================================================
#  This script deliberately creates an insecure SUID binary for privilege
#  escalation practice. Run ONLY in an isolated VM or container that you own.
#  Do NOT deploy on production systems or shared hosts.
# =============================================================================

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[!] Run as root: sudo $0"
  exit 1
fi

LAB_BINARY="/usr/local/bin/lab-path-helper"
LAB_SOURCE="/tmp/lab-path-helper.c"
LAB_TARGET_DIR="/var/lib/lab-path-demo"

echo "[*] PATH Hijacking lab — installing vulnerable SUID helper"

# Directory the helper will try to list (must exist for realistic behavior)
mkdir -p "${LAB_TARGET_DIR}"
chmod 755 "${LAB_TARGET_DIR}"

# -----------------------------------------------------------------------------
# Vulnerable SUID program: calls `ls` without an absolute path and without
# sanitizing PATH. Any user who can prepend a writable dir to PATH wins root.
# -----------------------------------------------------------------------------
cat > "${LAB_SOURCE}" <<'EOF'
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>

int main(int argc, char *argv[]) {
    char cmd[512];
    const char *target = (argc > 1) ? argv[1] : "/var/lib/lab-path-demo";

    /* Intentionally vulnerable: no PATH sanitization before shell-out */
    if (setuid(0) != 0 || setgid(0) != 0) {
        perror("setuid");
        return 1;
    }

    snprintf(cmd, sizeof(cmd), "ls -la %s", target);
    /* BUG: invokes `ls` via PATH instead of /bin/ls */
    return system(cmd);
}
EOF

echo "[*] Compiling ${LAB_BINARY} ..."
gcc -Wall -Wextra -o "${LAB_BINARY}" "${LAB_SOURCE}"
chmod 4755 "${LAB_BINARY}"
chown root:root "${LAB_BINARY}"

rm -f "${LAB_SOURCE}"

echo "[+] Installed vulnerable SUID binary: ${LAB_BINARY}"
echo "[+] Target directory for listing: ${LAB_TARGET_DIR}"
echo ""
echo "Verify:"
echo "  ls -la ${LAB_BINARY}"
echo "  strings ${LAB_BINARY} | grep -E '^ls$|system'"
echo ""
echo "Next: switch to an unprivileged user and run ./exploit.sh from this folder."
