/* Copyright (c) 2026, Ladybird contributors
 * SPDX-License-Identifier: BSD-2-Clause
 * Native boundary regression for the shared WAV/FFmpeg decode limits.
 */
#include "audio_decode_limits.h"
#include <assert.h>
#include <stdint.h>

int main(void)
{
    assert(!ladybird_v_audio_sample_rate_supported(2999));
    assert(ladybird_v_audio_sample_rate_supported(3000));
    assert(ladybird_v_audio_sample_rate_supported(768000));
    assert(!ladybird_v_audio_sample_rate_supported(768001));
    assert(!ladybird_v_audio_sample_rate_supported(UINT64_MAX));
    size_t count = 0;
    assert(ladybird_v_audio_sample_capacity(134217727, 1, 1, &count));
    assert(count * sizeof(float) == LADYBIRD_V_MAX_DECODED_AUDIO_BYTES);
    assert(ladybird_v_audio_sample_capacity(67108863, 1, 2, &count));
    assert(count * sizeof(float) == LADYBIRD_V_MAX_DECODED_AUDIO_BYTES);
    assert(!ladybird_v_audio_sample_capacity(134217728, 1, 1, &count));
    assert(!ladybird_v_audio_sample_capacity(0, 67108865, 2, &count));
    assert(!ladybird_v_audio_sample_capacity(UINT64_MAX, 1, 1, &count));
    assert(!ladybird_v_audio_sample_capacity(1, UINT64_MAX, 1, &count));
    assert(!ladybird_v_audio_sample_capacity(1, 1, UINT64_MAX, &count));
    assert(!ladybird_v_audio_sample_capacity(0, 0, 0, &count));
    assert(!ladybird_v_audio_sample_capacity(0, 0, 33, &count));
    assert(ladybird_v_audio_sample_capacity(0, 0, 32, &count) && count == 0);
    return 0;
}
