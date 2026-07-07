# Linux Privilege Escalation PoC Lab

> **Educational disclaimer:** This repository is intended **only** for authorized security training, CTF practice, and defensive research in **isolated lab environments** you own or have explicit permission to test. Misusing these techniques against systems without authorization is illegal and unethical. The author assumes no liability for misuse.

**Author:** Mostafa Tamime

---

## Overview

[Linux-privesc-PoC](https://github.com/anounymous68/Linux-privesc-PoC) is a modular hands-on lab for learning common Linux local privilege escalation vectors. Each directory is a self-contained scenario with:

| Component | Purpose |
|-----------|---------|
| `README.md` | Theory, prerequisites, reproduction, expected output |
| `setup.sh` | Creates the vulnerable condition (**run as root**) |
| `exploit.sh` | Demonstrates escalation (**run as low-privilege user**) |

## Lab modules

| Module | Vector | Directory |
|--------|--------|-----------|
| Enumeration | Recon with LinPEAS and manual commands | [`enumeration/`](enumeration/) |
| SUID/SGID | Misconfigured setuid binary | [`suid-sgid/`](suid-sgid/) |
| Sudo | NOPASSWD, `env_keep`, rule abuse | [`sudo-misconfig/`](sudo-misconfig/) |
| LD_PRELOAD | Shared library injection via sudo | [`ld-preload/`](ld-preload/) |
| Cron | Writable cron script / PATH hijack | [`cron-hijack/`](cron-hijack/) |
| Copy Fail | Kernel CVE-2026-31431 (`algif_aead` page cache write) | [`copy-fail-cve-2026-31431/`](copy-fail-cve-2026-31431/) |

## Recommended lab setup

Use a disposable VM (Ubuntu 22.04/24.04 LTS or Debian 12) with snapshots enabled.

```bash
# Clone and enter the repo
git clone https://github.com/anounymous68/Linux-privesc-PoC.git
cd Linux-privesc-PoC

# Create a dedicated low-privilege lab user (as root)
useradd -m -s /bin/bash labuser
echo 'labuser:labpass' | chpasswd

# Run each module's setup as root, then exploit as labuser
sudo ./suid-sgid/setup.sh
su - labuser
./suid-sgid/exploit.sh
```

## Suggested learning path

1. **Enumeration** — Run `manual_enum.sh` and review LinPEAS output before touching exploits.
2. **SUID/SGID** — Classic binary misconfiguration.
3. **Sudo misconfiguration** — Very common in real assessments.
4. **LD_PRELOAD** — Understand `env_keep` and library loading.
5. **Cron hijack** — Scheduled task and PATH weaknesses.
6. **Copy Fail (CVE-2026-31431)** — Kernel authencesn scatterlist bug; deterministic page cache write via `AF_ALG`.

## Cleanup

Each `setup.sh` prints module-specific cleanup hints. Revert snapshots or rebuild the VM between sessions for a clean state.

## References

- [GTFOBins](https://gtfobins.github.io/)
- [HackTricks — Linux Privilege Escalation](https://book.hacktricks.wiki/linux-hardening/privilege-escalation/index.html)
- [LinPEAS](https://github.com/carlospolop/PEASS-ng/tree/master/linPEAS)

## License

MIT — use responsibly in authorized lab environments only.
