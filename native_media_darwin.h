// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
#pragma once
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#include "native_avfoundation_darwin.h"
#include "native_ffmpeg_playback_darwin.h"
#include <stdint.h>
#include <stdlib.h>
#include <math.h>
#if defined(__aarch64__)
#include <arm_neon.h>
#endif

// All calls run on the browser's main thread. AVFoundation owns asynchronous
// networking, demuxing, decoding and audio; V pulls frames into VideoFrameSource.
@interface VoxMediaPlayback : NSObject
#ifdef LADYBIRD_V_HAS_FFMPEG
@property(nonatomic) VoxFFmpegVideo *webm;
@property(nonatomic) double webmPosition;
@property(nonatomic) double webmEpoch;
#endif
@property(nonatomic, retain) AVPlayer *player;
@property(nonatomic, retain) AVPlayerItemVideoOutput *output;
@property(nonatomic) BOOL seeking;
@property(atomic) NSUInteger seekGeneration;
@property(nonatomic) BOOL atEnd;
@property(nonatomic) BOOL endPending;
@property(nonatomic) double requestedRate;
@end
@implementation VoxMediaPlayback
- (void)recordEndForItem:(AVPlayerItem *)item generation:(NSUInteger)generation {
    if (generation != self.seekGeneration || self.seeking || self.atEnd || item != self.player.currentItem) return;
    self.atEnd = YES;
    self.endPending = YES;
}
- (void)itemDidPlayToEnd:(NSNotification *)notification {
    NSUInteger generation = self.seekGeneration;
    // AVFoundation may post from another thread. Keep the V-facing state on
    // the main thread and discard notifications overtaken by a seek.
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self recordEndForItem:notification.object generation:generation];
        });
    } else {
        [self recordEndForItem:notification.object generation:generation];
    }
}
- (void)dealloc {
#ifdef LADYBIRD_V_HAS_FFMPEG
    vox_ffmpeg_video_close(_webm);
#endif
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_player pause];
    [_player replaceCurrentItemWithPlayerItem:nil];
#if !__has_feature(objc_arc)
    [_player release];
    [_output release];
    [super dealloc];
#endif
}
@end

static VoxMediaPlayback *native_media_for_handle(void *handle) {
#if __has_feature(objc_arc)
    return (__bridge VoxMediaPlayback *)handle;
#else
    return (VoxMediaPlayback *)handle;
#endif
}

static void *native_media_open(const char *url) {
    NSURL *source = [NSURL URLWithString:[NSString stringWithUTF8String:url]];
    if (!source || ![@[@"https", @"http", @"file"] containsObject:source.scheme.lowercaseString]) return NULL;
    if (!vox_prepare_avfoundation()) return NULL;
    VoxMediaPlayback *media = [[VoxMediaPlayback alloc] init];
    AVPlayerItem *item = [vox_av_player_item playerItemWithURL:source];
    AVPlayerItemVideoOutput *output = [[vox_av_video_output alloc] initWithPixelBufferAttributes:
        @{(__bridge id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}];
    media.output = output;
#if !__has_feature(objc_arc)
    [output release];
#endif
    [item addOutput:media.output];
    media.player = [vox_av_player playerWithPlayerItem:item];
    media.player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
    [[NSNotificationCenter defaultCenter] addObserver:media selector:@selector(itemDidPlayToEnd:)
        name:vox_av_item_did_play_to_end object:item];
#if __has_feature(objc_arc)
    return (__bridge_retained void *)media;
#else
    return media;
#endif
}

// The caller fetches into an owned local file before opening this decoder.
static int32_t native_media_supports_webm(void) {
#ifdef LADYBIRD_V_HAS_FFMPEG
    return 1;
#else
    return 0;
#endif
}
static void *native_media_open_webm(const char *path) {
#ifdef LADYBIRD_V_HAS_FFMPEG
    VoxFFmpegVideo *video = vox_ffmpeg_video_open(path);
    if (!video) return NULL;
    VoxMediaPlayback *media = [[VoxMediaPlayback alloc] init];
    media.webm = video;
#if __has_feature(objc_arc)
    return (__bridge_retained void *)media;
#else
    return media;
#endif
#else
    (void)path;
    return NULL;
#endif
}

static void native_media_close(void *handle) {
#if __has_feature(objc_arc)
    VoxMediaPlayback *media = (__bridge_transfer VoxMediaPlayback *)handle;
    (void)media;
#else
    [native_media_for_handle(handle) release];
#endif
}
static int32_t native_media_status(void *handle) {
    VoxMediaPlayback *media = native_media_for_handle(handle);
    if (!media) return 0;
#ifdef LADYBIRD_V_HAS_FFMPEG
    if (media.webm) return media.webm->failed ? -1 : 1;
#endif
    AVPlayerItemStatus status = media.player.currentItem.status;
    return status == AVPlayerItemStatusFailed ? -1 : status == AVPlayerItemStatusReadyToPlay ? 1 : 0;
}
static const char *native_media_error(void *handle) {
#ifdef LADYBIRD_V_HAS_FFMPEG
    if (native_media_for_handle(handle).webm) return "WebM decoding failed";
#endif
    return [[[native_media_for_handle(handle) player] currentItem].error.localizedDescription UTF8String];
}
static double native_media_time(void *handle) {
    VoxMediaPlayback *media = native_media_for_handle(handle);
#ifdef LADYBIRD_V_HAS_FFMPEG
    if (media.webm) {
        if (media.atEnd) return media.webmPosition;
        double position = media.webmPosition + media.requestedRate
            * (NSProcessInfo.processInfo.systemUptime - media.webmEpoch);
        double duration = media.webm->duration;
        if ((media.requestedRate > 0 && isfinite(duration) && position >= duration)
            || (media.requestedRate < 0 && position <= 0)) {
            position = media.requestedRate < 0 ? 0 : duration;
            media.webmPosition = position;
            if (!media.atEnd) { media.atEnd = YES; media.endPending = YES; }
        }
        return fmax(0, position);
    }
#endif
    // The terminal decoded frame can precede the duration. The completion
    // notification establishes the exact endpoint used by HTML's ended test.
    double value = media.atEnd ? (media.requestedRate < 0 ? 0 : CMTimeGetSeconds(media.player.currentItem.duration))
        : CMTimeGetSeconds(media.player.currentTime);
    return isfinite(value) ? value : 0;
}
static int32_t native_media_ended(void *handle) {
    return native_media_for_handle(handle).atEnd;
}
static int32_t native_media_take_ended(void *handle) {
    VoxMediaPlayback *media = native_media_for_handle(handle);
    BOOL pending = media.endPending;
    media.endPending = NO;
    return pending;
}
static double native_media_duration(void *handle) {
#ifdef LADYBIRD_V_HAS_FFMPEG
    if (native_media_for_handle(handle).webm) return native_media_for_handle(handle).webm->duration;
#endif
    return CMTimeGetSeconds([native_media_for_handle(handle) player].currentItem.duration);
}
static int32_t native_media_audio(void *handle) {
    for (AVPlayerItemTrack *track in [native_media_for_handle(handle) player].currentItem.tracks)
        if ([track.assetTrack.mediaType isEqualToString:vox_av_audio_type]) return 1;
    return 0;
}
static int32_t native_media_width(void *handle) {
#ifdef LADYBIRD_V_HAS_FFMPEG
    if (native_media_for_handle(handle).webm) return native_media_for_handle(handle).webm->width;
#endif
    return (int32_t)[native_media_for_handle(handle) player].currentItem.presentationSize.width;
}
static int32_t native_media_height(void *handle) {
#ifdef LADYBIRD_V_HAS_FFMPEG
    if (native_media_for_handle(handle).webm) return native_media_for_handle(handle).webm->height;
#endif
    return (int32_t)[native_media_for_handle(handle) player].currentItem.presentationSize.height;
}
static int32_t native_media_buffer_count(void *handle) {
#ifdef LADYBIRD_V_HAS_FFMPEG
    if (native_media_for_handle(handle).webm) return isfinite(native_media_for_handle(handle).webm->duration) ? 1 : 0;
#endif
    return (int32_t)[native_media_for_handle(handle) player].currentItem.loadedTimeRanges.count;
}
static double native_media_buffer_edge(void *handle, int32_t index, int32_t end) {
#ifdef LADYBIRD_V_HAS_FFMPEG
    if (native_media_for_handle(handle).webm) return index == 0 && end ? native_media_for_handle(handle).webm->duration : 0;
#endif
    NSArray *ranges = [native_media_for_handle(handle) player].currentItem.loadedTimeRanges;
    if (index < 0 || index >= (int32_t)ranges.count) return 0;
    CMTimeRange range = [ranges[index] CMTimeRangeValue];
    return CMTimeGetSeconds(end ? CMTimeRangeGetEnd(range) : range.start);
}
static int32_t native_media_buffering(void *handle) {
#ifdef LADYBIRD_V_HAS_FFMPEG
    if (native_media_for_handle(handle).webm) return 0;
#endif
    VoxMediaPlayback *media = native_media_for_handle(handle);
    // A paused HLS seek can leave playbackBufferEmpty set even after the seek
    // completes, with its target buffered and playbackLikelyToKeepUp true.
    AVPlayerItem *item = media.player.currentItem;
    return media.seeking || (item.playbackBufferEmpty && !item.playbackLikelyToKeepUp);
}
static void native_media_play(void *handle, double rate) {
    VoxMediaPlayback *media = native_media_for_handle(handle);
#ifdef LADYBIRD_V_HAS_FFMPEG
    if (media.webm) {
        media.webmPosition = native_media_time(handle);
        media.webmEpoch = NSProcessInfo.processInfo.systemUptime;
        media.requestedRate = rate;
        return;
    }
#endif
    media.requestedRate = rate;
    if (!media.seeking) media.player.rate = (float)rate;
}
static void native_media_pause(void *handle) {
    VoxMediaPlayback *media = native_media_for_handle(handle);
#ifdef LADYBIRD_V_HAS_FFMPEG
    if (media.webm) {
        media.webmPosition = native_media_time(handle);
        media.requestedRate = 0;
        return;
    }
#endif
    media.requestedRate = 0;
    [media.player pause];
}
static void native_media_volume(void *handle, double volume) {
    [native_media_for_handle(handle) player].volume = (float)volume;
}
static void native_media_seek(void *handle, double seconds, int32_t approximate) {
    VoxMediaPlayback *media = native_media_for_handle(handle);
    if (!media || !isfinite(seconds)) return;
#ifdef LADYBIRD_V_HAS_FFMPEG
    if (media.webm) {
        seconds = fmax(0, seconds);
        if (isfinite(media.webm->duration)) seconds = fmin(seconds, media.webm->duration);
        if (!vox_ffmpeg_video_seek(media.webm, seconds)) { media.webm->failed = true; return; }
        media.webmPosition = seconds;
        media.webmEpoch = NSProcessInfo.processInfo.systemUptime;
        media.atEnd = media.endPending = NO;
        if (isfinite(media.webm->duration) && seconds >= media.webm->duration) {
            media.atEnd = media.endPending = YES;
        }
        return;
    }
#endif
    NSUInteger generation = ++media.seekGeneration;
    media.seeking = YES;
    media.atEnd = NO;
    media.endPending = NO;
    CMTime tolerance = approximate ? CMTimeMakeWithSeconds(0.1, 600) : kCMTimeZero;
    [media.player seekToTime:CMTimeMakeWithSeconds(seconds, 600)
        toleranceBefore:tolerance toleranceAfter:tolerance completionHandler:^(BOOL finished) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (generation != media.seekGeneration) return;
                media.seeking = NO;
                // AVPlayer pauses itself at the endpoint; HTML loops by seeking
                // while remaining unpaused. Honor any play/pause during the seek.
                if (finished) {
                    // A paused seek to the exact end does not produce AVPlayer's
                    // playback-completion notification. The completed seek itself
                    // establishes the endpoint in that case.
                    double duration = CMTimeGetSeconds(media.player.currentItem.duration);
                    if (!approximate && media.requestedRate >= 0 && isfinite(duration)
                        && duration > 0 && seconds >= duration) {
                        media.atEnd = YES;
                        media.endPending = YES;
                    }
                    media.player.rate = (float)media.requestedRate;
                }
            });
        }];
}
// A playing video converts every new frame on the main thread: swap red and
// blue four pixels at a time (1426x1080 BGRA frames on vlang.io).
static void native_media_bgra_to_rgba(const uint8_t *input, size_t stride, uint8_t *pixels,
    size_t w, size_t h) {
#if defined(__aarch64__)
    const uint8_t indices[] = {2, 1, 0, 3, 6, 5, 4, 7, 10, 9, 8, 11, 14, 13, 12, 15};
    uint8x16_t order = vld1q_u8(indices);
#endif
    for (size_t y = 0; y < h; ++y) {
        const uint8_t *src = input + y * stride;
        uint8_t *dst = pixels + y * w * 4;
        size_t x = 0;
#if defined(__aarch64__)
        for (; w - x >= 4; x += 4)
            vst1q_u8(dst + x * 4, vqtbl1q_u8(vld1q_u8(src + x * 4), order));
#endif
        for (; x < w; ++x) {
            dst[x * 4] = src[x * 4 + 2]; dst[x * 4 + 1] = src[x * 4 + 1];
            dst[x * 4 + 2] = src[x * 4]; dst[x * 4 + 3] = src[x * 4 + 3];
        }
    }
}
static uint8_t *native_media_copy_frame(void *handle, int32_t *width, int32_t *height) {
    VoxMediaPlayback *media = native_media_for_handle(handle);
    if (!media) return NULL;
#ifdef LADYBIRD_V_HAS_FFMPEG
    if (media.webm) {
        uint8_t *pixels = vox_ffmpeg_video_copy_frame(media.webm, native_media_time(handle));
        if (pixels) { *width = media.webm->width; *height = media.webm->height; }
        return pixels;
    }
#endif
    CMTime when = media.player.currentTime;
    if (![media.output hasNewPixelBufferForItemTime:when]) return NULL;
    CVPixelBufferRef frame = [media.output copyPixelBufferForItemTime:when itemTimeForDisplay:NULL];
    if (!frame) return NULL;
    size_t w = CVPixelBufferGetWidth(frame), h = CVPixelBufferGetHeight(frame);
    uint8_t *pixels = w && h && w <= INT32_MAX / 4 && h <= SIZE_MAX / (w * 4) ? malloc(w * h * 4) : NULL;
    if (pixels) {
        CVPixelBufferLockBaseAddress(frame, kCVPixelBufferLock_ReadOnly);
        const uint8_t *input = CVPixelBufferGetBaseAddress(frame);
        size_t stride = CVPixelBufferGetBytesPerRow(frame);
        native_media_bgra_to_rgba(input, stride, pixels, w, h);
        CVPixelBufferUnlockBaseAddress(frame, kCVPixelBufferLock_ReadOnly);
        *width = (int32_t)w; *height = (int32_t)h;
    }
    CVPixelBufferRelease(frame);
    return pixels;
}
static void native_media_free_frame(uint8_t *pixels) { free(pixels); }
