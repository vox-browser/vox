// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
#pragma once
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#include "native_avfoundation_darwin.h"
#include <stdint.h>
#include <stdlib.h>
#include <math.h>
#if defined(__aarch64__)
#include <arm_neon.h>
#endif

// All calls run on the browser's main thread. AVFoundation owns asynchronous
// networking, demuxing, decoding and audio; V pulls frames into VideoFrameSource.
@interface VoxMediaPlayback : NSObject
@property(nonatomic, retain) AVPlayer *player;
@property(nonatomic, retain) AVPlayerItemVideoOutput *output;
@property(nonatomic) BOOL seeking;
@property(nonatomic) NSUInteger seekGeneration;
@end
@implementation VoxMediaPlayback
- (void)dealloc {
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
#if __has_feature(objc_arc)
    return (__bridge_retained void *)media;
#else
    return media;
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
    AVPlayerItemStatus status = media.player.currentItem.status;
    return status == AVPlayerItemStatusFailed ? -1 : status == AVPlayerItemStatusReadyToPlay ? 1 : 0;
}
static const char *native_media_error(void *handle) {
    return [[[native_media_for_handle(handle) player] currentItem].error.localizedDescription UTF8String];
}
static double native_media_time(void *handle) {
    double value = CMTimeGetSeconds([native_media_for_handle(handle) player].currentTime);
    return isfinite(value) ? value : 0;
}
static double native_media_duration(void *handle) {
    return CMTimeGetSeconds([native_media_for_handle(handle) player].currentItem.duration);
}
static int32_t native_media_audio(void *handle) {
    for (AVPlayerItemTrack *track in [native_media_for_handle(handle) player].currentItem.tracks)
        if ([track.assetTrack.mediaType isEqualToString:vox_av_audio_type]) return 1;
    return 0;
}
static int32_t native_media_width(void *handle) {
    return (int32_t)[native_media_for_handle(handle) player].currentItem.presentationSize.width;
}
static int32_t native_media_height(void *handle) {
    return (int32_t)[native_media_for_handle(handle) player].currentItem.presentationSize.height;
}
static int32_t native_media_buffer_count(void *handle) {
    return (int32_t)[native_media_for_handle(handle) player].currentItem.loadedTimeRanges.count;
}
static double native_media_buffer_edge(void *handle, int32_t index, int32_t end) {
    NSArray *ranges = [native_media_for_handle(handle) player].currentItem.loadedTimeRanges;
    if (index < 0 || index >= (int32_t)ranges.count) return 0;
    CMTimeRange range = [ranges[index] CMTimeRangeValue];
    return CMTimeGetSeconds(end ? CMTimeRangeGetEnd(range) : range.start);
}
static int32_t native_media_buffering(void *handle) {
    VoxMediaPlayback *media = native_media_for_handle(handle);
    // A paused HLS seek can leave playbackBufferEmpty set even after the seek
    // completes, with its target buffered and playbackLikelyToKeepUp true.
    AVPlayerItem *item = media.player.currentItem;
    return media.seeking || (item.playbackBufferEmpty && !item.playbackLikelyToKeepUp);
}
static void native_media_play(void *handle, double rate) {
    [native_media_for_handle(handle) player].rate = (float)rate;
}
static void native_media_pause(void *handle) { [[native_media_for_handle(handle) player] pause]; }
static void native_media_volume(void *handle, double volume) {
    [native_media_for_handle(handle) player].volume = (float)volume;
}
static void native_media_seek(void *handle, double seconds, int32_t approximate) {
    VoxMediaPlayback *media = native_media_for_handle(handle);
    if (!media || !isfinite(seconds)) return;
    NSUInteger generation = ++media.seekGeneration;
    media.seeking = YES;
    CMTime tolerance = approximate ? CMTimeMakeWithSeconds(0.1, 600) : kCMTimeZero;
    [media.player seekToTime:CMTimeMakeWithSeconds(seconds, 600)
        toleranceBefore:tolerance toleranceAfter:tolerance completionHandler:^(BOOL finished) {
            if (generation == media.seekGeneration) media.seeking = NO;
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
