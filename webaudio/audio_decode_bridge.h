/*
 * Copyright (c) 2026, Ladybird contributors
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef LADYBIRD_V_AUDIO_DECODE_BRIDGE_H
#define LADYBIRD_V_AUDIO_DECODE_BRIDGE_H

#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "audio_decode_limits.h"

#ifdef LADYBIRD_V_HAS_FFMPEG
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/mem.h>
#include <libswresample/swresample.h>

typedef struct {
    const uint8_t *data;
    size_t size;
    size_t offset;
} LadybirdVAudioMemory;

static int ladybird_v_audio_read(void *opaque, uint8_t *destination, int size)
{
    LadybirdVAudioMemory *memory = (LadybirdVAudioMemory *)opaque;
    if (memory->offset >= memory->size)
        return AVERROR_EOF;
    size_t available = memory->size - memory->offset;
    size_t count = available < (size_t)size ? available : (size_t)size;
    memcpy(destination, memory->data + memory->offset, count);
    memory->offset += count;
    return (int)count;
}

static int64_t ladybird_v_audio_seek(void *opaque, int64_t offset, int whence)
{
    LadybirdVAudioMemory *memory = (LadybirdVAudioMemory *)opaque;
    if (whence == AVSEEK_SIZE)
        return (int64_t)memory->size;
    whence &= ~AVSEEK_FORCE;
    int64_t base = 0;
    if (whence == SEEK_CUR)
        base = (int64_t)memory->offset;
    else if (whence == SEEK_END)
        base = (int64_t)memory->size;
    else if (whence != SEEK_SET)
        return AVERROR(EINVAL);
    if (offset < -base || base + offset < 0 || (uint64_t)(base + offset) > memory->size)
        return AVERROR(EINVAL);
    memory->offset = (size_t)(base + offset);
    return base + offset;
}

static int ladybird_v_append_audio_frame(SwrContext **resampler,
    AVFrame *frame, int target_sample_rate, float **samples,
    size_t *frame_count, size_t *sample_capacity, int *channel_count)
{
    if (!ladybird_v_audio_sample_rate_supported((uint64_t)frame->sample_rate)
        || !ladybird_v_audio_sample_rate_supported((uint64_t)target_sample_rate))
        return -1;
    if (*resampler == NULL) {
        if (frame->ch_layout.nb_channels <= 0 || frame->ch_layout.nb_channels > 32
            || frame->sample_rate <= 0)
            return -1;
        AVChannelLayout output_layout = { 0 };
        if (av_channel_layout_copy(&output_layout, &frame->ch_layout) < 0)
            return -1;
        int result = swr_alloc_set_opts2(resampler, &output_layout,
            AV_SAMPLE_FMT_FLT, target_sample_rate, &frame->ch_layout,
            (enum AVSampleFormat)frame->format, frame->sample_rate, 0, NULL);
        av_channel_layout_uninit(&output_layout);
        if (result < 0 || swr_init(*resampler) < 0)
            return -1;
        *channel_count = frame->ch_layout.nb_channels;
    }

    int output_capacity = swr_get_out_samples(*resampler, frame->nb_samples);
    if (output_capacity < 0)
        return -1;
    size_t required = (*frame_count + (size_t)output_capacity) * (size_t)*channel_count;
    if (required > *sample_capacity) {
        if (required > SIZE_MAX / sizeof(float))
            return -1;
        float *grown = (float *)realloc(*samples, required * sizeof(float));
        if (grown == NULL)
            return -1;
        *samples = grown;
        *sample_capacity = required;
    }
    uint8_t *output[] = {
        (uint8_t *)(*samples + *frame_count * (size_t)*channel_count)
    };
    int converted = swr_convert(*resampler, output, output_capacity,
        (const uint8_t **)frame->extended_data, frame->nb_samples);
    if (converted < 0)
        return -1;
    *frame_count += (size_t)converted;
    return 0;
}
#endif

/* Decode to packed, interleaved float samples at the requested sample rate. */
static float *ladybird_v_decode_audio(const uint8_t *bytes, int byte_count,
    int requested_sample_rate, int *output_channels, int *output_frames,
    int *output_sample_rate)
{
    if (output_channels != NULL)
        *output_channels = 0;
    if (output_frames != NULL)
        *output_frames = 0;
    if (output_sample_rate != NULL)
        *output_sample_rate = 0;
#ifndef LADYBIRD_V_HAS_FFMPEG
    (void)bytes;
    (void)byte_count;
    (void)requested_sample_rate;
    return NULL;
#else
    if (bytes == NULL || byte_count <= 0
        || !ladybird_v_audio_sample_rate_supported((uint64_t)requested_sample_rate)
        || output_channels == NULL || output_frames == NULL
        || output_sample_rate == NULL)
        return NULL;

    LadybirdVAudioMemory memory = { bytes, (size_t)byte_count, 0 };
    AVFormatContext *format = avformat_alloc_context();
    AVIOContext *input = NULL;
    AVCodecContext *codec = NULL;
    AVPacket *packet = NULL;
    AVFrame *frame = NULL;
    SwrContext *resampler = NULL;
    float *samples = NULL;
    size_t frame_count = 0;
    size_t sample_capacity = 0;
    int channel_count = 0;
    int audio_stream = -1;
    uint8_t *input_buffer = NULL;

    if (format == NULL)
        goto cleanup;
    input_buffer = (uint8_t *)av_malloc(4096);
    if (input_buffer == NULL)
        goto cleanup;
    input = avio_alloc_context(input_buffer, 4096, 0, &memory,
        ladybird_v_audio_read, NULL, ladybird_v_audio_seek);
    if (input == NULL)
        goto cleanup;
    input_buffer = NULL; /* Owned by input from here. */
    format->pb = input;
    format->flags |= AVFMT_FLAG_CUSTOM_IO;
    if (avformat_open_input(&format, NULL, NULL, NULL) < 0
        || avformat_find_stream_info(format, NULL) < 0)
        goto cleanup;
    audio_stream = av_find_best_stream(format, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);
    if (audio_stream < 0)
        goto cleanup;
    AVStream *stream = format->streams[audio_stream];
    const AVCodec *decoder = avcodec_find_decoder(stream->codecpar->codec_id);
    if (decoder == NULL)
        goto cleanup;
    codec = avcodec_alloc_context3(decoder);
    if (codec == NULL || avcodec_parameters_to_context(codec, stream->codecpar) < 0
        || avcodec_open2(codec, decoder, NULL) < 0)
        goto cleanup;
    packet = av_packet_alloc();
    frame = av_frame_alloc();
    if (packet == NULL || frame == NULL)
        goto cleanup;

    while (av_read_frame(format, packet) >= 0) {
        if (packet->stream_index == audio_stream) {
            if (avcodec_send_packet(codec, packet) < 0) {
                av_packet_unref(packet);
                goto cleanup;
            }
            while (avcodec_receive_frame(codec, frame) == 0) {
                if (ladybird_v_append_audio_frame(&resampler, frame,
                    requested_sample_rate, &samples, &frame_count,
                    &sample_capacity, &channel_count) < 0) {
                    av_packet_unref(packet);
                    goto cleanup;
                }
                av_frame_unref(frame);
            }
        }
        av_packet_unref(packet);
    }
    if (avcodec_send_packet(codec, NULL) < 0)
        goto cleanup;
    while (avcodec_receive_frame(codec, frame) == 0) {
        if (ladybird_v_append_audio_frame(&resampler, frame,
            requested_sample_rate, &samples, &frame_count, &sample_capacity,
            &channel_count) < 0)
            goto cleanup;
        av_frame_unref(frame);
    }
    while (resampler != NULL) {
        int output_capacity = swr_get_out_samples(resampler, 0);
        if (output_capacity <= 0)
            break;
        size_t required = (frame_count + (size_t)output_capacity)
            * (size_t)channel_count;
        if (required > sample_capacity) {
            if (required > SIZE_MAX / sizeof(float))
                goto cleanup;
            float *grown = (float *)realloc(samples, required * sizeof(float));
            if (grown == NULL)
                goto cleanup;
            samples = grown;
            sample_capacity = required;
        }
        uint8_t *output[] = {
            (uint8_t *)(samples + frame_count * (size_t)channel_count)
        };
        int converted = swr_convert(resampler, output, output_capacity, NULL, 0);
        if (converted <= 0)
            break;
        frame_count += (size_t)converted;
    }
    if (frame_count == 0 || frame_count > INT_MAX || channel_count <= 0)
        goto cleanup;

    *output_channels = channel_count;
    *output_frames = (int)frame_count;
    *output_sample_rate = requested_sample_rate;

cleanup:
    if (resampler != NULL)
        swr_free(&resampler);
    if (frame != NULL)
        av_frame_free(&frame);
    if (packet != NULL)
        av_packet_free(&packet);
    if (codec != NULL)
        avcodec_free_context(&codec);
    if (format != NULL)
        avformat_close_input(&format);
    if (input != NULL)
        avio_context_free(&input);
    else if (input_buffer != NULL)
        av_free(input_buffer);
    if (*output_frames == 0) {
        free(samples);
        return NULL;
    }
    return samples;
#endif
}

static void ladybird_v_free_decoded_audio(float *samples)
{
    free(samples);
}

#endif
