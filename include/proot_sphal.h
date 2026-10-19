/* SPDX-License-Identifier: Apache-2.0 */

#ifndef PROOT_SPHAL_H
#define PROOT_SPHAL_H

#ifdef __cplusplus
extern "C" {
#endif

int proot_sphal_path_is_allowed(const char *path);
void *proot_sphal_open(const char *path);
void *proot_sphal_symbol(void *handle, const char *symbol);
int proot_sphal_close(void *handle);
const char *proot_sphal_error(void);

#ifdef __cplusplus
}
#endif

#endif
