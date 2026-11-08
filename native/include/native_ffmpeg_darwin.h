#ifndef VOX_NATIVE_FFMPEG_DARWIN_H
#define VOX_NATIVE_FFMPEG_DARWIN_H
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#ifdef LADYBIRD_V_HAS_FFMPEG
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libavutil/dict.h>
#include <libswscale/swscale.h>
#include <libyuv/convert_argb.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#define VOX_FFMPEG_STRINGIFY_INNER(value) #value
#define VOX_FFMPEG_STRINGIFY(value) VOX_FFMPEG_STRINGIFY_INNER(value)
#define VOX_FFMPEG_FUNCTIONS(X) \
    X(av_find_best_stream) \
    X(av_frame_alloc) \
    X(av_frame_free) \
    X(av_frame_unref) \
    X(av_packet_alloc) \
    X(av_packet_free) \
    X(av_packet_unref) \
    X(av_read_frame) \
    X(av_seek_frame) \
    X(avcodec_alloc_context3) \
    X(avcodec_find_decoder) \
    X(avcodec_find_decoder_by_name) \
    X(avcodec_flush_buffers) \
    X(avcodec_free_context) \
    X(avcodec_open2) \
    X(avcodec_parameters_to_context) \
    X(avcodec_receive_frame) \
    X(avcodec_send_packet) \
    X(avformat_close_input) \
    X(avformat_find_stream_info) \
    X(avformat_open_input) \
    X(av_dict_get) \
    X(sws_scale) \
    X(sws_getContext) \
    X(sws_freeContext) \
    X(sws_getCoefficients) \
    X(sws_setColorspaceDetails)

typedef struct {
#define VOX_FFMPEG_FIELD(name) __typeof__(&name) name;
    VOX_FFMPEG_FUNCTIONS(VOX_FFMPEG_FIELD)
#ifndef LADYBIRD_V_HAS_RUST_YUV
    VOX_FFMPEG_FIELD(H420ToABGR)
#endif
#undef VOX_FFMPEG_FIELD
    void *format_library, *scale_library, *yuv_library;
    bool ready;
} VoxFFmpegAPI;

static VoxFFmpegAPI native_ffmpeg_functions;
// Keep codec libraries absent from ordinary document startup. Resolve their
// complete host API once on the first decode, retaining handles for later calls.
static const VoxFFmpegAPI *native_ffmpeg_api(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        VoxFFmpegAPI *api = &native_ffmpeg_functions;
        api->format_library = dlopen("@rpath/libavformat."
            VOX_FFMPEG_STRINGIFY(LIBAVFORMAT_VERSION_MAJOR) ".dylib", RTLD_LAZY | RTLD_LOCAL);
        api->scale_library = dlopen("@rpath/libswscale."
            VOX_FFMPEG_STRINGIFY(LIBSWSCALE_VERSION_MAJOR) ".dylib", RTLD_LAZY | RTLD_LOCAL);
#ifndef LADYBIRD_V_HAS_RUST_YUV
        api->yuv_library = dlopen("@rpath/libyuv.dylib", RTLD_LAZY | RTLD_LOCAL);
#endif
        bool complete = api->format_library && api->scale_library;
#define VOX_FFMPEG_RESOLVE(name) \
        api->name = api->format_library ? dlsym(api->format_library, #name) : NULL; \
        if (!api->name && api->scale_library) api->name = dlsym(api->scale_library, #name); \
        if (!api->name) complete = false;
        VOX_FFMPEG_FUNCTIONS(VOX_FFMPEG_RESOLVE)
#undef VOX_FFMPEG_RESOLVE
#ifndef LADYBIRD_V_HAS_RUST_YUV
        api->H420ToABGR = api->yuv_library ? dlsym(api->yuv_library, "H420ToABGR") : NULL;
        if (!api->H420ToABGR) complete = false;
#endif
        api->ready = complete;
        if (!complete) {
            if (api->yuv_library) dlclose(api->yuv_library);
            if (api->scale_library) dlclose(api->scale_library);
            if (api->format_library) dlclose(api->format_library);
            api->format_library = api->scale_library = api->yuv_library = NULL;
        }
    });
    return native_ffmpeg_functions.ready ? &native_ffmpeg_functions : NULL;
}
#undef VOX_FFMPEG_FUNCTIONS
#undef VOX_FFMPEG_STRINGIFY
#undef VOX_FFMPEG_STRINGIFY_INNER
#endif

#ifdef LADYBIRD_V_HAS_RUST_YUV
extern bool ladybird_v_yuv_u8_to_rgba(const uint8_t *, uint32_t,
    const uint8_t *, uint32_t, const uint8_t *, uint32_t, uint32_t,
    uint32_t, bool, bool, uint8_t *, uint32_t, uint8_t, uint8_t);
#endif

#ifdef LADYBIRD_V_HAS_FFMPEG
static bool native_ffmpeg_convert_frame(const VoxFFmpegAPI *ffmpeg, AVFrame *frame,
    uint8_t *pixels, int pitch) {
	int width = frame->width, height = frame->height;
	// Gfx::YUVData converts unspecified VP9 matrix metadata as limited
	// BT.709. Use the identical Rust yuv conversion entry point so the
	// native frame has exactly the same RGBA values as upstream.
	if (frame->format == AV_PIX_FMT_YUV420P
	    && frame->color_range != AVCOL_RANGE_JPEG
	    && (frame->colorspace == AVCOL_SPC_UNSPECIFIED
	        || frame->colorspace == AVCOL_SPC_BT709)) {
#ifdef LADYBIRD_V_HAS_RUST_YUV
		if (ladybird_v_yuv_u8_to_rgba(frame->data[0], frame->linesize[0],
			frame->data[1], frame->linesize[1], frame->data[2],
			frame->linesize[2], width, height, true, true, pixels,
			pitch, 0, 0)) {
			return true;
		}
#else
		if (ffmpeg->H420ToABGR(frame->data[0], frame->linesize[0],
			frame->data[1], frame->linesize[1], frame->data[2],
			frame->linesize[2], pixels, pitch, width, height) == 0) {
			return true;
		}
#endif
	}
	struct SwsContext *converter = ffmpeg->sws_getContext(width, height, (enum AVPixelFormat)frame->format,
		width, height, AV_PIX_FMT_RGBA, SWS_BILINEAR, NULL, NULL, NULL);
	if (converter == NULL)
		return false;
	int colorspace = SWS_CS_DEFAULT;
	switch (frame->colorspace) {
	case AVCOL_SPC_BT709:
		colorspace = SWS_CS_ITU709;
		break;
	case AVCOL_SPC_FCC:
		colorspace = SWS_CS_FCC;
		break;
	case AVCOL_SPC_SMPTE240M:
		colorspace = SWS_CS_SMPTE240M;
		break;
	case AVCOL_SPC_BT2020_NCL:
	case AVCOL_SPC_BT2020_CL:
		colorspace = SWS_CS_BT2020;
		break;
	case AVCOL_SPC_BT470BG:
	case AVCOL_SPC_SMPTE170M:
		colorspace = SWS_CS_ITU601;
		break;
	case AVCOL_SPC_UNSPECIFIED:
	default:
		// Gfx::YUVData uses BT.709 when CICP matrix metadata is
		// absent, so the browser host must not use swscale's
		// BT.601 default for an unspecified VP9 stream.
		colorspace = SWS_CS_ITU709;
		break;
	}
	const int *coefficients = ffmpeg->sws_getCoefficients(colorspace);
	if (coefficients != NULL) {
		ffmpeg->sws_setColorspaceDetails(converter, coefficients,
			frame->color_range == AVCOL_RANGE_JPEG, coefficients, 1,
			0, 1 << 16, 1 << 16);
	}
	uint8_t *destination[] = { pixels, NULL, NULL, NULL };
	int strides[] = { pitch, 0, 0, 0 };
	int rows = ffmpeg->sws_scale(converter, (const uint8_t *const *)frame->data,
		frame->linesize, 0, height, destination, strides);
	ffmpeg->sws_freeContext(converter);
	if (rows <= 0) return false;
	return true;
}
#endif

// Decode the first video frame at or after `seconds` into tightly packed RGBA.
// The caller owns the returned buffer and releases it with
// native_free_video_frame(). LibWeb retains the copied pixels in its external
// video content source, keeping FFmpeg entirely behind the browser host edge.
uint8_t *native_decode_video_frame(const char *path, double seconds,
	int *output_width, int *output_height, int *output_pitch) {
	if (output_width != NULL)
		*output_width = 0;
	if (output_height != NULL)
		*output_height = 0;
	if (output_pitch != NULL)
		*output_pitch = 0;
#ifndef LADYBIRD_V_HAS_FFMPEG
	(void)path;
	(void)seconds;
	return NULL;
#else
	if (path == NULL || output_width == NULL || output_height == NULL
	    || output_pitch == NULL)
		return NULL;
	const VoxFFmpegAPI *ffmpeg = native_ffmpeg_api();
	if (ffmpeg == NULL) return NULL;
	AVFormatContext *format = NULL;
	AVCodecContext *codec = NULL;
	AVPacket *packet = NULL;
	AVFrame *frame = NULL;
	uint8_t *pixels = NULL;
	int video_stream = -1;
	if (ffmpeg->avformat_open_input(&format, path, NULL, NULL) < 0
	    || ffmpeg->avformat_find_stream_info(format, NULL) < 0)
		goto cleanup;
	video_stream = ffmpeg->av_find_best_stream(format, AVMEDIA_TYPE_VIDEO, -1, -1,
		NULL, 0);
	if (video_stream < 0)
		goto cleanup;
	AVStream *stream = format->streams[video_stream];
	const AVCodec *decoder = ffmpeg->avcodec_find_decoder(stream->codecpar->codec_id);
	// WebM carries VP8/VP9 alpha in BlockAdditional packets. FFmpeg's native
	// decoders ignore that plane; libvpx exposes it as YUVA for RGBA conversion.
	// Keep the ordinary decoder and YUV fast path for opaque video.
	const AVDictionaryEntry *alpha = ffmpeg->av_dict_get(stream->metadata, "alpha_mode", NULL, 0);
	if (alpha && strcmp(alpha->value, "1") == 0) {
		const char *name = stream->codecpar->codec_id == AV_CODEC_ID_VP9 ? "libvpx-vp9"
			: stream->codecpar->codec_id == AV_CODEC_ID_VP8 ? "libvpx" : NULL;
		if (name) {
			decoder = ffmpeg->avcodec_find_decoder_by_name(name);
		}
	}
	if (decoder == NULL)
		goto cleanup;
	codec = ffmpeg->avcodec_alloc_context3(decoder);
	if (codec == NULL || ffmpeg->avcodec_parameters_to_context(codec, stream->codecpar) < 0
	    || ffmpeg->avcodec_open2(codec, decoder, NULL) < 0)
		goto cleanup;
	if (seconds > 0.0) {
		int64_t timestamp = (int64_t)floor(seconds / av_q2d(stream->time_base));
		if (ffmpeg->av_seek_frame(format, video_stream, timestamp, AVSEEK_FLAG_BACKWARD) >= 0)
			ffmpeg->avcodec_flush_buffers(codec);
	}
	packet = ffmpeg->av_packet_alloc();
	frame = ffmpeg->av_frame_alloc();
	if (packet == NULL || frame == NULL)
		goto cleanup;
	for (;;) {
		int read_result = ffmpeg->av_read_frame(format, packet);
		if (read_result < 0) {
			ffmpeg->avcodec_send_packet(codec, NULL);
		} else if (packet->stream_index == video_stream) {
			ffmpeg->avcodec_send_packet(codec, packet);
		}
		ffmpeg->av_packet_unref(packet);
		for (;;) {
			int receive_result = ffmpeg->avcodec_receive_frame(codec, frame);
			if (receive_result < 0)
				break;
			double frame_seconds = frame->best_effort_timestamp == AV_NOPTS_VALUE
				? seconds
				: frame->best_effort_timestamp * av_q2d(stream->time_base);
			if (frame_seconds + 0.000001 < seconds) {
				ffmpeg->av_frame_unref(frame);
				continue;
			}
			int width = frame->width;
			int height = frame->height;
			if (width <= 0 || height <= 0)
				goto cleanup;
			int pitch = width * 4;
			pixels = malloc((size_t)pitch * (size_t)height);
			if (pixels == NULL)
				goto cleanup;
			if (!native_ffmpeg_convert_frame(ffmpeg, frame, pixels, pitch))
				goto cleanup;
			*output_width = width;
			*output_height = height;
			*output_pitch = pitch;
			goto cleanup;
		}
		if (read_result < 0)
			break;
	}

cleanup:
	if (frame != NULL)
		ffmpeg->av_frame_free(&frame);
	if (packet != NULL)
		ffmpeg->av_packet_free(&packet);
	if (codec != NULL)
		ffmpeg->avcodec_free_context(&codec);
	if (format != NULL)
		ffmpeg->avformat_close_input(&format);
	if (*output_width <= 0 || *output_height <= 0) {
		free(pixels);
		return NULL;
	}
	return pixels;
#endif
}

void native_free_video_frame(uint8_t *pixels) {
	free(pixels);
}

#endif
