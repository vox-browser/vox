#pragma once
#import <Cocoa/Cocoa.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
// OS operations only. Validation, placement, persistence schema and transitions are V.
typedef void (*VoxWindowEvent)(void *, int32_t, double *, int32_t *);
static NSMutableArray *vox_window_observers;
static void native_window_snapshot(void *handle, double *values, int32_t *flags) {
    NSWindow *window = (__bridge NSWindow *)handle;
    NSRect frame = window.frame;
    values[0]=frame.origin.x; values[1]=frame.origin.y; values[2]=frame.size.width; values[3]=frame.size.height;
    values[4]=window.minSize.width; values[5]=window.minSize.height;
    flags[0]=window.zoomed; flags[1]=(window.styleMask & NSWindowStyleMaskFullScreen)!=0; flags[2]=window.miniaturized;
}
static int32_t native_window_screens(double *rows, int32_t capacity) {
    int32_t count=0;
    for (NSScreen *screen in NSScreen.screens) {
        if (count>=capacity) break;
        NSRect rect=screen.visibleFrame;
        rows[count*4]=rect.origin.x; rows[count*4+1]=rect.origin.y;
        rows[count*4+2]=rect.size.width; rows[count*4+3]=rect.size.height;
        ++count;
    }
    return count;
}
static int32_t native_window_screen_index(void *handle) {
    NSUInteger index=[NSScreen.screens indexOfObject:[(__bridge NSWindow *)handle screen]];
    return index==NSNotFound ? 0 : (int32_t)index;
}
static void native_window_set_frame(void *handle, double x, double y, double width, double height) {
    [(__bridge NSWindow *)handle setFrame:NSMakeRect(x,y,width,height) display:NO];
}
static void native_window_action(void *handle, int32_t action) {
    NSWindow *window=(__bridge NSWindow *)handle;
    if (action==0) [window zoom:nil]; else [window toggleFullScreen:nil];
}
static char *native_host_read_plist(const char *path) {
    @autoreleasepool {
        NSDictionary *value=[NSDictionary dictionaryWithContentsOfFile:[NSString stringWithUTF8String:path]];
        if (!value || ![NSJSONSerialization isValidJSONObject:value]) return NULL;
        NSData *data=[NSJSONSerialization dataWithJSONObject:value options:0 error:NULL];
        if (!data) return NULL;
        return strndup(data.bytes,data.length);
    }
}
static int32_t native_host_write_plist(const char *path, const unsigned char *json, int32_t length) {
    @autoreleasepool {
        NSData *data=[NSData dataWithBytes:json length:length];
        id value=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        return [value isKindOfClass:NSDictionary.class] && [value writeToFile:[NSString stringWithUTF8String:path] atomically:YES];
    }
}
static void native_window_stop_observing(void) {
    for (id observer in vox_window_observers) [NSNotificationCenter.defaultCenter removeObserver:observer];
    vox_window_observers=nil;
}
static void native_window_observe(void *handle, void *owner, VoxWindowEvent callback) {
    native_window_stop_observing();
    NSWindow *window=(__bridge NSWindow *)handle;
    vox_window_observers=[NSMutableArray new];
    NSArray *names=@[NSWindowDidResizeNotification,NSWindowWillEnterFullScreenNotification,
        NSWindowDidEnterFullScreenNotification,NSWindowWillExitFullScreenNotification,
        NSWindowDidExitFullScreenNotification,NSWindowWillCloseNotification,NSWindowDidMoveNotification,
        NSWindowDidEndLiveResizeNotification,NSWindowDidDeminiaturizeNotification];
    for (NSUInteger i=0;i<names.count;++i) {
        int32_t kind=i<6 ? (int32_t)i : 0;
        id observer=[NSNotificationCenter.defaultCenter addObserverForName:names[i] object:window queue:nil usingBlock:^(NSNotification *note) {
            (void)note; double values[6]; int32_t flags[3]; native_window_snapshot(handle,values,flags); callback(owner,kind,values,flags);
        }];
        [vox_window_observers addObject:observer];
    }
    id observer=[NSNotificationCenter.defaultCenter addObserverForName:NSApplicationWillTerminateNotification object:NSApp queue:nil usingBlock:^(NSNotification *note) {
        (void)note; double values[6]; int32_t flags[3]; native_window_snapshot(handle,values,flags); callback(owner,5,values,flags);
    }];
    [vox_window_observers addObject:observer];
}
