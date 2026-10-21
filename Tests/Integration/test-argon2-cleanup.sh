#!/bin/bash
# Fault injection for the Argon2 shim. Production runs Argon2 single-threaded
# (context.threads = 1) so the upstream thread-failure cleanup paths are unreachable;
# this test asserts no worker thread is created, the 256 MiB workspace is zeroed and
# released, and an allocation failure zeroes the output. Synthetic inputs only.
set -euo pipefail
cd "$(dirname "$0")/../.."
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
cat > "$temporary/harness.c" <<'C'
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "argon2.h"
#include "thread.h"
#include "hycrypt_argon2.h"
static uint8_t *tracked;
static size_t tracked_size;
static int freed, wiped, fail_big, thread_calls;
void *test_malloc(size_t size) {
    if (fail_big && size > 1024 * 1024) { return NULL; }
    void *memory = malloc(size);
    if (size > 1024 * 1024) { tracked = memory; tracked_size = size; }
    return memory;
}
void test_free(void *memory) {
    if (memory && memory == tracked) {
        freed = 1;
        wiped = 1;
        for (size_t i = 0; i < tracked_size; ++i) if (tracked[i]) { wiped = 0; break; }
    }
    free(memory);
}
int argon2_thread_create(argon2_thread_handle_t *h, argon2_thread_func_t f, void *a) {
    (void)h; (void)f; (void)a; thread_calls += 1; return -1;
}
int argon2_thread_join(argon2_thread_handle_t h) { (void)h; return 0; }
void argon2_thread_exit(void) {}
int main(void) {
    uint8_t output[32], salt[16] = {0};
    const char password[] = "synthetic-test-input";
    int status = hycrypt_argon2id_raw(5, 262144, 6, password, sizeof(password) - 1,
                                      salt, sizeof(salt), output, sizeof(output));
    int output_zero = 1;
    for (size_t i = 0; i < sizeof(output); ++i) if (output[i]) output_zero = 0;
    printf("status=%d thread_calls=%d freed=%d wiped=%d output_zero=%d\n",
           status, thread_calls, freed, wiped, output_zero);
    int success_ok = status == ARGON2_OK && thread_calls == 0 && freed && wiped && !output_zero;

    fail_big = 1;
    for (size_t i = 0; i < sizeof(output); ++i) output[i] = 0xA5;
    int alloc_status = hycrypt_argon2id_raw(5, 262144, 6, password, sizeof(password) - 1,
                                            salt, sizeof(salt), output, sizeof(output));
    int alloc_zero = 1;
    for (size_t i = 0; i < sizeof(output); ++i) if (output[i]) alloc_zero = 0;
    printf("alloc_status=%d alloc_zero=%d\n", alloc_status, alloc_zero);
    int alloc_ok = alloc_status == ARGON2_MEMORY_ALLOCATION_ERROR && alloc_zero;
    return success_ok && alloc_ok ? 0 : 1;
}
C
includes=(-IVendor/argon2/include -IVendor/argon2/src -ISources/CArgon2Shim/include)
for source in argon2.c core.c blake2/blake2b.c encoding.c ref.c; do
    /usr/bin/clang -c -w "${includes[@]}" "Vendor/argon2/src/$source" -o "$temporary/$(basename "$source" .c).o"
done
/usr/bin/clang -c -w "${includes[@]}" -Dmalloc=test_malloc -Dfree=test_free \
    Sources/CArgon2Shim/hycrypt_argon2.c -o "$temporary/shim.o"
/usr/bin/clang -w "${includes[@]}" "$temporary"/*.o "$temporary/harness.c" -o "$temporary/harness"
"$temporary/harness"
echo 'Argon2 cleanup check passed: no worker threads, workspace wiped/released, allocation failure zeroes output.'
