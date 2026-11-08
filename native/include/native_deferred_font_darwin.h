#ifndef VOX_NATIVE_DEFERRED_FONT_DARWIN_H
#define VOX_NATIVE_DEFERRED_FONT_DARWIN_H
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef struct {
    NSString *path;
    CGFontRef font;
    BOOL attempted;
} VoxDeferredFont;

static void native_deferred_font_configure(VoxDeferredFont *state, NSString *path) {
    if (!path.length || ![[NSFileManager defaultManager] fileExistsAtPath:path]
        || [state->path isEqualToString:path]) return;
    state->path = [path copy];
    state->attempted = NO;
}

// An explicit configuration request may refresh the bytes at the same path.
// Keep the previous face available until that replacement opens successfully.
static BOOL native_deferred_font_configure_refresh(VoxDeferredFont *state, NSString *path) {
    if (!path.length || ![[NSFileManager defaultManager] fileExistsAtPath:path]) return NO;
    state->path = [path copy];
    state->attempted = NO;
    return YES;
}

static CGFontRef native_deferred_font_resolve(VoxDeferredFont *state,
    void (*did_load)(const char *)) {
    if (state->attempted || !state->path) return state->font;
    state->attempted = YES;
    CGDataProviderRef provider = CGDataProviderCreateWithFilename(state->path.fileSystemRepresentation);
    if (!provider) return state->font;
    CGFontRef font = CGFontCreateWithDataProvider(provider);
    CGDataProviderRelease(provider);
    if (!font) return state->font;
    if (state->font) CGFontRelease(state->font);
    state->font = font;
    if (did_load) did_load(state->path.fileSystemRepresentation);
    return font;
}

static void native_deferred_font_clear(VoxDeferredFont *state) {
    if (state->font) CGFontRelease(state->font);
    state->font = NULL;
    state->path = nil;
    state->attempted = NO;
}
#endif
