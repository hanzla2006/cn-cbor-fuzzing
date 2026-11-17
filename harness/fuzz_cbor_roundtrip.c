/*
 * libFuzzer / AFL++ harness for cn-cbor's decode + encode roundtrip.
 *
 * Decodes attacker-controlled bytes, then re-encodes the resulting tree, so
 * bugs reachable only on the encode path (or on structures the decoder
 * accepts but the encoder mishandles) are exercised too. Build with build.sh
 * by passing this file as the HARNESS.
 *
 * SPDX-License-Identifier: MIT
 */

#include <stddef.h>
#include <stdint.h>

#include "cn-cbor/cn-cbor.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    struct cn_cbor_errback err;

    cn_cbor *cb = cn_cbor_decode(data, size, &err);
    if (cb) {
        unsigned char out[4096];
        cn_cbor_encoder_write(out, 0, sizeof(out), cb);
        cn_cbor_free(cb);
    }

    return 0;
}
