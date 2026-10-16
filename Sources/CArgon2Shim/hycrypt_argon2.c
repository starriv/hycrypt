#define __STDC_WANT_LIB_EXT1__ 1
#include "hycrypt_argon2.h"

#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

#include "argon2.h"

/* argon2_ctx allocates and frees its workspace on the calling thread, and joins any
 * worker threads before returning, so thread-local ownership tracking is sufficient. */
static _Thread_local uint8_t *workspace;
static _Thread_local size_t workspace_size;

static int allocate(uint8_t **memory, size_t size) {
    *memory = malloc(size);
    if (*memory) {
        /* Best-effort: lock workspace in physical memory to prevent swap.
         * Failure is acceptable (RLIMIT_MEMLOCK may be low); FileVault covers swap. */
        (void)mlock(*memory, size);
    }
    workspace = *memory;
    workspace_size = *memory ? size : 0;
    return *memory ? 0 : -1;
}

static void release(uint8_t *memory, size_t size) {
    if (memory) {
        memset_s(memory, size, 0, size);
        (void)munlock(memory, size);
        free(memory);
    }
    if (memory == workspace) {
        workspace = NULL;
        workspace_size = 0;
    }
}

int hycrypt_argon2id_raw(uint32_t t_cost, uint32_t m_cost, uint32_t parallelism,
                         const void *pwd, size_t pwdlen, const void *salt, size_t saltlen,
                         void *hash, size_t hashlen) {
    if (pwdlen > ARGON2_MAX_PWD_LENGTH || saltlen > ARGON2_MAX_SALT_LENGTH ||
        hashlen > ARGON2_MAX_OUTLEN) {
        return ARGON2_PWD_TOO_LONG;
    }
    argon2_context context;
    memset(&context, 0, sizeof(context));
    context.out = (uint8_t *)hash;
    context.outlen = (uint32_t)hashlen;
    context.pwd = (uint8_t *)pwd;
    context.pwdlen = (uint32_t)pwdlen;
    context.salt = (uint8_t *)salt;
    context.saltlen = (uint32_t)saltlen;
    context.t_cost = t_cost;
    context.m_cost = m_cost;
    context.lanes = parallelism;
    context.threads = parallelism;
    context.allocate_cbk = allocate;
    context.free_cbk = release;
    /* Wipe the password buffer as soon as it has been absorbed. ARGON2_DEFAULT_FLAGS does not. */
    context.flags = ARGON2_DEFAULT_FLAGS | ARGON2_FLAG_CLEAR_PASSWORD | ARGON2_FLAG_CLEAR_SECRET;
    context.version = ARGON2_VERSION_13;

    workspace = NULL;
    workspace_size = 0;
    int result = argon2_ctx(&context, Argon2_id);
    /* Upstream returns without finalize() when fill_memory_blocks fails. */
    if (workspace) {
        release(workspace, workspace_size);
    }
    if (result != ARGON2_OK && hash && hashlen) {
        memset_s(hash, hashlen, 0, hashlen);
    }
    return result;
}
