#ifndef HYCRYPT_ARGON2_H
#define HYCRYPT_ARGON2_H

#include <stddef.h>
#include <stdint.h>

/// Argon2id v1.3 raw hash. The password buffer is wiped once absorbed, and the workspace is
/// wiped and released on every return path, including the reference implementation's
/// thread-failure path that skips its own cleanup.
int hycrypt_argon2id_raw(uint32_t t_cost, uint32_t m_cost, uint32_t parallelism,
                         const void *pwd, size_t pwdlen, const void *salt, size_t saltlen,
                         void *hash, size_t hashlen);

#endif
