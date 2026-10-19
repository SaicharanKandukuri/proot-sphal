/* SPDX-License-Identifier: Apache-2.0 */

#include "proot_sphal.h"

#include <assert.h>
#include <stddef.h>
#include <string.h>

static int fake_handle;

void *hybris_dlopen(const char *path, int flags)
{
    (void)flags;
    return strcmp(path, "/vendor/lib64/hw/vulkan.test.so") == 0
        ? &fake_handle : NULL;
}

void *hybris_dlsym(void *handle, const char *symbol)
{
    return handle == &fake_handle && strcmp(symbol, "test_symbol") == 0
        ? &fake_handle : NULL;
}

int hybris_dlclose(void *handle)
{
    return handle == &fake_handle ? 0 : -1;
}

char *hybris_dlerror(void)
{
    return "stub libhybris failure";
}

int main(void)
{
    void *handle;

    assert(proot_sphal_path_is_allowed("/vendor/lib64/hw/vulkan.test.so"));
    assert(proot_sphal_path_is_allowed("/odm/lib64/libexample.so"));
    assert(!proot_sphal_path_is_allowed(NULL));
    assert(!proot_sphal_path_is_allowed("vendor/lib64/libexample.so"));
    assert(!proot_sphal_path_is_allowed("/system/lib64/libexample.so"));
    assert(!proot_sphal_path_is_allowed("/vendor/../system/lib64/libexample.so"));

    handle = proot_sphal_open("/vendor/lib64/hw/vulkan.test.so");
    assert(handle != NULL);
    assert(proot_sphal_symbol(handle, "test_symbol") != NULL);
    assert(proot_sphal_close(handle) == 0);
    assert(proot_sphal_open("/vendor/../system/lib64/libexample.so") == NULL);
    assert(strstr(proot_sphal_error(), "absolute /vendor or /odm") != NULL);
    return 0;
}
