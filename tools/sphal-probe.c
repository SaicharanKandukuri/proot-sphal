/* SPDX-License-Identifier: Apache-2.0 */

#include "proot_sphal.h"

#include <stdio.h>

static void usage(const char *program)
{
    fprintf(stderr, "Usage: %s /vendor/or/odm/library.so [symbol]\n", program);
}

int main(int argc, char **argv)
{
    void *handle;

    if (argc < 2 || argc > 3) {
        usage(argv[0]);
        return 2;
    }
    handle = proot_sphal_open(argv[1]);
    if (handle == NULL) {
        fprintf(stderr, "sphal-probe: load failed: %s\n", proot_sphal_error());
        return 1;
    }
    printf("loaded %s at %p\n", argv[1], handle);
    if (argc == 3) {
        void *symbol = proot_sphal_symbol(handle, argv[2]);
        if (symbol == NULL) {
            fprintf(stderr, "sphal-probe: symbol failed: %s\n", proot_sphal_error());
            proot_sphal_close(handle);
            return 1;
        }
        printf("resolved %s at %p\n", argv[2], symbol);
    }
    return proot_sphal_close(handle) == 0 ? 0 : 1;
}
