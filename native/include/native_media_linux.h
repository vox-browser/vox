#pragma once

#include <gst/app/gstappsink.h>
#include <gst/video/video.h>
#include <math.h>
#include <stdint.h>
#include <string.h>

typedef struct {
    GstElement *pipeline;
    GstAppSink *sink;
    GstBus *bus;
    GstVideoFrame mapped;
    GstBuffer *last_buffer;
    uint8_t *packed;
    size_t packed_size;
    char *error;
    double rate, applied_rate, pending_position;
    int width, height;
    gboolean ready, audio, local, wants_play, buffering, seeking, pending_seek;
    gboolean approximate, ended, report_ended;
} VoxLinuxMedia;

static gboolean vox_linux_media_init(void) {
    static gsize initialized = 0;
    if (g_once_init_enter(&initialized))
        g_once_init_leave(&initialized, gst_init_check(NULL, NULL, NULL) ? 1 : 2);
    return initialized == 1;
}

static int32_t vox_linux_media_supports_mp4(void) {
    if (!vox_linux_media_init()) return 0;
    GstElementFactory *demux = gst_element_factory_find("qtdemux");
    GstCaps *h264 = gst_caps_from_string("video/x-h264");
    GList *decoders = gst_element_factory_list_get_elements(GST_ELEMENT_FACTORY_TYPE_DECODER,
        GST_RANK_MARGINAL);
    GList *matches = gst_element_factory_list_filter(decoders, h264, GST_PAD_SINK, FALSE);
    gboolean result = demux && matches;
    if (demux) gst_object_unref(demux);
    gst_plugin_feature_list_free(matches);
    gst_plugin_feature_list_free(decoders);
    gst_caps_unref(h264);
    return result;
}

static void vox_linux_media_release_frame(void *handle) {
    VoxLinuxMedia *media = handle;
    if (media->mapped.buffer) {
        gst_video_frame_unmap(&media->mapped);
        media->mapped = (GstVideoFrame){0};
    }
}

static void native_media_close(void *handle) {
    VoxLinuxMedia *media = handle;
    if (!media) return;
    vox_linux_media_release_frame(media);
    if (media->last_buffer) gst_buffer_unref(media->last_buffer);
    gst_element_set_state(media->pipeline, GST_STATE_NULL);
    gst_object_unref(media->bus);
    gst_object_unref(media->pipeline);
    gst_object_unref(media->sink);
    g_free(media->packed);
    g_free(media->error);
    g_free(media);
}

static void *native_media_open(const char *uri) {
    if (!uri || (!g_str_has_prefix(uri, "file://") && !g_str_has_prefix(uri, "http://")
            && !g_str_has_prefix(uri, "https://")) || !vox_linux_media_init()) return NULL;
    GstElement *pipeline = gst_element_factory_make("playbin", NULL);
    GstElement *sink = gst_element_factory_make("appsink", NULL);
    if (!pipeline || !sink) {
        if (pipeline) gst_object_unref(pipeline);
        if (sink) gst_object_unref(sink);
        return NULL;
    }
    gst_object_ref_sink(sink);
    GstCaps *caps = gst_caps_from_string("video/x-raw,format=RGBA,width=[1,4096],height=[1,4096]");
    gst_app_sink_set_caps(GST_APP_SINK(sink), caps);
    gst_caps_unref(caps);
    // The streaming threads hold at most one queued frame and never wait
    // for the browser to pull a sample at EOS.
    g_object_set(sink, "max-buffers", 1u, "drop", TRUE, "wait-on-eos", FALSE,
        "enable-last-sample", FALSE, NULL);
    g_object_set(pipeline, "uri", uri, "video-sink", sink, NULL);
    VoxLinuxMedia *media = g_new0(VoxLinuxMedia, 1);
    media->pipeline = pipeline;
    media->sink = GST_APP_SINK(sink);
    media->bus = gst_element_get_bus(pipeline);
    media->local = g_str_has_prefix(uri, "file://");
    media->rate = media->applied_rate = 1;
    if (gst_element_set_state(pipeline, GST_STATE_PAUSED) == GST_STATE_CHANGE_FAILURE) {
        native_media_close(media);
        return NULL;
    }
    return media;
}

static void vox_linux_media_apply_state(VoxLinuxMedia *media) {
    GstState next = media->wants_play && media->rate != 0 && !media->buffering && !media->ended
        ? GST_STATE_PLAYING : GST_STATE_PAUSED;
    if (gst_element_set_state(media->pipeline, next) == GST_STATE_CHANGE_FAILURE && !media->error)
        media->error = g_strdup("Could not change the media playback state");
}

static double native_media_time(void *handle) {
    VoxLinuxMedia *media = handle;
    gint64 position;
    if (!media) return 0;
    if (media->pending_seek || media->seeking) return media->pending_position;
    return gst_element_query_position(media->pipeline, GST_FORMAT_TIME, &position) && position >= 0
        ? (double)position / GST_SECOND : 0;
}

static double native_media_duration(void *handle) {
    VoxLinuxMedia *media = handle;
    gint64 duration;
    return media && gst_element_query_duration(media->pipeline, GST_FORMAT_TIME, &duration) && duration >= 0
        ? (double)duration / GST_SECOND : NAN;
}

static void vox_linux_media_apply_seek(VoxLinuxMedia *media) {
    if (!media->ready || media->seeking || (!media->pending_seek && media->rate == media->applied_rate)) return;
    if (media->rate == 0 && !media->pending_seek) return;
    double position = media->pending_seek ? media->pending_position : native_media_time(media);
    double duration = native_media_duration(media);
    if (isfinite(duration)) position = MIN(position, duration);
    double rate = media->rate != 0 ? media->rate : media->applied_rate;
    GstSeekFlags flags = GST_SEEK_FLAG_FLUSH
        | (media->pending_seek && media->approximate ? GST_SEEK_FLAG_KEY_UNIT : GST_SEEK_FLAG_ACCURATE);
    gint64 target = (gint64)(position * GST_SECOND);
    media->pending_seek = FALSE;
    if (!gst_element_seek(media->pipeline, rate, GST_FORMAT_TIME, flags,
            GST_SEEK_TYPE_SET, rate > 0 ? target : 0,
            rate > 0 ? GST_SEEK_TYPE_NONE : GST_SEEK_TYPE_SET, rate > 0 ? 0 : target)) return;
    media->pending_position = position;
    media->applied_rate = rate;
    media->seeking = TRUE;
    media->ended = media->report_ended = FALSE;
    vox_linux_media_apply_state(media);
}

static int32_t native_media_status(void *handle) {
    VoxLinuxMedia *media = handle;
    if (!media) return -1;
    GstMessage *message;
    while ((message = gst_bus_pop(media->bus))) {
        switch (GST_MESSAGE_TYPE(message)) {
        case GST_MESSAGE_ERROR: {
            GError *failure = NULL;
            gst_message_parse_error(message, &failure, NULL);
            if (!media->error) media->error = g_strdup(failure ? failure->message : "Media playback failed");
            g_clear_error(&failure);
            break;
        }
        case GST_MESSAGE_EOS:
            media->ended = media->report_ended = TRUE;
            break;
        case GST_MESSAGE_BUFFERING: {
            int percent = 100;
            gst_message_parse_buffering(message, &percent);
            gboolean buffering = percent < 100;
            if (buffering != media->buffering) {
                media->buffering = buffering;
                vox_linux_media_apply_state(media);
            }
            break;
        }
        case GST_MESSAGE_ASYNC_DONE:
            if (GST_MESSAGE_SRC(message) == GST_OBJECT(media->pipeline)) media->seeking = FALSE;
            break;
        default:
            break;
        }
        gst_message_unref(message);
    }
    if (media->error) return -1;
    if (!media->ready) {
        GstState state;
        GstStateChangeReturn change = gst_element_get_state(media->pipeline, &state, NULL, 0);
        if (change == GST_STATE_CHANGE_FAILURE) return -1;
        if (change == GST_STATE_CHANGE_ASYNC || state < GST_STATE_PAUSED) return 0;
        int audio = 0;
        g_object_get(media->pipeline, "n-audio", &audio, NULL);
        media->audio = audio > 0;
        GstPad *pad = gst_element_get_static_pad(GST_ELEMENT(media->sink), "sink");
        GstCaps *caps = gst_pad_get_current_caps(pad);
        gst_object_unref(pad);
        GstVideoInfo info;
        if (caps && gst_video_info_from_caps(&info, caps)) {
            media->width = GST_VIDEO_INFO_WIDTH(&info);
            media->height = GST_VIDEO_INFO_HEIGHT(&info);
        }
        if (caps) gst_caps_unref(caps);
        media->ready = TRUE;
    }
    vox_linux_media_apply_seek(media);
    return 1;
}

static const char *native_media_error(void *handle) { return ((VoxLinuxMedia *)handle)->error; }
static int32_t native_media_width(void *handle) { return ((VoxLinuxMedia *)handle)->width; }
static int32_t native_media_height(void *handle) { return ((VoxLinuxMedia *)handle)->height; }
static int32_t native_media_audio(void *handle) { return ((VoxLinuxMedia *)handle)->audio; }
static int32_t native_media_buffering(void *handle) {
    VoxLinuxMedia *media = handle;
    return media->buffering || media->pending_seek || media->seeking;
}
static int32_t native_media_ended(void *handle) { return handle && ((VoxLinuxMedia *)handle)->ended; }
static int32_t native_media_take_ended(void *handle) {
    VoxLinuxMedia *media = handle;
    gboolean result = media->report_ended;
    media->report_ended = FALSE;
    return result;
}
static int32_t native_media_buffer_count(void *handle) {
    return ((VoxLinuxMedia *)handle)->local && isfinite(native_media_duration(handle));
}
static double native_media_buffer_edge(void *handle, int32_t index, int32_t end) {
    return index == 0 && end ? native_media_duration(handle) : 0;
}
static void native_media_play(void *handle, double rate) {
    VoxLinuxMedia *media = handle;
    if (!media || !isfinite(rate)) return;
    media->wants_play = TRUE;
    media->rate = rate;
    vox_linux_media_apply_seek(media);
    vox_linux_media_apply_state(media);
}
static void native_media_pause(void *handle) {
    VoxLinuxMedia *media = handle;
    if (!media) return;
    media->wants_play = FALSE;
    vox_linux_media_apply_state(media);
}
static void native_media_volume(void *handle, double volume) {
    if (handle) g_object_set(((VoxLinuxMedia *)handle)->pipeline, "volume", volume, NULL);
}
static void native_media_seek(void *handle, double seconds, int32_t approximate) {
    VoxLinuxMedia *media = handle;
    if (!media || !isfinite(seconds) || seconds < 0 || seconds >= (double)G_MAXINT64 / GST_SECOND) return;
    media->pending_position = seconds;
    media->pending_seek = TRUE;
    media->approximate = approximate != 0;
    vox_linux_media_apply_seek(media);
}

// Decode and conversion run on the streaming threads. The caller borrows the
// sample for its synchronous retained-frame update, then releases the mapping.
static uint8_t *native_media_copy_frame(void *handle, int32_t *width, int32_t *height) {
    VoxLinuxMedia *media = handle;
    if (!media->width || media->pending_seek || media->seeking) return NULL;
    // Pulling a regular sample clears appsink's pending preroll buffer.
    GstSample *sample = gst_app_sink_try_pull_preroll(media->sink, 0);
    if (!sample && media->wants_play && media->rate != 0 && !media->buffering)
        sample = gst_app_sink_try_pull_sample(media->sink, 0);
    if (!sample) return NULL;
    GstBuffer *buffer = gst_sample_get_buffer(sample);
    GstCaps *caps = gst_sample_get_caps(sample);
    GstVideoInfo info;
    if (!buffer || !caps || buffer == media->last_buffer || !gst_video_info_from_caps(&info, caps)
        || GST_VIDEO_INFO_FORMAT(&info) != GST_VIDEO_FORMAT_RGBA
        || !gst_video_frame_map(&media->mapped, &info, buffer, GST_MAP_READ)) {
        gst_sample_unref(sample);
        return NULL;
    }
    if (media->last_buffer) gst_buffer_unref(media->last_buffer);
    media->last_buffer = gst_buffer_ref(buffer);
    gst_sample_unref(sample);
    *width = GST_VIDEO_FRAME_WIDTH(&media->mapped);
    *height = GST_VIDEO_FRAME_HEIGHT(&media->mapped);
    int stride = GST_VIDEO_FRAME_PLANE_STRIDE(&media->mapped, 0);
    int pitch = *width * 4;
    uint8_t *pixels = GST_VIDEO_FRAME_PLANE_DATA(&media->mapped, 0);
    if (stride == pitch) return pixels;
    size_t size = (size_t)pitch * *height;
    if (stride < pitch) {
        vox_linux_media_release_frame(media);
        return NULL;
    }
    if (media->packed_size < size) {
        uint8_t *packed = g_try_realloc(media->packed, size);
        if (!packed) {
            vox_linux_media_release_frame(media);
            return NULL;
        }
        media->packed = packed;
        media->packed_size = size;
    }
    for (int row = 0; row < *height; ++row)
        memcpy(media->packed + (size_t)row * pitch, pixels + (size_t)row * stride, pitch);
    return media->packed;
}
