/*
 * libFuzzer harness for cn-cbor's decode path.
 *
 * Feeds attacker-controlled bytes straight into cn_cbor_decode and lets
 * AddressSanitizer / UBSan catch any memory-safety or undefined-behavior
 * violation in the parser. Build with build.sh.
 *
 * SPDX-License-Identifier: MIT
 */

#include <stddef.h>
#include <stdint.h>

#include "cn-cbor/cn-cbor.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    struct cn_cbor_errback err;

    /* cn_cbor_decode takes a buffer + length of untrusted input. */
    cn_cbor *cb = cn_cbor_decode(data, size, &err);

    /* Free on success so use-after-free / double-free bugs surface too. */
    if (cb) {
        cn_cbor_free(cb);
    }

    return 0;
}
