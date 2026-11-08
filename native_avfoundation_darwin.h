#pragma once
#import <Foundation/Foundation.h>
#include "platform/native_state.h"
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdlib.h>

// Playback owns AVFoundation. Documents without media need neither its class
// registration nor its native dependencies during browser startup.
static Class vox_av_player, vox_av_player_item, vox_av_video_output;
static NSString *vox_av_audio_type;
VOX_NATIVE_STATE NSString *vox_av_item_did_play_to_end;
static int vox_prepare_avfoundation(void) {
    static dispatch_once_t once;
    static int ready;
    dispatch_once(&once, ^{
        void *library = dlopen("/System/Library/Frameworks/AVFoundation.framework/AVFoundation", RTLD_LAZY | RTLD_LOCAL);
        if (!library) return;
        Class player = NSClassFromString(@"AVPlayer");
        Class item = NSClassFromString(@"AVPlayerItem");
        Class output = NSClassFromString(@"AVPlayerItemVideoOutput");
        NSString * __unsafe_unretained const *audio = (NSString * __unsafe_unretained const *)dlsym(library, "AVMediaTypeAudio");
        NSString * __unsafe_unretained const *did_end = (NSString * __unsafe_unretained const *)dlsym(library, "AVPlayerItemDidPlayToEndTimeNotification");
        if (!player || !item || !output || !audio || !*audio || !did_end || !*did_end) { dlclose(library); return; }
        vox_av_player = player;
        vox_av_player_item = item;
        vox_av_video_output = output;
        vox_av_audio_type = *audio;
        vox_av_item_did_play_to_end = *did_end;
        ready = 1;
        // Keep the framework and its classes alive while playback handles exist.
    });
    return ready;
}

__attribute__((constructor)) static void vox_eager_avfoundation_diagnostic(void) {
    if (getenv("VOX_EAGER_AVFOUNDATION")) (void)vox_prepare_avfoundation();
}
