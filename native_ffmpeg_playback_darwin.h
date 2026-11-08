// Video-only WebM decoding. Networking and resource ownership stay in V.
#pragma once
#include "native_ffmpeg_darwin.h"
#ifdef LADYBIRD_V_HAS_FFMPEG
typedef struct {
    const VoxFFmpegAPI *api;
    AVFormatContext *format;
    AVCodecContext *codec;
    AVPacket *packet;
    AVFrame *frame;
    int stream, width, height;
    double duration, next_time;
    bool pending, draining, finished, failed;
} VoxFFmpegVideo;

static void vox_ffmpeg_video_close(VoxFFmpegVideo *video) {
    if (!video) return;
    const VoxFFmpegAPI *api = video->api;
    if (video->frame) api->av_frame_free(&video->frame);
    if (video->packet) api->av_packet_free(&video->packet);
    if (video->codec) api->avcodec_free_context(&video->codec);
    if (video->format) api->avformat_close_input(&video->format);
    free(video);
}

static VoxFFmpegVideo *vox_ffmpeg_video_open(const char *path) {
    const VoxFFmpegAPI *api = native_ffmpeg_api();
    if (!api || !path) return NULL;
    VoxFFmpegVideo *video = calloc(1, sizeof(*video));
    if (!video) return NULL;
    video->api = api;
    if (api->avformat_open_input(&video->format, path, NULL, NULL) < 0
        || api->avformat_find_stream_info(video->format, NULL) < 0) goto fail;
    // Do not advertise silent playback of an audible resource. AVFoundation
    // remains the audio backend until a WebM audio sink is available.
    if (api->av_find_best_stream(video->format, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0) >= 0)
        goto fail;
    video->stream = api->av_find_best_stream(video->format, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    if (video->stream < 0) goto fail;
    AVStream *stream = video->format->streams[video->stream];
    if (stream->codecpar->codec_id != AV_CODEC_ID_VP8
        && stream->codecpar->codec_id != AV_CODEC_ID_VP9) goto fail;
    const AVCodec *decoder = api->avcodec_find_decoder(stream->codecpar->codec_id);
    const AVDictionaryEntry *alpha = api->av_dict_get(stream->metadata, "alpha_mode", NULL, 0);
    if (alpha && strcmp(alpha->value, "1") == 0)
        decoder = api->avcodec_find_decoder_by_name(stream->codecpar->codec_id == AV_CODEC_ID_VP9
            ? "libvpx-vp9" : "libvpx");
    if (!decoder) goto fail;
    video->codec = api->avcodec_alloc_context3(decoder);
    if (!video->codec || api->avcodec_parameters_to_context(video->codec, stream->codecpar) < 0
        || api->avcodec_open2(video->codec, decoder, NULL) < 0) goto fail;
    video->width = video->codec->width;
    video->height = video->codec->height;
    if (video->width <= 0 || video->width > INT32_MAX / 4 || video->height <= 0
        || (size_t)video->height > SIZE_MAX / ((size_t)video->width * 4)) goto fail;
    video->duration = video->format->duration == AV_NOPTS_VALUE ? NAN
        : (double)video->format->duration / AV_TIME_BASE;
    video->packet = api->av_packet_alloc();
    video->frame = api->av_frame_alloc();
    if (!video->packet || !video->frame) goto fail;
    return video;
fail:
    vox_ffmpeg_video_close(video);
    return NULL;
}

static bool vox_ffmpeg_video_seek(VoxFFmpegVideo *video, double seconds) {
    AVStream *stream = video->format->streams[video->stream];
    int64_t target = (int64_t)floor(seconds / av_q2d(stream->time_base));
    if (video->api->av_seek_frame(video->format, video->stream, target, AVSEEK_FLAG_BACKWARD) < 0)
        return false;
    video->api->avcodec_flush_buffers(video->codec);
    video->api->av_frame_unref(video->frame);
    video->pending = video->draining = video->finished = video->failed = false;
    return true;
}

static bool vox_ffmpeg_video_next(VoxFFmpegVideo *video) {
    const VoxFFmpegAPI *api = video->api;
    for (;;) {
        int result = api->avcodec_receive_frame(video->codec, video->frame);
        if (result == 0) {
            video->next_time = video->frame->best_effort_timestamp == AV_NOPTS_VALUE ? 0
                : video->frame->best_effort_timestamp
                    * av_q2d(video->format->streams[video->stream]->time_base);
            video->pending = true;
            return true;
        }
        if (result == AVERROR_EOF) { video->finished = true; return false; }
        if (result != AVERROR(EAGAIN) || video->draining) {
            video->failed = true; return false;
        }
        do {
            result = api->av_read_frame(video->format, video->packet);
            if (result < 0) break;
            if (video->packet->stream_index == video->stream) break;
            api->av_packet_unref(video->packet);
        } while (true);
        if (result < 0) {
            if (result != AVERROR_EOF) { video->failed = true; return false; }
            result = api->avcodec_send_packet(video->codec, NULL);
            video->draining = true;
        } else {
            result = api->avcodec_send_packet(video->codec, video->packet);
            api->av_packet_unref(video->packet);
        }
        if (result < 0 && result != AVERROR_EOF) { video->failed = true; return false; }
    }
}

// Retain a future decoded frame and publish only the latest frame due at the
// playback clock. Paused polls neither decode nor publish duplicate frames.
static uint8_t *vox_ffmpeg_video_copy_frame(VoxFFmpegVideo *video, double seconds) {
    uint8_t *pixels = NULL;
    while (!video->finished && !video->failed) {
        if (!video->pending && !vox_ffmpeg_video_next(video)) break;
        if (video->next_time > seconds + 0.000001) break;
        if (video->frame->width != video->width || video->frame->height != video->height) {
            video->failed = true; break;
        }
        if (!pixels) pixels = malloc((size_t)video->width * video->height * 4);
        if (!pixels || !native_ffmpeg_convert_frame(video->api, video->frame, pixels, video->width * 4)) {
            video->failed = true; break;
        }
        video->api->av_frame_unref(video->frame);
        video->pending = false;
    }
    if (video->failed) { free(pixels); return NULL; }
    return pixels;
}
#endif
