/* Copyright (c) 2026, Ladybird contributors
 * SPDX-License-Identifier: BSD-2-Clause
 * LibMediaCodecs/Limits.h, Ladybird 2abe68fefd4e5bedce639d19f0c1620c2b14fbf9.
 */
#ifndef LADYBIRD_V_AUDIO_DECODE_LIMITS_H
#define LADYBIRD_V_AUDIO_DECODE_LIMITS_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* Ladybird 6cffda19bd949448d336d61761aff9dc767c51fe. */
#define LADYBIRD_V_MAX_DECODED_AUDIO_BYTES (512ULL * 1024 * 1024)

static bool ladybird_v_audio_sample_rate_supported(uint64_t rate)
{
    return rate >= 3000 && rate <= 768000;
}

static bool ladybird_v_decoded_audio_fits(uint64_t frames, uint64_t channels)
{
    return channels > 0 && channels <= 32
        && frames <= LADYBIRD_V_MAX_DECODED_AUDIO_BYTES / sizeof(float) / channels;
}

/* Check the addition before either multiplication or realloc, including the
 * resampler's final flush. No arithmetic here can wrap even for hostile sizes. */
static bool ladybird_v_audio_sample_capacity(uint64_t frames, uint64_t additional_frames,
    uint64_t channels, size_t *sample_count)
{
    if (!ladybird_v_decoded_audio_fits(frames, channels))
        return false;
    uint64_t maximum_frames = LADYBIRD_V_MAX_DECODED_AUDIO_BYTES / sizeof(float) / channels;
    if (additional_frames > maximum_frames - frames)
        return false;
    *sample_count = (size_t)((frames + additional_frames) * channels);
    return true;
}

#endif
