/* Copyright (c) 2026, Ladybird contributors
 * SPDX-License-Identifier: BSD-2-Clause
 * LibMediaCodecs/Limits.h, Ladybird 2abe68fefd4e5bedce639d19f0c1620c2b14fbf9.
 */
#ifndef LADYBIRD_V_AUDIO_DECODE_LIMITS_H
#define LADYBIRD_V_AUDIO_DECODE_LIMITS_H

#include <stdbool.h>
#include <stdint.h>

static bool ladybird_v_audio_sample_rate_supported(uint64_t rate)
{
    return rate >= 3000 && rate <= 768000;
}

#endif
