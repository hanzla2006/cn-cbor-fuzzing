/*
 * libFuzzer / AFL++ harness: decode -> encode -> decode -> encode, with a byte
 * comparison of the two encodings.
 *
 * Exercises the encoder and checks encode/decode consistency: the bytes the
 * encoder produces from a tree must (a) decode again and (b) re-encode to the
 * identical bytes. A mismatch is an encoder/decoder inconsistency, so we abort
 * to surface it to the fuzzer.
 *
 * SPDX-License-Identifier: MIT
 */

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "cn-cbor/cn-cbor.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    struct cn_cbor_errback err;

    cn_cbor *cb = cn_cbor_decode(data, size, &err);
    if (!cb) {
        return 0;
    }

    unsigned char out1[8192];
    ssize_t n1 = cn_cbor_encoder_write(out1, 0, sizeof(out1), cb);
    cn_cbor_free(cb);
    if (n1 < 0) {
        return 0;  /* buffer too small / encode error: not a defect */
    }

    /* The encoder's own output must decode again. */
    cn_cbor *cb2 = cn_cbor_decode(out1, (size_t)n1, &err);
    if (!cb2) {
        abort();
    }

    unsigned char out2[8192];
    ssize_t n2 = cn_cbor_encoder_write(out2, 0, sizeof(out2), cb2);
    cn_cbor_free(cb2);
    if (n2 < 0) {
        abort();  /* a tree we just decoded failed to re-encode */
    }

    /* Re-encoding a decoded tree must reproduce the same bytes. */
    if (n1 != n2 || memcmp(out1, out2, (size_t)n1) != 0) {
        abort();
    }

    return 0;
}
