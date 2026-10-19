/* SPDX-License-Identifier: Apache-2.0 */

#include "proot_sphal.h"

#include <dlfcn.h>
#include <errno.h>
#include <stddef.h>
#include <string.h>

/* Public libhybris API. Keeping these declarations local lets consumers use
 * this loader without importing libhybris headers into their source tree. */
extern void *hybris_dlopen(const char *filename, int flag);
extern void *hybris_dlsym(void *handle, const char *symbol);
extern int hybris_dlclose(void *handle);
extern char *hybris_dlerror(void);

static _Thread_local const char *last_error;

static int has_parent_segment(const char *path)
{
    const char *cursor = path;

    while ((cursor = strstr(cursor, "..")) != NULL) {
        const int left_boundary = cursor == path || cursor[-1] == '/';
        const int right_boundary = cursor[2] == '\0' || cursor[2] == '/';
        if (left_boundary && right_boundary)
            return 1;
        cursor += 2;
    }
    return 0;
}

int proot_sphal_path_is_allowed(const char *path)
{
    static const char *const roots[] = { "/vendor/", "/odm/" };
    size_t index;

    if (path == NULL || has_parent_segment(path))
        return 0;
    for (index = 0; index < sizeof(roots) / sizeof(roots[0]); ++index) {
        const size_t length = strlen(roots[index]);
        if (strncmp(path, roots[index], length) == 0 && path[length] != '\0')
            return 1;
    }
    return 0;
}

void *proot_sphal_open(const char *path)
{
    void *handle;

    last_error = NULL;
    if (!proot_sphal_path_is_allowed(path)) {
        errno = EINVAL;
        last_error = "SPHAL path must be an absolute /vendor or /odm path without '..'";
        return NULL;
    }
    handle = hybris_dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL)
        last_error = hybris_dlerror();
    return handle;
}

void *proot_sphal_symbol(void *handle, const char *symbol)
{
    void *address;

    last_error = NULL;
    if (handle == NULL || symbol == NULL || symbol[0] == '\0') {
        errno = EINVAL;
        last_error = "a valid SPHAL handle and non-empty symbol are required";
        return NULL;
    }
    address = hybris_dlsym(handle, symbol);
    if (address == NULL)
        last_error = hybris_dlerror();
    return address;
}

int proot_sphal_close(void *handle)
{
    int result;

    last_error = NULL;
    if (handle == NULL) {
        errno = EINVAL;
        last_error = "a valid SPHAL handle is required";
        return -1;
    }
    result = hybris_dlclose(handle);
    if (result != 0)
        last_error = hybris_dlerror();
    return result;
}

const char *proot_sphal_error(void)
{
    return last_error;
}
