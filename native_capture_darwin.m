#include <dlfcn.h>
#include <Cocoa/Cocoa.h>
#include "native/include/native_snapshot_png_darwin.h"
#include "native/include/native_allocator_policy_darwin.h"
#include "native/include/native_glyph_flags.h"
#include "native/include/native_gpu_canvas_limits.h"
#include "native/include/native_test_window_darwin.h"
#include "native/include/native_media_preferences_darwin.h"
#include "native/include/native_writing_tools_darwin.h"
#include "native/include/native_ui_intelligence_darwin.h"
#include <CoreImage/CoreImage.h>
#include <CoreText/CoreText.h>
#include <malloc/malloc.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <execinfo.h>
#include <unistd.h>
#include "processmetrics/instruction_counter_darwin.h"
#include "processmetrics/thread_instruction_counter_darwin.h"

static void native_capture_instruction_checkpoint(const char *label) {
    if (!getenv("VOX_PROFILE_INSTRUCTIONS")) return;
    vox_thread_instruction_checkpoint(label);
    uint64_t instructions = 0;
    if (vox_process_instructions(&instructions) == 0)
        fprintf(stderr, "Vox instructions cumulative: %s %llu\n", label,
            (unsigned long long)instructions);
}

#include "native/include/native_layer_presentation_darwin.h"
#include "native/include/native_presented_capture_darwin.h"
#include "native/include/native_image_capture_policy_darwin.h"
#include "native/include/native_scroll_raster_darwin.h"
int native_gpu_tile_compositor_enabled(void) {
    if (!native_scroll_tile_setting || !getenv("VOX_GPU_TILE_COMPOSITOR")
        || getenv("VOX_DISABLE_SCROLL_TILE_COMPOSITOR") || native_scroll_gpu_tile_failed) return 0;
    return native_scroll_gpu_tiles_enabled()
        && native_scroll_tile_destination == NSGraphicsContext.currentContext.CGContext;
}
#include "native/include/native_stationary_raster_darwin.h"
#include "native/include/native_deferred_font_darwin.h"
#include "native/include/native_svg_mask_layer_darwin.h"
#include "native/include/native_svg_mask_pixels.h"

#include "native/include/native_ffmpeg_darwin.h"
#include "native/include/native_media_darwin.h"
#include "native/include/native_webp_darwin.h"
#include "native/include/native_jpeg_darwin.h"
#include "native/include/native_png_color_darwin.h"
#include "native/include/native_opacity_group_darwin.h"
#include "native/include/native_opacity_canvas_pool_darwin.h"
#include "native/include/native_bitmap_snapshot_darwin.h"
#include "native/include/native_svg_mask_opacity_darwin.h"

int native_prefers_overlay_scrollbars(void) {
	return [NSScroller preferredScrollerStyle] == NSScrollerStyleOverlay;
}


static NSString *native_capture_string(string value) {
	return [[NSString alloc] initWithBytes:value.str
	                              length:(NSUInteger)value.len
	                            encoding:NSUTF8StringEncoding];
}

static NSView *native_cached_browser_view;
static NSImageView *native_cached_snapshot_view;
static id<NSObject> native_activity_token;

// Keep the test display selected before Sokol starts, including when the app
// has no main or key window because the user is working in another application.
void native_position_window_top_right(void) {
	NSWindow *window = [NSApp mainWindow];
	if (window == nil) {
		window = [NSApp keyWindow];
	}
	if (window == nil) {
		window = [[NSApp windows] firstObject];
	}
	NSScreen *screen = native_test_window_screen ?: [window screen];
	if (screen == nil) {
		screen = [NSScreen mainScreen];
	}
	native_test_window_position(window, screen);
}

// Keep the run loop lively even when the window is occluded or not frontmost.
// Without this, App Nap throttles the process, stalling both page loads in
// background windows and the GCD main-queue work that captures cached rasters.
void native_prevent_app_nap(void) {
	if (native_activity_token != nil) {
		return;
	}
	native_activity_token = [[NSProcessInfo processInfo]
		beginActivityWithOptions:(NSActivityUserInitiated | NSActivityLatencyCritical)
		                  reason:@"Ladybird V rendering"];
}

static void native_consider_largest_view(NSView *view, NSView **largest_view, CGFloat *largest_area) {
	if (view == nil || [view isHidden]) {
		return;
	}
	NSSize size = [view bounds].size;
	CGFloat area = MAX(size.width, 0.0) * MAX(size.height, 0.0);
	if (area > *largest_area) {
		*largest_area = area;
		*largest_view = view;
	}
	for (NSView *subview in [view subviews]) {
		native_consider_largest_view(subview, largest_view, largest_area);
	}
}

static NSView *native_browser_view(void) {
	// Native field editors and app switching can make an auxiliary window key
	// or main. Keep using the drawable's owning window while it is attached.
	NSWindow *window = [native_cached_browser_view window];
	if (window == nil) {
		window = [NSApp mainWindow];
	}
	if (window == nil) {
		window = [NSApp keyWindow];
	}
	if (window == nil) {
		for (NSWindow *candidate in [NSApp windows]) {
			NSSize size = [[candidate contentView] bounds].size;
			if (size.width > 0.0 && size.height > 0.0) {
				window = candidate;
				break;
			}
		}
	}
	// The sokol view can acquire zero-sized helper siblings after startup, so
	// select and retain the largest drawable view instead of the last subview.
	NSView *largest_view = nil;
	CGFloat largest_area = 0.0;
	native_consider_largest_view([window contentView], &largest_view, &largest_area);
    // Startup and native controls can replace the content view while the old
    // view still has positive bounds. Resolve against the live window tree.
    native_cached_browser_view = largest_view;
    return largest_view;
}

// Sokol keeps a MetalKit parent behind its native Cocoa drawing child. The
// browser never submits a Metal pass through that view. In particular, its
// default multisampled depth/color attachments and periodic redraws are unused.
// Keep the parent and its event responder, but release its drawable storage.
@protocol VoxNativeMetalDrawable <NSObject>
- (void)setPaused:(BOOL)paused;
- (void)setEnableSetNeedsDisplay:(BOOL)enabled;
- (void)setSampleCount:(NSUInteger)count;
- (void)setDepthStencilPixelFormat:(NSUInteger)format;
- (void)releaseDrawables;
@end

static void native_configure_browser_drawable_tree(NSView *view) {
	if (view == nil) return;
	if ([view respondsToSelector:@selector(setPaused:)]
		&& [view respondsToSelector:@selector(setEnableSetNeedsDisplay:)]
		&& [view respondsToSelector:@selector(setSampleCount:)]
		&& [view respondsToSelector:@selector(setDepthStencilPixelFormat:)]
		&& [view respondsToSelector:@selector(releaseDrawables)]) {
		id<VoxNativeMetalDrawable> drawable = (id<VoxNativeMetalDrawable>)view;
		[drawable setPaused:YES];
		[drawable setEnableSetNeedsDisplay:NO];
		[drawable setSampleCount:1];
		// MTLPixelFormatInvalid: no depth/stencil attachment for Cocoa drawing.
		[drawable setDepthStencilPixelFormat:0];
		[drawable releaseDrawables];
	}
	for (NSView *child in [view subviews]) {
		native_configure_browser_drawable_tree(child);
	}
}

void native_configure_browser_drawables(void) {
	native_configure_browser_drawable_tree(native_browser_view());
}

static NSString *native_document_font_name;
static VoxDeferredFont native_regular_document_font;
static VoxDeferredFont native_bold_document_font;
static VoxDeferredFont native_emoji_font;
static void native_load_regular_document_font(const char *path);
static void native_load_bold_document_font(const char *path);

static CGFontRef native_document_graphics_font(int weight) {
	CGFontRef font = weight >= 600
		? native_deferred_font_resolve(&native_bold_document_font, native_load_bold_document_font) : NULL;
	return font ?: native_deferred_font_resolve(&native_regular_document_font, native_load_regular_document_font);
}

static NSFont *native_document_font(float size, int bold, int italic, int monospace) {
	NSFont *font = nil;
	if (!monospace) (void)native_document_graphics_font(400);
	if (monospace) {
		font = [NSFont fontWithName:@"Menlo" size:MAX(size - 5.0, 1.0)];
	} else if (native_document_font_name != nil) {
		font = [NSFont fontWithName:native_document_font_name size:size];
	}
	if (font == nil) {
		font = [NSFont userFontOfSize:size];
	}
	NSFontTraitMask traits = 0;
	if (bold) {
		traits |= NSBoldFontMask;
	}
	if (italic) {
		traits |= NSItalicFontMask;
	}
	if (traits != 0) {
		font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:traits];
	}
	return font;
}

static void native_load_regular_document_font(const char *path) {
	if (getenv("VOX_DOCUMENT_FONT_DIAGNOSTICS")) fprintf(stderr, "VOX_DOCUMENT_FONT regular loaded %s\n", path);
	CGFontRef font = native_regular_document_font.font;
	CFErrorRef registration_error = NULL;
	CTFontManagerRegisterGraphicsFont(font, &registration_error);
	if (registration_error != NULL) {
		CFRelease(registration_error);
	}
	CFStringRef postscript_name = CGFontCopyPostScriptName(font);
	if (postscript_name != NULL) {
		native_document_font_name = [(__bridge NSString *)postscript_name copy];
		CFRelease(postscript_name);
	}
}

static void native_load_bold_document_font(const char *path) {
	if (getenv("VOX_DOCUMENT_FONT_DIAGNOSTICS")) fprintf(stderr, "VOX_DOCUMENT_FONT bold loaded %s\n", path);
	(void)path;
}

static void native_configure_fallback_document_font(VoxDeferredFont *state,
	NSString *path, void (*did_load)(const char *)) {
	// Explicit configuration can refresh bytes at the same path. Keep the old
	// face until a replacement opens successfully, as the eager path did.
	if (!native_deferred_font_configure_refresh(state, path)) return;
	if (getenv("VOX_DOCUMENT_FONT_DIAGNOSTICS")) fprintf(stderr, "VOX_DOCUMENT_FONT configured %s\n", path.fileSystemRepresentation);
	if (getenv("VOX_EAGER_DOCUMENT_FONT")) (void)native_deferred_font_resolve(state, did_load);
}

void native_configure_document_font(string path_value) {
	native_configure_fallback_document_font(&native_regular_document_font,
		native_capture_string(path_value), native_load_regular_document_font);
}

void native_configure_document_bold_font(string path_value) {
	native_configure_fallback_document_font(&native_bold_document_font,
		native_capture_string(path_value), native_load_bold_document_font);
}

void native_configure_emoji_font(string path_value) {
	native_deferred_font_configure(&native_emoji_font, native_capture_string(path_value));
}

static void native_load_emoji_font(const char *path) {
	(void)path;
}

// Convert the embedding view's logical top-left coordinates to the same global
// top-left screen coordinates used by platform MouseEvent screenX/screenY.
void native_pointer_screen_position(double x, double y, double *screen_x, double *screen_y) {
	NSView *view = native_browser_view();
	if (view == nil || [view window] == nil)
		return;
	NSPoint point = NSMakePoint(x, [view isFlipped] ? y : [view bounds].size.height - y);
	point = [view convertPoint:point toView:nil];
	point = [[view window] convertPointToScreen:point];
	NSScreen *primary_screen = [[NSScreen screens] firstObject];
	*screen_x = point.x;
	*screen_y = NSMaxY([primary_screen frame]) - point.y;
}

int native_window_width(void) {
	return (int)llround([native_browser_view() bounds].size.width);
}

int native_window_height(void) {
	return (int)llround([native_browser_view() bounds].size.height);
}

static void native_trace_browser_redraw(const char *point) {
	if (!getenv("VOX_TRACE_REDRAWS")) return;
	fprintf(stderr, "Vox redraw %s: generation=%llu paint=%llu presenting=%d work=%d\n",
		point, (unsigned long long)native_layer_redraw_generation,
		(unsigned long long)native_layer_paint_generation,
		native_layer_presenting, native_layer_document_work_active);
	void *frames[12];
	int count = backtrace(frames, 12);
	backtrace_symbols_fd(frames, count, STDERR_FILENO);
}

static void native_mark_browser_redraw(void) {
	if (native_frame_timeline_enabled())
		fprintf(stderr, "VOX_TIMELINE mark t=%.6f\n", native_frame_timeline_now());
	// An asynchronous resource can complete while the application has no main
	// or key window. Keep redrawing the window that owns our retained drawable.
	NSWindow *window = [native_browser_view() window];
	if (window == nil) {
		window = [NSApp mainWindow];
		if (window == nil) {
			window = [NSApp keyWindow];
		}
	}
	static int redraw_all = -1;
	if (redraw_all < 0) {
		const char *value = getenv("VOX_REDRAW_ALL_NATIVE_VIEWS");
		redraw_all = value && *value;
	}
	NSUInteger count = 0;
	if (redraw_all) {
		NSMutableArray<NSView *> *views = [NSMutableArray array];
		if (window.contentView) [views addObject:window.contentView];
		while (views.count) {
			NSView *view = views.lastObject; [views removeLastObject];
			view.needsDisplay = YES; count++;
			[views addObjectsFromArray:view.subviews];
		}
	} else {
		count = native_layer_request_canvas_frames(window.contentView);
	}
	const char *diagnostics = getenv("VOX_REDRAW_SCOPE_DIAGNOSTICS");
	if (diagnostics && *diagnostics)
		fprintf(stderr, "VOX_REDRAW_SCOPE all=%d count=%lu\n", redraw_all, (unsigned long)count);
	NSEvent *event = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
	                                location:NSZeroPoint
	                           modifierFlags:0
	                               timestamp:0
	                            windowNumber:[window windowNumber]
	                                 context:nil
	                                 subtype:0
	                                   data1:0
	                                   data2:0];
	[NSApp postEvent:event atStart:NO];
}

static void native_request_browser_redraw(void) {
	++native_layer_redraw_generation;
	native_trace_browser_redraw("deliver");
	native_mark_browser_redraw();
}

// Documents under the Chromium policy show focus only while the window is
// focused and active. Screenshot test windows keep the application inactive.
int native_browser_window_is_active(void) {
	static dispatch_once_t observing;
	dispatch_once(&observing, ^{
		NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
		for (NSNotificationName name in @[NSApplicationDidBecomeActiveNotification,
				NSApplicationDidResignActiveNotification, NSWindowDidBecomeKeyNotification,
				NSWindowDidResignKeyNotification]) {
			[center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
				usingBlock:^(NSNotification *notification) {
					(void)notification;
					native_request_browser_redraw();
				}];
		}
	});
	NSWindow *window = [native_browser_view() window];
	return NSApp.isActive && window.isKeyWindow ? 1 : 0;
}

void native_wake_browser(void) {
	native_trace_browser_redraw("request");
	if (native_frame_timeline_enabled())
		fprintf(stderr, "VOX_TIMELINE wake t=%.6f\n", native_frame_timeline_now());
	// Style and layout can request thousands of frames before the main queue
	// runs. One wake covers all work already queued; keep later requests able
	// to schedule another wake once this delivery begins.
	static bool wake_queued;
	if (__atomic_exchange_n(&wake_queued, true, __ATOMIC_ACQ_REL)) return;
	dispatch_async(dispatch_get_main_queue(), ^{
		__atomic_store_n(&wake_queued, false, __ATOMIC_RELEASE);
		native_request_browser_redraw();
	});
}

// A PageClient repaint requested while the V owner is preparing this frame
// belongs to that frame's input. Stamp it now so a main-queue delivery delayed
// until replay cannot invalidate pixels which already include the change.
// Worker completions and requests after preparation retain ordinary wakes.
void native_wake_browser_during_preparation(void) {
	if (!NSThread.isMainThread || !native_layer_presenting
		|| !native_layer_document_work_active || native_layer_paint_started) {
		native_wake_browser();
		return;
	}
	static bool wake_queued;
	static uint64_t requested_generation;
	requested_generation = ++native_layer_redraw_generation;
	native_trace_browser_redraw("preparation request");
	if (wake_queued) return;
	wake_queued = true;
	dispatch_async(dispatch_get_main_queue(), ^{
		wake_queued = false;
		if (native_layer_last_prepared_generation >= requested_generation) {
			native_trace_browser_redraw("preparation consumed");
			return;
		}
		native_mark_browser_redraw();
	});
}

void native_wake_browser_after(int milliseconds) {
	native_trace_browser_redraw("schedule timer");
	if (native_frame_timeline_enabled())
		fprintf(stderr, "VOX_TIMELINE wake_after t=%.6f ms=%d\n", native_frame_timeline_now(), milliseconds);
	int64_t delay = (int64_t)MAX(milliseconds, 0) * NSEC_PER_MSEC;
	dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, delay);
	// Sampling after constructing the dispatch deadline gives a conservative
	// boundary which cannot precede the timer's actual requested fire time.
	double deadline = CACurrentMediaTime() + (double)delay / NSEC_PER_SEC;
	BOOL coalesce = getenv("VOX_COALESCE_EXPIRED_FRAME_TIMERS") != NULL;
	// The retained block keeps this identity alive. A preparation in another
	// window, or a worker request without a main-thread target, cannot consume it.
	NSView *requested_view = coalesce && NSThread.isMainThread ? native_browser_view() : nil;
	dispatch_after(when, dispatch_get_main_queue(), ^{
		if (requested_view && requested_view == native_browser_view()
			&& native_layer_last_preparation_view == (uintptr_t)(__bridge void *)requested_view
			&& native_layer_last_preparation_started >= deadline) {
			if (getenv("VOX_FRAME_TIMER_DIAGNOSTICS"))
				fprintf(stderr, "VOX_EXPIRED_FRAME_TIMER consumed=1 lateness_us=%.3f\n",
					(native_layer_last_preparation_started - deadline) * 1e6);
			return;
		}
		native_request_browser_redraw();
	});
}

static uint64_t native_capture_retry_generation;
static BOOL native_capture_retry_pending;
static int (*native_capture_retry_ready)(void *);
static void *native_capture_retry_context;

static void native_deliver_capture_retry(uint64_t generation) {
	if (!native_capture_retry_pending || generation != native_capture_retry_generation) return;
	// The current frame already checks resource readiness at its end. A retry
	// delivered during it only dirties that same frame and forces another paint.
	if (native_layer_presenting || native_layer_document_work_active) {
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC),
			dispatch_get_main_queue(), ^{ native_deliver_capture_retry(generation); });
		return;
	}
	if (native_capture_retry_ready) {
		int ready = native_capture_retry_ready(native_capture_retry_context);
		if (ready < 0) { native_capture_retry_pending = NO; return; }
		if (!ready) {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 16 * NSEC_PER_MSEC),
				dispatch_get_main_queue(), ^{ native_deliver_capture_retry(generation); });
			return;
		}
	}
	native_capture_retry_pending = NO;
	native_request_browser_redraw();
}

void native_cancel_capture_retry(void) {
	native_capture_retry_pending = NO;
	++native_capture_retry_generation;
}

void native_schedule_capture_retry(int (*ready)(void *), void *context) {
	if (native_capture_retry_pending) return;
	native_capture_retry_pending = YES;
	native_capture_retry_ready = ready;
	native_capture_retry_context = context;
	uint64_t generation = ++native_capture_retry_generation;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 16 * NSEC_PER_MSEC),
		dispatch_get_main_queue(), ^{ native_deliver_capture_retry(generation); });
}

void native_show_cached_snapshot(string path_value) {
	NSString *path = native_capture_string(path_value);
	void (^show_snapshot)(void) = ^{
		NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
		NSView *browser_view = native_browser_view();
		if (image == nil || browser_view == nil) {
			return;
		}
		[native_cached_snapshot_view removeFromSuperview];
		native_cached_snapshot_view = [[NSImageView alloc] initWithFrame:[browser_view bounds]];
		[native_cached_snapshot_view setImage:image];
		[native_cached_snapshot_view setImageScaling:NSImageScaleAxesIndependently];
		[native_cached_snapshot_view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[browser_view addSubview:native_cached_snapshot_view
		                 positioned:NSWindowAbove
		                 relativeTo:nil];
		[browser_view setNeedsDisplay:YES];
		[browser_view displayIfNeeded];
	};
	if ([NSThread isMainThread]) {
		show_snapshot();
	} else {
		dispatch_async(dispatch_get_main_queue(), show_snapshot);
	}
}

void native_hide_cached_snapshot(void) {
	void (^hide_snapshot)(void) = ^{
		[native_cached_snapshot_view removeFromSuperview];
		native_cached_snapshot_view = nil;
	};
	if ([NSThread isMainThread]) {
		hide_snapshot();
	} else {
		dispatch_async(dispatch_get_main_queue(), hide_snapshot);
	}
}

// Screenshot references use one device pixel per CSS pixel unless
// LADYBIRD_SCREENSHOT_SCALE requests a denser capture, such as 2 for the same
// device-pixel output a Retina window presents.
static CGFloat native_screenshot_scale(void) {
	const char *value = getenv("LADYBIRD_SCREENSHOT_SCALE");
	double scale = value == NULL ? 1.0 : strtod(value, NULL);
	return isfinite(scale) && scale > 1.0 ? (CGFloat)scale : 1.0;
}

static BOOL native_screenshot_uses_logical_pixels(void) {
	return getenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS") != NULL && native_screenshot_scale() <= 1.0;
}

void native_cache_browser_snapshot(string path_value) {
	NSString *path = native_capture_string(path_value);
	BOOL debug_snapshot = getenv("LADYBIRD_DEBUG_SNAPSHOT") != NULL;
	if (debug_snapshot) {
		fprintf(stderr, "Ladybird V: scheduling cached snapshot %s\n", [path fileSystemRepresentation]);
	}
	// Capture on the next main-loop turn (after the in-progress drawRect: has
	// returned) rather than after a fixed delay: dispatch_async runs as soon as
	// the current frame finishes, and posting a wake guarantees the run loop
	// iterates to service it even when the app is otherwise idle.
	dispatch_async(dispatch_get_main_queue(), ^{
		native_when_document_work_idle(^{
		NSView *view = native_browser_view();
		[view displayIfNeeded];
		NSRect bounds = [view bounds];
		NSBitmapImageRep *bitmap = nil;
		// LibWeb screenshot references use one device pixel per CSS pixel. A
		// Retina cacheDisplay bitmap followed by an image-tool resize changes
		// Skia's discrete coverage and blur kernels, so create the test surface at
		// its final logical resolution from the outset.
		if (getenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS") != NULL) {
			NSInteger pixels_wide = (NSInteger)llround(bounds.size.width * native_screenshot_scale());
			NSInteger pixels_high = (NSInteger)llround(bounds.size.height * native_screenshot_scale());
			if (pixels_wide > 0 && pixels_high > 0) {
				bitmap = [[NSBitmapImageRep alloc]
					initWithBitmapDataPlanes:NULL
					              pixelsWide:pixels_wide
					              pixelsHigh:pixels_high
					           bitsPerSample:8
					         samplesPerPixel:4
					                hasAlpha:YES
					                isPlanar:NO
					          colorSpaceName:NSDeviceRGBColorSpace
					             bytesPerRow:pixels_wide * 4
					            bitsPerPixel:32];
				[bitmap setSize:bounds.size];
			}
		} else {
			bitmap = [view bitmapImageRepForCachingDisplayInRect:bounds];
		}
		if (bitmap == nil) {
			CGFloat scale = [[view window] backingScaleFactor];
			if (scale <= 0.0) {
				scale = 1.0;
			}
			NSInteger pixels_wide = (NSInteger)llround(bounds.size.width * scale);
			NSInteger pixels_high = (NSInteger)llround(bounds.size.height * scale);
			if (pixels_wide <= 0 || pixels_high <= 0) {
				if (debug_snapshot) {
					fprintf(stderr, "Ladybird V: snapshot aborted, zero-size view\n");
				}
				return;
			}
			bitmap = [[NSBitmapImageRep alloc]
				initWithBitmapDataPlanes:NULL
				              pixelsWide:pixels_wide
				              pixelsHigh:pixels_high
				           bitsPerSample:8
				         samplesPerPixel:4
				                hasAlpha:YES
				                isPlanar:NO
				          colorSpaceName:NSDeviceRGBColorSpace
				             bytesPerRow:pixels_wide * 4
				            bitsPerPixel:32];
			[bitmap setSize:bounds.size];
		}
		NSBitmapImageRep *presented = native_presented_capture_bitmap(view, bounds, bitmap.pixelsWide, bitmap.pixelsHigh);
		if (presented) bitmap = presented;
		else native_cache_display_in_bitmap(view, bounds, bitmap);
		NSBitmapImageRep *encoded_bitmap = presented ?:
		    [bitmap bitmapImageRepByConvertingToColorSpace:[NSColorSpace sRGBColorSpace]
		                                  renderingIntent:NSColorRenderingIntentRelativeColorimetric];
		if (encoded_bitmap == nil) {
			encoded_bitmap = bitmap;
		}
		NSData *png = native_encode_snapshot_png(encoded_bitmap);
		if (png == nil) {
			if (debug_snapshot) {
				fprintf(stderr, "Ladybird V: cached snapshot PNG encoding failed\n");
			}
			return;
		}
		[[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent]
		                         withIntermediateDirectories:YES
		                                          attributes:nil
		                                               error:nil];
		BOOL saved = [png writeToFile:path options:NSDataWritingAtomic error:nil];
		if (debug_snapshot) {
			fprintf(stderr, "Ladybird V: cached snapshot %s\n", saved ? "saved" : "write failed");
		}
		});
	});
	// Nudge the run loop so the queued capture is serviced promptly even if no
	// user or timer event would otherwise wake it.
	native_request_browser_redraw();
}

static void native_draw_solid_rect_srgb(float x, float y, float width, float height,
	gg__Color color, int caret) {
	if (width <= 0 || height <= 0) {
		return;
	}
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL) {
		return;
	}
	static CGColorSpaceRef colorSpace;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	});
	CGFloat components[] = {
		(CGFloat)color.r / 255.0,
		(CGFloat)color.g / 255.0,
		(CGFloat)color.b / 255.0,
		(CGFloat)color.a / 255.0,
	};
	CGColorRef cgColor = CGColorCreate(colorSpace, components);
	CGContextSetFillColorWithColor(context, cgColor);
	CGRect rect = CGRectMake(x, y, width, height);
	if (!vox_initial_document_clear(&native_layer_initial_document_clear, context, rect,
		color.r, color.g, color.b, color.a)) CGContextFillRect(context, rect);
	CGColorRelease(cgColor);
}

void native_draw_rect_srgb(float x, float y, float width, float height, gg__Color color) {
	native_draw_solid_rect_srgb(x, y, width, height, color, 0);
}

void native_draw_caret_rect_srgb(float x, float y, float width, float height, gg__Color color) {
	native_draw_solid_rect_srgb(x, y, width, height, color, 1);
}

static CGContextRef native_font_compositing_context;
static int native_font_compositing_transparency_depth;

static void native_begin_tracked_transparency_layer(CGContextRef context, CFDictionaryRef info) {
	vox_initial_document_clear_disarm(&native_layer_initial_document_clear, context);
	if (context == native_font_compositing_context) {
		native_font_compositing_transparency_depth++;
	}
	CGContextBeginTransparencyLayer(context, info);
}

static void native_end_tracked_transparency_layer(CGContextRef context) {
	CGContextEndTransparencyLayer(context);
	if (context == native_font_compositing_context) {
		native_font_compositing_transparency_depth--;
	}
}

void native_begin_clip(void) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	vox_initial_document_clear_disarm(&native_layer_initial_document_clear, context);
	if (context == NULL) {
		return;
	}
	CGContextSaveGState(context);
}

void native_end_clip(void) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context != NULL) {
		CGContextRestoreGState(context);
	}
}

static CGBlendMode native_css_background_blend_mode(int mode) {
	switch (mode) {
	case 1: return kCGBlendModeMultiply;
	case 2: return kCGBlendModeScreen;
	case 3: return kCGBlendModeOverlay;
	case 4: return kCGBlendModeDarken;
	case 5: return kCGBlendModeLighten;
	case 6: return kCGBlendModeColorDodge;
	case 7: return kCGBlendModeColorBurn;
	case 8: return kCGBlendModeHardLight;
	case 9: return kCGBlendModeSoftLight;
	case 10: return kCGBlendModeDifference;
	case 11: return kCGBlendModeExclusion;
	case 12: return kCGBlendModeHue;
	case 13: return kCGBlendModeSaturation;
	case 14: return kCGBlendModeColor;
	case 15: return kCGBlendModeLuminosity;
	case 16: return kCGBlendModePlusDarker;
	case 17: return kCGBlendModePlusLighter;
	default: return kCGBlendModeNormal;
	}
}

void native_begin_background_blend_group(void) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL) {
		return;
	}
	CGContextSaveGState(context);
	native_begin_tracked_transparency_layer(context, NULL);
}

void native_end_background_blend_group(void) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL) {
		return;
	}
	native_end_tracked_transparency_layer(context);
	CGContextRestoreGState(context);
}

void native_begin_background_blend_mode(int mode) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL) {
		return;
	}
	CGContextSaveGState(context);
	CGContextSetBlendMode(context, native_css_background_blend_mode(mode));
}

void native_end_background_blend_mode(void) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context != NULL) {
		CGContextRestoreGState(context);
	}
}

#include "native/include/native_chromium_screen_blend.h"

static CGBlendMode native_compositing_operator(int mode) {
	switch (mode) {
	case 1: return kCGBlendModeDestinationIn;
	case 2: return kCGBlendModeMultiply;
	case 3: return kCGBlendModeScreen;
	case 4: return kCGBlendModeOverlay;
	case 5: return kCGBlendModeDarken;
	case 6: return kCGBlendModeLighten;
	case 7: return kCGBlendModeColorDodge;
	case 8: return kCGBlendModeColorBurn;
	case 9: return kCGBlendModeHardLight;
	case 10: return kCGBlendModeSoftLight;
	case 11: return kCGBlendModeDifference;
	case 12: return kCGBlendModeExclusion;
	case 13: return kCGBlendModeHue;
	case 14: return kCGBlendModeSaturation;
	case 15: return kCGBlendModeColor;
	case 16: return kCGBlendModeLuminosity;
	case 17: return kCGBlendModePlusDarker;
	case 18: return kCGBlendModePlusLighter;
	default: return kCGBlendModeNormal;
	}
}

// A Chromium-profile opacity group with normal or screen blending paints into its own
// bitmap, which shares the compositing canvas's format and device space. Its
// leaves therefore keep their exact Skia compositing, and the group is drawn
// over the backdrop with Chromium's floating-point layer composite.
typedef struct {
	int offscreen;
	int passthrough;
	CGContextRef parent;
	CGContextRef context;
	uint8_t *pixels;
	float opacity;
	int blend_mode;
	int left, top, right, bottom;
	int text_gpu_boundary; // Diagnostic: 1 current prefix, 2 pending GPU prefix.
} NativeOpacityGroup;

#define NATIVE_OPACITY_GROUP_MAX_DEPTH 64
static NativeOpacityGroup native_opacity_groups[NATIVE_OPACITY_GROUP_MAX_DEPTH];
static int native_opacity_group_depth;
static int native_opacity_group_overflow_depth;

static int native_compositing_canvas_is_readable(CGContextRef context) {
	if (context == NULL) return 0;
	CGAffineTransform ctm = CGContextGetCTM(context);
	return context != NULL && context == native_font_compositing_context
		&& native_font_compositing_transparency_depth == 0
		&& CGBitmapContextGetData(context) != NULL
		&& CGBitmapContextGetBitsPerPixel(context) == 32
		&& CGBitmapContextGetAlphaInfo(context) == kCGImageAlphaPremultipliedLast
		&& (CGBitmapContextGetBitmapInfo(context) & kCGBitmapByteOrderMask) == kCGBitmapByteOrder32Big
		&& ctm.a > 0 && ctm.d > 0 && ctm.b == 0 && ctm.c == 0 && ctm.tx == 0 && ctm.ty == 0;
}

static void native_set_deferred_layer_destination(CGContextRef context, int active) {
}

void native_begin_deferred_layer_frame(int enabled) {
}

int native_finish_deferred_layer_frame(void) {
    int valid = !native_scroll_gpu_tile_frame_failed;
    native_scroll_gpu_tile_frame_failed = NO;
    return valid;
}

static int native_begin_offscreen_opacity_group(NativeOpacityGroup *group, CGContextRef parent,
	float opacity, int blend_mode) {
	if (!native_compositing_canvas_is_readable(parent)) {
		return 0;
	}
	size_t width = CGBitmapContextGetWidth(parent), height = CGBitmapContextGetHeight(parent);
	CGRect clip = CGContextGetClipBoundingBox(parent);
	if (CGRectIsNull(clip) || CGRectIsEmpty(clip)) {
		return 0;
	}
	CGRect device = CGRectIsInfinite(clip)
		? CGRectMake(0, 0, (CGFloat)width, (CGFloat)height)
		: CGContextConvertRectToDeviceSpace(parent, clip);
	// A bitmap context's device space runs downwards, like its rows.
	int left = (int)MAX(0.0, floor(CGRectGetMinX(device)));
	int right = (int)MIN((double)width, ceil(CGRectGetMaxX(device)));
	int top = (int)MAX(0.0, floor(CGRectGetMinY(device)));
	int bottom = (int)MIN((double)height, ceil(CGRectGetMaxY(device)));
	if (left >= right || top >= bottom) {
		return 0;
	}
	VoxOpacityCanvas canvas = native_acquire_opacity_canvas(width, height,
		CGBitmapContextGetColorSpace(parent));
	CGContextRef context = canvas.context;
	if (context == NULL) return 0;
	CGContextConcatCTM(context, CGContextGetCTM(parent));
	CGContextClipToRect(context, clip);
	native_set_deferred_layer_destination(context, 1);
	CGContextSetShouldAntialias(context, true);
	CGContextSetInterpolationQuality(context, CGContextGetInterpolationQuality(parent));
	BOOL flipped = [[NSGraphicsContext currentContext] isFlipped];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:
		[NSGraphicsContext graphicsContextWithCGContext:context flipped:flipped]];
	*group = (NativeOpacityGroup){
		.offscreen = 1, .parent = parent, .context = context, .pixels = canvas.pixels,
		.opacity = MIN(MAX(opacity, 0.0f), 1.0f),
		.blend_mode = blend_mode,
		.left = left, .top = top, .right = right, .bottom = bottom,
	};
	native_font_compositing_context = context;
	return 1;
}

static void native_end_offscreen_opacity_group(NativeOpacityGroup *group) {
	native_set_deferred_layer_destination(group->context, 0);
	[NSGraphicsContext restoreGraphicsState];
	native_font_compositing_context = group->parent;
	native_font_compositing_transparency_depth = 0;
    int nested_gpu = 0;
	CGContextFlush(group->context);
	CGContextFlush(group->parent);
	size_t width = CGBitmapContextGetWidth(group->parent);
	size_t height = CGBitmapContextGetHeight(group->parent);
	size_t layer_pitch = width * 4;
	size_t parent_pitch = CGBitmapContextGetBytesPerRow(group->parent);
	const uint8_t *backdrop = (const uint8_t *)CGBitmapContextGetData(group->parent);
	int left, top, right, bottom;
	if (native_opacity_canvas_ink_bounds((VoxOpacityCanvas){group->context, group->pixels},
		layer_pitch, group->left, group->top,
			group->right, group->bottom, &left, &top, &right, &bottom)) {
		size_t ink_width = (size_t)(right - left), ink_height = (size_t)(bottom - top);
		CGColorSpaceRef color_space = CGBitmapContextGetColorSpace(group->parent);
		CGContextRef result_context = CGBitmapContextCreate(NULL, ink_width, ink_height,
			8, ink_width * 4, color_space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
		uint8_t *result = result_context == NULL ? NULL : (uint8_t *)CGBitmapContextGetData(result_context);
		if (result != NULL) {
			for (size_t row = 0; row < ink_height; ++row) {
				if (group->blend_mode == 3) native_composite_screen_pixels(
					group->pixels + (top + row) * layer_pitch + (size_t)left * 4,
					backdrop + (top + row) * parent_pitch + (size_t)left * 4,
					result + row * ink_width * 4, ink_width, group->opacity);
				else native_composite_opacity_pixels(
					group->pixels + (top + row) * layer_pitch + (size_t)left * 4,
					backdrop + (top + row) * parent_pitch + (size_t)left * 4,
					result + row * ink_width * 4, ink_width, group->opacity);
			}
			CGImageRef image = native_take_bitmap_image_for_destination(result_context, group->parent);
			if (image != NULL) {
				// Copy the composite into place under the backdrop's clip.
				CGRect target = CGContextConvertRectToUserSpace(group->parent,
					CGRectMake(left, top, ink_width, ink_height));
				CGContextSaveGState(group->parent);
				CGContextSetBlendMode(group->parent, kCGBlendModeCopy);
				CGContextSetInterpolationQuality(group->parent, kCGInterpolationNone);
				CGContextDrawImage(group->parent, target, image);
				CGContextRestoreGState(group->parent);
				CGImageRelease(image);
			}
		} else if (result_context != NULL) {
			CGContextRelease(result_context);
		}
	}
	native_release_opacity_canvas((VoxOpacityCanvas){group->context, group->pixels},
		group->left, group->top, group->right, group->bottom);
}

void native_begin_css_effect_layer(float opacity, int blend_mode) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL) {
		return;
	}
	CGContextSaveGState(context);
	if (native_opacity_group_depth < NATIVE_OPACITY_GROUP_MAX_DEPTH) {
		NativeOpacityGroup *group = &native_opacity_groups[native_opacity_group_depth++];
		*group = (NativeOpacityGroup){ .parent = context };
		if ((blend_mode == 0 || blend_mode == 3)
			&& native_begin_offscreen_opacity_group(group, context, opacity, blend_mode)) {
			return;
		}

	} else {
		native_opacity_group_overflow_depth++;
	}
	CGContextSetAlpha(context, opacity);
	CGContextSetBlendMode(context, native_compositing_operator(blend_mode));
	native_begin_tracked_transparency_layer(context, NULL);
}

void native_set_chromium_opaque_layer_continuation(int enabled) {
}

void native_end_css_effect_layer(void) {
	if (native_opacity_group_overflow_depth > 0) {
		native_opacity_group_overflow_depth--;
	} else if (native_opacity_group_depth > 0) {
		NativeOpacityGroup group = native_opacity_groups[--native_opacity_group_depth];
		if (group.passthrough) {
			CGContextRestoreGState(group.parent);
			return;
		}
		if (group.offscreen) {
			native_end_offscreen_opacity_group(&group);
			CGContextRestoreGState(group.parent);
			return;
		}
	}
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL) {
		return;
	}
	native_end_tracked_transparency_layer(context);
	CGContextRestoreGState(context);
}

static CGColorRef native_srgb_color(gg__Color color) {
	static CGColorSpaceRef color_space;
	static dispatch_once_t once_token;
	dispatch_once(&once_token, ^{
		color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	});
	CGFloat components[] = {
		(CGFloat)color.r / 255.0,
		(CGFloat)color.g / 255.0,
		(CGFloat)color.b / 255.0,
		(CGFloat)color.a / 255.0,
	};
	return CGColorCreate(color_space, components);
}

// The display density documents see as their device pixel ratio: the screenshot
// scale for captures (logical 1x by default), otherwise the main screen's
// backing scale.
double native_display_device_pixel_ratio(void) {
	if (getenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS") != NULL) {
		return native_screenshot_scale();
	}
	CGFloat scale = [[NSScreen mainScreen] backingScaleFactor];
	return isfinite(scale) && scale > 0 ? scale : 1.0;
}

// Retained glyph runs name the exact face V shaped them with: either a font
// file plus its collection index, or a key registered below for a matched
// system face with variation coordinates. Replay must draw with that face;
// glyph IDs are meaningless in any other font. cpuraster's CoreText services
// own the registry, so its glyph masks and this fallback open the same face.
#include "cpuraster/glyph_coretext.h"

// Register a CoreText-selected face for retained glyph replay under `key`.
int native_register_system_face(string key, string path, string postscript_name,
	const uint32_t *axis_tags, const float *axis_values, int axis_count) {
	NSString *key_string = native_capture_string(key);
	NSString *path_string = native_capture_string(path);
	NSString *name_string = native_capture_string(postscript_name);
	if (key_string.length == 0 || path_string.length == 0) return 0;
	return cpuraster_ct_register_face(key_string.UTF8String, path_string.fileSystemRepresentation,
		name_string ? name_string.UTF8String : "", axis_tags, axis_values, axis_count);
}

// A CTFont for a retained run's face at `size`, or NULL when the face cannot
// be opened.
static CTFontRef native_replay_font(const char *font_path, int face_index, CGFloat size) CF_RETURNS_RETAINED {
	if (font_path == NULL || *font_path == 0) return NULL;
	int flags = 0;
	CTFontRef base = (CTFontRef)cpuraster_ct_font_for_face(font_path, face_index, &flags);
	if (base == NULL) return NULL;
	CTFontRef font = CTFontCreateCopyWithAttributes(base, MAX(size, 0.0), NULL, NULL);
	CFRelease(base);
	return font;
}

// Retained text rasters (main.v's native_draw_retained_glyph_run()): cpuraster
// draws a run's glyph masks into a device-pixel RGBA raster covering its
// bounds, as the removed Skia bridge's leaf raster did. Opaque document text
// blends over a copy of the page pixels it covers, as Blink's raster does,
// and replaces them; other runs draw over transparency and Quartz blends the
// result. `geometry` receives the raster's logical left/top, its device
// width/height, whether it holds the backdrop, and its logical width/height
// (seven values). Returns 0 when the
// destination cannot take a raster, 2 when the run is clipped out, else 1.
int native_text_raster_begin(float left, float top, float right, float bottom,
	float canvas_width, float canvas_height, int font_smoothing, int32_t *geometry, float *scale_out) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL || geometry == NULL || scale_out == NULL) return 0;
	if (!isfinite(left) || !isfinite(top) || !isfinite(right) || !isfinite(bottom)) return 0;
	int region_left = MAX(0, (int)floorf(left - 2.0f));
	int region_top = MAX(0, (int)floorf(top - 2.0f));
	int region_right = MIN((int)ceilf(canvas_width), (int)ceilf(right + 2.0f));
	int region_bottom = MIN((int)ceilf(canvas_height), (int)ceilf(bottom + 2.0f));
	if (region_right <= region_left || region_bottom <= region_top) return 2;
	CGRect clip = CGContextGetClipBoundingBox(context);
	if (CGRectIsNull(clip) || CGRectIsEmpty(clip)) return 2;
	if (!CGRectIsInfinite(clip) && isfinite(clip.origin.x) && isfinite(clip.origin.y)
		&& isfinite(clip.size.width) && isfinite(clip.size.height)) {
		const double fringe = 2.0;
		if (!(region_right > CGRectGetMinX(clip) - fringe && region_left < CGRectGetMaxX(clip) + fringe
			&& region_bottom > canvas_height - CGRectGetMaxY(clip) - fringe
			&& region_top < canvas_height - CGRectGetMinY(clip) + fringe)) return 2;
	}
	CGSize horizontal = CGContextConvertSizeToDeviceSpace(context, CGSizeMake(1.0, 0.0));
	CGSize vertical = CGContextConvertSizeToDeviceSpace(context, CGSizeMake(0.0, 1.0));
	double scale = MAX(hypot(horizontal.width, horizontal.height), hypot(vertical.width, vertical.height));
	if (!isfinite(scale) || scale <= 0.0) scale = 1.0;
	int width = MAX(1, (int)ceilf((float)(region_right - region_left) * (float)scale));
	int height = MAX(1, (int)ceilf((float)(region_bottom - region_top) * (float)scale));
	if ((int64_t)width * height > 64 * 1024 * 1024) return 0;
	int backdrop = 0;
	if ((font_smoothing & 16) && context == native_font_compositing_context
		&& native_font_compositing_transparency_depth == 0
		&& CGBitmapContextGetBitsPerPixel(context) == 32
		&& CGBitmapContextGetAlphaInfo(context) == kCGImageAlphaPremultipliedLast
		&& (CGBitmapContextGetBitmapInfo(context) & kCGBitmapByteOrderMask) == kCGBitmapByteOrder32Big
		&& CGBitmapContextGetData(context) != NULL) {
		CGAffineTransform ctm = CGContextGetCTM(context);
		size_t x = (size_t)lround(region_left * scale), y = (size_t)lround(region_top * scale);
		backdrop = ctm.a > 0 && ctm.d > 0 && ctm.b == 0 && ctm.c == 0 && ctm.tx == 0 && ctm.ty == 0
			&& x + (size_t)width <= CGBitmapContextGetWidth(context)
			&& y + (size_t)height <= CGBitmapContextGetHeight(context);
	}
	geometry[0] = region_left;
	geometry[1] = region_top;
	geometry[2] = width;
	geometry[3] = height;
	geometry[4] = backdrop;
	geometry[5] = region_right - region_left;
	geometry[6] = region_bottom - region_top;
	*scale_out = (float)scale;
	return 1;
}

// Copy the page pixels a backdrop raster covers (premultiplied RGBA rows).
int native_text_raster_read_backdrop(uint8_t *pixels, int left, int top, int width, int height, float scale) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL || pixels == NULL) return 0;
	CGContextFlush(context);
	const uint8_t *data = (const uint8_t *)CGBitmapContextGetData(context);
	if (data == NULL) return 0;
	size_t pitch = CGBitmapContextGetBytesPerRow(context);
	size_t x = (size_t)lround(left * scale), y = (size_t)lround(top * scale);
	for (int row = 0; row < height; ++row)
		memcpy(pixels + (size_t)row * width * 4, data + (y + (size_t)row) * pitch + x * 4, (size_t)width * 4);
	return 1;
}

// Composite a finished raster: a backdrop raster replaces its pixels under
// the current clip, a transparent one blends over them.
int native_text_raster_finish(const uint8_t *pixels, int left, int top, int width, int height,
	int logical_width, int logical_height, float canvas_height, int backdrop) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL || pixels == NULL) return 0;
	CFDataRef data = CFDataCreate(kCFAllocatorDefault, pixels, (CFIndex)width * height * 4);
	if (data == NULL) return 0;
	CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
	CFRelease(data);
	if (provider == NULL) return 0;
	CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	CGImageRef image = CGImageCreate((size_t)width, (size_t)height, 8, 32, (size_t)width * 4, space,
		(CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big, provider, NULL, false,
		kCGRenderingIntentDefault);
	CGColorSpaceRelease(space);
	CGDataProviderRelease(provider);
	if (image == NULL) return 0;
	CGRect rect = CGRectMake(left, canvas_height - (float)(top + logical_height),
		logical_width, (float)logical_height);
	CGContextSaveGState(context);
	if (backdrop) CGContextSetBlendMode(context, kCGBlendModeCopy);
	CGContextSetInterpolationQuality(context, kCGInterpolationNone);
	CGContextDrawImage(context, rect, image);
	CGContextRestoreGState(context);
	CGImageRelease(image);
	return 1;
}

// The native boundary supplies the destination pixels; geometry and GPU
// rasterization belong to V's gg.canvas adapter.
#include "native/include/native_graphite_bridge.h"
extern int vox_draw_document_shape_pixels(uint8_t*, int, int, int, int, int, int, VoxGraphiteShape*);
VOX_NATIVE_STATE VoxGraphiteShape native_v_shape_state;

static int native_try_v_document_shape(VoxGraphiteShape shape, const float* matrix,
    float canvas_width, float canvas_height, float page_x, float page_y, float scroll_y) {
    if ([[NSGraphicsContext currentContext] CGContext] != native_font_compositing_context) return 0;
    float x=shape.rect[0], y=shape.rect[1], width=shape.rect[2], height=shape.rect[3];
    int fill=shape.fill; float thickness=shape.thickness;
    float left = INFINITY, top = INFINITY, right = -INFINITY, bottom = -INFINITY;
    float pad = (fill == 0 || fill == 12) ? fmaxf(thickness, 0) * .5f : ((fill == 10 || fill == 13) ? fmaxf(thickness, 0) * 1.5f : 0);
    for (int i = 0; i < 4; ++i) {
        float px = x + ((i & 1) ? width + pad : -pad);
        float py = y + ((i & 2) ? height + pad : -pad);
        float dx = matrix[0]*px + matrix[2]*py + matrix[4];
        float dy = matrix[1]*px + matrix[3]*py + matrix[5];
        left=fminf(left,dx); top=fminf(top,dy); right=fmaxf(right,dx); bottom=fmaxf(bottom,dy);
    }
    int32_t geometry[7]; float scale;
    int prepared = native_text_raster_begin(left, top, right, bottom, canvas_width, canvas_height,
        16, geometry, &scale);
    if (prepared == 2) return 1;
    if (prepared != 1) return 0;
    int w=geometry[2], h=geometry[3], backdrop=geometry[4];
    size_t size=(size_t)w*h*4;
    uint8_t* pixels=calloc(size,1);
    if (!pixels) return 0;
    if (backdrop && !native_text_raster_read_backdrop(pixels,geometry[0],geometry[1],w,h,scale)) {
        free(pixels); return 0;
    }
    float sx=(float)w/geometry[5], sy=(float)h/geometry[6];
    float cropped[9]={matrix[0]*sx,matrix[2]*sx,(matrix[4]-geometry[0])*sx,
        matrix[1]*sy,matrix[3]*sy,(matrix[5]-geometry[1])*sy,0,0,1};
    memcpy(shape.matrix,cropped,sizeof(cropped));
    int drawn=vox_draw_document_shape_pixels(pixels,w,h,w*4,backdrop,
        (int)lround((geometry[0]-page_x)*scale),
        (int)lround((geometry[1]-page_y+scroll_y)*scale),&shape);
    if (drawn) drawn=native_text_raster_finish(pixels,geometry[0],geometry[1],w,h,
        geometry[5],geometry[6],canvas_height,backdrop);
    free(pixels);
    return drawn;
}

// Shared paint descriptors; native code only transfers pixels and coordinates.
int native_draw_document_shape_group(VoxGraphiteShape* shapes, int count, float* matrix,
    float canvas_width,float canvas_height,float page_x,float page_y,float scroll_y) {
    if(!shapes||!matrix||count<=0||count>32||[[NSGraphicsContext currentContext] CGContext]!=native_font_compositing_context)return 0;
    float left=INFINITY,top=INFINITY,right=-INFINITY,bottom=-INFINITY;
    for(int j=0;j<count;++j) {
        VoxGraphiteShape* shape=&shapes[j];
        float pad=(shape->fill==0||shape->fill==12)?fmaxf(shape->thickness,0)*.5f:
            ((shape->fill==10||shape->fill==13)?fmaxf(shape->thickness,0)*1.5f:0);
        for(int i=0;i<4;++i) {
            float x=shape->rect[0]+((i&1)?shape->rect[2]+pad:-pad);
            float y=shape->rect[1]+((i&2)?shape->rect[3]+pad:-pad);
            float dx=matrix[0]*x+matrix[2]*y+matrix[4],dy=matrix[1]*x+matrix[3]*y+matrix[5];
            left=fminf(left,dx);top=fminf(top,dy);right=fmaxf(right,dx);bottom=fmaxf(bottom,dy);
        }
    }
    int32_t geometry[7];float scale;
    int prepared=native_text_raster_begin(left,top,right,bottom,canvas_width,canvas_height,16,geometry,&scale);
    if(prepared==2)return 1;
    if(prepared!=1)return 0;
    int w=geometry[2],h=geometry[3],backdrop=geometry[4];
    uint8_t* pixels=calloc((size_t)w*h*4,1);
    if(!pixels)return 0;
    if(backdrop&&!native_text_raster_read_backdrop(pixels,geometry[0],geometry[1],w,h,scale)) {free(pixels);return 0;}
    VoxGraphiteShape copy[32];memcpy(copy,shapes,count*sizeof(*shapes));
    float sx=(float)w/geometry[5],sy=(float)h/geometry[6];
    float cropped[9]={matrix[0]*sx,matrix[2]*sx,(matrix[4]-geometry[0])*sx,
        matrix[1]*sy,matrix[3]*sy,(matrix[5]-geometry[1])*sy,0,0,1};
    for(int j=0;j<count;++j)memcpy(copy[j].matrix,cropped,sizeof(cropped));
    extern int vox_draw_document_shape_group_pixels(uint8_t*,int,int,int,int,int,int,VoxGraphiteShape*,int);
    int drawn=vox_draw_document_shape_group_pixels(pixels,w,h,w*4,backdrop,
        (int)lround((geometry[0]-page_x)*scale),(int)lround((geometry[1]-page_y+scroll_y)*scale),copy,count);
    if(drawn)drawn=native_text_raster_finish(pixels,geometry[0],geometry[1],w,h,geometry[5],geometry[6],canvas_height,backdrop);
    free(pixels);return drawn;
}

static int native_try_v_rounded_rect(float x, float y, float width, float height,
    const float* radii, const float* matrix, float canvas_width, float canvas_height,
    gg__Color color, int fill, float thickness, int anti_alias,
    float page_x, float page_y, float scroll_y) {
    if ([[NSGraphicsContext currentContext] CGContext] != native_font_compositing_context) return 0;
    VoxGraphiteShape shape = native_v_shape_state;
    shape.rect[0] = x; shape.rect[1] = y; shape.rect[2] = width; shape.rect[3] = height;
    memcpy(shape.rect + 4, radii, 8 * sizeof(float));
    shape.red = color.r; shape.green = color.g; shape.blue = color.b; shape.alpha = color.a;
    shape.fill = fill; shape.thickness = thickness; shape.anti_alias = anti_alias;
    shape.force_msaa = 1;
    return native_try_v_document_shape(shape,matrix,canvas_width,canvas_height,page_x,page_y,scroll_y);
}

int native_draw_document_shape(const VoxGraphiteShape* shape, const float* matrix,
    float canvas_width, float canvas_height, float page_x, float page_y, float scroll_y) {
    if (!shape || !matrix) return 0;
    return native_try_v_document_shape(*shape,matrix,canvas_width,canvas_height,page_x,page_y,scroll_y);
}

extern int vox_draw_document_path_pixels(uint8_t*, int, int, int, int, VoxGraphitePath*);
static int native_try_v_svg_path(CGPathRef path, const float* segments, int count, int even_odd,
    const float* matrix, float canvas_width, float canvas_height, gg__Color color,
    const float* components, int stroke, float stroke_width, int cap, int join,
    float miter, int non_scaling) {
    if ([[NSGraphicsContext currentContext] CGContext] != native_font_compositing_context) return 0;
    CGRect bounds=CGPathGetPathBoundingBox(path);
    float pad=stroke ? fmaxf(stroke_width,0)*fmaxf(miter,1) : 0;
    float left=INFINITY,top=INFINITY,right=-INFINITY,bottom=-INFINITY;
    for(int i=0;i<4;++i) {
        float x=bounds.origin.x+((i&1)?bounds.size.width+pad:-pad);
        float y=bounds.origin.y+((i&2)?bounds.size.height+pad:-pad);
        float dx=matrix[0]*x+matrix[2]*y+matrix[4],dy=matrix[1]*x+matrix[3]*y+matrix[5];
        left=fminf(left,dx);top=fminf(top,dy);right=fmaxf(right,dx);bottom=fmaxf(bottom,dy);
    }
    int32_t geometry[7];float scale;
    int prepared=native_text_raster_begin(left,top,right,bottom,canvas_width,canvas_height,16,geometry,&scale);
    if(prepared==2)return 1;
    if(prepared!=1)return 0;
    int w=geometry[2],h=geometry[3],backdrop=geometry[4];
    uint8_t* pixels=calloc((size_t)w*h*4,1);
    if(!pixels)return 0;
    if(backdrop&&!native_text_raster_read_backdrop(pixels,geometry[0],geometry[1],w,h,scale)){
        free(pixels);return 0;
    }
    float sx=(float)w/geometry[5],sy=(float)h/geometry[6];
    VoxGraphitePath draw={0};
    float cropped[9]={matrix[0]*sx,matrix[2]*sx,(matrix[4]-geometry[0])*sx,
        matrix[1]*sy,matrix[3]*sy,(matrix[5]-geometry[1])*sy,0,0,1};
    memcpy(draw.matrix,cropped,sizeof(cropped));
    draw.segments=segments;draw.segment_count=count;draw.even_odd=even_odd;
    draw.red=color.r;draw.green=color.g;draw.blue=color.b;draw.alpha=color.a;
    draw.stroke=stroke;draw.stroke_width=stroke_width;draw.line_cap=cap;draw.line_join=join;
    draw.miter_limit=miter;draw.non_scaling_stroke=non_scaling;
    draw.opacity=1;
    draw.has_float_color=components!=NULL;
    if(components)memcpy(draw.float_color,components,4*sizeof(float));
    int drawn=vox_draw_document_path_pixels(pixels,w,h,w*4,backdrop,&draw);
    if(drawn)drawn=native_text_raster_finish(pixels,geometry[0],geometry[1],w,h,
        geometry[5],geometry[6],canvas_height,backdrop);
    free(pixels);return drawn;
}

static void native_configure_glyph_rasterization(CGContextRef context, int font_smoothing) {
	font_smoothing &= 15;
	CGContextSetShouldAntialias(context, font_smoothing != 1);
	CGContextSetAllowsFontSmoothing(context, font_smoothing != 1 && font_smoothing != 2);
	CGContextSetShouldSmoothFonts(context, font_smoothing != 1 && font_smoothing != 2);
	CGContextSetAllowsFontSubpixelPositioning(context, true);
	CGContextSetShouldSubpixelPositionFonts(context, true);
	// SkFont retains the exact HarfBuzz positions. Do not let CoreGraphics snap
	// those positions to its own subpixel grid during display-list replay.
	CGContextSetAllowsFontSubpixelQuantization(context, true);
	CGContextSetShouldSubpixelQuantizeFonts(context, false);
}

// DisplayListPlayerSkia replays the glyph IDs and positions retained by
// Gfx::GlyphRun. Keep those values in glyph space here as well: its positive-Y
// axis is the font's ascent direction, while the CSS transform's positive-Y
// axis points down. Building the two basis vectors explicitly avoids asking
// AppKit to shape the source string again and preserves arbitrary CSS affine
// transforms.
static int native_draw_retained_glyph_run(CGContextRef context,
	const char *font_path, int face_index, const uint16_t *glyphs, const double *packed_positions, int glyph_count,
	float font_size, int font_weight, int emoji_face, float baseline_x, float baseline_y,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_width, float canvas_height, CGColorRef color, float blur,
	int shadow_only, int font_smoothing) {
	if (context == NULL || glyphs == NULL || packed_positions == NULL
		|| glyph_count <= 0) {
		return 0;
	}
	// Draw with the exact face the run was shaped with. The configured
	// document font remains the fallback for runs without a face.
	CTFontRef font = emoji_face ? NULL : native_replay_font(font_path, face_index, font_size);
	if (font == NULL) {
		CGFontRef graphics_font = emoji_face
			? native_deferred_font_resolve(&native_emoji_font, native_load_emoji_font)
			: native_document_graphics_font(font_weight);
		if (!graphics_font) return 0;
		font = CTFontCreateWithGraphicsFont(graphics_font, MAX(font_size, 0.0f), NULL, NULL);
	}
	if (font == NULL) {
		return 0;
	}
	// CGPoint is two CGFloats, and CGFloat is double on every macOS target this
	// application supports. GlyphRun owns this packed f64 buffer for its entire
	// retained lifetime, so replay performs no position conversion/allocation.
	const CGPoint *positions = (const CGPoint *)packed_positions;
	CGFloat origin_x = page_x + transform_e
		+ transform_a * baseline_x + transform_c * baseline_y;
	CGFloat origin_y = canvas_height - page_y + scroll_y - transform_f
		- transform_b * baseline_x - transform_d * baseline_y;
	CGAffineTransform glyph_to_canvas = CGAffineTransformMake(
		transform_a, -transform_b, -transform_c, transform_d,
		origin_x, origin_y);
	CGContextSaveGState(context);
	native_configure_glyph_rasterization(context, font_smoothing);
	CGContextSetFillColorWithColor(context, color);
	if (shadow_only && blur > 0.0f) {
		CGRect clip_bounds = CGContextGetClipBoundingBox(context);
		CGFloat displacement = clip_bounds.size.width + 8192.0;
		glyph_to_canvas.tx += displacement;
		CGContextSetShadowWithColor(context, CGSizeMake(-displacement, 0.0),
			floorf(blur), color);
	}
	CGContextConcatCTM(context, glyph_to_canvas);
	CTFontDrawGlyphs(font, (const CGGlyph *)glyphs, positions,
		(CFIndex)glyph_count, context);
	CGContextRestoreGState(context);
	CFRelease(font);
	return 1;
}

void native_draw_ellipse_srgb(float x, float y, float width, float height,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_height, gg__Color color, int fill,
	float thickness) {
	if (width <= 0.0 || height <= 0.0) {
		return;
	}
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL) {
		return;
	}
	CGPathRef path = CGPathCreateWithEllipseInRect(CGRectMake(x, y, width, height), NULL);
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	CGColorRef cg_color = native_srgb_color(color);
	CGContextSaveGState(context);
	CGContextConcatCTM(context, to_canvas);
	CGContextAddPath(context, path);
	if (fill) {
		CGContextSetFillColorWithColor(context, cg_color);
		CGContextFillPath(context);
	} else {
		CGContextSetStrokeColorWithColor(context, cg_color);
		CGContextSetLineWidth(context, MAX(thickness, 0.0));
		CGContextStrokePath(context);
	}
	CGContextRestoreGState(context);
	CGColorRelease(cg_color);
	CGPathRelease(path);
}

void native_draw_document_text_srgb(float x, float y, string value, gg__Color color,
	float size, int bold, int italic, int monospace) {
	NSString *text = native_capture_string(value);
	NSFont *font = native_document_font(size, bold, italic, monospace);
	NSColor *foreground = [NSColor colorWithSRGBRed:(CGFloat)color.r / 255.0
	                                        green:(CGFloat)color.g / 255.0
	                                         blue:(CGFloat)color.b / 255.0
	                                        alpha:(CGFloat)color.a / 255.0];
	[text drawAtPoint:NSMakePoint(x, y - 15.0)
	      withAttributes:@{ NSForegroundColorAttributeName : foreground, NSFontAttributeName : font }];
}

void native_draw_document_text_shadow_srgb(float x, float y, string value,
	gg__Color color, float size, int bold, int italic, int monospace, float blur) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL)
		return;
	NSString *text = native_capture_string(value);
	NSFont *font = native_document_font(size, bold, italic, monospace);
	NSColor *foreground = [NSColor colorWithSRGBRed:(CGFloat)color.r / 255.0
	                                        green:(CGFloat)color.g / 255.0
	                                         blue:(CGFloat)color.b / 255.0
	                                        alpha:(CGFloat)color.a / 255.0];
	CGColorRef cg_color = native_srgb_color(color);
	NSDictionary *attributes = @{
		NSForegroundColorAttributeName : foreground,
		NSFontAttributeName : font,
	};
	NSSize text_size = [text sizeWithAttributes:attributes];
	CGRect clip_bounds = CGContextGetClipBoundingBox(context);
	CGFloat displacement = clip_bounds.size.width + text_size.width
		+ MAX(blur, 0.0f) * 8.0f + 1024.0f;
	CGContextSaveGState(context);
	// DisplayListPlayerSkia blurs only the glyph mask. Move AppKit's sharp
	// source outside the current clip and shift its CoreGraphics shadow back to
	// the retained draw location, as the path-shadow bridge does.
	CGContextSetShadowWithColor(context, CGSizeMake(-displacement, 0.0),
		floorf(MAX(blur, 0.0f)), cg_color);
	[text drawAtPoint:NSMakePoint(x + displacement, y - 15.0)
	      withAttributes:attributes];
	CGContextRestoreGState(context);
	CGColorRelease(cg_color);
}

int native_draw_document_glyph_run_srgb(const uint16_t *glyphs,
	const double *positions, int glyph_count, float font_size, int font_weight, int emoji_face,
	float baseline_x, float baseline_y, float transform_a, float transform_b,
	float transform_c, float transform_d, float transform_e, float transform_f,
	float page_x, float page_y, float scroll_y, float canvas_width, float canvas_height,
	string font_path_value, int face_index,
	gg__Color color, float blur, int shadow_only, int font_smoothing) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	NSString *font_path = native_capture_string(font_path_value);
	CGColorRef cg_color = native_srgb_color(color);
	int did_draw = native_draw_retained_glyph_run(context, [font_path UTF8String], face_index, glyphs, positions, glyph_count,
		font_size, font_weight, emoji_face, baseline_x, baseline_y, transform_a, transform_b,
		transform_c, transform_d, transform_e, transform_f, page_x, page_y,
		scroll_y, canvas_width, canvas_height, cg_color, blur, shadow_only,
		font_smoothing);
	CGColorRelease(cg_color);
	return did_draw;
}

int native_draw_canvas_glyph_run_rgba(uint8_t *pixels, int width, int height,
	int pitch, int pixels_are_premultiplied, const uint16_t *glyphs,
	const double *positions, int glyph_count,
	float font_size, int font_weight, string font_path_value, int face_index,
	float baseline_x, float baseline_y, float transform_a, float transform_b,
	float transform_c, float transform_d, float transform_e, float transform_f,
	uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha,
	float gradient_x0, float gradient_y0, float gradient_x1, float gradient_y1,
	const float *gradient_stops, int gradient_stop_count, float global_alpha,
	int stroke, int use_outline, float stroke_width) {
	(void)pixels; (void)width; (void)height; (void)pitch;
	(void)pixels_are_premultiplied; (void)glyphs;
	(void)positions; (void)glyph_count; (void)font_size; (void)font_weight;
	(void)font_path_value; (void)face_index; (void)baseline_x; (void)baseline_y;
	(void)transform_a; (void)transform_b; (void)transform_c; (void)transform_d;
	(void)transform_e; (void)transform_f; (void)red; (void)green; (void)blue;
	(void)alpha; (void)gradient_x0; (void)gradient_y0; (void)gradient_x1;
	(void)gradient_y1; (void)gradient_stops; (void)gradient_stop_count;
	(void)global_alpha; (void)stroke; (void)use_outline; (void)stroke_width;
	return 0;
}

void native_draw_polygon_srgb(const float *points, int point_count, float canvas_height,
	gg__Color color) {
	if (points == NULL || point_count < 3) {
		return;
	}
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL) {
		return;
	}
	CGColorRef cg_color = native_srgb_color(color);
	CGContextSetFillColorWithColor(context, cg_color);
	CGContextBeginPath(context);
	CGContextMoveToPoint(context, points[0], canvas_height - points[1]);
	for (int index = 1; index < point_count; ++index) {
		CGContextAddLineToPoint(context, points[index * 2],
		                        canvas_height - points[index * 2 + 1]);
	}
	CGContextClosePath(context);
	CGContextFillPath(context);
	CGColorRelease(cg_color);
}

int native_draw_line_srgb(float from_x, float from_y, float to_x, float to_y,
	float thickness, int line_style, float canvas_width, float canvas_height,
	gg__Color color) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL || thickness <= 0.0f) {
		return 0;
	}
	// Keep the native backend independent of GG's immediate-mode GPU pipeline.
	CGContextSaveGState(context);
	CGColorRef cg_color = native_srgb_color(color);
	CGContextSetStrokeColorWithColor(context, cg_color);
	CGContextSetLineWidth(context, thickness);
	if (line_style == 1) {
		CGFloat dash[] = { 0.0, thickness * 2.0 };
		CGContextSetLineDash(context, 0.0, dash, 2);
		CGContextSetLineCap(context, kCGLineCapRound);
	} else if (line_style == 2) {
		CGFloat dash[] = { thickness * 3.0, thickness * 3.0 };
		CGContextSetLineDash(context, 0.0, dash, 2);
	}
	CGContextBeginPath(context);
	CGContextMoveToPoint(context, from_x, canvas_height - from_y);
	CGContextAddLineToPoint(context, to_x, canvas_height - to_y);
	CGContextStrokePath(context);
	CGColorRelease(cg_color);
	CGContextRestoreGState(context);
	return 1;
}

static void native_add_elliptical_arc(CGMutablePathRef path, CGFloat center_x,
	CGFloat center_y, CGFloat radius_x, CGFloat radius_y, CGFloat start_angle,
	CGFloat end_angle) {
	if (radius_x <= 0.0 || radius_y <= 0.0) {
		return;
	}
	CGAffineTransform ellipse_transform = CGAffineTransformMakeTranslation(center_x, center_y);
	ellipse_transform = CGAffineTransformScale(ellipse_transform, radius_x, radius_y);
	CGPathAddArc(path, &ellipse_transform, 0.0, 0.0, 1.0, start_angle, end_angle, false);
}

static CGPathRef native_create_corner_rounded_rect_path(float x, float y, float width,
	float height, float top_left_x, float top_left_y, float top_right_x,
	float top_right_y, float bottom_right_x, float bottom_right_y,
	float bottom_left_x, float bottom_left_y) {
	top_left_x = MAX(top_left_x, 0.0f);
	top_left_y = MAX(top_left_y, 0.0f);
	top_right_x = MAX(top_right_x, 0.0f);
	top_right_y = MAX(top_right_y, 0.0f);
	bottom_right_x = MAX(bottom_right_x, 0.0f);
	bottom_right_y = MAX(bottom_right_y, 0.0f);
	bottom_left_x = MAX(bottom_left_x, 0.0f);
	bottom_left_y = MAX(bottom_left_y, 0.0f);
	// SkRRect scales overlapping radii to fit the rectangle. Retained shadow
	// commands can reuse border-box radii with the smaller padding box, so do
	// that normalization here rather than relying on each caller to pre-scale.
	float scale = 1.0f;
	if (top_left_x + top_right_x > width)
		scale = MIN(scale, width / (top_left_x + top_right_x));
	if (bottom_left_x + bottom_right_x > width)
		scale = MIN(scale, width / (bottom_left_x + bottom_right_x));
	if (top_left_y + bottom_left_y > height)
		scale = MIN(scale, height / (top_left_y + bottom_left_y));
	if (top_right_y + bottom_right_y > height)
		scale = MIN(scale, height / (top_right_y + bottom_right_y));
	top_left_x *= scale;
	top_left_y *= scale;
	top_right_x *= scale;
	top_right_y *= scale;
	bottom_right_x *= scale;
	bottom_right_y *= scale;
	bottom_left_x *= scale;
	bottom_left_y *= scale;
	CGMutablePathRef path = CGPathCreateMutable();
	CGPathMoveToPoint(path, NULL, x + top_left_x, y);
	CGPathAddLineToPoint(path, NULL, x + width - top_right_x, y);
	if (top_right_x > 0.0 && top_right_y > 0.0) {
		native_add_elliptical_arc(path, x + width - top_right_x, y + top_right_y,
			top_right_x, top_right_y, -M_PI_2, 0.0);
	} else {
		CGPathAddLineToPoint(path, NULL, x + width, y);
	}
	CGPathAddLineToPoint(path, NULL, x + width, y + height - bottom_right_y);
	if (bottom_right_x > 0.0 && bottom_right_y > 0.0) {
		native_add_elliptical_arc(path, x + width - bottom_right_x,
			y + height - bottom_right_y, bottom_right_x, bottom_right_y, 0.0, M_PI_2);
	} else {
		CGPathAddLineToPoint(path, NULL, x + width, y + height);
	}
	CGPathAddLineToPoint(path, NULL, x + bottom_left_x, y + height);
	if (bottom_left_x > 0.0 && bottom_left_y > 0.0) {
		native_add_elliptical_arc(path, x + bottom_left_x,
			y + height - bottom_left_y, bottom_left_x, bottom_left_y, M_PI_2, M_PI);
	} else {
		CGPathAddLineToPoint(path, NULL, x, y + height);
	}
	CGPathAddLineToPoint(path, NULL, x, y + top_left_y);
	if (top_left_x > 0.0 && top_left_y > 0.0) {
		native_add_elliptical_arc(path, x + top_left_x, y + top_left_y,
			top_left_x, top_left_y, M_PI, M_PI * 1.5);
	} else {
		CGPathAddLineToPoint(path, NULL, x, y);
	}
	CGPathCloseSubpath(path);
	return path;
}

static CGFloat native_vector_angle(CGFloat ux, CGFloat uy, CGFloat vx, CGFloat vy) {
	return atan2(ux * vy - uy * vx, ux * vx + uy * vy);
}

// Convert SVG/Gfx endpoint-form elliptical arcs to CoreGraphics' center-form
// arc. The ellipse transform keeps the curve exact instead of replaying its
// software hit-test tessellation.
static void native_path_add_endpoint_arc(CGMutablePathRef path, CGFloat end_x,
	CGFloat end_y, CGFloat input_radius_x, CGFloat input_radius_y,
	CGFloat rotation, bool large_arc, bool sweep) {
	CGPoint start = CGPathGetCurrentPoint(path);
	if (start.x == end_x && start.y == end_y) {
		return;
	}
	CGFloat radius_x = fabs(input_radius_x);
	CGFloat radius_y = fabs(input_radius_y);
	if (radius_x == 0.0 || radius_y == 0.0) {
		CGPathAddLineToPoint(path, NULL, end_x, end_y);
		return;
	}
	CGFloat cosine = cos(rotation);
	CGFloat sine = sin(rotation);
	CGFloat half_dx = (start.x - end_x) / 2.0;
	CGFloat half_dy = (start.y - end_y) / 2.0;
	CGFloat x1_prime = cosine * half_dx + sine * half_dy;
	CGFloat y1_prime = -sine * half_dx + cosine * half_dy;
	CGFloat radii_scale = x1_prime * x1_prime / (radius_x * radius_x)
		+ y1_prime * y1_prime / (radius_y * radius_y);
	if (radii_scale > 1.0) {
		CGFloat scale = sqrt(radii_scale);
		radius_x *= scale;
		radius_y *= scale;
	}
	CGFloat radius_x_squared = radius_x * radius_x;
	CGFloat radius_y_squared = radius_y * radius_y;
	CGFloat x1_squared = x1_prime * x1_prime;
	CGFloat y1_squared = y1_prime * y1_prime;
	CGFloat denominator = radius_x_squared * y1_squared + radius_y_squared * x1_squared;
	if (denominator == 0.0) {
		CGPathAddLineToPoint(path, NULL, end_x, end_y);
		return;
	}
	CGFloat sign = large_arc == sweep ? -1.0 : 1.0;
	CGFloat coefficient = sign * sqrt(MAX(0.0,
		(radius_x_squared * radius_y_squared - radius_x_squared * y1_squared
			- radius_y_squared * x1_squared) / denominator));
	CGFloat center_x_prime = coefficient * radius_x * y1_prime / radius_y;
	CGFloat center_y_prime = coefficient * -radius_y * x1_prime / radius_x;
	CGFloat center_x = cosine * center_x_prime - sine * center_y_prime
		+ (start.x + end_x) / 2.0;
	CGFloat center_y = sine * center_x_prime + cosine * center_y_prime
		+ (start.y + end_y) / 2.0;
	CGFloat start_unit_x = (x1_prime - center_x_prime) / radius_x;
	CGFloat start_unit_y = (y1_prime - center_y_prime) / radius_y;
	CGFloat end_unit_x = (-x1_prime - center_x_prime) / radius_x;
	CGFloat end_unit_y = (-y1_prime - center_y_prime) / radius_y;
	CGFloat start_angle = native_vector_angle(1.0, 0.0, start_unit_x, start_unit_y);
	CGFloat angle_delta = native_vector_angle(start_unit_x, start_unit_y,
		end_unit_x, end_unit_y);
	if (!sweep && angle_delta > 0.0) {
		angle_delta -= 2.0 * M_PI;
	} else if (sweep && angle_delta < 0.0) {
		angle_delta += 2.0 * M_PI;
	}
	CGAffineTransform ellipse_transform = CGAffineTransformMake(
		cosine * radius_x, sine * radius_x, -sine * radius_y,
		cosine * radius_y, center_x, center_y);
	CGPathAddArc(path, &ellipse_transform, 0.0, 0.0, 1.0, start_angle,
		start_angle + angle_delta, angle_delta < 0.0);
}

static CGMutablePathRef native_create_path_from_data(const float *data,
	int segment_count) {
	CGMutablePathRef path = CGPathCreateMutable();
	if (data == NULL || segment_count <= 0) {
		return path;
	}
	for (int index = 0; index < segment_count; ++index) {
		const float *segment = data + index * 12;
		switch ((int)segment[0]) {
		case 0:
			CGPathMoveToPoint(path, NULL, segment[1], segment[2]);
			break;
		case 1:
			CGPathAddLineToPoint(path, NULL, segment[1], segment[2]);
			break;
		case 2:
			CGPathAddQuadCurveToPoint(path, NULL, segment[3], segment[4],
				segment[1], segment[2]);
			break;
		case 3:
			CGPathAddCurveToPoint(path, NULL, segment[3], segment[4],
				segment[5], segment[6], segment[1], segment[2]);
			break;
		case 4:
			native_path_add_endpoint_arc(path, segment[1], segment[2],
				segment[7], segment[8], segment[9], segment[10] != 0.0,
				segment[11] != 0.0);
			break;
		case 5:
			CGPathCloseSubpath(path);
			break;
		case 6:
			// Explicit SVG ellipse bounds, using the native segment stride.
			if (isfinite(segment[1]) && isfinite(segment[2])
				&& isfinite(segment[3]) && isfinite(segment[4])
				&& segment[3] > segment[1] && segment[4] > segment[2]) {
				CGPathAddEllipseInRect(path, NULL, CGRectMake(segment[1], segment[2],
					segment[3] - segment[1], segment[4] - segment[2]));
			}
			break;
		default:
			break;
		}
	}
	return path;
}

void native_add_path_clip(const float *data, int segment_count, int even_odd,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_height) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL) {
		return;
	}
	if (data == NULL || segment_count <= 0) {
		CGContextClipToRect(context, CGRectZero);
		return;
	}
	CGMutablePathRef local_path = native_create_path_from_data(data, segment_count);
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	CGPathRef canvas_path = CGPathCreateCopyByTransformingPath(local_path, &to_canvas);
	CGContextAddPath(context, canvas_path);
	if (even_odd) {
		CGContextEOClip(context);
	} else {
		CGContextClip(context);
	}
	CGPathRelease(canvas_path);
	CGPathRelease(local_path);
}

#include "native/include/native_graphite_bridge.h"

int native_draw_svg_path_batch(const VoxGraphitePath *paths, int count,
    const float *outer, float x, float y, float width, float height,
    float page_x, float page_y, float scroll_y, float canvas_width, float canvas_height,
    const float *rounded_clip) {
    if (!paths || count <= 0 || count > 65536 || !outer || width <= 0 || height <= 0 ||
        [[NSGraphicsContext currentContext] CGContext] != native_font_compositing_context) return 0;
    float matrix[6] = {outer[0],outer[1],outer[2],outer[3],
        page_x+outer[4],page_y-scroll_y+outer[5]};
    float left=INFINITY,top=INFINITY,right=-INFINITY,bottom=-INFINITY;
    for(int i=0;i<4;++i) {
        float px=x+((i&1)?width:0),py=y+((i&2)?height:0);
        float dx=matrix[0]*px+matrix[2]*py+matrix[4],dy=matrix[1]*px+matrix[3]*py+matrix[5];
        left=fminf(left,dx);top=fminf(top,dy);right=fmaxf(right,dx);bottom=fmaxf(bottom,dy);
    }
    int32_t geometry[7];float scale;
    int prepared=native_text_raster_begin(left,top,right,bottom,canvas_width,canvas_height,16,geometry,&scale);
    if(prepared==2)return 1;
    if(prepared!=1)return 0;
    int w=geometry[2],h=geometry[3],backdrop=geometry[4];
    uint8_t* pixels=calloc((size_t)w*h*4,1);
    if(!pixels)return 0;
    if(backdrop&&!native_text_raster_read_backdrop(pixels,geometry[0],geometry[1],w,h,scale)) {
        free(pixels);return 0;
    }
    float sx=(float)w/geometry[5],sy=(float)h/geometry[6];
    const float parent[9]={matrix[0]*sx,matrix[2]*sx,(matrix[4]-geometry[0])*sx,
        matrix[1]*sy,matrix[3]*sy,(matrix[5]-geometry[1])*sy,0,0,1};
    const float viewport[4]={x,y,width,height};
    extern int vox_draw_document_svg_pixels(uint8_t*,int,int,int,int,VoxGraphitePath*,int,float*,float*,float*);
    int drawn=vox_draw_document_svg_pixels(pixels,w,h,w*4,backdrop,(VoxGraphitePath*)paths,count,(float*)parent,(float*)viewport,(float*)rounded_clip);
    if(drawn)drawn=native_text_raster_finish(pixels,geometry[0],geometry[1],w,h,
        geometry[5],geometry[6],canvas_height,backdrop);
    free(pixels);return drawn;
}

int native_draw_svg_cover_pattern(const VoxGraphitePath *paths, int count,
    const float *outer, const float *tile, const float *clip,
    float page_x, float page_y, float scroll_y, float canvas_width, float canvas_height) {
    return 0;
}

#include "native/include/native_rounded_svg_ancestor_darwin.h"

int native_draw_svg_path_batch_with_rounded_ancestor(const VoxGraphitePath *paths,
    int count, const float *outer, float x, float y, float width, float height,
    float page_x, float page_y, float scroll_y, float canvas_width,
    float canvas_height, const float *rounded_clip) {
    return 0;
}

static CGColorRef native_svg_srgb_color(gg__Color color, const float *precise) {
    if (!precise) return native_srgb_color(color);
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGFloat components[] = {precise[0], precise[1], precise[2], precise[3]};
    CGColorRef result = CGColorCreate(space, components);
    CGColorSpaceRelease(space);
    return result;
}

void native_draw_svg_path_srgb(const float *data, int segment_count, int even_odd,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_width, float canvas_height, gg__Color fill_color, int has_fill,
	gg__Color stroke_color, int has_stroke, float stroke_width, int line_cap,
	int line_join, float miter_limit, int non_scaling_stroke,
	const double *dash_data, int dash_count, double dash_offset,
	const float *fill_components, const float *stroke_components) {
	if (data == NULL || segment_count <= 0 || (!has_fill && !has_stroke)) {
		return;
	}
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL) {
		return;
	}
	CGFloat host_scale = [[native_browser_view() window] backingScaleFactor];
	if (!isfinite(host_scale) || host_scale <= 0.0)
		host_scale = 1.0;
	// Skia and CoreGraphics place a half-device-pixel host-space stroke on
	// opposite sides of the coverage tie. A tiny device-space bias matches the
	// recorder's inclusive edge without changing a visible stroke dimension.
	float resolved_stroke_width = non_scaling_stroke && native_font_compositing_context == NULL
		? stroke_width / host_scale + 2.0f / 512.0f : stroke_width;
	CGMutablePathRef path = native_create_path_from_data(data, segment_count);
    if (dash_count == 0 && !(has_fill && has_stroke)) {
        const float matrix[6]={transform_a,transform_b,transform_c,transform_d,
            page_x+transform_e,page_y-scroll_y+transform_f};
        if(native_try_v_svg_path(path,data,segment_count,even_odd,matrix,canvas_width,canvas_height,
            has_stroke?stroke_color:fill_color,has_stroke?stroke_components:fill_components,
            has_stroke,stroke_width,line_cap,line_join,miter_limit,non_scaling_stroke)) {
            CGPathRelease(path);return;
        }
    }

	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	if (non_scaling_stroke && has_stroke) {
		if (has_fill) {
			CGColorRef fill = native_svg_srgb_color(fill_color, fill_components);
			CGContextSaveGState(context);
			CGContextConcatCTM(context, to_canvas);
			CGContextAddPath(context, path);
			CGContextSetFillColorWithColor(context, fill);
			CGContextDrawPath(context, even_odd ? kCGPathEOFill : kCGPathFill);
			CGContextRestoreGState(context);
			CGColorRelease(fill);
		}
		CGPathRef transformed_path = CGPathCreateCopyByTransformingPath(path, &to_canvas);
		CGColorRef stroke = native_svg_srgb_color(stroke_color, stroke_components);
		CGContextSaveGState(context);
		CGContextAddPath(context, transformed_path);
		CGContextSetStrokeColorWithColor(context, stroke);
		CGContextSetLineWidth(context, MAX(resolved_stroke_width, 0.0));
		CGContextSetLineCap(context, line_cap == 1 ? kCGLineCapRound
			: line_cap == 2 ? kCGLineCapSquare : kCGLineCapButt);
		CGContextSetLineJoin(context, line_join == 1 ? kCGLineJoinRound
			: line_join == 2 ? kCGLineJoinBevel : kCGLineJoinMiter);
		CGContextSetMiterLimit(context, MAX(miter_limit, 1.0));
		if (dash_data != NULL && dash_count > 0)
			CGContextSetLineDash(context, dash_offset, dash_data, dash_count);
		CGContextStrokePath(context);
		CGContextRestoreGState(context);
		CGColorRelease(stroke);
		CGPathRelease(transformed_path);
		CGPathRelease(path);
		return;
	}
	CGContextSaveGState(context);
	CGContextConcatCTM(context, to_canvas);
	CGContextAddPath(context, path);
	CGColorRef fill = NULL;
	CGColorRef stroke = NULL;
	if (has_fill) {
		fill = native_svg_srgb_color(fill_color, fill_components);
		CGContextSetFillColorWithColor(context, fill);
	}
	if (has_stroke) {
		stroke = native_svg_srgb_color(stroke_color, stroke_components);
		CGContextSetStrokeColorWithColor(context, stroke);
		CGContextSetLineWidth(context, MAX(stroke_width, 0.0));
		CGContextSetLineCap(context, line_cap == 1 ? kCGLineCapRound
			: line_cap == 2 ? kCGLineCapSquare : kCGLineCapButt);
		CGContextSetLineJoin(context, line_join == 1 ? kCGLineJoinRound
			: line_join == 2 ? kCGLineJoinBevel : kCGLineJoinMiter);
		CGContextSetMiterLimit(context, MAX(miter_limit, 1.0));
		if (dash_data != NULL && dash_count > 0)
			CGContextSetLineDash(context, dash_offset, dash_data, dash_count);
	}
	CGPathDrawingMode mode;
	if (has_fill && has_stroke) {
		mode = even_odd ? kCGPathEOFillStroke : kCGPathFillStroke;
	} else if (has_fill) {
		mode = even_odd ? kCGPathEOFill : kCGPathFill;
	} else {
		mode = kCGPathStroke;
	}
	CGContextDrawPath(context, mode);
	if (fill != NULL) {
		CGColorRelease(fill);
	}
	if (stroke != NULL) {
		CGColorRelease(stroke);
	}
	CGContextRestoreGState(context);
	CGPathRelease(path);
}

static void native_draw_svg_linear_gradient_path_in_context(CGContextRef context,
	const float *data, int segment_count, int even_odd, float transform_a,
	float transform_b, float transform_c, float transform_d, float transform_e,
	float transform_f, float page_x, float page_y, float scroll_y,
	float canvas_height, int stroke, float stroke_width, int line_cap,
	int line_join, float miter_limit, float start_x, float start_y, float end_x,
	float end_y, float gradient_a, float gradient_b, float gradient_c,
	float gradient_d, float gradient_e, float gradient_f, int spread_method,
	int linear_color_space, const float *stop_data, int stop_count, float opacity) {
	if (context == NULL || data == NULL || segment_count <= 0 || stop_data == NULL
		|| stop_count <= 0) {
		return;
	}
	(void)opacity;
	CGMutablePathRef path = native_create_path_from_data(data, segment_count);
	CGRect path_bounds = CGPathGetBoundingBox(path);
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	CGAffineTransform gradient_transform = CGAffineTransformMake(gradient_a,
		gradient_b, gradient_c, gradient_d, gradient_e, gradient_f);
	CGContextSaveGState(context);
	CGContextConcatCTM(context, to_canvas);
	CGContextAddPath(context, path);
	if (stroke) {
		CGContextSetLineWidth(context, MAX(stroke_width, 0.0));
		CGContextSetLineCap(context, line_cap == 1 ? kCGLineCapRound
			: line_cap == 2 ? kCGLineCapSquare : kCGLineCapButt);
		CGContextSetLineJoin(context, line_join == 1 ? kCGLineJoinRound
			: line_join == 2 ? kCGLineJoinBevel : kCGLineJoinMiter);
		CGContextSetMiterLimit(context, MAX(miter_limit, 1.0));
		CGContextReplacePathWithStrokedPath(context);
		CGContextClip(context);
	} else if (even_odd) {
		CGContextEOClip(context);
	} else {
		CGContextClip(context);
	}

	int gradient_stop_count = stop_count == 1 ? 2 : stop_count;
	CGFloat *components = calloc((size_t)gradient_stop_count * 4, sizeof(CGFloat));
	CGFloat *locations = calloc((size_t)gradient_stop_count, sizeof(CGFloat));
	if (components == NULL || locations == NULL) {
		free(components);
		free(locations);
		CGContextRestoreGState(context);
		CGPathRelease(path);
		return;
	}
	for (int index = 0; index < gradient_stop_count; ++index) {
		int source_index = stop_count == 1 ? 0 : index;
		components[index * 4] = fminf(fmaxf(stop_data[source_index * 5], 0), 1);
		components[index * 4 + 1] = fminf(fmaxf(stop_data[source_index * 5 + 1], 0), 1);
		components[index * 4 + 2] = fminf(fmaxf(stop_data[source_index * 5 + 2], 0), 1);
		components[index * 4 + 3] = fminf(fmaxf(stop_data[source_index * 5 + 3], 0), 1);
		locations[index] = stop_count == 1 ? index
			: fminf(fmaxf(stop_data[source_index * 5 + 4], 0), 1);
	}
	CGColorSpaceRef color_space = CGColorSpaceCreateWithName(linear_color_space
		? kCGColorSpaceLinearSRGB : kCGColorSpaceSRGB);
	if (color_space == NULL) {
		color_space = CGColorSpaceCreateDeviceRGB();
	}
	CGGradientRef gradient = CGGradientCreateWithColorComponents(color_space,
		components, locations, (size_t)gradient_stop_count);
	free(components);
	free(locations);
	CGColorSpaceRelease(color_space);
	if (gradient == NULL) {
		CGContextRestoreGState(context);
		CGPathRelease(path);
		return;
	}

	CGContextConcatCTM(context, gradient_transform);
	CGPoint start = CGPointMake(start_x, start_y);
	CGPoint end = CGPointMake(end_x, end_y);
	CGFloat vector_x = end.x - start.x;
	CGFloat vector_y = end.y - start.y;
	CGFloat vector_length_squared = vector_x * vector_x + vector_y * vector_y;
	if (vector_length_squared <= 1e-12) {
		const float *last_stop = stop_data + (stop_count - 1) * 5;
		CGContextSetRGBFillColor(context, last_stop[0], last_stop[1], last_stop[2],
			last_stop[3]);
		CGRect fill_bounds = CGRectInset(CGRectApplyAffineTransform(path_bounds,
			CGAffineTransformInvert(gradient_transform)), -1, -1);
		CGContextFillRect(context, fill_bounds);
	} else if (spread_method == 0) {
		CGContextDrawLinearGradient(context, gradient, start, end,
			kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
	} else {
		CGAffineTransform inverse = CGAffineTransformInvert(gradient_transform);
		CGPoint corners[4] = {
			CGPointApplyAffineTransform(CGPointMake(CGRectGetMinX(path_bounds), CGRectGetMinY(path_bounds)), inverse),
			CGPointApplyAffineTransform(CGPointMake(CGRectGetMaxX(path_bounds), CGRectGetMinY(path_bounds)), inverse),
			CGPointApplyAffineTransform(CGPointMake(CGRectGetMaxX(path_bounds), CGRectGetMaxY(path_bounds)), inverse),
			CGPointApplyAffineTransform(CGPointMake(CGRectGetMinX(path_bounds), CGRectGetMaxY(path_bounds)), inverse),
		};
		CGFloat minimum = HUGE_VAL;
		CGFloat maximum = -HUGE_VAL;
		for (int index = 0; index < 4; ++index) {
			CGFloat projection = ((corners[index].x - start.x) * vector_x
				+ (corners[index].y - start.y) * vector_y) / vector_length_squared;
			minimum = MIN(minimum, projection);
			maximum = MAX(maximum, projection);
		}
		NSInteger first = (NSInteger)floor(minimum);
		NSInteger last = (NSInteger)ceil(maximum);
		for (NSInteger index = first; index < last; ++index) {
			CGPoint copy_start = CGPointMake(start.x + index * vector_x,
				start.y + index * vector_y);
			CGPoint copy_end = CGPointMake(end.x + index * vector_x,
				end.y + index * vector_y);
			if (spread_method == 2 && labs(index) % 2 == 1) {
				CGPoint temporary = copy_start;
				copy_start = copy_end;
				copy_end = temporary;
			}
			CGContextDrawLinearGradient(context, gradient, copy_start, copy_end, 0);
		}
	}
	CGGradientRelease(gradient);
	CGContextRestoreGState(context);
	CGPathRelease(path);
}

void native_draw_svg_linear_gradient_path(const float *data, int segment_count,
	int even_odd, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x,
	float page_y, float scroll_y, float canvas_height, int stroke,
	float stroke_width, int line_cap, int line_join, float miter_limit,
	float start_x, float start_y, float end_x, float end_y, float gradient_a,
	float gradient_b, float gradient_c, float gradient_d, float gradient_e,
	float gradient_f, int spread_method, int linear_color_space,
	const float *stop_data, int stop_count, float opacity) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	native_draw_svg_linear_gradient_path_in_context(context, data, segment_count,
		even_odd, transform_a, transform_b, transform_c, transform_d, transform_e,
		transform_f, page_x, page_y, scroll_y, canvas_height, stroke, stroke_width,
		line_cap, line_join, miter_limit, start_x, start_y, end_x, end_y,
		gradient_a, gradient_b, gradient_c, gradient_d, gradient_e, gradient_f,
		spread_method, linear_color_space, stop_data, stop_count, opacity);
}

#include "native/include/native_css_gradient_gpu_darwin.h"

int native_draw_clipped_svg_linear_gradient_path(const float *data, int segment_count,
	int even_odd, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x,
	float page_y, float scroll_y, float canvas_height, int stroke,
	float stroke_width, int line_cap, int line_join, float miter_limit,
	float start_x, float start_y, float end_x, float end_y, float gradient_a,
	float gradient_b, float gradient_c, float gradient_d, float gradient_e,
	float gradient_f, int spread_method, int linear_color_space,
	const float *stop_data, int stop_count, float opacity, const float *clip, const float *ancestor_clip) {
    if (spread_method != 4 || stroke || linear_color_space) return 0;
    VoxGraphitePath draw={0};
    draw.segments=data; draw.segment_count=segment_count; draw.even_odd=even_odd;
    draw.gradient=1; draw.gradient_premul=1; draw.opacity=1;
    draw.stops=stop_data; draw.stop_count=stop_count;
    float points[6]={start_x,start_y,end_x,end_y,0,0};
    memcpy(draw.gradient_points,points,sizeof(points));
    float local[9]={gradient_a,gradient_c,gradient_e,gradient_b,gradient_d,gradient_f,0,0,1};
    memcpy(draw.gradient_matrix,local,sizeof(local));
    draw.has_clip=clip!=NULL; draw.has_ancestor_clip=ancestor_clip!=NULL;
    if (clip) memcpy(draw.clip,clip,sizeof(draw.clip));
    if (ancestor_clip) memcpy(draw.ancestor_clip,ancestor_clip,sizeof(draw.ancestor_clip));
    float matrix[6]={transform_a,transform_b,transform_c,transform_d,
        page_x+transform_e,page_y-scroll_y+transform_f};
    return native_try_v_css_gradient(draw,matrix,page_x,page_y,scroll_y,canvas_height);
}

int native_draw_clipped_svg_radial_gradient_path(const float *data, int segment_count,
	int even_odd, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x,
	float page_y, float scroll_y, float canvas_height, int stroke,
	float stroke_width, int line_cap, int line_join, float miter_limit,
	float start_x, float start_y, float start_radius, float end_x, float end_y,
	float end_radius, float gradient_a,
	float gradient_b, float gradient_c, float gradient_d, float gradient_e,
	float gradient_f, int spread_method, int linear_color_space,
	const float *stop_data, int stop_count, float opacity, const float *clip, const float *ancestor_clip) {
    if (spread_method != 4 || stroke || linear_color_space) return 0;
    VoxGraphitePath draw={0};
    draw.segments=data; draw.segment_count=segment_count; draw.even_odd=even_odd;
    draw.gradient=2; draw.gradient_premul=1; draw.opacity=1;
    draw.stops=stop_data; draw.stop_count=stop_count;
    float points[6]={start_x,start_y,start_radius,end_x,end_y,end_radius};
    memcpy(draw.gradient_points,points,sizeof(points));
    float local[9]={gradient_a,gradient_c,gradient_e,gradient_b,gradient_d,gradient_f,0,0,1};
    memcpy(draw.gradient_matrix,local,sizeof(local));
    draw.has_clip=clip!=NULL; draw.has_ancestor_clip=ancestor_clip!=NULL;
    if (clip) memcpy(draw.clip,clip,sizeof(draw.clip));
    if (ancestor_clip) memcpy(draw.ancestor_clip,ancestor_clip,sizeof(draw.ancestor_clip));
    float matrix[6]={transform_a,transform_b,transform_c,transform_d,
        page_x+transform_e,page_y-scroll_y+transform_f};
    return native_try_v_css_gradient(draw,matrix,page_x,page_y,scroll_y,canvas_height);
}

static void native_draw_svg_radial_gradient_path_in_context(CGContextRef context,
	const float *data, int segment_count, int even_odd, float transform_a,
	float transform_b, float transform_c, float transform_d, float transform_e,
	float transform_f, float page_x, float page_y, float scroll_y,
	float canvas_height, int stroke, float stroke_width, int line_cap,
	int line_join, float miter_limit, float start_x, float start_y,
	float start_radius, float end_x, float end_y, float end_radius,
	float gradient_a, float gradient_b, float gradient_c, float gradient_d,
	float gradient_e, float gradient_f, int spread_method,
	int linear_color_space, const float *stop_data, int stop_count, float opacity) {
	if (context == NULL || data == NULL || segment_count <= 0 || stop_data == NULL
		|| stop_count <= 0) {
		return;
	}
	(void)opacity;
	CGMutablePathRef path = native_create_path_from_data(data, segment_count);
	CGRect path_bounds = CGPathGetBoundingBox(path);
	if (stroke) {
		path_bounds = CGRectInset(path_bounds, -MAX(stroke_width, 0.0),
			-MAX(stroke_width, 0.0));
	}
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	CGAffineTransform gradient_transform = CGAffineTransformMake(gradient_a,
		gradient_b, gradient_c, gradient_d, gradient_e, gradient_f);
	CGContextSaveGState(context);
	CGContextConcatCTM(context, to_canvas);
	CGContextAddPath(context, path);
	if (stroke) {
		CGContextSetLineWidth(context, MAX(stroke_width, 0.0));
		CGContextSetLineCap(context, line_cap == 1 ? kCGLineCapRound
			: line_cap == 2 ? kCGLineCapSquare : kCGLineCapButt);
		CGContextSetLineJoin(context, line_join == 1 ? kCGLineJoinRound
			: line_join == 2 ? kCGLineJoinBevel : kCGLineJoinMiter);
		CGContextSetMiterLimit(context, MAX(miter_limit, 1.0));
		CGContextReplacePathWithStrokedPath(context);
		CGContextClip(context);
	} else if (even_odd) {
		CGContextEOClip(context);
	} else {
		CGContextClip(context);
	}

	int gradient_stop_count = stop_count == 1 ? 2 : stop_count;
	CGFloat *components = calloc((size_t)gradient_stop_count * 4, sizeof(CGFloat));
	CGFloat *locations = calloc((size_t)gradient_stop_count, sizeof(CGFloat));
	if (components == NULL || locations == NULL) {
		free(components);
		free(locations);
		CGContextRestoreGState(context);
		CGPathRelease(path);
		return;
	}
	for (int index = 0; index < gradient_stop_count; ++index) {
		int source_index = stop_count == 1 ? 0 : index;
		components[index * 4] = fminf(fmaxf(stop_data[source_index * 5], 0), 1);
		components[index * 4 + 1] = fminf(fmaxf(stop_data[source_index * 5 + 1], 0), 1);
		components[index * 4 + 2] = fminf(fmaxf(stop_data[source_index * 5 + 2], 0), 1);
		components[index * 4 + 3] = fminf(fmaxf(stop_data[source_index * 5 + 3], 0), 1);
		locations[index] = stop_count == 1 ? index
			: fminf(fmaxf(stop_data[source_index * 5 + 4], 0), 1);
	}
	CGColorSpaceRef color_space = CGColorSpaceCreateWithName(linear_color_space
		? kCGColorSpaceLinearSRGB : kCGColorSpaceSRGB);
	if (color_space == NULL) {
		color_space = CGColorSpaceCreateDeviceRGB();
	}
	CGGradientRef gradient = CGGradientCreateWithColorComponents(color_space,
		components, locations, (size_t)gradient_stop_count);
	free(components);
	free(locations);
	CGColorSpaceRelease(color_space);
	if (gradient == NULL) {
		CGContextRestoreGState(context);
		CGPathRelease(path);
		return;
	}

	CGContextConcatCTM(context, gradient_transform);
	CGPoint start = CGPointMake(start_x, start_y);
	CGPoint end = CGPointMake(end_x, end_y);
	CGFloat center_dx = end.x - start.x;
	CGFloat center_dy = end.y - start.y;
	CGFloat radius_delta = end_radius - start_radius;
	if (fabs(center_dx) <= 1e-6 && fabs(center_dy) <= 1e-6
		&& fabs(radius_delta) <= 1e-6) {
		const float *last_stop = stop_data + (stop_count - 1) * 5;
		CGContextSetRGBFillColor(context, last_stop[0], last_stop[1], last_stop[2],
			last_stop[3]);
		CGRect fill_bounds = CGRectInset(CGRectApplyAffineTransform(path_bounds,
			CGAffineTransformInvert(gradient_transform)), -1, -1);
		CGContextFillRect(context, fill_bounds);
	} else if (spread_method == 0) {
		CGContextDrawRadialGradient(context, gradient, start,
			MAX(start_radius, 0.0), end, MAX(end_radius, 0.0),
			kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
	} else {
		CGAffineTransform inverse = CGAffineTransformInvert(gradient_transform);
		CGPoint corners[4] = {
			CGPointApplyAffineTransform(CGPointMake(CGRectGetMinX(path_bounds), CGRectGetMinY(path_bounds)), inverse),
			CGPointApplyAffineTransform(CGPointMake(CGRectGetMaxX(path_bounds), CGRectGetMinY(path_bounds)), inverse),
			CGPointApplyAffineTransform(CGPointMake(CGRectGetMaxX(path_bounds), CGRectGetMaxY(path_bounds)), inverse),
			CGPointApplyAffineTransform(CGPointMake(CGRectGetMinX(path_bounds), CGRectGetMaxY(path_bounds)), inverse),
		};
		CGFloat maximum_distance = 0.0;
		for (int index = 0; index < 4; ++index) {
			maximum_distance = MAX(maximum_distance,
				hypot(corners[index].x - start.x, corners[index].y - start.y));
		}
		CGFloat tile_extent = MAX(fabs(radius_delta), hypot(center_dx, center_dy));
		NSInteger first = 0;
		NSInteger last = 1;
		if (tile_extent > 1e-6) {
			NSInteger reach = (NSInteger)ceil((maximum_distance
				+ MAX(start_radius, end_radius)) / tile_extent) + 4;
			first = MAX(-reach, -2048);
			last = MIN(reach, 2048);
		}
		for (NSInteger index = first; index < last; ++index) {
			CGPoint copy_start = CGPointMake(start.x + index * center_dx,
				start.y + index * center_dy);
			CGPoint copy_end = CGPointMake(end.x + index * center_dx,
				end.y + index * center_dy);
			CGFloat copy_start_radius = start_radius + index * radius_delta;
			CGFloat copy_end_radius = end_radius + index * radius_delta;
			if (copy_start_radius < 0.0 && copy_end_radius <= 0.0) {
				continue;
			}
			copy_start_radius = MAX(copy_start_radius, 0.0);
			copy_end_radius = MAX(copy_end_radius, 0.0);
			if (spread_method == 2 && labs(index) % 2 == 1) {
				CGPoint temporary_center = copy_start;
				copy_start = copy_end;
				copy_end = temporary_center;
				CGFloat temporary_radius = copy_start_radius;
				copy_start_radius = copy_end_radius;
				copy_end_radius = temporary_radius;
			}
			CGContextDrawRadialGradient(context, gradient, copy_start,
				copy_start_radius, copy_end, copy_end_radius, 0);
		}
	}
	CGGradientRelease(gradient);
	CGContextRestoreGState(context);
	CGPathRelease(path);
}

void native_draw_svg_radial_gradient_path(const float *data, int segment_count,
	int even_odd, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x,
	float page_y, float scroll_y, float canvas_height, int stroke,
	float stroke_width, int line_cap, int line_join, float miter_limit,
	float start_x, float start_y, float start_radius, float end_x, float end_y,
	float end_radius, float gradient_a, float gradient_b, float gradient_c,
	float gradient_d, float gradient_e, float gradient_f, int spread_method,
	int linear_color_space, const float *stop_data, int stop_count, float opacity) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	native_draw_svg_radial_gradient_path_in_context(context, data, segment_count,
		even_odd, transform_a, transform_b, transform_c, transform_d, transform_e,
		transform_f, page_x, page_y, scroll_y, canvas_height, stroke, stroke_width,
		line_cap, line_join, miter_limit, start_x, start_y, start_radius, end_x,
		end_y, end_radius, gradient_a, gradient_b, gradient_c, gradient_d,
		gradient_e, gradient_f, spread_method, linear_color_space, stop_data,
		stop_count, opacity);
}

// CSS gradients are submitted as one native shading operation, matching the shape of
// DisplayListPlayerSkia's Paint*Gradient handlers. stop_data is sampled by V through the exact
// CSS interpolation path before it reaches CoreGraphics, which only needs to interpolate the
// short sRGB spans between those samples.
int native_draw_css_gradient_path(const float *data, int segment_count, int even_odd,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_height, int kind, float tile_x, float tile_y,
	float tile_width, float tile_height, float x1, float y1, float x2, float y2,
	float center_x, float center_y, float radius_x, float radius_y,
	float start_degrees, const float *stop_data, int stop_count) {
	if (data == NULL || segment_count <= 0 || stop_data == NULL || stop_count <= 0
		|| tile_width <= 0.0 || tile_height <= 0.0) {
		return 0;
	}
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL) {
		return 0;
	}

	int gradient_stop_count = stop_count == 1 ? 2 : stop_count;
	CGFloat *components = calloc((size_t)gradient_stop_count * 4, sizeof(CGFloat));
	CGFloat *locations = calloc((size_t)gradient_stop_count, sizeof(CGFloat));
	if (components == NULL || locations == NULL) {
		free(components);
		free(locations);
		return 0;
	}
	for (int index = 0; index < gradient_stop_count; ++index) {
		int source_index = stop_count == 1 ? 0 : index;
		components[index * 4] = fminf(fmaxf(stop_data[source_index * 5], 0), 1);
		components[index * 4 + 1] = fminf(fmaxf(stop_data[source_index * 5 + 1], 0), 1);
		components[index * 4 + 2] = fminf(fmaxf(stop_data[source_index * 5 + 2], 0), 1);
		components[index * 4 + 3] = fminf(fmaxf(stop_data[source_index * 5 + 3], 0), 1);
		locations[index] = stop_count == 1 ? index
			: fminf(fmaxf(stop_data[source_index * 5 + 4], 0), 1);
	}
	CGColorSpaceRef color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	if (color_space == NULL) {
		color_space = CGColorSpaceCreateDeviceRGB();
	}
	CGGradientRef gradient = CGGradientCreateWithColorComponents(color_space,
		components, locations, (size_t)gradient_stop_count);
	free(components);
	free(locations);
	CGColorSpaceRelease(color_space);
	if (gradient == NULL) {
		return 0;
	}

	CGMutablePathRef path = native_create_path_from_data(data, segment_count);
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	CGContextSaveGState(context);
	CGContextConcatCTM(context, to_canvas);
	CGContextAddPath(context, path);
	if (even_odd) {
		CGContextEOClip(context);
	} else {
		CGContextClip(context);
	}

	int rendered = 1;
	if (kind == 0) {
		CGPoint start = CGPointMake(tile_x + x1 * tile_width,
			tile_y + y1 * tile_height);
		CGPoint end = CGPointMake(tile_x + x2 * tile_width,
			tile_y + y2 * tile_height);
		if (hypot(end.x - start.x, end.y - start.y) <= 1e-6) {
			const float *last_stop = stop_data + (stop_count - 1) * 5;
			CGContextSetRGBFillColor(context, last_stop[0], last_stop[1],
				last_stop[2], last_stop[3]);
			CGContextFillRect(context, CGRectMake(tile_x, tile_y, tile_width, tile_height));
		} else {
			CGContextDrawLinearGradient(context, gradient, start, end,
				kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
		}
	} else if (kind == 1) {
		CGFloat absolute_radius_x = fabs(radius_x * tile_width);
		CGFloat absolute_radius_y = fabs(radius_y * tile_height);
		if (absolute_radius_x <= 1e-6 || absolute_radius_y <= 1e-6) {
			const float *last_stop = stop_data + (stop_count - 1) * 5;
			CGContextSetRGBFillColor(context, last_stop[0], last_stop[1],
				last_stop[2], last_stop[3]);
			CGContextFillRect(context, CGRectMake(tile_x, tile_y, tile_width, tile_height));
		} else {
			CGAffineTransform ellipse = CGAffineTransformMake(absolute_radius_x, 0,
				0, absolute_radius_y, tile_x + center_x * tile_width,
				tile_y + center_y * tile_height);
			CGContextConcatCTM(context, ellipse);
			CGContextDrawRadialGradient(context, gradient, CGPointZero, 0,
				CGPointZero, 1,
				kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
		}
	} else if (kind == 2) {
		if (@available(macOS 14.0, *)) {
			CGPoint center = CGPointMake(tile_x + center_x * tile_width,
				tile_y + center_y * tile_height);
			CGFloat angle = (start_degrees - 90.0) * M_PI / 180.0;
			CGContextDrawConicGradient(context, gradient, center, angle);
		} else {
			rendered = 0;
		}
	} else {
		rendered = 0;
	}

	CGContextRestoreGState(context);
	CGPathRelease(path);
	CGGradientRelease(gradient);
	return rendered;
}

#define NATIVE_SVG_CLIP_CACHE_SIZE 4

typedef struct {
	uint64_t key;
	CGImageRef image;
	CGRect rect;
	uint64_t last_use;
} NativeSVGClipCacheEntry;

static NativeSVGClipCacheEntry native_svg_clip_cache[NATIVE_SVG_CLIP_CACHE_SIZE];
static uint64_t native_svg_clip_cache_clock;
static CGContextRef native_svg_clip_build_context;
static CGImageRef native_svg_clip_image;
static uint64_t native_svg_clip_build_key;
static CGRect native_svg_clip_rect;
static float native_svg_clip_canvas_width;
static int native_svg_clip_build_is_color;
static int native_svg_clip_build_is_luminance;
static int native_svg_clip_build_opacity_depth;
static int native_svg_clip_build_quartz_opacity_depth;
static VoxSVGMaskOpacityBitmap native_svg_clip_opacity_bitmaps[VOX_SVG_MASK_OPACITY_BITMAP_DEPTH];

static uint64_t native_svg_clip_hash_float(uint64_t hash, float value) {
	uint32_t bits;
	memcpy(&bits, &value, sizeof(bits));
	hash ^= bits;
	return hash * UINT64_C(1099511628211);
}

static uint64_t native_svg_mask_cache_key(unsigned long long input_key,
	int content_mask, float canvas_width, float canvas_height, float page_x,
	float page_y, float scroll_y) {
	uint64_t key = (uint64_t)input_key;
	key ^= content_mask ? UINT64_C(0x6d61736b636f6e74)
	                    : UINT64_C(0x636c6970616c7068);
	key *= UINT64_C(1099511628211);
	key = native_svg_clip_hash_float(key, canvas_width);
	key = native_svg_clip_hash_float(key, canvas_height);
	key = native_svg_clip_hash_float(key, page_x);
	key = native_svg_clip_hash_float(key, page_y);
	return native_svg_clip_hash_float(key, scroll_y);
}

static int native_prepare_svg_mask(unsigned long long input_key, int content_mask,
	float canvas_width, float canvas_height, float page_x, float page_y,
	float scroll_y) {
	native_svg_clip_canvas_width = canvas_width;
	native_svg_clip_build_opacity_depth = 0;
	native_svg_clip_build_quartz_opacity_depth = 0;
	native_svg_clip_cache_clock++;
	uint64_t key = native_svg_mask_cache_key(input_key, content_mask, canvas_width,
		canvas_height, page_x, page_y, scroll_y);
	native_svg_clip_build_key = key;
	native_svg_clip_image = NULL;
	native_svg_clip_build_context = NULL;
	for (int index = 0; index < NATIVE_SVG_CLIP_CACHE_SIZE; ++index) {
		if (native_svg_clip_cache[index].image != NULL
			&& native_svg_clip_cache[index].key == key) {
			native_svg_clip_cache[index].last_use = native_svg_clip_cache_clock;
			native_svg_clip_image = native_svg_clip_cache[index].image;
			native_svg_clip_rect = native_svg_clip_cache[index].rect;
			return 0;
		}
	}
	return 1;
}

static CGFloat native_window_backing_scale(void) {
	CGFloat scale = [[native_browser_view() window] backingScaleFactor];
	if (scale <= 0.0) {
		scale = 1.0;
	}
	return scale;
}

static CGFloat native_svg_mask_backing_scale(void) {
	// Screenshot references are logical-pixel Skia surfaces. Building nested
	// masks, patterns, and filter layers at the Retina window scale and then
	// shrinking the captured view applies a second sampling kernel and changes
	// edge coverage. Keep those intermediate surfaces at the reference scale;
	// interactive windows still use their native backing density.
	if (native_screenshot_uses_logical_pixels()) {
		return 1.0;
	}
	if (getenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS") != NULL) {
		return native_screenshot_scale();
	}
	return native_window_backing_scale();
}

#define NATIVE_CSS_FILTER_MAX_DEPTH 64
#include "native/include/native_sparse_bitmap_context_darwin.h"
#include "native/include/native_sparse_opacity_ink_darwin.h"

typedef struct {
	int kind;
	float first;
	float second;
	float third;
	float red;
	float green;
	float blue;
	float alpha;
} NativeCSSFilterOperation;

typedef struct {
	int kind;
	int mode;
	int x_channel;
	int y_channel;
	float first;
	float second;
	float third;
	float fourth;
	float fifth;
	float sixth;
	float red;
	float green;
	float blue;
	float alpha;
	int *inputs;
	size_t input_count;
	double matrix[20];
	size_t matrix_count;
	unsigned char *color_tables[4];
	CGImageRef image;
} NativeSVGFilterNode;

static CGImageRef native_copy_cg_image(gg__Image *image);

typedef struct {
	CGContextRef context;
	CGContextRef destination;
	// Non-null only for this layer's dedicated anonymous zero-fill mapping.
	uint8_t *sparse_input_pixels;
	CGImageRef backdrop_source;
	CGPathRef backdrop_clip;
	CGRect backdrop_bounds;
	float canvas_width;
	float canvas_height;
	CGFloat scale;
	NativeCSSFilterOperation *operations;
	size_t operation_count;
	size_t operation_capacity;
	NativeSVGFilterNode *graph_nodes;
	size_t graph_node_count;
	int graph_root_id;
	CGRect graph_bounds;
	int has_graph_bounds;
	int routes_pattern_paint;
	int active;
	int copies_to_fresh_frame;
	int borrows_fresh_frame;
	CGRect pointwise_output_bounds;
	int has_pointwise_output_bounds;
	int gradient_blur_recording;
	// The blur's cached output stands in for its input leaves' raster.
	int gradient_blur_deferred;
	int svg_filter_recording;
	float svg_filter_transform[6];
	float svg_filter_bounds[4];
	float svg_filter_page_origin[2];
} NativeCSSFilterLayer;

static NativeCSSFilterLayer native_css_filter_stack[NATIVE_CSS_FILTER_MAX_DEPTH];
static int native_css_filter_stack_depth;
static int native_css_filter_overflow_depth;
static CIContext *native_css_filter_ci_context;
VOX_NATIVE_STATE CIContext *native_css_filter_software_context;
static CGColorSpaceRef native_css_filter_color_space;

// Run after the native draw has unwound. Managed references held by a paint
// callback's C stack must not keep its temporary construction data alive during
// the idle collection.
void native_dispatch_browser_memory_cleanup(void *owner, void (*callback)(void *)) {
	if (callback == NULL) return;
	dispatch_async(dispatch_get_main_queue(), ^{
		native_when_document_work_idle(^{ callback(owner); });
	});
}

static uint64_t native_graphics_cleanup_generation;
static BOOL native_idle_graphics_cleanup_scheduled;

void native_schedule_idle_graphics_cleanup(void) {
	if (native_idle_graphics_cleanup_scheduled) return;
	native_idle_graphics_cleanup_scheduled = YES;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		native_when_document_work_idle(^{
			native_idle_graphics_cleanup_scheduled = NO;
			native_discard_opacity_canvas_pool();
		});
	});
}

static void native_release_unused_graphics_memory(void) {
	if (![NSThread isMainThread]) return;
	@autoreleasepool {
		native_discard_opacity_canvas_pool();
		// A page without filters never creates this renderer. Preserve that lazy
		// behavior while returning unused textures from existing filter contexts.
		if (native_css_filter_ci_context != nil) {
			[native_css_filter_ci_context reclaimResources];
			[native_css_filter_ci_context clearCaches];
		}
		if (native_css_filter_software_context != nil) {
			[native_css_filter_software_context reclaimResources];
			[native_css_filter_software_context clearCaches];
		}
	}
	malloc_zone_pressure_relief(NULL, 0);
}

// Native allocations are independent of managed allocation debt. A static
// document replayed for a toolbar update can refill GPU caches without creating
// enough V garbage to trigger another collection.
void native_schedule_static_graphics_cleanup(void) {
	uint64_t generation = ++native_graphics_cleanup_generation;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 250 * NSEC_PER_MSEC),
		dispatch_get_main_queue(), ^{
			if (generation != native_graphics_cleanup_generation) return;
			native_when_document_work_idle(^{
				if (generation == native_graphics_cleanup_generation)
					native_release_unused_graphics_memory();
			});
		});
}

static void native_initialize_css_filter_renderer(void) {
	static dispatch_once_t once_token;
	dispatch_once(&once_token, ^{
		native_css_filter_color_space =
			CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
		native_css_filter_ci_context = [CIContext contextWithOptions:@{
			kCIContextWorkingColorSpace : (__bridge id)native_css_filter_color_space,
			kCIContextOutputColorSpace : (__bridge id)native_css_filter_color_space,
		}];
	});
}

// Retained filters may be outside the initial viewport. Prepare their shared
// renderer while adopting the display list, rather than creating a Metal/Core
// Image context on the first wheel event that exposes one. No bitmap, filter
// graph or rendered result is retained here; pages without filters stay lazy.
void native_prepare_css_filter_renderer(void) {
	if (getenv("VOX_DISABLE_EARLY_CSS_FILTER_CONTEXT") || native_css_filter_ci_context) return;
	BOOL diagnostics = getenv("VOX_CSS_FILTER_PREPARATION_DIAGNOSTICS") != NULL;
	double started = diagnostics ? CACurrentMediaTime() : 0;
	native_initialize_css_filter_renderer();
	if (diagnostics) fprintf(stderr, "VOX_CSS_FILTER_PREPARED context=%d us=%.3f\n",
		native_css_filter_ci_context != nil, (CACurrentMediaTime() - started) * 1e6);
}

void native_begin_css_filter_layer(float canvas_width, float canvas_height) {
	if (native_css_filter_stack_depth >= NATIVE_CSS_FILTER_MAX_DEPTH) {
		native_css_filter_overflow_depth++;
		return;
	}
	NativeCSSFilterLayer layer = {
		.destination = [[NSGraphicsContext currentContext] CGContext],
		.canvas_width = canvas_width,
		.canvas_height = canvas_height,
		.scale = native_svg_mask_backing_scale(),
	};
	if (layer.destination != NULL && canvas_width > 0.0f && canvas_height > 0.0f) {
		size_t width = (size_t)MAX(1.0, ceil(canvas_width * layer.scale));
		size_t height = (size_t)MAX(1.0, ceil(canvas_height * layer.scale));
		CGColorSpaceRef color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
		if (getenv("VOX_SPARSE_CSS_FILTER_INPUTS")) {
            layer.context = native_create_sparse_bitmap_context(width, height, color_space);
            if (layer.context) layer.sparse_input_pixels = (uint8_t *)CGBitmapContextGetData(layer.context);
        }
        if (!layer.context)
            layer.context = CGBitmapContextCreate(NULL, width, height, 8, width * 4,
                color_space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
		CGColorSpaceRelease(color_space);
		if (layer.context != NULL) {
			CGContextScaleCTM(layer.context, layer.scale, layer.scale);
			CGContextSetShouldAntialias(layer.context, true);
			CGContextSetInterpolationQuality(layer.context, kCGInterpolationHigh);
			[NSGraphicsContext saveGraphicsState];
			[NSGraphicsContext setCurrentContext:
				[NSGraphicsContext graphicsContextWithCGContext:layer.context flipped:NO]];
			layer.active = 1;
		}
	}
	native_css_filter_stack[native_css_filter_stack_depth++] = layer;
}

void native_end_css_filter_layer(void);

// `content_key` is a scroll-independent identity of the layer's commands, or
// zero; the bridge reuses the rasterized blur while it is unchanged.
void native_record_css_gradient_blur_input(uint64_t content_key) {
	(void)content_key;
}

void native_record_css_svg_filter_input(float a, float b, float c, float d, float e, float f,
    float left, float top, float right, float bottom, float page_x, float page_y) {
}

// The strip and damage rectangles a reused scroll frame clips to, as x, y,
// width, height in top-left canvas points; zero rectangles clear them.
void native_set_scroll_damage_rects(float const *rects, int count) {
    (void)rects; (void)count;
}

// A top-level video's retained backdrop, in document CSS pixels.
void native_capture_video_backdrop(double x, double y, double width, double height) {
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    VoxScrollRaster *cache = &native_scroll_raster;
    long rect[4], origin, first, end;
    // An isolated layer cannot seed the root's backdrop cache. Validate before
    // synchronizing: an ignored capture must not download its parent's tiles.
    if (!cache->active || context != cache->context
        || !native_video_backdrop_geometry(cache,cache->scroll,x,y,width,height,rect,&origin)
        || !native_video_backdrop_visible(cache,rect,origin,&first,&end)) return;
    native_video_backdrop_capture([[NSGraphicsContext currentContext] CGContext],
        x, y, width, height);
}

void native_invalidate_video_backdrop(double x, double y, double width, double height) {
    native_video_backdrop_invalidate(x, y, width, height);
}

// The next image draws are frames of a playing video.
static int native_video_frame_image;

#include "native/include/native_video_image_resource.h"
void native_set_video_frame_image(int active) {
    native_video_frame_image = active != 0;
    native_video_image_resource_key = 0;
}

void native_set_video_frame_resource(uint64_t source, uint64_t revision, uint64_t generation) {
    native_video_image_resource_key = native_video_frame_image && getenv("VOX_GPU_VIDEO_UPLOAD_KEYS")
        ? native_video_image_resource_identity(source,revision,generation) : 0;
}


// GPU canvas over a complete eligible frame or the rectangles a reused frame repaints.
// Repainted rectangles are viewport device rows; the canvas also holds chrome.
// A caller-owned sequence after the document ring has been stored, with
// conservative top-left canvas-point bounds. Graphics policy stays in V.
int native_gpu_canvas_begin_rects(const float *rects, int count) {
    return 0;
}

int native_gpu_canvas_begin(void) {
	return 0;
}

// Called after a successful begin; a frame drawn at page zoom has fractional
// device geometry (see GpuCanvasFrame::fractional_geometry).
void native_gpu_canvas_fractional_geometry(int enabled) {
}

void native_gpu_canvas_cpu_access(void) {
}

int native_gpu_canvas_command(const char *kind, int kind_len, int flags) {
	return 0;
}

int native_gpu_canvas_nested_layer_active(void) {
    return 0;
}

int native_gpu_canvas_can_defer_layers(void) {
    return 0;
}

int native_gpu_canvas_can_present(void) {
    return 0;
}
void native_gpu_canvas_end(void) {
}

void native_reject_scroll_raster_frame(void) {
    native_scroll_raster_independent_content();
}

static int native_try_restore_gpu_video_backdrop(CGContextRef context, const uint8_t *pixels,
    int width, int height, int pitch, int x, int y) {
    return 0;
}

void native_restore_video_backdrop(double x, double y, double width, double height) {
    if (!native_video_backdrop_restore_with_gpu([[NSGraphicsContext currentContext] CGContext],
            x, y, width, height, native_try_restore_gpu_video_backdrop))
        native_scroll_raster_independent_content();
}

// Reports the root raster's scroll position to an injected precise-scroll
// probe (tools/measure_precise_scroll_darwin.m), which pairs it with frame
// publications. Without the probe the lookup finds nothing and this is a no-op.
void native_set_chromium_raster_scroll_y(double scroll_y) {
    static dispatch_once_t once;
    static void (*report)(double);
    dispatch_once(&once, ^{
        report = (void (*)(double))dlsym(RTLD_DEFAULT, "vox_precise_scroll_rendered_y");
    });
    if (report) report(scroll_y);
}

// The Chromium raster tiles whose GPU render pass is multisampled in this
// frame; their anti-aliased shapes take multisampled coverage.
void native_set_chromium_raster_layer(double origin_x, double origin_y, int root) {
    (void)origin_x; (void)origin_y; (void)root;
}

void native_set_chromium_direct_image_layer(int enabled) {
}

void native_set_chromium_raster_layer_size(double width, double height) {
    (void)width; (void)height;
}

void native_set_chromium_save_layer_image_raster(double x, double y,
    double width, double height, int tile_rows) {
    (void)x; (void)y; (void)width; (void)height; (void)tile_rows;
}

void native_set_chromium_msaa_tiles(const int *tiles, int count, int tile_rows) {
	(void)tiles; (void)count; (void)tile_rows;
}

void native_set_chromium_msaa_grid(const int *tiles, int count, int tile_width,
    int tile_height, int columns) {
    (void)tiles; (void)count; (void)tile_width; (void)tile_height; (void)columns;
}

// Whether the next native rounded rectangle can draw an underlay in its pass.
int native_rounded_rect_underlay_supported(void) {
	return 1;
}

// The filled rounded rectangle, as x, y, width, height and four corner radius
// pairs, that the next native rounded rectangle draws first in its own pass.
void native_set_rounded_rect_underlay(const float *rect, gg__Color color) {
    native_v_shape_state.has_underlay = rect != NULL;
    if (rect) memcpy(native_v_shape_state.underlay_rect,rect,12*sizeof(float));
    native_v_shape_state.underlay_rgba[0]=color.r; native_v_shape_state.underlay_rgba[1]=color.g;
    native_v_shape_state.underlay_rgba[2]=color.b; native_v_shape_state.underlay_rgba[3]=color.a;
}

void native_set_rounded_rect_underlay_color(const float *color) {
    native_v_shape_state.has_float_underlay_color = color != NULL;
    if (color) memcpy(native_v_shape_state.underlay_float_color,color,4*sizeof(float));
}

void native_set_image_background(gg__Color color) {
	(void)color;
}

void native_set_image_border(float const* rect, float width, gg__Color color) {
}

// Insets retained by a single visible rounded border, including transparent sides.
void native_set_rounded_border_widths(const float *widths) {
    if (widths) memcpy(native_v_shape_state.border_widths,widths,4*sizeof(float));
}

// Rectangles clipped out of the next anti-aliased rectangle, as left, top,
// right and bottom; a count of zero clears them.
void native_set_rect_clip_outs(const double *rects, int count) {
    free((void*)native_v_shape_state.clip_outs);
    native_v_shape_state.clip_outs = NULL;
    native_v_shape_state.clip_out_count = 0;
    if (!rects || count <= 0 || count > 4096) return;
    float* copy = malloc((size_t)count * 4 * sizeof(float));
    if (!copy) return;
    for (int i = 0; i < count * 4; ++i) copy[i] = (float)rects[i];
    native_v_shape_state.clip_outs = copy;
    native_v_shape_state.clip_out_count = count;
}

void native_set_css_gradient_tile_bounds(const float *bounds) {
}

void native_set_chromium_shared_recording(int enabled, int width, int height) {
}

void native_set_chromium_layer_shared_recording(int enabled) {
}

void native_set_chromium_paint_origin(double x, double y, int active) {
    (void)x; (void)y; (void)active;
}

void native_begin_font_compositing_layer(float width, float height) {
	CGContextRef destination = [[NSGraphicsContext currentContext] CGContext];
	int fresh_destination = native_layer_claim_document_bitmap(destination);
	int previous_depth = native_css_filter_stack_depth;
	CGFloat scale = native_svg_mask_backing_scale();
	if (fresh_destination && previous_depth < NATIVE_CSS_FILTER_MAX_DEPTH
		&& native_layer_begin_document_canvas(destination, width, height, scale)) {
		NativeCSSFilterLayer layer = {
			.context = CGContextRetain(destination), .destination = destination,
			.canvas_width = width, .canvas_height = height, .scale = scale,
			.active = 1, .copies_to_fresh_frame = 1, .borrows_fresh_frame = 1,
		};
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:
			[NSGraphicsContext graphicsContextWithCGContext:destination flipped:NO]];
		native_css_filter_stack[native_css_filter_stack_depth++] = layer;
	} else {
		native_begin_css_filter_layer(width, height);
	}
	if (fresh_destination && native_css_filter_stack_depth == previous_depth + 1) {
		NativeCSSFilterLayer *layer = &native_css_filter_stack[previous_depth];
		if (layer->active && layer->destination == destination)
			layer->copies_to_fresh_frame = 1;
	}
	native_font_compositing_context = [[NSGraphicsContext currentContext] CGContext];
	native_font_compositing_transparency_depth = 0;
}

int native_set_small_svg_path_cache(int enabled) {
	(void)enabled;
	return 0;
}

uint64_t native_small_svg_path_cache_hits(void) {
	return 0;
}

void native_end_font_compositing_layer(void) {
	native_font_compositing_context = NULL;
	native_font_compositing_transparency_depth = 0;
	native_end_css_filter_layer();
}

void native_begin_backdrop_filter_layer(float canvas_width, float canvas_height,
	float region_x, float region_y, float region_width, float region_height,
	float top_left_x, float top_left_y, float top_right_x, float top_right_y,
	float bottom_right_x, float bottom_right_y, float bottom_left_x,
	float bottom_left_y, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x,
	float page_y, float scroll_y, int source_outside_current_filter) {
	if (native_css_filter_stack_depth >= NATIVE_CSS_FILTER_MAX_DEPTH) {
		native_css_filter_overflow_depth++;
		return;
	}
	CGContextRef destination = [[NSGraphicsContext currentContext] CGContext];
	CGContextRef source = destination;
	CGContextRef transparent_source = NULL;
	if (source_outside_current_filter && native_css_filter_stack_depth > 0) {
		NativeCSSFilterLayer const *current_filter =
			&native_css_filter_stack[native_css_filter_stack_depth - 1];
		if (current_filter->destination != NULL) {
			source = current_filter->destination;
			if (current_filter->borrows_fresh_frame) {
				transparent_source = CGBitmapContextCreate(NULL,
					CGBitmapContextGetWidth(source), CGBitmapContextGetHeight(source),
					8, CGBitmapContextGetBytesPerRow(source),
					CGBitmapContextGetColorSpace(source), CGBitmapContextGetBitmapInfo(source));
				source = transparent_source;
			}
		}
	}
	NativeCSSFilterLayer layer = {
		.destination = destination,
		.canvas_width = canvas_width,
		.canvas_height = canvas_height,
		.scale = native_svg_mask_backing_scale(),
	};
	if (source != NULL && destination != NULL && region_width > 0.0f
		&& region_height > 0.0f && canvas_width > 0.0f && canvas_height > 0.0f) {
		layer.backdrop_source = CGBitmapContextCreateImage(source);
		CGPathRef local_path = native_create_corner_rounded_rect_path(region_x,
			region_y, region_width, region_height, top_left_x, top_left_y,
			top_right_x, top_right_y, bottom_right_x, bottom_right_y,
			bottom_left_x, bottom_left_y);
		CGAffineTransform to_canvas = CGAffineTransformMake(transform_a,
			-transform_b, transform_c, -transform_d, page_x + transform_e,
			canvas_height - page_y + scroll_y - transform_f);
		layer.backdrop_clip = CGPathCreateCopyByTransformingPath(local_path,
			&to_canvas);
		CGPathRelease(local_path);
		if (layer.backdrop_clip != NULL) {
			layer.backdrop_bounds = CGRectIntersection(
				CGRectStandardize(CGPathGetPathBoundingBox(layer.backdrop_clip)),
				CGRectMake(0, 0, canvas_width, canvas_height));
		}
		layer.active = layer.backdrop_source != NULL && layer.backdrop_clip != NULL
			&& !CGRectIsNull(layer.backdrop_bounds)
			&& !CGRectIsEmpty(layer.backdrop_bounds);
	}
	if (transparent_source) CGContextRelease(transparent_source);
	native_css_filter_stack[native_css_filter_stack_depth++] = layer;
}

void native_add_css_filter_operation(int kind, float first, float second,
	float third, gg__Color color) {
	if (native_css_filter_overflow_depth > 0 || native_css_filter_stack_depth <= 0) {
		return;
	}
	NativeCSSFilterLayer *layer =
		&native_css_filter_stack[native_css_filter_stack_depth - 1];
	if (layer->operation_count == layer->operation_capacity) {
		size_t capacity = layer->operation_capacity == 0 ? 8
			: layer->operation_capacity * 2;
		NativeCSSFilterOperation *operations = realloc(layer->operations,
			capacity * sizeof(NativeCSSFilterOperation));
		if (operations == NULL) {
			return;
		}
		layer->operations = operations;
		layer->operation_capacity = capacity;
	}
	layer->operations[layer->operation_count++] = (NativeCSSFilterOperation) {
		.kind = kind,
		.first = first,
		.second = second,
		.third = third,
		.red = (float)color.r / 255.0f,
		.green = (float)color.g / 255.0f,
		.blue = (float)color.b / 255.0f,
		.alpha = (float)color.a / 255.0f,
	};
}

void native_begin_svg_filter_graph(int root_id, int node_count, float bounds_x,
	float bounds_y, float bounds_width, float bounds_height, float transform_a,
	float transform_b, float transform_c, float transform_d, float transform_e,
	float transform_f, float page_x, float page_y) {
	if (native_css_filter_overflow_depth > 0 || native_css_filter_stack_depth <= 0
		|| node_count <= 0 || root_id < 0 || root_id >= node_count) {
		return;
	}
	NativeCSSFilterLayer *layer =
		&native_css_filter_stack[native_css_filter_stack_depth - 1];
	free(layer->graph_nodes);
	layer->graph_nodes = calloc((size_t)node_count, sizeof(NativeSVGFilterNode));
	if (layer->graph_nodes == NULL) {
		return;
	}
	layer->graph_node_count = (size_t)node_count;
	layer->graph_root_id = root_id;
	if (bounds_width > 0.0f && bounds_height > 0.0f) {
		// V's retained visual transform already includes every live scroll
		// offset. Convert its top-left document-space bounds to Core Image's
		// bottom-left, backing-pixel coordinate system.
		CGAffineTransform to_canvas = CGAffineTransformMake(transform_a,
			-transform_b, transform_c, -transform_d, page_x + transform_e,
			layer->canvas_height - page_y - transform_f);
		CGRect mapped = CGRectStandardize(CGRectApplyAffineTransform(
			CGRectMake(bounds_x, bounds_y, bounds_width, bounds_height), to_canvas));
		mapped = CGRectIntersection(mapped,
			CGRectMake(0, 0, layer->canvas_width, layer->canvas_height));
		if (!CGRectIsNull(mapped) && !CGRectIsEmpty(mapped)) {
			layer->graph_bounds = CGRectMake(mapped.origin.x * layer->scale,
				mapped.origin.y * layer->scale, mapped.size.width * layer->scale,
				mapped.size.height * layer->scale);
			layer->has_graph_bounds = 1;
		}
	}
	for (int index = 0; index < node_count; ++index) {
		layer->graph_nodes[index].kind = -1;
	}
}

void native_add_svg_filter_node(int id, int kind, float first, float second,
	float third, float fourth, float fifth, float sixth, gg__Color color,
	int mode, int x_channel, int y_channel) {
	if (native_css_filter_overflow_depth > 0 || native_css_filter_stack_depth <= 0) {
		return;
	}
	NativeCSSFilterLayer *layer =
		&native_css_filter_stack[native_css_filter_stack_depth - 1];
	if (id < 0 || (size_t)id >= layer->graph_node_count) {
		return;
	}
	NativeSVGFilterNode *node = &layer->graph_nodes[id];
	node->kind = kind;
	node->mode = mode;
	node->x_channel = x_channel;
	node->y_channel = y_channel;
	node->first = first;
	node->second = second;
	node->third = third;
	node->fourth = fourth;
	node->fifth = fifth;
	node->sixth = sixth;
	node->red = (float)color.r / 255.0f;
	node->green = (float)color.g / 255.0f;
	node->blue = (float)color.b / 255.0f;
	node->alpha = (float)color.a / 255.0f;
}

void native_set_svg_filter_node_inputs(int id, const int *inputs, int count) {
	if (native_css_filter_overflow_depth > 0 || native_css_filter_stack_depth <= 0
		|| count <= 0 || inputs == NULL) {
		return;
	}
	NativeCSSFilterLayer *layer =
		&native_css_filter_stack[native_css_filter_stack_depth - 1];
	if (id < 0 || (size_t)id >= layer->graph_node_count) {
		return;
	}
	NativeSVGFilterNode *node = &layer->graph_nodes[id];
	free(node->inputs);
	node->inputs = malloc((size_t)count * sizeof(int));
	if (node->inputs == NULL) {
		return;
	}
	memcpy(node->inputs, inputs, (size_t)count * sizeof(int));
	node->input_count = (size_t)count;
}

void native_set_svg_filter_node_matrix(int id, const double *matrix, int count) {
	if (native_css_filter_overflow_depth > 0 || native_css_filter_stack_depth <= 0
		|| count != 20 || matrix == NULL) {
		return;
	}
	NativeCSSFilterLayer *layer =
		&native_css_filter_stack[native_css_filter_stack_depth - 1];
	if (id < 0 || (size_t)id >= layer->graph_node_count) {
		return;
	}
	NativeSVGFilterNode *node = &layer->graph_nodes[id];
	memcpy(node->matrix, matrix, sizeof(node->matrix));
	node->matrix_count = 20;
}

void native_set_svg_filter_color_table(int id, int channel,
	const unsigned char *values, int count) {
	if (native_css_filter_overflow_depth > 0 || native_css_filter_stack_depth <= 0
		|| channel < 0 || channel >= 4 || count != 256 || values == NULL) {
		return;
	}
	NativeCSSFilterLayer *layer =
		&native_css_filter_stack[native_css_filter_stack_depth - 1];
	if (id < 0 || (size_t)id >= layer->graph_node_count) {
		return;
	}
	NativeSVGFilterNode *node = &layer->graph_nodes[id];
	free(node->color_tables[channel]);
	node->color_tables[channel] = malloc(256);
	if (node->color_tables[channel] != NULL) {
		memcpy(node->color_tables[channel], values, 256);
	}
}

void native_set_svg_filter_node_image(int id, gg__Image *image) {
	if (native_css_filter_overflow_depth > 0 || native_css_filter_stack_depth <= 0
		|| image == NULL) {
		return;
	}
	NativeCSSFilterLayer *layer =
		&native_css_filter_stack[native_css_filter_stack_depth - 1];
	if (id < 0 || (size_t)id >= layer->graph_node_count) {
		return;
	}
	NativeSVGFilterNode *node = &layer->graph_nodes[id];
	CGImageRef decoded = native_copy_cg_image(image);
	if (decoded == NULL) {
		return;
	}
	if (node->image != NULL) {
		CGImageRelease(node->image);
	}
	node->image = decoded;
}

static CIImage *native_css_filter_color_matrix(CIImage *input,
	const CGFloat matrix[20]) {
	CIFilter *filter = [CIFilter filterWithName:@"CIColorMatrix"];
	[filter setValue:input forKey:kCIInputImageKey];
	[filter setValue:[CIVector vectorWithX:matrix[0] Y:matrix[1]
		Z:matrix[2] W:matrix[3]] forKey:@"inputRVector"];
	[filter setValue:[CIVector vectorWithX:matrix[5] Y:matrix[6]
		Z:matrix[7] W:matrix[8]] forKey:@"inputGVector"];
	[filter setValue:[CIVector vectorWithX:matrix[10] Y:matrix[11]
		Z:matrix[12] W:matrix[13]] forKey:@"inputBVector"];
	[filter setValue:[CIVector vectorWithX:matrix[15] Y:matrix[16]
		Z:matrix[17] W:matrix[18]] forKey:@"inputAVector"];
	[filter setValue:[CIVector vectorWithX:matrix[4] Y:matrix[9]
		Z:matrix[14] W:matrix[19]] forKey:@"inputBiasVector"];
	return [filter valueForKey:kCIOutputImageKey];
}

static CIImage *native_apply_css_color_filter(CIImage *input, int kind,
	CGFloat amount) {
	CGFloat matrix[20] = {
		1, 0, 0, 0, 0,
		0, 1, 0, 0, 0,
		0, 0, 1, 0, 0,
		0, 0, 0, 1, 0,
	};
	switch (kind) {
	case 0: { // brightness
		matrix[0] = amount;
		matrix[6] = amount;
		matrix[12] = amount;
		break;
	}
	case 1: { // contrast
		CGFloat intercept = -(0.5 * amount) + 0.5;
		matrix[0] = amount;
		matrix[4] = intercept;
		matrix[6] = amount;
		matrix[9] = intercept;
		matrix[12] = amount;
		matrix[14] = intercept;
		break;
	}
	case 2: { // grayscale
		CGFloat inverse = 1.0 - amount;
		CGFloat values[20] = {
			0.2126 + 0.7874 * inverse, 0.7152 - 0.7152 * inverse,
			0.0722 - 0.0722 * inverse, 0, 0,
			0.2126 - 0.2126 * inverse, 0.7152 + 0.2848 * inverse,
			0.0722 - 0.0722 * inverse, 0, 0,
			0.2126 - 0.2126 * inverse, 0.7152 - 0.7152 * inverse,
			0.0722 + 0.9278 * inverse, 0, 0,
			0, 0, 0, 1, 0,
		};
		memcpy(matrix, values, sizeof(matrix));
		break;
	}
	case 3: { // invert
		matrix[0] = 1.0 - 2.0 * amount;
		matrix[4] = amount;
		matrix[6] = 1.0 - 2.0 * amount;
		matrix[9] = amount;
		matrix[12] = 1.0 - 2.0 * amount;
		matrix[14] = amount;
		break;
	}
	case 4: // opacity
		matrix[18] = amount;
		break;
	case 5: { // saturate
		CGFloat values[20] = {
			0.213 + 0.787 * amount, 0.715 - 0.715 * amount,
			0.072 - 0.072 * amount, 0, 0,
			0.213 - 0.213 * amount, 0.715 + 0.285 * amount,
			0.072 - 0.072 * amount, 0, 0,
			0.213 - 0.213 * amount, 0.715 - 0.715 * amount,
			0.072 + 0.928 * amount, 0, 0,
			0, 0, 0, 1, 0,
		};
		memcpy(matrix, values, sizeof(matrix));
		break;
	}
	case 6: { // sepia
		CGFloat inverse = 1.0 - amount;
		CGFloat values[20] = {
			0.393 + 0.607 * inverse, 0.769 - 0.769 * inverse,
			0.189 - 0.189 * inverse, 0, 0,
			0.349 - 0.349 * inverse, 0.686 + 0.314 * inverse,
			0.168 - 0.168 * inverse, 0, 0,
			0.272 - 0.272 * inverse, 0.534 - 0.534 * inverse,
			0.131 + 0.869 * inverse, 0, 0,
			0, 0, 0, 1, 0,
		};
		memcpy(matrix, values, sizeof(matrix));
		break;
	}
	default:
		break;
	}
	return native_css_filter_color_matrix(input, matrix);
}

static CIImage *native_apply_css_hue_rotate(CIImage *input, CGFloat degrees) {
	CGFloat radians = degrees * M_PI / 180.0;
	CGFloat cosine = cos(radians);
	CGFloat sine = sin(radians);
	CGFloat matrix[20] = {
		0.213 + cosine * 0.787 - sine * 0.213,
		0.715 - cosine * 0.715 - sine * 0.715,
		0.072 - cosine * 0.072 + sine * 0.928, 0, 0,
		0.213 - cosine * 0.213 + sine * 0.143,
		0.715 + cosine * 0.285 + sine * 0.140,
		0.072 - cosine * 0.072 - sine * 0.283, 0, 0,
		0.213 - cosine * 0.213 - sine * 0.787,
		0.715 - cosine * 0.715 + sine * 0.715,
		0.072 + cosine * 0.928 + sine * 0.072, 0, 0,
		0, 0, 0, 1, 0,
	};
	return native_css_filter_color_matrix(input, matrix);
}

static CIImage *native_apply_css_blur(CIImage *input, CGFloat radius) {
	CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
	[filter setValue:input forKey:kCIInputImageKey];
	[filter setValue:@(MAX(radius, 0.0)) forKey:kCIInputRadiusKey];
	return [filter valueForKey:kCIOutputImageKey];
}

static CIImage *native_apply_css_drop_shadow(CIImage *input,
	NativeCSSFilterOperation operation, CGFloat scale) {
	CGFloat alpha_matrix[20] = {
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 1, 0,
	};
	CIImage *shadow = native_css_filter_color_matrix(input, alpha_matrix);
	shadow = native_apply_css_blur(shadow, operation.third * scale);
	CGFloat color_matrix[20] = {
		0, 0, 0, operation.red, 0,
		0, 0, 0, operation.green, 0,
		0, 0, 0, operation.blue, 0,
		0, 0, 0, operation.alpha, 0,
	};
	shadow = native_css_filter_color_matrix(shadow, color_matrix);
	CIFilter *offset = [CIFilter filterWithName:@"CIAffineTransform"];
	[offset setValue:shadow forKey:kCIInputImageKey];
	CGAffineTransform transform = CGAffineTransformMakeTranslation(
		operation.first * scale, -operation.second * scale);
	[offset setValue:[NSValue value:&transform withObjCType:@encode(CGAffineTransform)]
		forKey:kCIInputTransformKey];
	shadow = [offset valueForKey:kCIOutputImageKey];
	CIFilter *compose = [CIFilter filterWithName:@"CISourceOverCompositing"];
	[compose setValue:input forKey:kCIInputImageKey];
	[compose setValue:shadow forKey:kCIInputBackgroundImageKey];
	return [compose valueForKey:kCIOutputImageKey];
}

static CIImage *native_apply_svg_offset(CIImage *input, CGFloat dx, CGFloat dy) {
	CIFilter *filter = [CIFilter filterWithName:@"CIAffineTransform"];
	[filter setValue:input forKey:kCIInputImageKey];
	CGAffineTransform transform = CGAffineTransformMakeTranslation(dx, -dy);
	[filter setValue:[NSValue value:&transform withObjCType:@encode(CGAffineTransform)]
		forKey:kCIInputTransformKey];
	return [filter valueForKey:kCIOutputImageKey];
}

static CIImage *native_apply_svg_anisotropic_filter(CIImage *input,
	NSString *filter_name, CGFloat radius_x, CGFloat radius_y) {
	radius_x = MAX(radius_x, 0.0);
	radius_y = MAX(radius_y, 0.0);
	if (radius_x == 0.0 && radius_y == 0.0) {
		return input;
	}
	// Core Image exposes one radius for Gaussian blur and morphology. Scale one
	// axis around the operation to retain LibGfx's independent x/y radii.
	CGFloat operation_radius = MAX(radius_x, 0.001);
	CGFloat y_scale = operation_radius / MAX(radius_y, 0.001);
	CIImage *scaled = input;
	if (fabs(y_scale - 1.0) > 0.0001) {
		scaled = [scaled imageByApplyingTransform:CGAffineTransformMakeScale(1.0, y_scale)];
	}
	CIFilter *filter = [CIFilter filterWithName:filter_name];
	[filter setValue:scaled forKey:kCIInputImageKey];
	[filter setValue:@(operation_radius) forKey:kCIInputRadiusKey];
	CIImage *output = [filter valueForKey:kCIOutputImageKey];
	if (fabs(y_scale - 1.0) > 0.0001) {
		output = [output imageByApplyingTransform:CGAffineTransformMakeScale(1.0,
			1.0 / y_scale)];
	}
	return output;
}

static CIImage *native_apply_svg_blend(CIImage *background, CIImage *foreground,
	int mode) {
	CIBlendKernel *kernel = CIBlendKernel.sourceOver;
	switch (mode) {
	case 1: kernel = CIBlendKernel.multiply; break;
	case 2: kernel = CIBlendKernel.screen; break;
	case 3: kernel = CIBlendKernel.overlay; break;
	case 4: kernel = CIBlendKernel.darken; break;
	case 5: kernel = CIBlendKernel.lighten; break;
	case 6: kernel = CIBlendKernel.colorDodge; break;
	case 7: kernel = CIBlendKernel.colorBurn; break;
	case 8: kernel = CIBlendKernel.hardLight; break;
	case 9: kernel = CIBlendKernel.softLight; break;
	case 10: kernel = CIBlendKernel.difference; break;
	case 11: kernel = CIBlendKernel.exclusion; break;
	case 12: kernel = CIBlendKernel.hue; break;
	case 13: kernel = CIBlendKernel.saturation; break;
	case 14: kernel = CIBlendKernel.color; break;
	case 15: kernel = CIBlendKernel.luminosity; break;
	case 16: {
		static CIBlendKernel *plus_darker;
		static dispatch_once_t once_token;
		dispatch_once(&once_token, ^{
			// This is the same deliberate Safari-compatible formula used by
			// LibGfx::to_skia_blender(), including both saturate stages.
			plus_darker = [CIBlendKernel kernelWithString:
				@"kernel vec4 plusDarker(__sample source, __sample destination) { "
				 "return clamp(clamp(destination.a + source.a, 0.0, 1.0) - "
				 "clamp(destination.a - destination, 0.0, 1.0) - "
				 "clamp(source.a - source, 0.0, 1.0), 0.0, 1.0); }"];
		});
		kernel = plus_darker ?: CIBlendKernel.darken;
		break;
	}
	case 17:
	case 24: kernel = CIBlendKernel.componentAdd; break;
	case 20: kernel = CIBlendKernel.sourceIn; break;
	case 21: kernel = CIBlendKernel.destinationOut; break;
	case 22: kernel = CIBlendKernel.sourceAtop; break;
	case 23: kernel = CIBlendKernel.exclusiveOr; break;
	default: break;
	}
	return [kernel applyWithForeground:foreground background:background];
}

static CIImage *native_apply_svg_arithmetic(CIImage *background,
	CIImage *foreground, NativeSVGFilterNode const *node) {
	static CIColorKernel *kernel;
	static dispatch_once_t once_token;
	dispatch_once(&once_token, ^{
		kernel = [CIColorKernel kernelWithString:
			@"kernel vec4 svgArithmetic(__sample background, __sample foreground, "
			 "float k1, float k2, float k3, float k4) { "
			 "vec4 result = clamp(k1 * foreground * background + k2 * foreground + "
			 "k3 * background + vec4(k4), 0.0, 1.0); "
			 "return vec4(min(result.rgb, vec3(result.a)), result.a); }"];
	});
	if (kernel == nil) {
		return foreground;
	}
	CGRect extent = CGRectUnion(background.extent, foreground.extent);
	return [kernel applyWithExtent:extent arguments:@[ background, foreground,
		@(node->first), @(node->second), @(node->third), @(node->fourth) ]];
}

static CIImage *native_svg_filter_input(CIImage *__unsafe_unretained const *outputs,
	size_t count,
	int id, CIImage *source) {
	if (id < 0) {
		return source;
	}
	if ((size_t)id >= count || outputs[id] == nil) {
		return source;
	}
	return outputs[id];
}

typedef struct {
	CGRect rect;
	int infinite;
	int valid;
} NativeSVGFilterExtent;

static NativeSVGFilterExtent native_svg_finite_extent(CGRect rect) {
	return (NativeSVGFilterExtent) { .rect = rect, .valid = 1 };
}

static NativeSVGFilterExtent native_svg_infinite_extent(void) {
	return (NativeSVGFilterExtent) { .infinite = 1, .valid = 1 };
}

static NativeSVGFilterExtent native_svg_union_extents(NativeSVGFilterExtent first,
	NativeSVGFilterExtent second) {
	if (first.infinite || second.infinite) {
		return native_svg_infinite_extent();
	}
	if (!first.valid) {
		return second;
	}
	if (!second.valid) {
		return first;
	}
	return native_svg_finite_extent(CGRectUnion(first.rect, second.rect));
}

static NativeSVGFilterExtent native_svg_intersect_extents(
	NativeSVGFilterExtent first, NativeSVGFilterExtent second) {
	if (first.infinite) {
		return second;
	}
	if (second.infinite) {
		return first;
	}
	if (!first.valid || !second.valid) {
		return (NativeSVGFilterExtent) {};
	}
	CGRect intersection = CGRectIntersection(first.rect, second.rect);
	return CGRectIsNull(intersection) || CGRectIsEmpty(intersection)
		? (NativeSVGFilterExtent) {}
		: native_svg_finite_extent(intersection);
}

static NativeSVGFilterExtent native_svg_filter_input_extent(
	NativeSVGFilterExtent const *outputs, size_t count, int id,
	NativeSVGFilterExtent source) {
	if (id < 0 || (size_t)id >= count || !outputs[id].valid) {
		return source;
	}
	return outputs[id];
}

static NativeSVGFilterExtent native_svg_source_extent(
	NativeCSSFilterLayer const *layer, CGRect source_extent) {
	NativeSVGFilterExtent extent = native_svg_finite_extent(
		layer->has_graph_bounds ? layer->graph_bounds : source_extent);
	// The standard CSS chain is the inner filter. Track the same geometric
	// expansion before evaluating the outer SVG graph's SourceGraphic input.
	for (NSInteger index = (NSInteger)layer->operation_count - 1;
		index >= 0; --index) {
		NativeCSSFilterOperation operation = layer->operations[index];
		if (operation.kind == 0) {
			CGFloat spread = MAX(0.0, operation.first * layer->scale * 3.0);
			extent.rect = CGRectInset(extent.rect, -spread, -spread);
		} else if (operation.kind == 1) {
			CGFloat spread = MAX(0.0, operation.third * layer->scale * 3.0);
			CGRect shadow = CGRectOffset(CGRectInset(extent.rect, -spread, -spread),
				operation.first * layer->scale, -operation.second * layer->scale);
			extent.rect = CGRectUnion(extent.rect, shadow);
		}
	}
	return extent;
}

static CIImage *native_apply_svg_color_table(CIImage *input,
	NativeSVGFilterNode const *node) {
	static CIKernel *kernel;
	static dispatch_once_t once_token;
	dispatch_once(&once_token, ^{
		kernel = [CIKernel kernelWithString:
			@"kernel vec4 svgColorTable(sampler source, sampler lookup) { "
			 "vec4 value = unpremultiply(sample(source, samplerCoord(source))); "
			 "float r = sample(lookup, vec2(floor(clamp(value.r * 255.0, 0.0, 255.0) + 0.5) + 0.5, 0.5)).r; "
			 "float g = sample(lookup, vec2(floor(clamp(value.g * 255.0, 0.0, 255.0) + 0.5) + 0.5, 1.5)).r; "
			 "float b = sample(lookup, vec2(floor(clamp(value.b * 255.0, 0.0, 255.0) + 0.5) + 0.5, 2.5)).r; "
			 "float a = sample(lookup, vec2(floor(clamp(value.a * 255.0, 0.0, 255.0) + 0.5) + 0.5, 3.5)).r; "
			 "return premultiply(vec4(r, g, b, a)); }"];
	});
	if (kernel == nil) {
		return input;
	}
	NSMutableData *table_data = [NSMutableData dataWithLength:256 * 4 * 4];
	unsigned char *pixels = table_data.mutableBytes;
	for (int channel = 0; channel < 4; ++channel) {
		for (int value = 0; value < 256; ++value) {
			unsigned char mapped = node->color_tables[channel] != NULL
				? node->color_tables[channel][value] : (unsigned char)value;
			size_t offset = ((size_t)channel * 256 + (size_t)value) * 4;
			pixels[offset] = mapped;
			pixels[offset + 1] = mapped;
			pixels[offset + 2] = mapped;
			pixels[offset + 3] = 255;
		}
	}
	CIImage *lookup = [CIImage imageWithBitmapData:table_data bytesPerRow:256 * 4
		size:CGSizeMake(256, 4) format:kCIFormatRGBA8 colorSpace:nil];
	CGRect lookup_extent = lookup.extent;
	CIImage *mapped = [kernel applyWithExtent:input.extent
		roiCallback:^CGRect(int input_index, CGRect destination) {
			return input_index == 0 ? destination : lookup_extent;
		}
		arguments:@[ input, lookup ]];
	if (mapped == nil) {
		return input;
	}
	return mapped;
}

static CIVector *native_svg_channel_selector(int channel) {
	switch (channel) {
	case 0: return [CIVector vectorWithX:1 Y:0 Z:0 W:0];
	case 1: return [CIVector vectorWithX:0 Y:1 Z:0 W:0];
	case 2: return [CIVector vectorWithX:0 Y:0 Z:1 W:0];
	default: return [CIVector vectorWithX:0 Y:0 Z:0 W:1];
	}
}

static CIImage *native_apply_svg_displacement(CIImage *color,
	CIImage *displacement, NativeSVGFilterNode const *node, CGFloat scale) {
	static CIKernel *kernel;
	static dispatch_once_t once_token;
	dispatch_once(&once_token, ^{
		kernel = [CIKernel kernelWithString:
			@"kernel vec4 svgDisplacement(sampler color, sampler displacement, "
			 "float amount, vec4 xSelector, vec4 ySelector) { "
			 "vec2 destination = destCoord(); "
			 "vec4 map = unpremultiply(sample(displacement, "
			 "samplerTransform(displacement, destination))); "
			 "float dx = amount * (dot(map, xSelector) - 0.5); "
			 "float dy = amount * (dot(map, ySelector) - 0.5); "
			 "return sample(color, samplerTransform(color, "
			 "destination + vec2(dx, -dy))); }"];
	});
	if (kernel == nil || scale == 0.0) {
		return color;
	}
	CGFloat reach = fabs(scale) * 0.5;
	return [kernel applyWithExtent:CGRectInset(color.extent, -reach, -reach)
		roiCallback:^CGRect(int input_index, CGRect destination) {
			return input_index == 0 ? CGRectInset(destination, -reach, -reach)
				: destination;
		}
		arguments:@[ color, displacement, @(scale),
			native_svg_channel_selector(node->x_channel),
			native_svg_channel_selector(node->y_channel) ]] ?: color;
}

typedef struct {
	uint8_t permutation[256];
	double gradient[4][256][2];
} NativeSVGTurbulenceData;

static int native_svg_turbulence_random(int *seed) {
	static int const amplitude = 16807;
	static int const quotient = 127773;
	static int const remainder = 2836;
	int64_t result = (int64_t)amplitude * (*seed % quotient)
		- (int64_t)remainder * (*seed / quotient);
	if (result <= 0) {
		result += 2147483647;
	}
	*seed = (int)result;
	return *seed;
}

static void native_svg_initialize_turbulence(NativeSVGTurbulenceData *data,
	double seed_value) {
	static int const random_maximum = 2147483647;
	int seed;
	if (!isfinite(seed_value) || seed_value >= random_maximum - 1) {
		seed = random_maximum - 1;
	} else if (seed_value <= INT32_MIN) {
		seed = INT32_MIN;
	} else {
		seed = (int)trunc(seed_value);
	}
	if (seed <= 0) {
		seed = -(seed % (random_maximum - 1)) + 1;
	}
	uint16_t noise[4][256][2];
	for (int channel = 0; channel < 4; ++channel) {
		for (int index = 0; index < 256; ++index) {
			data->permutation[index] = (uint8_t)index;
			noise[channel][index][0] = (uint16_t)(native_svg_turbulence_random(&seed) % 512);
			noise[channel][index][1] = (uint16_t)(native_svg_turbulence_random(&seed) % 512);
		}
	}
	for (int index = 255; index > 0; --index) {
		uint8_t value = data->permutation[index];
		int replacement = native_svg_turbulence_random(&seed) % 256;
		data->permutation[index] = data->permutation[replacement];
		data->permutation[replacement] = value;
	}
	for (int channel = 0; channel < 4; ++channel) {
		for (int index = 0; index < 256; ++index) {
			int selected = data->permutation[index];
			float x = ((float)noise[channel][selected][0] - 256.0f) / 256.0f;
			float y = ((float)noise[channel][selected][1] - 256.0f) / 256.0f;
			float length = hypotf(x, y);
			if (length == 0.0) {
				x = 1.0f;
				y = 0.0f;
				length = 1.0f;
			}
			uint16_t encoded_x = (uint16_t)lrintf((x / length + 1.0f) * 32767.5f);
			uint16_t encoded_y = (uint16_t)lrintf((y / length + 1.0f) * 32767.5f);
			data->gradient[channel][index][0] = (double)encoded_x / 32767.5 - 1.0;
			data->gradient[channel][index][1] = (double)encoded_y / 32767.5 - 1.0;
		}
	}
}

static double native_svg_turbulence_lerp(double first, double second,
	double progress) {
	return first + progress * (second - first);
}

static double native_svg_turbulence_noise(NativeSVGTurbulenceData const *data,
	int channel, double x, double y) {
	double floor_x = floor(x);
	double floor_y = floor(y);
	double fraction_x = x - floor_x;
	double fraction_y = y - floor_y;
	int x0 = ((int)floor_x) & 255;
	int x1 = (x0 + 1) & 255;
	int y0 = ((int)floor_y) & 255;
	int y1 = (y0 + 1) & 255;
	int b00 = (data->permutation[x0] + y0) & 255;
	int b10 = (data->permutation[x1] + y0) & 255;
	int b01 = (data->permutation[x0] + y1) & 255;
	int b11 = (data->permutation[x1] + y1) & 255;
	double smooth_x = fraction_x * fraction_x * (3.0 - 2.0 * fraction_x);
	double smooth_y = fraction_y * fraction_y * (3.0 - 2.0 * fraction_y);
	double a = native_svg_turbulence_lerp(
		data->gradient[channel][b00][0] * fraction_x
			+ data->gradient[channel][b00][1] * fraction_y,
		data->gradient[channel][b10][0] * (fraction_x - 1.0)
			+ data->gradient[channel][b10][1] * fraction_y, smooth_x);
	double b = native_svg_turbulence_lerp(
		data->gradient[channel][b01][0] * fraction_x
			+ data->gradient[channel][b01][1] * (fraction_y - 1.0),
		data->gradient[channel][b11][0] * (fraction_x - 1.0)
			+ data->gradient[channel][b11][1] * (fraction_y - 1.0), smooth_x);
	return native_svg_turbulence_lerp(a, b, smooth_y);
}

static CIImage *native_apply_svg_turbulence(CGRect extent,
	NativeSVGFilterNode const *node, CGFloat scale) {
	size_t width = (size_t)MAX(1.0, ceil(extent.size.width));
	size_t height = (size_t)MAX(1.0, ceil(extent.size.height));
	NSMutableData *bitmap = [NSMutableData dataWithLength:width * height * 4];
	uint8_t *pixels = bitmap.mutableBytes;
	double coordinate_scale = scale > 0.0 ? scale : 1.0;
	int octave_count = MAX(0, MIN(255, (int)node->third));
	NativeSVGTurbulenceData data;
	native_svg_initialize_turbulence(&data, node->fourth);
	for (size_t pixel_y = 0; pixel_y < height; ++pixel_y) {
		for (size_t pixel_x = 0; pixel_x < width; ++pixel_x) {
			double coordinate_x = ((double)pixel_x + 0.5)
				/ coordinate_scale * node->first;
			double coordinate_y = ((double)pixel_y + 0.5)
				/ coordinate_scale * node->second;
			double color[4] = { 0, 0, 0, 0 };
			double ratio = 1.0;
			for (int octave = 0; octave < octave_count; ++octave) {
				for (int channel = 0; channel < 4; ++channel) {
					double noise = native_svg_turbulence_noise(&data, channel,
						coordinate_x, coordinate_y);
					color[channel] += (node->mode == 1 ? noise : fabs(noise)) * ratio;
				}
				coordinate_x *= 2.0;
				coordinate_y *= 2.0;
				ratio *= 0.5;
			}
			if (node->mode == 1) {
				for (int channel = 0; channel < 4; ++channel) {
					color[channel] = color[channel] * 0.5 + 0.5;
				}
			}
			double alpha = MIN(1.0, MAX(0.0, color[3]));
			size_t offset = (pixel_y * width + pixel_x) * 4;
			for (int channel = 0; channel < 3; ++channel) {
				double component = MIN(1.0, MAX(0.0, color[channel])) * alpha;
				pixels[offset + channel] = (uint8_t)lrint(component * 255.0);
			}
			pixels[offset + 3] = (uint8_t)lrint(alpha * 255.0);
		}
	}
	CIImage *image = [CIImage imageWithBitmapData:bitmap bytesPerRow:width * 4
		size:CGSizeMake(width, height) format:kCIFormatRGBA8 colorSpace:nil];
	return [image imageByApplyingTransform:CGAffineTransformMakeTranslation(
		extent.origin.x, extent.origin.y)];
}

static CIImage *native_apply_svg_filter_graph(NativeCSSFilterLayer const *layer,
	CIImage *source) {
	if (layer->graph_nodes == NULL || layer->graph_node_count == 0
		|| layer->graph_root_id < 0
		|| (size_t)layer->graph_root_id >= layer->graph_node_count) {
		return source;
	}
	CIImage *__unsafe_unretained *outputs =
		(CIImage *__unsafe_unretained *)calloc(layer->graph_node_count,
			sizeof(CIImage *));
	NativeSVGFilterExtent *output_extents = calloc(layer->graph_node_count,
		sizeof(NativeSVGFilterExtent));
	if (outputs == NULL || output_extents == NULL) {
		free(outputs);
		free(output_extents);
		return source;
	}
	CGRect source_extent = source.extent;
	NativeSVGFilterExtent logical_source_extent =
		native_svg_source_extent(layer, source_extent);
	for (size_t index = 0; index < layer->graph_node_count; ++index) {
		NativeSVGFilterNode const *node = &layer->graph_nodes[index];
		CIImage *first = node->input_count > 0
			? native_svg_filter_input(outputs, layer->graph_node_count,
				 node->inputs[0], source)
			: source;
		NativeSVGFilterExtent first_extent = node->input_count > 0
			? native_svg_filter_input_extent(output_extents,
				layer->graph_node_count, node->inputs[0], logical_source_extent)
			: logical_source_extent;
		switch (node->kind) {
		case 0: { // flood
			// Gfx::Filter::flood() replaces the CSS color's alpha with the
			// primitive opacity via SkColorSetA; it does not multiply them.
			CIColor *color = [CIColor colorWithRed:node->red green:node->green
				blue:node->blue alpha:node->first];
			outputs[index] = [[CIImage imageWithColor:color]
				imageByCroppingToRect:source_extent];
			// SkImageFilters::Shader is unbounded. Downstream Porter-Duff
			// operations constrain it; an unbounded root is cropped to the
			// transparent trigger bounds below.
			output_extents[index] = native_svg_infinite_extent();
			break;
		}
		case 1: { // blend/composite
			CIImage *foreground = node->input_count > 1
				? native_svg_filter_input(outputs, layer->graph_node_count,
					node->inputs[1], source)
				: source;
			outputs[index] = native_apply_svg_blend(first, foreground, node->mode);
			NativeSVGFilterExtent foreground_extent = node->input_count > 1
				? native_svg_filter_input_extent(output_extents,
					layer->graph_node_count, node->inputs[1], logical_source_extent)
				: logical_source_extent;
			if (node->mode == 20) { // SourceIn
				output_extents[index] = native_svg_intersect_extents(first_extent,
					foreground_extent);
			} else if (node->mode == 21 || node->mode == 22) {
				// DestinationOut and SourceAtop retain the background extent.
				output_extents[index] = first_extent;
			} else {
				output_extents[index] = native_svg_union_extents(first_extent,
					foreground_extent);
			}
			break;
		}
		case 2: // component-transfer color table
			outputs[index] = native_apply_svg_color_table(first, node);
			output_extents[index] = first_extent;
			break;
		case 3: { // arithmetic composite
			CIImage *foreground = node->input_count > 1
				? native_svg_filter_input(outputs, layer->graph_node_count,
					node->inputs[1], source)
				: source;
			outputs[index] = native_apply_svg_arithmetic(first, foreground, node);
			NativeSVGFilterExtent foreground_extent = node->input_count > 1
				? native_svg_filter_input_extent(output_extents,
					layer->graph_node_count, node->inputs[1], logical_source_extent)
				: logical_source_extent;
			output_extents[index] = node->fourth != 0.0f
				? native_svg_infinite_extent()
				: native_svg_union_extents(first_extent, foreground_extent);
			break;
		}
		case 4: { // blur
			outputs[index] = native_apply_svg_anisotropic_filter(first,
				@"CIGaussianBlur", node->first * layer->scale,
				node->second * layer->scale);
			output_extents[index] = first_extent;
			if (!first_extent.infinite && first_extent.valid) {
				output_extents[index].rect = CGRectInset(first_extent.rect,
					-MAX(0.0, node->first * layer->scale * 3.0),
					-MAX(0.0, node->second * layer->scale * 3.0));
			}
			break;
		}
		case 5: { // color matrix
			if (node->matrix_count != 20) {
				outputs[index] = first;
				break;
			}
			CGFloat matrix[20];
			for (int value_index = 0; value_index < 20; ++value_index) {
				matrix[value_index] = node->matrix[value_index];
			}
			outputs[index] = native_css_filter_color_matrix(first, matrix);
			output_extents[index] = first_extent;
			break;
		}
		case 6: // saturate
			outputs[index] = native_apply_css_color_filter(first, 5, node->first);
			output_extents[index] = first_extent;
			break;
		case 7: // hue rotate
			outputs[index] = native_apply_css_hue_rotate(first, node->first);
			output_extents[index] = first_extent;
			break;
		case 8: { // merge
			CIImage *merged = nil;
			NativeSVGFilterExtent merged_extent = {};
			for (size_t input_index = 0; input_index < node->input_count; ++input_index) {
				CIImage *input = native_svg_filter_input(outputs,
					layer->graph_node_count, node->inputs[input_index], source);
				merged = merged == nil ? input
					: native_apply_svg_blend(merged, input, 0);
				merged_extent = native_svg_union_extents(merged_extent,
					native_svg_filter_input_extent(output_extents,
						layer->graph_node_count, node->inputs[input_index],
						logical_source_extent));
			}
			outputs[index] = merged == nil ? source : merged;
			output_extents[index] = merged == nil ? logical_source_extent : merged_extent;
			break;
		}
		case 9: // erode
			outputs[index] = native_apply_svg_anisotropic_filter(first,
				@"CIMorphologyMinimum", node->first * layer->scale,
				node->second * layer->scale);
			output_extents[index] = first_extent;
			break;
		case 10: { // dilate
			outputs[index] = native_apply_svg_anisotropic_filter(first,
				@"CIMorphologyMaximum", node->first * layer->scale,
				node->second * layer->scale);
			output_extents[index] = first_extent;
			if (!first_extent.infinite && first_extent.valid) {
				output_extents[index].rect = CGRectInset(first_extent.rect,
					-MAX(0.0, node->first * layer->scale),
					-MAX(0.0, node->second * layer->scale));
			}
			break;
		}
		case 11: // offset
			outputs[index] = native_apply_svg_offset(first, node->first * layer->scale,
				node->second * layer->scale);
			output_extents[index] = first_extent;
			if (!first_extent.infinite && first_extent.valid) {
				output_extents[index].rect = CGRectOffset(first_extent.rect,
					node->first * layer->scale, -node->second * layer->scale);
			}
			break;
		case 12: // turbulence/fractalNoise
			// Skia evaluates the shader in the filtered layer's local surface.
			// Restrict this bitmap to the same retained bounds so browser chrome
			// offsets do not shift the deterministic noise field.
			outputs[index] = native_apply_svg_turbulence(
				layer->has_graph_bounds ? layer->graph_bounds : source_extent,
				node, layer->scale);
			output_extents[index] = native_svg_infinite_extent();
			break;
		case 13: { // displacement-map
			CIImage *displacement = node->input_count > 1
				? native_svg_filter_input(outputs, layer->graph_node_count,
					node->inputs[1], source)
				: source;
			outputs[index] = native_apply_svg_displacement(first, displacement,
				node, node->first * layer->scale);
			output_extents[index] = first_extent;
			if (!first_extent.infinite && first_extent.valid) {
				CGFloat spread = fabs(node->first * layer->scale) * 0.5;
				output_extents[index].rect = CGRectInset(first_extent.rect,
					-spread, -spread);
			}
			break;
		}
		case 14: // interpolation color-space conversion
			outputs[index] = [first imageByApplyingFilter:node->first != 0.0f
				? @"CISRGBToneCurveToLinear" : @"CILinearToSRGBToneCurve"];
			output_extents[index] = first_extent;
			break;
		case 15: { // decoded image frame
			if (node->image == NULL) {
				// SVGFEImageElement is skipped while its resource is unavailable.
				// The retained input is the graph result from before this primitive.
				outputs[index] = first;
				output_extents[index] = first_extent;
				break;
			}
			CGRect destination = layer->has_graph_bounds
				? layer->graph_bounds : source_extent;
			CGFloat width = (CGFloat)CGImageGetWidth(node->image);
			CGFloat height = (CGFloat)CGImageGetHeight(node->image);
			if (width <= 0.0 || height <= 0.0 || CGRectIsEmpty(destination)) {
				outputs[index] = first;
				output_extents[index] = first_extent;
				break;
			}
			CIImage *decoded = [CIImage imageWithCGImage:node->image];
			CGAffineTransform fit = CGAffineTransformMake(
				destination.size.width / width, 0, 0,
				-destination.size.height / height, destination.origin.x,
				destination.origin.y + destination.size.height);
			outputs[index] = [[decoded imageByApplyingTransform:fit]
				imageByCroppingToRect:destination];
			output_extents[index] = native_svg_finite_extent(destination);
			break;
		}
		default:
			outputs[index] = first;
			output_extents[index] = first_extent;
			break;
		}
	}
	CIImage *result = outputs[layer->graph_root_id] ?: source;
	NativeSVGFilterExtent result_extent = output_extents[layer->graph_root_id];
	CGRect crop = result_extent.infinite
		? (layer->has_graph_bounds ? layer->graph_bounds : source_extent)
		: result_extent.rect;
	if (!result_extent.valid) {
		crop = layer->has_graph_bounds ? layer->graph_bounds : source_extent;
	}
	crop = CGRectIntersection(crop, source_extent);
	if (!CGRectIsNull(crop) && !CGRectIsEmpty(crop)) {
		result = [result imageByCroppingToRect:crop];
	}
	free(outputs);
	free(output_extents);
	return result;
}

static void native_free_svg_filter_graph(NativeCSSFilterLayer *layer) {
	for (size_t index = 0; index < layer->graph_node_count; ++index) {
		NativeSVGFilterNode *node = &layer->graph_nodes[index];
		free(node->inputs);
		for (int channel = 0; channel < 4; ++channel) {
			free(node->color_tables[channel]);
		}
		if (node->image != NULL) {
			CGImageRelease(node->image);
		}
	}
	free(layer->graph_nodes);
	layer->graph_nodes = NULL;
	layer->graph_node_count = 0;
}

// Fresh page rasters are not reusable CGImage resources. Core Image's CGImage
// import retains IOSurface mappings for each new image, even after its context
// clears its caches. Import owned, immutable bitmap bytes instead, preserving
// the native premultiplied format and color space. Other formats keep their
// ordinary Core Image decoder.
static CIImage *native_css_filter_source_image(CGImageRef image) {
	CIFormat format = 0;
	CGBitmapInfo order = CGImageGetBitmapInfo(image) & kCGBitmapByteOrderMask;
	CGImageAlphaInfo alpha = CGImageGetAlphaInfo(image);
	if (CGImageGetBitsPerComponent(image) == 8 && CGImageGetBitsPerPixel(image) == 32) {
		if (alpha == kCGImageAlphaPremultipliedLast && order == kCGBitmapByteOrder32Big)
			format = kCIFormatRGBA8;
		else if (alpha == kCGImageAlphaPremultipliedFirst && order == kCGBitmapByteOrder32Little)
			format = kCIFormatBGRA8;
	}
	size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
	size_t pitch = CGImageGetBytesPerRow(image);
	if (format && !CGImageGetDecode(image) && height && pitch && height <= SIZE_MAX / pitch) {
		BOOL timing = getenv("VOX_CSS_FILTER_STAGE_TIMES") != NULL;
		double started = timing ? CACurrentMediaTime() : 0;
		CFDataRef bytes = CGDataProviderCopyData(CGImageGetDataProvider(image));
		if (timing) fprintf(stderr,
            "VOX_CSS_FILTER_SOURCE width=%zu height=%zu pitch=%zu provider_bytes=%ld copy_us=%.3f\n",
            width, height, pitch, bytes ? (long)CFDataGetLength(bytes) : -1L,
            (CACurrentMediaTime() - started) * 1e6);
		if (bytes && (size_t)CFDataGetLength(bytes) == height * pitch) {
			CIImage *source = [CIImage imageWithBitmapData:(__bridge NSData *)bytes
				bytesPerRow:pitch size:CGSizeMake(width, height) format:format
				colorSpace:CGImageGetColorSpace(image)];
			CFRelease(bytes);
			return source;
		}
		if (bytes) CFRelease(bytes);
	}
	return [CIImage imageWithCGImage:image];
}

static CIImage *native_apply_css_filter_layer(NativeCSSFilterLayer const *layer,
	CGImageRef source_image) {
	CIImage *output = native_css_filter_source_image(source_image);
	for (NSInteger index = (NSInteger)layer->operation_count - 1;
		index >= 0; --index) {
		NativeCSSFilterOperation operation = layer->operations[index];
		switch (operation.kind) {
		case 0:
			output = native_apply_css_blur(output, operation.first * layer->scale);
			break;
		case 1:
			output = native_apply_css_drop_shadow(output, operation, layer->scale);
			break;
		case 2:
			output = native_apply_css_color_filter(output, (int)operation.second,
				operation.first);
			break;
		case 3:
			output = native_apply_css_hue_rotate(output, operation.first);
			break;
		default:
			break;
		}
	}
	return native_apply_svg_filter_graph(layer, output);
}

#ifdef VOX_TEST_CROPPED_CSS_FILTERS
static int native_test_cropped_css_filters;
#endif

// Color filters map each pixel on its own, and keep transparent pixels
// transparent. Core Image renders, and the destination composites, only the
// part of the layer its clip can show: a scrolled strip need not filter and
// blend the whole canvas. The crop keeps whole device pixels of an image that
// maps one to one onto the destination, so every visible pixel is unchanged.
static BOOL native_css_filter_has_pointwise_device_mapping(NativeCSSFilterLayer const *layer,
	CGRect source_rect) {
	const char *disabled = getenv("VOX_DISABLE_CROPPED_CSS_FILTERS");
	if ((disabled && disabled[0] && strcmp(disabled, "0") != 0)
		|| layer->destination == NULL || layer->graph_node_count != 0
		|| layer->operation_count == 0 || layer->copies_to_fresh_frame
		|| layer->borrows_fresh_frame || !(layer->scale >= 1)
		|| layer->scale != floor(layer->scale)
		|| layer->canvas_width * layer->scale != source_rect.size.width
		|| layer->canvas_height * layer->scale != source_rect.size.height)
		return NO;
	for (size_t index = 0; index < layer->operation_count; ++index) {
		int kind = layer->operations[index].kind;
		if (kind != 2 && kind != 3) return NO;
	}
	CGAffineTransform ctm = CGContextGetCTM(layer->destination);
	if (ctm.a != layer->scale || ctm.d != layer->scale || ctm.b != 0 || ctm.c != 0
		|| ctm.tx != floor(ctm.tx) || ctm.ty != floor(ctm.ty)) return NO;
	return YES;
}

static CGRect native_css_filter_output_rect(NativeCSSFilterLayer const *layer,
	CGRect source_rect) {
	if (!native_css_filter_has_pointwise_device_mapping(layer, source_rect)) return source_rect;
	CGRect clip = CGContextGetClipBoundingBox(layer->destination);
	if (CGRectIsNull(clip) || CGRectIsInfinite(clip) || CGRectIsEmpty(clip)
		|| !isfinite(CGRectGetMinX(clip)) || !isfinite(CGRectGetMaxX(clip))
		|| !isfinite(CGRectGetMinY(clip)) || !isfinite(CGRectGetMaxY(clip)))
		return source_rect;
	if (layer->has_pointwise_output_bounds) {
		clip = CGRectIntersection(clip, layer->pointwise_output_bounds);
		if (CGRectIsNull(clip) || CGRectIsEmpty(clip)) return source_rect;
	}
	CGFloat left = floor(CGRectGetMinX(clip) * layer->scale) - 2;
	CGFloat bottom = floor(CGRectGetMinY(clip) * layer->scale) - 2;
	CGFloat right = ceil(CGRectGetMaxX(clip) * layer->scale) + 2;
	CGFloat top = ceil(CGRectGetMaxY(clip) * layer->scale) + 2;
	CGRect pixels = CGRectIntersection(CGRectMake(left, bottom, right - left, top - bottom),
		source_rect);
	if (CGRectIsNull(pixels) || CGRectIsEmpty(pixels)
		|| CGRectEqualToRect(pixels, source_rect)) return source_rect;
#ifdef VOX_TEST_CROPPED_CSS_FILTERS
	native_test_cropped_css_filters++;
#endif
	return pixels;
}

// The current scroll-damage plan bounds the complete filtered group's output.
// Pointwise filters cannot move ink outside that bound. Keep an additional
// CSS-pixel fringe here, then the usual device-pixel crop guard above.
void native_bound_pointwise_filter_output(double x, double y, double width, double height) {
	if (!getenv("VOX_BOUND_POINTWISE_FILTER_OUTPUTS") || native_css_filter_overflow_depth
		|| !native_css_filter_stack_depth) return;
	NativeCSSFilterLayer *layer = &native_css_filter_stack[native_css_filter_stack_depth - 1];
	if (!layer->active || !isfinite(x) || !isfinite(y) || !isfinite(width) || !isfinite(height)
		|| width <= 0 || height <= 0 || fabs(x) > 1000000 || fabs(y) > 1000000
		|| width > 1000000 || height > 1000000
		|| !native_css_filter_has_pointwise_device_mapping(layer,
			CGRectMake(0, 0, layer->canvas_width * layer->scale, layer->canvas_height * layer->scale))) return;
	for (size_t index = 0; index < layer->operation_count; ++index)
		if (!isfinite(layer->operations[index].first) || !isfinite(layer->operations[index].second)) return;
	layer->pointwise_output_bounds = CGRectInset(
		CGRectMake(x, layer->canvas_height - y - height, width, height), -3, -3);
	layer->has_pointwise_output_bounds = 1;
}

#include "native/include/native_opacity_group_darwin.h"

// Diagnostic only: verify retained geometry against the completed input's
// actual alpha coverage. This scan is excluded from unprofiled timing arms.
static void native_verify_pointwise_filter_output_bounds(NativeCSSFilterLayer *layer) {
	if (!layer->has_pointwise_output_bounds || !getenv("VOX_BOUNDED_POINTWISE_FILTER_VERIFY")) return;
	size_t width = CGBitmapContextGetWidth(layer->context), height = CGBitmapContextGetHeight(layer->context);
	size_t pitch = CGBitmapContextGetBytesPerRow(layer->context);
	const uint8_t *pixels = CGBitmapContextGetData(layer->context);
	BOOL valid = pixels && width && height && width <= SIZE_MAX / 4 && pitch >= width * 4
		&& CGBitmapContextGetBitsPerComponent(layer->context) == 8
		&& CGBitmapContextGetBitsPerPixel(layer->context) == 32;
	if (valid) {
		CGContextFlush(layer->context);
		CGRect whole = CGRectMake(0, 0, width, height);
		CGRect bounded = native_css_filter_output_rect(layer, whole);
		NativeCSSFilterLayer reference = *layer;
		reference.has_pointwise_output_bounds = 0;
		CGRect original = native_css_filter_output_rect(&reference, whole);
		int left, top, right, bottom;
		int found = native_opacity_layer_ink_bounds(pixels, pitch, original.origin.x,
			height - CGRectGetMaxY(original), CGRectGetMaxX(original), height - original.origin.y,
			&left, &top, &right, &bottom);
		valid = !found || CGRectContainsRect(bounded, CGRectMake(left, height - bottom, right - left, bottom - top));
	}
	fprintf(stderr, "VOX_BOUNDED_POINTWISE_VERIFY valid=%d\n", valid);
	if (!valid) layer->has_pointwise_output_bounds = 0;
}

#ifdef VOX_TEST_EMPTY_BOUNDED_POINTWISE_FILTERS
static unsigned native_test_empty_bounded_pointwise_filters;
#endif

// An empty intersection is a completed no-op, not a request to fall back to
// filtering the full canvas. The retained group bounds already include three
// CSS pixels of rounding guard; also preserve the usual two-device-pixel clip
// fringe before proving that none of its output can reach the destination.
static BOOL native_css_filter_bounded_output_is_empty(NativeCSSFilterLayer const *layer) {
    if (getenv("VOX_DISABLE_EMPTY_BOUNDED_POINTWISE_FILTERS")
        || !layer->active || !layer->has_pointwise_output_bounds
        || layer->svg_filter_recording || layer->gradient_blur_recording
        || !native_css_filter_has_pointwise_device_mapping(layer,
            CGRectMake(0, 0, layer->canvas_width * layer->scale,
                layer->canvas_height * layer->scale))) return NO;
    CGRect clip = CGContextGetClipBoundingBox(layer->destination);
    // Quartz reports a null rectangle when intersected damage clips are
    // empty. That is also a no-op, rather than an unknown/unbounded clip.
    if (!CGRectIsNull(clip) && !CGRectIsEmpty(clip)) {
        if (CGRectIsInfinite(clip)
            || !isfinite(CGRectGetMinX(clip)) || !isfinite(CGRectGetMaxX(clip))
            || !isfinite(CGRectGetMinY(clip)) || !isfinite(CGRectGetMaxY(clip))) return NO;
        clip = CGRectInset(clip, -2 / layer->scale, -2 / layer->scale);
        if (CGRectIntersectsRect(clip, layer->pointwise_output_bounds)) return NO;
    }
#ifdef VOX_TEST_EMPTY_BOUNDED_POINTWISE_FILTERS
    ++native_test_empty_bounded_pointwise_filters;
#endif
    if (getenv("VOX_EMPTY_BOUNDED_POINTWISE_FILTER_DIAGNOSTICS"))
        fprintf(stderr, "VOX_EMPTY_BOUNDED_POINTWISE_FILTER operations=%zu\n", layer->operation_count);
    return YES;
}

#ifdef VOX_TEST_EMPTY_POINTWISE_FILTERS
static unsigned native_test_empty_pointwise_filters;
#endif

// Pointwise filters preserve zero alpha. If every source pixel that can reach
// the destination clip is transparent, filtering and source-over publication
// cannot change that destination. Include the ordinary crop's guard pixels;
// blur, shadows, SVG graphs and non-integral mappings retain ordinary replay.
static BOOL native_css_filter_visible_input_is_empty(NativeCSSFilterLayer const *layer) {
    if (!getenv("VOX_SKIP_EMPTY_POINTWISE_FILTERS") || !layer->active || !layer->context
        || layer->svg_filter_recording || layer->gradient_blur_recording) return NO;
    CGContextRef context = layer->context;
    size_t width = CGBitmapContextGetWidth(context), height = CGBitmapContextGetHeight(context);
    size_t pitch = CGBitmapContextGetBytesPerRow(context);
    CGBitmapInfo info = CGBitmapContextGetBitmapInfo(context);
    if (!width || !height || width > INT_MAX || height > INT_MAX
        || width > SIZE_MAX / 4 || pitch < width * 4 || pitch > 64 * 1024 * 1024 / height
        || CGBitmapContextGetBitsPerComponent(context) != 8
        || CGBitmapContextGetBitsPerPixel(context) != 32
        || (info != (kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big)
            && info != (kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little))) return NO;
    CGRect whole = CGRectMake(0, 0, width, height);
    if (!native_css_filter_has_pointwise_device_mapping(layer, whole)) return NO;
    for (size_t index = 0; index < layer->operation_count; ++index) {
        NativeCSSFilterOperation operation = layer->operations[index];
        if (!isfinite(operation.first) || !isfinite(operation.second)) return NO;
    }
    CGContextFlush(context);
    const uint8_t *pixels = CGBitmapContextGetData(context);
    if (!pixels) return NO;
    CGRect rect = native_css_filter_output_rect(layer, whole);
    size_t left = rect.origin.x, right = CGRectGetMaxX(rect);
    size_t top = height - CGRectGetMaxY(rect), bottom = height - rect.origin.y;
    for (size_t y = top; y < bottom; ++y) {
        const uint32_t *row = (const uint32_t *)(pixels + y * pitch);
        size_t x = left;
#if defined(__aarch64__) && !defined(VOX_OPACITY_DISABLE_NEON)
        for (; right - x >= 16; x += 16) {
            uint32x4x4_t block = vld1q_u32_x4(row + x);
            uint32x4_t ink = vorrq_u32(vorrq_u32(block.val[0], block.val[1]),
                vorrq_u32(block.val[2], block.val[3]));
            if (vmaxvq_u32(ink)) return NO;
        }
#endif
        for (; x < right; ++x) if (row[x]) return NO;
    }
#ifdef VOX_TEST_EMPTY_POINTWISE_FILTERS
    ++native_test_empty_pointwise_filters;
#endif
    if (getenv("VOX_EMPTY_POINTWISE_FILTER_DIAGNOSTICS"))
        fprintf(stderr, "VOX_EMPTY_POINTWISE_FILTER width=%.0f height=%.0f operations=%zu\n",
            rect.size.width, rect.size.height, layer->operation_count);
    return YES;
}

#ifdef VOX_TEST_SOFTWARE_POINTWISE_FILTERS
static unsigned native_test_software_pointwise_filters;
#endif

// Small owned inputs need little arithmetic but a GPU submission still waits
// for the queue. Keep Core Image's existing filter graph and color management,
// selecting its software renderer only for bounded pointwise images.
static CIContext *native_css_filter_render_context(NativeCSSFilterLayer const *layer,
    CGImageRef input) {
    native_initialize_css_filter_renderer();
    size_t width = input ? CGImageGetWidth(input) : 0;
    size_t height = input ? CGImageGetHeight(input) : 0;
    BOOL software = getenv("VOX_SOFTWARE_POINTWISE_FILTERS") && input && width && height
        && width <= 262144 / height && layer->operation_count && layer->operations
        && !layer->graph_node_count && !layer->borrows_fresh_frame && !layer->copies_to_fresh_frame
        && CGImageGetBitsPerComponent(input) == 8 && CGImageGetBitsPerPixel(input) == 32
        && CGImageGetDecode(input) == NULL;
    for (size_t index = 0; software && index < layer->operation_count; ++index) {
        NativeCSSFilterOperation operation = layer->operations[index];
        software = (operation.kind == 2 || operation.kind == 3)
            && isfinite(operation.first) && isfinite(operation.second);
    }
    if (!software) return native_css_filter_ci_context;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        native_css_filter_software_context = [CIContext contextWithOptions:@{
            kCIContextUseSoftwareRenderer: @YES,
            kCIContextWorkingColorSpace: (__bridge id)native_css_filter_color_space,
            kCIContextOutputColorSpace: (__bridge id)native_css_filter_color_space,
        }];
    });
    if (!native_css_filter_software_context) return native_css_filter_ci_context;
#ifdef VOX_TEST_SOFTWARE_POINTWISE_FILTERS
    ++native_test_software_pointwise_filters;
#endif
    if (getenv("VOX_SOFTWARE_POINTWISE_FILTER_DIAGNOSTICS"))
        fprintf(stderr, "VOX_SOFTWARE_POINTWISE_FILTER width=%zu height=%zu operations=%zu\n",
            width, height, layer->operation_count);
    return native_css_filter_software_context;
}

static CGImageRef native_render_css_filter_image(NativeCSSFilterLayer const *layer,
    CGImageRef input, CGRect bounds, BOOL allow_software) {
    BOOL timing = getenv("VOX_CSS_FILTER_STAGE_TIMES") != NULL;
    double started = timing ? CACurrentMediaTime() : 0;
    native_initialize_css_filter_renderer();
    CIContext *renderer = allow_software
        ? native_css_filter_render_context(layer, input) : native_css_filter_ci_context;
    double selected = timing ? CACurrentMediaTime() : 0;
    CIImage *filtered = native_apply_css_filter_layer(layer, input);
    double applied = timing ? CACurrentMediaTime() : 0;
    CGImageRef image = [renderer createCGImage:filtered fromRect:bounds
        format:kCIFormatRGBA8 colorSpace:native_css_filter_color_space];
    if (timing) fprintf(stderr,
        "VOX_CSS_FILTER_RENDER width=%.0f height=%.0f software=%d context_us=%.3f apply_us=%.3f render_us=%.3f\n",
        bounds.size.width, bounds.size.height, renderer == native_css_filter_software_context,
        (selected - started) * 1e6, (applied - selected) * 1e6,
        (CACurrentMediaTime() - applied) * 1e6);
    if (renderer == native_css_filter_software_context
        && getenv("VOX_SOFTWARE_POINTWISE_FILTER_VERIFY")) {
        CGImageRef reference = [native_css_filter_ci_context createCGImage:filtered
            fromRect:bounds format:kCIFormatRGBA8 colorSpace:native_css_filter_color_space];
        CFDataRef actual = image ? CGDataProviderCopyData(CGImageGetDataProvider(image)) : NULL;
        CFDataRef expected = reference ? CGDataProviderCopyData(CGImageGetDataProvider(reference)) : NULL;
        size_t width = image ? CGImageGetWidth(image) : 0;
        size_t height = image ? CGImageGetHeight(image) : 0;
        size_t pitch = image ? CGImageGetBytesPerRow(image) : 0;
        size_t expected_pitch = reference ? CGImageGetBytesPerRow(reference) : 0;
        BOOL valid = actual && expected && reference
            && width == CGImageGetWidth(reference) && height == CGImageGetHeight(reference)
            && pitch >= width * 4 && expected_pitch >= width * 4
            && CFDataGetLength(actual) >= pitch * height
            && CFDataGetLength(expected) >= expected_pitch * height;
        size_t differing = 0;
        int error = valid ? 0 : -1;
        if (valid) for (size_t y = 0; y < height; ++y)
            for (size_t x = 0; x < width * 4; ++x) {
                int delta = abs(CFDataGetBytePtr(actual)[y * pitch + x]
                    - CFDataGetBytePtr(expected)[y * expected_pitch + x]);
                if (delta) ++differing;
                if (delta > error) error = delta;
            }
        fprintf(stderr, "VOX_SOFTWARE_POINTWISE_VERIFY valid=%d pixels=%zu differing_channels=%zu max_error=%d\n",
            valid, width * height, differing, error);
        if (actual) CFRelease(actual);
        if (expected) CFRelease(expected);
        if (reference) CGImageRelease(reference);
    }
    return image;
}

#ifdef VOX_TEST_GRAYSCALE_IDENTITY
static unsigned native_test_grayscale_identities;
#endif

#ifdef VOX_TEST_COMPACT_CSS_FILTER_INPUT
static unsigned native_test_compact_css_filter_inputs;
#endif

// A cropped CGImage can retain its complete viewport-sized provider. Give
// pointwise filters an independently owned compact input when their visible
// output already qualifies for the established integer-device crop.
static CGImageRef native_compact_css_filter_input(NativeCSSFilterLayer const *layer,
    CGContextRef context, CGRect *output_rect) {
    BOOL tight = (getenv("VOX_TIGHT_CSS_FILTER_INPUT") || getenv("VOX_CACHE_CSS_COLOR_FILTERS")
        || getenv("VOX_GPU_CANVAS_FILTER_LAYERS") || getenv("VOX_GPU_CANVAS_OFFSCREEN_LAYERS")
        || getenv("VOX_SOFTWARE_POINTWISE_FILTERS") || getenv("VOX_SPARSE_CSS_FILTER_INPUTS"))
        && !getenv("VOX_DISABLE_TIGHT_CSS_FILTER_INPUT");
    if ((!getenv("VOX_COMPACT_CSS_FILTER_INPUT") && !tight && !layer->has_pointwise_output_bounds) || getenv("VOX_DISABLE_COMPACT_CSS_FILTER_INPUT")
        || !context || CGBitmapContextGetBitsPerComponent(context) != 8
        || CGBitmapContextGetBitsPerPixel(context) != 32) return NULL;
    CGBitmapInfo info = CGBitmapContextGetBitmapInfo(context);
    if (info != (kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big)
        && info != (kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little)) return NULL;
    size_t width = CGBitmapContextGetWidth(context), height = CGBitmapContextGetHeight(context);
    size_t source_pitch = CGBitmapContextGetBytesPerRow(context);
    if (!width || !height || width > SIZE_MAX / 4 || source_pitch < width * 4
        || source_pitch > 64 * 1024 * 1024 / height) return NULL;
    CGRect whole = CGRectMake(0, 0, width, height);
    CGRect rect = native_css_filter_output_rect(layer, whole);
    if (layer->has_pointwise_output_bounds && getenv("VOX_BOUNDED_POINTWISE_FILTER_DIAGNOSTICS"))
        fprintf(stderr, "VOX_BOUNDED_POINTWISE_FILTER source=%.0fx%.0f output=%.0fx%.0f\n",
            whole.size.width, whole.size.height, rect.size.width, rect.size.height);
    if (tight && !native_css_filter_has_pointwise_device_mapping(layer, whole)) return NULL;
    if (!tight && CGRectEqualToRect(rect, whole)) return NULL;
    CGContextFlush(context);
    const uint8_t *source = CGBitmapContextGetData(context);
    CGColorSpaceRef color = CGBitmapContextGetColorSpace(context);
    if (!source || !color) return NULL;
    if (tight) {
        int left, top, right, bottom;
        BOOL sparse = layer->sparse_input_pixels == source && layer->context == context;
        int found = sparse ? native_opacity_canvas_ink_bounds(
                (VoxOpacityCanvas){context, layer->sparse_input_pixels}, source_pitch,
                (int)rect.origin.x, (int)(height-CGRectGetMaxY(rect)),
                (int)CGRectGetMaxX(rect), (int)(height-rect.origin.y), &left,&top,&right,&bottom)
            : native_opacity_layer_ink_bounds(source,source_pitch,(int)rect.origin.x,
                (int)(height-CGRectGetMaxY(rect)),(int)CGRectGetMaxX(rect),
                (int)(height-rect.origin.y),&left,&top,&right,&bottom);
        if (sparse && getenv("VOX_SPARSE_CSS_FILTER_INPUT_DIAGNOSTICS"))
            fprintf(stderr, "VOX_SPARSE_CSS_FILTER_INPUT source_bytes=%zu found=%d\n",
                source_pitch * height, found);
        if (!found) {
            left=(int)rect.origin.x; top=(int)(height-CGRectGetMaxY(rect));
            right=left+1; bottom=top+1;
        }
        rect=CGRectMake(left,height-bottom,right-left,bottom-top);
        if (CGRectEqualToRect(rect,whole)) return NULL;
    }
    size_t left = rect.origin.x, top = height - CGRectGetMaxY(rect);
    size_t copy_width = rect.size.width, copy_height = rect.size.height, pitch = copy_width * 4;
    CFMutableDataRef data = CFDataCreateMutable(NULL, pitch * copy_height);
    if (!data) return NULL;
    CFDataSetLength(data, pitch * copy_height);
    uint8_t *pixels = CFDataGetMutableBytePtr(data);
    for (size_t row = 0; row < copy_height; ++row)
        memcpy(pixels + row * pitch, source + (top + row) * source_pitch + left * 4, pitch);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGImageRef image = provider ? CGImageCreate(copy_width, copy_height, 8, 32, pitch,
        color, info, provider, NULL, true, kCGRenderingIntentDefault) : NULL;
    if (provider) CGDataProviderRelease(provider);
    CFRelease(data);
    if (image) {
        *output_rect = rect;
#ifdef VOX_TEST_COMPACT_CSS_FILTER_INPUT
        ++native_test_compact_css_filter_inputs;
#endif
        if (getenv("VOX_COMPACT_CSS_FILTER_INPUT_DIAGNOSTICS"))
            fprintf(stderr, "Vox compact CSS filter input: source_bytes=%zu compact_bytes=%zu\n",
                source_pitch * height, pitch * copy_height);
    }
    return image;
}

// Both grayscale paths require addressable premultiplied sRGB bitmap rows.
typedef struct {
    uint8_t *pixels;
    size_t pitch, left, top, width, height;
    BOOL bgra;
    double amount;
    CGRect rect;
} NativeGrayscaleBitmap;

static BOOL native_css_grayscale_bitmap(NativeCSSFilterLayer const *layer,
    CGContextRef context, NativeGrayscaleBitmap *bitmap) {
    if (!context || !layer->operation_count || layer->graph_node_count) return NO;
    double inverse = 1;
    for (size_t index = 0; index < layer->operation_count; ++index) {
        NativeCSSFilterOperation operation = layer->operations[index];
        if (operation.kind != 2 || operation.second != 2 || !isfinite(operation.first)
            || operation.first < 0 || operation.first > 1) return NO;
        inverse *= 1 - operation.first;
    }
    CGBitmapInfo info = CGBitmapContextGetBitmapInfo(context);
    BOOL rgba = info == (kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    BOOL bgra = info == (kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    size_t width = CGBitmapContextGetWidth(context), height = CGBitmapContextGetHeight(context);
    size_t pitch = CGBitmapContextGetBytesPerRow(context);
    if ((!rgba && !bgra) || CGBitmapContextGetBitsPerComponent(context) != 8
        || CGBitmapContextGetBitsPerPixel(context) != 32
        || !width || !height || width > SIZE_MAX / 4 || pitch < width * 4
        || pitch > 64 * 1024 * 1024 / height) return NO;
    static CGColorSpaceRef srgb;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB); });
    if (!srgb || !CGBitmapContextGetColorSpace(context)
        || !CFEqual(srgb, CGBitmapContextGetColorSpace(context))) return NO;
    CGContextFlush(context);
    uint8_t *pixels = CGBitmapContextGetData(context);
    if (!pixels) return NO;
    // Inspect the live bitmap before its context is consumed by the image.
    // A cropped CGImage may expose its parent's provider rather than an
    // addressable crop; scanning these rows needs no provider-sized copy.
    CGRect rect = native_css_filter_output_rect(layer, CGRectMake(0, 0, width, height));
    size_t left = rect.origin.x, top = height - CGRectGetMaxY(rect);
    size_t scan_width = rect.size.width, scan_height = rect.size.height;
    *bitmap = (NativeGrayscaleBitmap){pixels, pitch, left, top, scan_width, scan_height,
        bgra, 1 - inverse, rect};
    return YES;
}

static BOOL native_css_grayscale_is_identity(NativeCSSFilterLayer const *layer,
    CGContextRef context, CGRect *output_rect) {
    if (!getenv("VOX_ENABLE_GRAYSCALE_IDENTITY") || getenv("VOX_DISABLE_GRAYSCALE_IDENTITY")) return NO;
    NativeGrayscaleBitmap bitmap;
    if (!native_css_grayscale_bitmap(layer, context, &bitmap)) return NO;
    *output_rect = bitmap.rect;
    BOOL identity = YES;
    for (size_t y = 0; identity && y < bitmap.height; ++y) {
        const uint8_t *row = bitmap.pixels + (bitmap.top + y) * bitmap.pitch + bitmap.left * 4;
        for (size_t x = 0; x < bitmap.width; ++x) {
            const uint8_t *p = row + x * 4;
            if (p[0] != p[1] || p[1] != p[2]) { identity = NO; break; }
        }
    }
#ifdef VOX_TEST_GRAYSCALE_IDENTITY
    if (identity) ++native_test_grayscale_identities;
#endif
    if (getenv("VOX_GRAYSCALE_IDENTITY_DIAGNOSTICS"))
        fprintf(stderr, "Vox grayscale identity: context_rows accepted=%d size=%zux%zu\n", identity, bitmap.width, bitmap.height);
    return identity;
}

// A grayscale matrix is homogeneous, so it acts directly on premultiplied
// sRGB bytes. Fuse a grayscale-only chain before quantizing, preserving alpha
// and neutral pixels. Other formats, profiles and filter chains keep Core Image.
static CGImageRef native_css_filter_grayscale_rows(NativeCSSFilterLayer const *layer,
    CGContextRef context, CGRect *output_rect) {
    if (!getenv("VOX_ENABLE_CPU_GRAYSCALE_FILTERS") || getenv("VOX_DISABLE_CPU_GRAYSCALE_FILTERS")) return NULL;
    NativeGrayscaleBitmap bitmap;
    if (!native_css_grayscale_bitmap(layer, context, &bitmap)) return NULL;
    // Isolated filters commonly contain a small logo on a transparent viewport.
    // Trim zero pixels only for the same integer device mapping as the ordinary
    // clip crop. Whole-frame copy/borrow publication retains its full extent.
    CGAffineTransform ctm = layer->destination ? CGContextGetCTM(layer->destination) : CGAffineTransformIdentity;
    if (layer->destination && !layer->copies_to_fresh_frame && !layer->borrows_fresh_frame
        && layer->scale >= 1 && layer->scale == floor(layer->scale)
        && layer->canvas_width * layer->scale == CGBitmapContextGetWidth(context)
        && layer->canvas_height * layer->scale == CGBitmapContextGetHeight(context)
        && ctm.a == layer->scale && ctm.d == layer->scale && ctm.b == 0 && ctm.c == 0
        && ctm.tx == floor(ctm.tx) && ctm.ty == floor(ctm.ty)) {
        int left, top, right, bottom;
        if (!native_opacity_layer_ink_bounds(bitmap.pixels, bitmap.pitch, (int)bitmap.left,
                (int)bitmap.top, (int)(bitmap.left + bitmap.width), (int)(bitmap.top + bitmap.height),
                &left, &top, &right, &bottom)) {
            left = (int)bitmap.left; top = (int)bitmap.top; right = left + 1; bottom = top + 1;
        }
        bitmap.left = left; bitmap.top = top;
        bitmap.width = right - left; bitmap.height = bottom - top;
        bitmap.rect = CGRectMake(left, CGBitmapContextGetHeight(context) - bottom,
            bitmap.width, bitmap.height);
    }
    // Own a compact output rather than changing the source. Allocation/image
    // failure can then fall back without applying a partial filter twice.
    size_t pitch = bitmap.width * 4;
    CFMutableDataRef data = CFDataCreateMutable(NULL, pitch * bitmap.height);
    if (!data) return NULL;
    CFDataSetLength(data, pitch * bitmap.height);
    uint8_t *pixels = CFDataGetMutableBytePtr(data);
    uint32_t red = (uint32_t)lround(65536 * .2126 * bitmap.amount);
    uint32_t green = (uint32_t)lround(65536 * .7152 * bitmap.amount);
    uint32_t blue = (uint32_t)lround(65536 * .0722 * bitmap.amount);
    uint32_t rr = 65536 - green - blue, gg = 65536 - red - blue, bb = 65536 - red - green;
    for (size_t y = 0; y < bitmap.height; ++y) {
        const uint8_t *row = bitmap.pixels + (bitmap.top + y) * bitmap.pitch + bitmap.left * 4;
        for (size_t x = 0; x < bitmap.width; ++x) {
            const uint8_t *p = row + x * 4;
            uint8_t *out = pixels + y * pitch + x * 4;
            uint32_t r = p[bitmap.bgra ? 2 : 0], g = p[1], b = p[bitmap.bgra ? 0 : 2];
            out[bitmap.bgra ? 2 : 0] = (rr * r + green * g + blue * b + 32768) >> 16;
            out[1] = (red * r + gg * g + blue * b + 32768) >> 16;
            out[bitmap.bgra ? 0 : 2] = (red * r + green * g + bb * b + 32768) >> 16;
            out[3] = p[3];
        }
    }
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGImageRef image = provider ? CGImageCreate(bitmap.width, bitmap.height, 8, 32,
        pitch, CGBitmapContextGetColorSpace(context), CGBitmapContextGetBitmapInfo(context),
        provider, NULL, true, kCGRenderingIntentDefault) : NULL;
    if (provider) CGDataProviderRelease(provider);
    CFRelease(data);
    if (!image) return NULL;
    *output_rect = bitmap.rect;
    if (getenv("VOX_CPU_GRAYSCALE_DIAGNOSTICS"))
        fprintf(stderr, "Vox CPU grayscale: rows=%zux%zu amount=%g\n", bitmap.width, bitmap.height, bitmap.amount);
    return image;
}

#include "native/include/native_css_color_filter_cache_darwin.h"

static int native_try_gpu_css_filter_image(CGContextRef destination, CGImageRef image,
    CGRect target, float canvas_height) {
    return 0;
}

void native_end_css_filter_layer(void) {
	BOOL timing = getenv("VOX_CSS_FILTER_STAGE_TIMES") != NULL;
	double timing_start = timing ? CACurrentMediaTime() : 0;
	if (native_css_filter_overflow_depth > 0) {
		native_css_filter_overflow_depth--;
		return;
	}
	if (native_css_filter_stack_depth <= 0) {
		return;
	}
	NativeCSSFilterLayer layer =
		native_css_filter_stack[--native_css_filter_stack_depth];
    BOOL deferred_color_filter = native_css_filter_has_pointwise_device_mapping(&layer,
        CGRectMake(0, 0, layer.canvas_width * layer.scale, layer.canvas_height * layer.scale));
	if (!layer.active) {
		free(layer.operations);
		native_free_svg_filter_graph(&layer);
		return;
	}
	double timing_access = timing ? CACurrentMediaTime() : 0;
    if (native_css_filter_visible_input_is_empty(&layer)) {
        [NSGraphicsContext restoreGraphicsState];
        CGContextRelease(layer.context);
        free(layer.operations);
        native_free_svg_filter_graph(&layer);
        return;
    }
	if (layer.borrows_fresh_frame && layer.operation_count == 0
		&& layer.graph_node_count == 0) {
		CGContextRestoreGState(layer.context);
		[NSGraphicsContext restoreGraphicsState];
		CGContextRelease(layer.context);
		free(layer.operations);
		native_free_svg_filter_graph(&layer);
		return;
	}
	if (layer.copies_to_fresh_frame && layer.operation_count == 0
		&& layer.graph_node_count == 0
		&& native_layer_copy_document_bitmap(layer.context, layer.destination,
			layer.canvas_width, layer.canvas_height)) {
		[NSGraphicsContext restoreGraphicsState];
		CGContextRelease(layer.context);
		free(layer.operations);
		native_free_svg_filter_graph(&layer);
		return;
	}
    CGRect identity_rect = CGRectNull;
    CGRect compact_rect = CGRectNull;
    native_verify_pointwise_filter_output_bounds(&layer);
    if (native_css_filter_bounded_output_is_empty(&layer)) {
        [NSGraphicsContext restoreGraphicsState];
        CGContextRelease(layer.context);
        free(layer.operations);
        native_free_svg_filter_graph(&layer);
        return;
    }
    CGImageRef compact_input = native_compact_css_filter_input(&layer, layer.context, &compact_rect);
    CGImageRef grayscale_image = native_css_filter_grayscale_rows(&layer, layer.context, &identity_rect);
    BOOL grayscale_identity = !grayscale_image
        && native_css_grayscale_is_identity(&layer, layer.context, &identity_rect);
	double timing_input = timing ? CACurrentMediaTime() : 0;
	CGImageRef source_image;
	if (layer.borrows_fresh_frame) {
		// A filter attached to the enclosing layer still needs an isolated source.
		// Quartz snapshots retain their pixels when the fresh target is cleared.
		source_image = CGBitmapContextCreateImage(layer.context);
		CGContextRestoreGState(layer.context);
		CGContextRelease(layer.context);
	} else {
		source_image = layer.operation_count == 0 && layer.graph_node_count == 0
			? native_take_bitmap_image_for_destination(layer.context, layer.destination)
			: native_take_bitmap_image(layer.context);
	}
	[NSGraphicsContext restoreGraphicsState];
	double timing_source = timing ? CACurrentMediaTime() : 0;
	if (layer.borrows_fresh_frame)
		CGContextClearRect(layer.destination,
			CGRectMake(0, 0, layer.canvas_width, layer.canvas_height));

	if (source_image == NULL) {
		if (compact_input) CGImageRelease(compact_input);
		if (grayscale_image) CGImageRelease(grayscale_image);
		free(layer.operations);
		native_free_svg_filter_graph(&layer);
		return;
	}
	double timing_filter = timing_source, timing_draw = timing_source;
	@autoreleasepool {
		CGRect source_rect = CGRectMake(0, 0,
			CGImageGetWidth(source_image), CGImageGetHeight(source_image));
		CGImageRef filtered_image = NULL;
		CGRect filtered_rect = source_rect;
		if (grayscale_image) {
			filtered_image = grayscale_image;
			filtered_rect = identity_rect;
		} else if (layer.operation_count == 0 && layer.graph_node_count == 0) {
			filtered_image = CGImageRetain(source_image);
		} else {
			filtered_rect = compact_input ? compact_rect
				: CGRectIsNull(identity_rect) ? native_css_filter_output_rect(&layer, source_rect) : identity_rect;
			// The crop's pixels depend on no others, so Core Image reads and
			// filters only them rather than the complete layer.
			CGImageRef cropped_source = compact_input ? CGImageRetain(compact_input)
				: CGRectEqualToRect(filtered_rect, source_rect) ? NULL
				: CGImageCreateWithImageInRect(source_image, CGRectMake(filtered_rect.origin.x,
					source_rect.size.height - CGRectGetMaxY(filtered_rect),
					filtered_rect.size.width, filtered_rect.size.height));
			if (cropped_source == NULL) filtered_rect = source_rect;
			CGImageRef input = cropped_source ? cropped_source : source_image;
			if (grayscale_identity && (cropped_source || CGRectEqualToRect(identity_rect, source_rect))) {
				filtered_image = CGImageRetain(input);
			} else if (compact_input && (filtered_image = native_cached_css_color_filter_image(&layer, input))) {
				// The immutable cached result uses the same Core Image arithmetic.
			} else {
				filtered_image = native_render_css_filter_image(&layer, input,
                    cropped_source ? CGRectMake(0, 0, filtered_rect.size.width,
                        filtered_rect.size.height) : source_rect, compact_input != NULL);
			}
			if (cropped_source) CGImageRelease(cropped_source);
		}
		timing_filter = timing ? CACurrentMediaTime() : 0;
		if (filtered_image != NULL && layer.destination != NULL) {
			CGRect target = CGRectEqualToRect(filtered_rect, source_rect)
				? CGRectMake(0, 0, layer.canvas_width, layer.canvas_height)
				: CGRectMake(filtered_rect.origin.x / layer.scale,
					filtered_rect.origin.y / layer.scale,
					filtered_rect.size.width / layer.scale,
					filtered_rect.size.height / layer.scale);
            int gpu_result = deferred_color_filter
                ? native_try_gpu_css_filter_image(layer.destination, filtered_image, target, layer.canvas_height) : 0;
            if (gpu_result != 1) {
                native_layer_draw_document_image(layer.destination, target,
                    filtered_image, layer.copies_to_fresh_frame);
            }
			CGImageRelease(filtered_image);
		}
		timing_draw = timing ? CACurrentMediaTime() : 0;
	}
	CGImageRelease(source_image);
	if (compact_input) CGImageRelease(compact_input);
	free(layer.operations);
	native_free_svg_filter_graph(&layer);
	if (timing) fprintf(stderr,
        "VOX_CSS_FILTER_STAGES canvas=%.0fx%.0f scale=%.0f operations=%zu compact=%d grayscale=%d access_us=%.3f input_us=%.3f source_us=%.3f filter_us=%.3f draw_us=%.3f cleanup_us=%.3f total_us=%.3f\n",
        layer.canvas_width, layer.canvas_height, layer.scale, layer.operation_count,
        compact_input != NULL, grayscale_image != NULL, (timing_access - timing_start) * 1e6,
        (timing_input - timing_access) * 1e6, (timing_source - timing_input) * 1e6,
        (timing_filter - timing_source) * 1e6, (timing_draw - timing_filter) * 1e6,
        (CACurrentMediaTime() - timing_draw) * 1e6, (CACurrentMediaTime() - timing_start) * 1e6);
}

void native_end_backdrop_filter_layer(float opacity) {
	if (native_css_filter_overflow_depth > 0) {
		native_css_filter_overflow_depth--;
		return;
	}
	if (native_css_filter_stack_depth <= 0) {
		return;
	}
	NativeCSSFilterLayer layer =
		native_css_filter_stack[--native_css_filter_stack_depth];
	if (layer.active) {
		@autoreleasepool {
			native_initialize_css_filter_renderer();
			CIImage *output = native_apply_css_filter_layer(&layer,
				layer.backdrop_source);
			// Core Image is demand-driven. Render only the transformed backdrop
			// bounds; blur and drop-shadow filters request their required source
			// pixels outside this rectangle through their region-of-interest logic.
			CGRect source_rect = CGRectMake(
				layer.backdrop_bounds.origin.x * layer.scale,
				layer.backdrop_bounds.origin.y * layer.scale,
				layer.backdrop_bounds.size.width * layer.scale,
				layer.backdrop_bounds.size.height * layer.scale);
			source_rect = CGRectIntersection(source_rect, CGRectMake(0, 0,
				CGImageGetWidth(layer.backdrop_source),
				CGImageGetHeight(layer.backdrop_source)));
			CGImageRef filtered_image = [native_css_filter_ci_context
				createCGImage:output fromRect:source_rect format:kCIFormatRGBA8
				colorSpace:native_css_filter_color_space];
			if (filtered_image != NULL) {
				CGContextSaveGState(layer.destination);
				CGContextAddPath(layer.destination, layer.backdrop_clip);
				CGContextClip(layer.destination);
				CGContextSetAlpha(layer.destination, MAX(0.0f, MIN(opacity, 1.0f)));
				CGContextDrawImage(layer.destination,
					layer.backdrop_bounds,
					filtered_image);
				CGContextRestoreGState(layer.destination);
				CGImageRelease(filtered_image);
			}
		}
	}
	if (layer.backdrop_source != NULL) {
		CGImageRelease(layer.backdrop_source);
	}
	if (layer.backdrop_clip != NULL) {
		CGPathRelease(layer.backdrop_clip);
	}
	free(layer.operations);
	native_free_svg_filter_graph(&layer);
}

static CGRect native_svg_mask_canvas_rect(float area_x, float area_y,
	float area_width, float area_height, float transform_a, float transform_b,
	float transform_c, float transform_d, float transform_e, float transform_f,
	float page_x, float page_y, float scroll_y, float canvas_width,
	float canvas_height) {
	if (area_width <= 0.0 || area_height <= 0.0) {
		return CGRectZero;
	}
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	CGRect mapped = CGRectStandardize(CGRectApplyAffineTransform(
		CGRectMake(area_x, area_y, area_width, area_height), to_canvas));
	mapped = CGRectInset(mapped, -1.0, -1.0);
	CGRect clipped = CGRectIntersection(mapped,
		CGRectMake(0, 0, canvas_width, canvas_height));
	return CGRectIsNull(clipped) || CGRectIsEmpty(clipped) ? CGRectZero : clipped;
}

static CGContextRef native_background_text_clip_build_context;
static CGContextRef native_background_text_content_context;
static CGContextRef native_background_text_destination;
static CGImageRef native_background_text_clip_image;
static CGRect native_background_text_clip_rect;
static CGRect native_background_text_raster_rect;
static int native_background_text_clip_active;
static int native_background_text_gradient_pending;
static int native_background_text_gradient_recording;
static void *native_background_text_mask_input;
static float native_background_text_canvas_width, native_background_text_canvas_height;

void native_prepare_background_text_gradient_input(void) {
	native_background_text_gradient_pending = 1;
}

// Supply the retained mask layer's device-aligned bounds to the V rasterizer.
// V selects the gradient grid; this boundary only converts canvas coordinates.
int native_background_text_gradient_bounds(float page_x, float page_y,
	float scroll_y, float *bounds) {
	if (!bounds || native_background_text_clip_active != 1
		|| !native_background_text_gradient_recording
		|| CGRectIsEmpty(native_background_text_raster_rect)) return 0;
	bounds[0] = native_background_text_raster_rect.origin.x - page_x;
	bounds[1] = native_background_text_canvas_height
		- CGRectGetMaxY(native_background_text_raster_rect) - page_y + scroll_y;
	bounds[2] = native_background_text_raster_rect.size.width;
	bounds[3] = native_background_text_raster_rect.size.height;
	return 1;
}

static void native_discard_background_text_recording(CGContextRef context) {
}

void native_begin_background_text_clip(float canvas_width, float canvas_height,
	float clip_x, float clip_y, float clip_width, float clip_height) {
	if (native_background_text_content_context != NULL) {
		native_discard_background_text_recording(native_background_text_content_context);
		CGContextRelease(native_background_text_content_context);
		native_background_text_content_context = NULL;
	}
	native_background_text_destination = NULL;
	if (native_background_text_clip_build_context != NULL) {
		native_discard_background_text_recording(native_background_text_clip_build_context);
		CGContextRelease(native_background_text_clip_build_context);
		native_background_text_clip_build_context = NULL;
	}
	if (native_background_text_clip_image != NULL) {
		CGImageRelease(native_background_text_clip_image);
		native_background_text_clip_image = NULL;
	}
	native_background_text_mask_input = NULL;
	native_background_text_gradient_recording = native_background_text_gradient_pending;
	native_background_text_gradient_pending = 0;
	native_background_text_canvas_width = canvas_width;
	native_background_text_canvas_height = canvas_height;
	CGRect canvas_rect = CGRectMake(0, 0, canvas_width, canvas_height);
	native_background_text_clip_rect = CGRectIntersection(
		CGRectStandardize(CGRectMake(clip_x, clip_y, clip_width, clip_height)), canvas_rect);
	if (CGRectIsNull(native_background_text_clip_rect)
		|| CGRectIsEmpty(native_background_text_clip_rect)) {
		native_background_text_clip_rect = CGRectZero;
	}
	CGFloat scale = native_svg_mask_backing_scale();
	// Keep the mask on the destination device grid. Fractional clip bounds
	// remain the paint clip, but must not resample the glyph coverage image.
	native_background_text_raster_rect = CGRectMake(
		floor(CGRectGetMinX(native_background_text_clip_rect) * scale) / scale,
		floor(CGRectGetMinY(native_background_text_clip_rect) * scale) / scale, 0, 0);
	native_background_text_raster_rect.size.width =
		ceil(CGRectGetMaxX(native_background_text_clip_rect) * scale) / scale
		- native_background_text_raster_rect.origin.x;
	native_background_text_raster_rect.size.height =
		ceil(CGRectGetMaxY(native_background_text_clip_rect) * scale) / scale
		- native_background_text_raster_rect.origin.y;
	size_t width = (size_t)MAX(1.0, round(native_background_text_raster_rect.size.width * scale));
	size_t height = (size_t)MAX(1.0, round(native_background_text_raster_rect.size.height * scale));
	CGColorSpaceRef color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	native_background_text_clip_build_context = CGBitmapContextCreate(NULL, width,
		height, 8, width * 4, color_space,
		kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	CGColorSpaceRelease(color_space);
	if (native_background_text_clip_build_context == NULL) {
		return;
	}
	CGContextScaleCTM(native_background_text_clip_build_context, scale, scale);
	CGContextTranslateCTM(native_background_text_clip_build_context,
		-native_background_text_raster_rect.origin.x,
		-native_background_text_raster_rect.origin.y);
	CGContextSetShouldAntialias(native_background_text_clip_build_context, true);
}

void native_add_background_text_clip_run(float x, float y, string value,
	float size, int bold, int italic, int monospace) {
	if (native_background_text_clip_build_context == NULL) {
		return;
	}
	// CoreText fallback drawing is absent from the retained Skia mask.
	native_discard_background_text_recording(native_background_text_clip_build_context);
	native_background_text_gradient_recording = 0;
	NSString *text = native_capture_string(value);
	NSFont *font = native_document_font(size, bold, italic, monospace);
	NSGraphicsContext *graphics = [NSGraphicsContext
		graphicsContextWithCGContext:native_background_text_clip_build_context
		flipped:NO];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:graphics];
	[text drawAtPoint:NSMakePoint(x, y - 15.0)
	      withAttributes:@{
		      NSForegroundColorAttributeName : [NSColor whiteColor],
		      NSFontAttributeName : font
	      }];
	[NSGraphicsContext restoreGraphicsState];
}

extern int32_t vox_draw_background_glyph_mask(uint16_t *, double *, int32_t,
	float, int32_t, float, float, float, float, float, float, float, float,
	float, float, float, float, float, string, int32_t, int32_t);

int native_add_background_glyph_clip_run(const uint16_t *glyphs,
	const double *positions, int glyph_count, float font_size, int font_weight, int emoji_face,
	float baseline_x, float baseline_y, float transform_a, float transform_b,
	float transform_c, float transform_d, float transform_e, float transform_f,
	float page_x, float page_y, float scroll_y, float canvas_width, float canvas_height,
	string font_path_value, int face_index, int font_smoothing) {
	if (native_background_text_clip_build_context == NULL) {
		return 0;
	}
	if (!emoji_face && (font_smoothing & 16)) {
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:[NSGraphicsContext
			graphicsContextWithCGContext:native_background_text_clip_build_context flipped:NO]];
		int drawn = vox_draw_background_glyph_mask((uint16_t *)glyphs, (double *)positions, glyph_count,
			font_size, font_weight, baseline_x, baseline_y, transform_a, transform_b,
			transform_c, transform_d, transform_e, transform_f, page_x, page_y,
			scroll_y, canvas_width, canvas_height, font_path_value, face_index, font_smoothing);
		[NSGraphicsContext restoreGraphicsState];
		if (drawn) return 1;
	}
	// Upstream records text-mask glyphs in black. Skia's text contrast/gamma
	// adjustment is paint-color dependent even though DestinationIn later uses
	// only alpha, so using white here produces a substantially heavier edge.
	CGColorRef black = CGColorCreateGenericRGB(0.0, 0.0, 0.0, 1.0);
	NSString *font_path = native_capture_string(font_path_value);
	int did_draw = native_draw_retained_glyph_run(native_background_text_clip_build_context,
		[font_path UTF8String], face_index, glyphs, positions, glyph_count, font_size, font_weight, emoji_face, baseline_x,
		baseline_y, transform_a, transform_b, transform_c, transform_d,
		transform_e, transform_f, page_x, page_y, scroll_y,
		canvas_width, canvas_height,
		black, 0.0f, 0, font_smoothing);
	CGColorRelease(black);
	return did_draw;
}

void native_finish_background_text_clip(void) {
	CGContextRef destination = [[NSGraphicsContext currentContext] CGContext];
	if (native_background_text_clip_build_context != NULL) {
		native_background_text_clip_image = CGBitmapContextCreateImage(
			native_background_text_clip_build_context);
		CGContextRelease(native_background_text_clip_build_context);
		native_background_text_clip_build_context = NULL;
	}
	if (destination == NULL) {
		native_background_text_mask_input = NULL;
		return;
	}
	native_background_text_mask_input = NULL;
	CGContextSaveGState(destination);
	if (native_background_text_clip_image != NULL
		&& !CGRectIsEmpty(native_background_text_clip_rect)) {
		CGContextClipToRect(destination, native_background_text_clip_rect);
		CGContextClipToMask(destination, native_background_text_raster_rect,
			native_background_text_clip_image);
	} else {
		CGContextClipToRect(destination, CGRectZero);
	}
	native_begin_tracked_transparency_layer(destination, NULL);
	native_background_text_clip_active = 1;
	if (native_background_text_clip_image != NULL) {
		CGImageRelease(native_background_text_clip_image);
		native_background_text_clip_image = NULL;
	}
}

void native_end_background_text_clip(void) {
	if (!native_background_text_clip_active) {
		return;
	}
	if (native_background_text_clip_active == 2) {
		CGContextFlush(native_background_text_content_context);
		CGImageRef content = CGBitmapContextCreateImage(
			native_background_text_content_context);
		[NSGraphicsContext restoreGraphicsState];
		int retained = 0;
		native_discard_background_text_recording(native_background_text_content_context);
		CGContextRelease(native_background_text_content_context);
		native_background_text_content_context = NULL;
		if (content != NULL) CGImageRelease(content);
		if (native_background_text_clip_image != NULL) {
			CGImageRelease(native_background_text_clip_image);
			native_background_text_clip_image = NULL;
		}
		native_background_text_destination = NULL;
		native_background_text_clip_active = 0;
		return;
	}
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context != NULL) {
		native_end_tracked_transparency_layer(context);
		CGContextRestoreGState(context);
	}
	native_background_text_clip_active = 0;
}

void native_begin_svg_clip_mask(unsigned long long input_key, float canvas_width,
	float canvas_height, float area_x, float area_y, float area_width,
	float area_height, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x,
	float page_y, float scroll_y) {
	native_svg_clip_build_is_color = 0;
	native_svg_clip_build_is_luminance = 0;
	if (!native_prepare_svg_mask(input_key, 0, canvas_width, canvas_height, page_x,
		page_y, scroll_y)) {
		return;
	}
	native_svg_clip_rect = native_svg_mask_canvas_rect(area_x, area_y, area_width,
		area_height, transform_a, transform_b, transform_c, transform_d,
		transform_e, transform_f, page_x, page_y, scroll_y, canvas_width,
		canvas_height);
	CGFloat scale = native_svg_mask_backing_scale();
	size_t width = (size_t)MAX(1.0, ceil(native_svg_clip_rect.size.width * scale));
	size_t height = (size_t)MAX(1.0, ceil(native_svg_clip_rect.size.height * scale));
	native_svg_clip_build_context = CGBitmapContextCreate(NULL, width, height, 8,
		width, NULL, kCGImageAlphaOnly);
	if (native_svg_clip_build_context != NULL) {
		CGContextScaleCTM(native_svg_clip_build_context, scale, scale);
		CGContextTranslateCTM(native_svg_clip_build_context,
			-native_svg_clip_rect.origin.x, -native_svg_clip_rect.origin.y);
		CGContextSetShouldAntialias(native_svg_clip_build_context, true);
		CGContextSetGrayFillColor(native_svg_clip_build_context, 1.0, 1.0);
	}
}

void native_begin_svg_content_mask(unsigned long long input_key, int luminance,
	float canvas_width, float canvas_height, float area_x, float area_y,
	float area_width, float area_height, float transform_a, float transform_b,
	float transform_c, float transform_d, float transform_e, float transform_f,
	float page_x, float page_y, float scroll_y) {
	native_svg_clip_build_is_color = 1;
	native_svg_clip_build_is_luminance = luminance;
	if (!native_prepare_svg_mask(input_key, 1, canvas_width, canvas_height, page_x,
		page_y, scroll_y)) {
		return;
	}
	native_svg_clip_rect = native_svg_mask_canvas_rect(area_x, area_y, area_width,
		area_height, transform_a, transform_b, transform_c, transform_d,
		transform_e, transform_f, page_x, page_y, scroll_y, canvas_width,
		canvas_height);
	CGFloat scale = native_svg_mask_backing_scale();
	size_t width = (size_t)MAX(1.0, ceil(native_svg_clip_rect.size.width * scale));
	size_t height = (size_t)MAX(1.0, ceil(native_svg_clip_rect.size.height * scale));
	CGColorSpaceRef color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	native_svg_clip_build_context = CGBitmapContextCreate(NULL, width, height, 8,
		width * 4, color_space,
		kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	CGColorSpaceRelease(color_space);
	if (native_svg_clip_build_context == NULL) {
		return;
	}
	CGContextScaleCTM(native_svg_clip_build_context, scale, scale);
	CGContextTranslateCTM(native_svg_clip_build_context,
		-native_svg_clip_rect.origin.x, -native_svg_clip_rect.origin.y);
	CGContextSetShouldAntialias(native_svg_clip_build_context, true);
	if (area_width <= 0.0 || area_height <= 0.0) {
		CGContextClipToRect(native_svg_clip_build_context, CGRectZero);
		return;
	}
	CGMutablePathRef local_area = CGPathCreateMutable();
	CGPathAddRect(local_area, NULL,
		CGRectMake(area_x, area_y, area_width, area_height));
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	CGPathRef canvas_area = CGPathCreateCopyByTransformingPath(local_area, &to_canvas);
	CGContextAddPath(native_svg_clip_build_context, canvas_area);
	CGContextClip(native_svg_clip_build_context);
	CGPathRelease(canvas_area);
	CGPathRelease(local_area);
}

void native_add_svg_clip_mask_path(const float *data, int segment_count, int even_odd,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_width, float canvas_height) {
	if (native_svg_clip_image != NULL || native_svg_clip_build_context == NULL
		|| data == NULL || segment_count <= 0) {
		return;
	}
	CGMutablePathRef local_path = native_create_path_from_data(data, segment_count);
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	CGPathRef canvas_path = CGPathCreateCopyByTransformingPath(local_path, &to_canvas);
	CGContextAddPath(native_svg_clip_build_context, canvas_path);
	if (even_odd) {
		CGContextEOFillPath(native_svg_clip_build_context);
	} else {
		CGContextFillPath(native_svg_clip_build_context);
	}
	CGPathRelease(canvas_path);
	CGPathRelease(local_path);
}

void native_begin_svg_mask_opacity(float opacity) {
	if (native_svg_clip_image != NULL || native_svg_clip_build_context == NULL) {
		return;
	}
	int depth = native_svg_clip_build_opacity_depth;
	if (native_font_compositing_context != NULL && native_svg_clip_build_is_color
		&& native_svg_clip_build_quartz_opacity_depth == 0
		&& depth < VOX_SVG_MASK_OPACITY_BITMAP_DEPTH
		&& native_begin_svg_mask_bitmap_opacity(&native_svg_clip_opacity_bitmaps[depth],
			native_svg_clip_build_context, opacity)) {
		native_svg_clip_build_context = native_svg_clip_opacity_bitmaps[depth].canvas.context;
		native_svg_clip_build_opacity_depth++;
		return;
	}
	CGContextSaveGState(native_svg_clip_build_context);
	native_svg_clip_build_opacity_depth++;
	native_svg_clip_build_quartz_opacity_depth++;
	CGContextSetAlpha(native_svg_clip_build_context, fminf(fmaxf(opacity, 0.0f), 1.0f));
	native_begin_tracked_transparency_layer(native_svg_clip_build_context, NULL);
}

void native_end_svg_mask_opacity(void) {
	if (native_svg_clip_image != NULL || native_svg_clip_build_context == NULL
		|| native_svg_clip_build_opacity_depth == 0) {
		return;
	}
	native_svg_clip_build_opacity_depth--;
	int depth = native_svg_clip_build_opacity_depth;
	if (depth < VOX_SVG_MASK_OPACITY_BITMAP_DEPTH
		&& native_svg_clip_opacity_bitmaps[depth].canvas.context != NULL) {
		CGContextRef parent = native_svg_clip_opacity_bitmaps[depth].parent;
		native_end_svg_mask_bitmap_opacity(&native_svg_clip_opacity_bitmaps[depth]);
		native_svg_clip_build_context = parent;
		return;
	}
	native_end_tracked_transparency_layer(native_svg_clip_build_context);
	CGContextRestoreGState(native_svg_clip_build_context);
	native_svg_clip_build_quartz_opacity_depth--;
}

static void native_draw_svg_mask_path_part(CGContextRef context, CGPathRef path,
	int fill, int even_odd) {
	CGContextAddPath(context, path);
	if (fill) {
		CGContextDrawPath(context, even_odd ? kCGPathEOFill : kCGPathFill);
	} else {
		CGContextDrawPath(context, kCGPathStroke);
	}
}

void native_add_svg_content_mask_path(const float *data, int segment_count,
	int even_odd, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x,
	float page_y, float scroll_y, float canvas_width, float canvas_height,
	gg__Color fill_color,
	int has_fill, gg__Color stroke_color, int has_stroke, float stroke_width,
	int line_cap, int line_join, float miter_limit, int stroke_first) {
	if (native_svg_clip_image != NULL || native_svg_clip_build_context == NULL
		|| data == NULL || segment_count <= 0 || (!has_fill && !has_stroke)) {
		return;
	}
	CGMutablePathRef path = native_create_path_from_data(data, segment_count);
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	CGContextSaveGState(native_svg_clip_build_context);
	CGContextConcatCTM(native_svg_clip_build_context, to_canvas);
	CGColorRef fill = NULL;
	CGColorRef stroke = NULL;
	if (has_fill) {
		fill = native_srgb_color(fill_color);
		CGContextSetFillColorWithColor(native_svg_clip_build_context, fill);
	}
	if (has_stroke) {
		stroke = native_srgb_color(stroke_color);
		CGContextSetStrokeColorWithColor(native_svg_clip_build_context, stroke);
		CGContextSetLineWidth(native_svg_clip_build_context, MAX(stroke_width, 0.0));
		CGContextSetLineCap(native_svg_clip_build_context,
			line_cap == 1 ? kCGLineCapRound
			              : line_cap == 2 ? kCGLineCapSquare : kCGLineCapButt);
		CGContextSetLineJoin(native_svg_clip_build_context,
			line_join == 1 ? kCGLineJoinRound
			               : line_join == 2 ? kCGLineJoinBevel : kCGLineJoinMiter);
		CGContextSetMiterLimit(native_svg_clip_build_context, MAX(miter_limit, 1.0));
	}
	if (stroke_first && has_stroke) {
		native_draw_svg_mask_path_part(native_svg_clip_build_context, path, 0, even_odd);
	}
	if (has_fill) {
		native_draw_svg_mask_path_part(native_svg_clip_build_context, path, 1, even_odd);
	}
	if (!stroke_first && has_stroke) {
		native_draw_svg_mask_path_part(native_svg_clip_build_context, path, 0, even_odd);
	}
	if (fill != NULL) {
		CGColorRelease(fill);
	}
	if (stroke != NULL) {
		CGColorRelease(stroke);
	}
	CGContextRestoreGState(native_svg_clip_build_context);
	CGPathRelease(path);
}

void native_add_svg_content_mask_linear_gradient_path(const float *data,
	int segment_count, int even_odd, float transform_a, float transform_b,
	float transform_c, float transform_d, float transform_e, float transform_f,
	float page_x, float page_y, float scroll_y, float canvas_height, int stroke,
	float stroke_width, int line_cap, int line_join, float miter_limit,
	float start_x, float start_y, float end_x, float end_y, float gradient_a,
	float gradient_b, float gradient_c, float gradient_d, float gradient_e,
	float gradient_f, int spread_method, int linear_color_space,
	const float *stop_data, int stop_count, float opacity) {
	if (native_svg_clip_image != NULL || native_svg_clip_build_context == NULL) {
		return;
	}
	native_draw_svg_linear_gradient_path_in_context(native_svg_clip_build_context,
		data, segment_count, even_odd, transform_a, transform_b, transform_c,
		transform_d, transform_e, transform_f, page_x, page_y, scroll_y,
		canvas_height, stroke, stroke_width, line_cap, line_join, miter_limit,
		start_x, start_y, end_x, end_y, gradient_a, gradient_b, gradient_c,
		gradient_d, gradient_e, gradient_f, spread_method, linear_color_space,
		stop_data, stop_count, opacity);
}

void native_add_svg_content_mask_radial_gradient_path(const float *data,
	int segment_count, int even_odd, float transform_a, float transform_b,
	float transform_c, float transform_d, float transform_e, float transform_f,
	float page_x, float page_y, float scroll_y, float canvas_height, int stroke,
	float stroke_width, int line_cap, int line_join, float miter_limit,
	float start_x, float start_y, float start_radius, float end_x, float end_y,
	float end_radius, float gradient_a, float gradient_b, float gradient_c,
	float gradient_d, float gradient_e, float gradient_f, int spread_method,
	int linear_color_space, const float *stop_data, int stop_count, float opacity) {
	if (native_svg_clip_image != NULL || native_svg_clip_build_context == NULL) {
		return;
	}
	native_draw_svg_radial_gradient_path_in_context(native_svg_clip_build_context,
		data, segment_count, even_odd, transform_a, transform_b, transform_c,
		transform_d, transform_e, transform_f, page_x, page_y, scroll_y,
		canvas_height, stroke, stroke_width, line_cap, line_join, miter_limit,
		start_x, start_y, start_radius, end_x, end_y, end_radius, gradient_a,
		gradient_b, gradient_c, gradient_d, gradient_e, gradient_f, spread_method,
		linear_color_space, stop_data, stop_count, opacity);
}

static CGImageRef native_finalize_svg_mask_cache(void) {
	if (native_svg_clip_image == NULL && native_svg_clip_build_context != NULL) {
		size_t width = CGBitmapContextGetWidth(native_svg_clip_build_context);
		size_t height = CGBitmapContextGetHeight(native_svg_clip_build_context);
		size_t source_stride = CGBitmapContextGetBytesPerRow(native_svg_clip_build_context);
		uint8_t *source = CGBitmapContextGetData(native_svg_clip_build_context);
		CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
		CGContextRef mask_context = CGBitmapContextCreate(NULL, width, height, 8,
			width * 4, color_space,
			kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
		CGColorSpaceRelease(color_space);
		if (source != NULL && mask_context != NULL) {
			uint8_t *mask = CGBitmapContextGetData(mask_context);
			size_t mask_stride = CGBitmapContextGetBytesPerRow(mask_context);
			native_convert_svg_mask_pixels(source, source_stride, mask, mask_stride,
				width, height, native_svg_clip_build_is_color,
				native_svg_clip_build_is_luminance);
			native_svg_clip_image = CGBitmapContextCreateImage(mask_context);
		}
		if (mask_context != NULL) {
			CGContextRelease(mask_context);
		}
		CGContextRelease(native_svg_clip_build_context);
		native_svg_clip_build_context = NULL;
		if (native_svg_clip_image != NULL) {
			int replacement = 0;
			for (int index = 1; index < NATIVE_SVG_CLIP_CACHE_SIZE; ++index) {
				if (native_svg_clip_cache[index].image == NULL
					|| native_svg_clip_cache[index].last_use
						< native_svg_clip_cache[replacement].last_use) {
					replacement = index;
				}
			}
			if (native_svg_clip_cache[replacement].image != NULL) {
				CGImageRelease(native_svg_clip_cache[replacement].image);
			}
			native_svg_clip_cache[replacement].key = native_svg_clip_build_key;
			native_svg_clip_cache[replacement].image = native_svg_clip_image;
			native_svg_clip_cache[replacement].rect = native_svg_clip_rect;
			native_svg_clip_cache[replacement].last_use = native_svg_clip_cache_clock;
		}
	}
	return native_svg_clip_image;
}

void native_finish_svg_mask_cache(void) {
	native_finalize_svg_mask_cache();
	native_svg_clip_image = NULL;
}

void native_finish_svg_clip_mask(void) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	native_finalize_svg_mask_cache();
	if (context != NULL && native_svg_clip_image != NULL) {
		CGContextClipToRect(context, native_svg_clip_rect);
		CGContextClipToMask(context, native_svg_clip_rect, native_svg_clip_image);
	}
	native_svg_clip_image = NULL;
}

void native_begin_svg_mask_layer(void) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL) {
		return;
	}
	// Cache preparation does not change the destination clip. Keep unsupported
	// mask compositing scoped to this layer, including any nested masks.
	native_begin_svg_mask_layer_in_context(context, native_svg_clip_rect);
	if (context == native_font_compositing_context) {
		native_font_compositing_transparency_depth++;
	}
}

void native_end_svg_mask_layer(unsigned long long input_key, int content_mask,
	float canvas_width, float canvas_height, float page_x, float page_y,
	float scroll_y) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL) {
		return;
	}
	uint64_t key = native_svg_mask_cache_key(input_key, content_mask, canvas_width,
		canvas_height, page_x, page_y, scroll_y);
	CGImageRef image = NULL;
	CGRect mask_rect = CGRectZero;
	for (int index = 0; index < NATIVE_SVG_CLIP_CACHE_SIZE; ++index) {
		if (native_svg_clip_cache[index].image != NULL
			&& native_svg_clip_cache[index].key == key) {
			image = native_svg_clip_cache[index].image;
			mask_rect = native_svg_clip_cache[index].rect;
			native_svg_clip_cache[index].last_use = ++native_svg_clip_cache_clock;
			break;
		}
	}
	CGRect canvas_rect = CGRectMake(0, 0, canvas_width, canvas_height);
	CGContextSaveGState(context);
	if (image != NULL) {
		CGMutablePathRef outside = CGPathCreateMutable();
		CGPathAddRect(outside, NULL, canvas_rect);
		CGPathAddRect(outside, NULL, mask_rect);
		CGContextAddPath(context, outside);
		CGContextEOClip(context);
		CGContextSetBlendMode(context, kCGBlendModeClear);
		CGContextFillRect(context, canvas_rect);
		CGPathRelease(outside);
		CGContextRestoreGState(context);
		CGContextSaveGState(context);
		CGContextSetBlendMode(context, kCGBlendModeDestinationIn);
		CGContextDrawImage(context, mask_rect, image);
	} else {
		CGContextSetBlendMode(context, kCGBlendModeClear);
		CGContextFillRect(context, canvas_rect);
	}
	CGContextRestoreGState(context);
	native_end_tracked_transparency_layer(context);
	CGContextRestoreGState(context);
}

void native_add_corner_rounded_clip(float x, float y, float width, float height,
	float top_left_x, float top_left_y, float top_right_x, float top_right_y,
	float bottom_right_x, float bottom_right_y, float bottom_left_x,
	float bottom_left_y, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x,
	float page_y, float scroll_y, float canvas_height) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL) {
		return;
	}
	if (width <= 0.0 || height <= 0.0) {
		CGContextClipToRect(context, CGRectZero);
		return;
	}
	CGPathRef local_path = native_create_corner_rounded_rect_path(x, y, width, height,
		top_left_x, top_left_y, top_right_x, top_right_y, bottom_right_x,
		bottom_right_y, bottom_left_x, bottom_left_y);
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	CGPathRef canvas_path = CGPathCreateCopyByTransformingPath(local_path, &to_canvas);
	CGContextAddPath(context, canvas_path);
	CGContextClip(context);
	CGPathRelease(canvas_path);
	CGPathRelease(local_path);
}

void native_add_image_viewport_clip(float x, float y, float width, float height,
    float a, float b, float c, float d, float e, float f,
    float page_x, float page_y, float scroll_y, float canvas_height) {
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    if (!context) return;
    if (width <= 0 || height <= 0) {
        CGContextClipToRect(context, CGRectZero);
        return;
    }
    CGAffineTransform transform_to_canvas = CGAffineTransformMake(a, -b, c, -d,
        page_x + e, canvas_height - page_y + scroll_y - f);
    CGPathRef path = CGPathCreateWithRect(CGRectMake(x, y, width, height), &transform_to_canvas);
    CGContextAddPath(context, path);
    CGContextClip(context);
    CGPathRelease(path);
}

void native_set_unrounded_paint_color(const float *color) {
    native_v_shape_state.has_float_color = color != NULL;
    if (color) memcpy(native_v_shape_state.float_color,color,4*sizeof(float));
}

int native_plain_rect_prefetch_enabled(void) {
    static int enabled = -1;
    if (enabled < 0) {
        const char *opt_in = getenv("VOX_ENABLE_RECT_PREFETCH");
        const char *value = getenv("VOX_DISABLE_RECT_PREFETCH");
        enabled = opt_in && *opt_in && (!value || !*value);
    }
    return enabled;
}

void native_prefetch_plain_rects(const VoxGraphiteShape *shapes, int count,
    float page_x, float page_y, float canvas_width, float canvas_height) {
}

// Keep the scratch context private to a balanced lookahead replay. The normal
// command stream resumes on its original context before GPU cache submission.

int native_rect_prefetch_scratch_enabled(void) {
    const char *value = getenv("VOX_RECT_PREFETCH_SCRATCH");
    return value && *value;
}

int native_begin_rect_prefetch_scratch(const VoxGraphiteShape *shapes, int count,
    float page_x, float page_y, float canvas_width, float canvas_height) {
    return 0;
}

int native_append_rect_prefetch_scratch(int index) {
    return 0;
}

int native_finish_rect_prefetch_scratch(int commit) {
    return 0;
}

#include "native/include/native_chromium_corner_shapes_darwin.h"

// Deferred viewport scrollbars repaint a few pixels after the scroll raster
// has stored the document. Quartz fills them directly; a Skia leaf would
// rasterize on the GPU and wait for its readback.
static int native_quartz_scrollbar_leaves;
void native_set_quartz_scrollbar_leaves(int enabled) {
	native_quartz_scrollbar_leaves = enabled != 0;
}

void native_draw_rounded_rect_srgb(float x, float y, float width, float height,
	float top_left_x, float top_left_y, float top_right_x, float top_right_y,
	float bottom_right_x, float bottom_right_y, float bottom_left_x, float bottom_left_y,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y, float scroll_y,
	float canvas_width, float canvas_height, gg__Color color, int fill, float thickness,
	int anti_alias) {
	if (width <= 0.0 || height <= 0.0) {
		return;
	}
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL) {
		return;
	}
    const float radii[8]={top_left_x,top_left_y,top_right_x,top_right_y,
        bottom_right_x,bottom_right_y,bottom_left_x,bottom_left_y};
    const float matrix[6]={transform_a,transform_b,transform_c,transform_d,
        page_x+transform_e,page_y-scroll_y+transform_f};
    if (!native_quartz_scrollbar_leaves && native_try_v_rounded_rect(x,y,width,height,radii,matrix,
        canvas_width,canvas_height,color,fill,thickness,anti_alias,page_x,page_y,scroll_y)) return;

	CGPathRef local_path = native_create_corner_rounded_rect_path(x, y, width, height,
		top_left_x, top_left_y, top_right_x, top_right_y, bottom_right_x,
		bottom_right_y, bottom_left_x, bottom_left_y);

	// V paint coordinates are CSS y-down coordinates. Map the retained CSS transform directly
	// into Cocoa's y-up canvas without flattening the rounded rectangle into a polygon first.
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	CGPathRef canvas_path = CGPathCreateCopyByTransformingPath(local_path, &to_canvas);
	CGColorRef cg_color = native_srgb_color(color);
	// The Skia leaf honors the caller's coverage choice; keep it here too.
	if (native_quartz_scrollbar_leaves) {
		CGContextSaveGState(context);
		CGContextSetShouldAntialias(context, anti_alias != 0);
	}
	CGContextAddPath(context, canvas_path);
	if (fill) {
		CGContextSetFillColorWithColor(context, cg_color);
		CGContextFillPath(context);
	} else {
		CGContextSetStrokeColorWithColor(context, cg_color);
		CGContextSetLineWidth(context, MAX(thickness, 0.0f));
		CGContextStrokePath(context);
	}
	if (native_quartz_scrollbar_leaves) CGContextRestoreGState(context);
	CGColorRelease(cg_color);
	CGPathRelease(canvas_path);
	CGPathRelease(local_path);
}

static CGPathRef native_rounded_rect_path(CGRect rect, CGFloat radius) {
	CGFloat clamped_radius = MIN(MAX(radius, 0.0), MIN(rect.size.width, rect.size.height) / 2.0);
	return CGPathCreateWithRoundedRect(rect, clamped_radius, clamped_radius, NULL);
}

void native_draw_outer_box_shadow_srgb(float source_x, float source_y, float source_width,
	float source_height, float source_radius, float clip_x, float clip_y, float clip_width,
	float clip_height, float clip_radius, float blur, gg__Color color) {
	if (source_width <= 0 || source_height <= 0 || clip_width <= 0 || clip_height <= 0) {
		return;
	}
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL) {
		return;
	}
	CGContextSaveGState(context);
	CGRect source_rect = CGRectMake(source_x, source_y, source_width, source_height);
	CGRect clip_rect = CGRectMake(clip_x, clip_y, clip_width, clip_height);
	CGPathRef source_path = native_rounded_rect_path(source_rect, source_radius);
	CGPathRef clip_path = native_rounded_rect_path(clip_rect, clip_radius);
	CGContextAddRect(context, CGContextGetClipBoundingBox(context));
	CGContextAddPath(context, clip_path);
	CGContextEOClip(context);
	CGColorRef cg_color = native_srgb_color(color);
	CGContextSetShadowWithColor(context, CGSizeZero, MAX(blur, 0.0), cg_color);
	CGContextSetFillColorWithColor(context, cg_color);
	CGContextAddPath(context, source_path);
	CGContextFillPath(context);
	CGColorRelease(cg_color);
	CGPathRelease(clip_path);
	CGPathRelease(source_path);
	CGContextRestoreGState(context);
}

static void native_fill_blurred_path(CGContextRef context, CGPathRef path,
	bool even_odd, float blur_radius, CGColorRef color) {
	CGContextSetFillColorWithColor(context, color);
	// Skia receives an integer sigma of blur_radius / 2. CoreGraphics' shadow
	// softness is specified as a diameter-like blur amount, so the equivalent
	// visual kernel uses the full retained radius.
	float core_graphics_blur = floorf(MAX(blur_radius, 0.0f));
	if (core_graphics_blur == 0.0f) {
		CGContextAddPath(context, path);
		if (even_odd)
			CGContextEOFillPath(context);
		else
			CGContextFillPath(context);
		return;
	}
	// CoreGraphics' shadow API normally paints the sharp source on top of the
	// shadow. Skia's blur mask paints only the filtered mask. Move the source
	// outside the current clip and offset its shadow back to the retained path.
	CGRect clip_bounds = CGContextGetClipBoundingBox(context);
	CGRect path_bounds = CGPathGetBoundingBox(path);
	CGFloat displacement = clip_bounds.size.width + path_bounds.size.width
		+ core_graphics_blur * 8.0f + 1024.0f;
	CGAffineTransform move_source = CGAffineTransformMakeTranslation(displacement, 0.0f);
	CGPathRef shifted_path = CGPathCreateCopyByTransformingPath(path, &move_source);
	CGContextSetShadowWithColor(context, CGSizeMake(-displacement, 0.0f), core_graphics_blur,
		color);
	CGContextAddPath(context, shifted_path);
	if (even_odd)
		CGContextEOFillPath(context);
	else
		CGContextFillPath(context);
	CGPathRelease(shifted_path);
}

void native_draw_outer_box_shadow_corners_srgb(float shadow_x, float shadow_y,
	float shadow_width, float shadow_height, float shadow_top_left_x,
	float shadow_top_left_y, float shadow_top_right_x, float shadow_top_right_y,
	float shadow_bottom_right_x, float shadow_bottom_right_y, float shadow_bottom_left_x,
	float shadow_bottom_left_y, float content_x, float content_y, float content_width,
	float content_height, float content_top_left_x, float content_top_left_y,
	float content_top_right_x, float content_top_right_y, float content_bottom_right_x,
	float content_bottom_right_y, float content_bottom_left_x, float content_bottom_left_y,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y, float scroll_y,
	float canvas_width, float canvas_height, float blur, gg__Color color) {
	if (shadow_width <= 0.0f || shadow_height <= 0.0f || content_width < 0.0f
		|| content_height < 0.0f)
		return;
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL)
		return;
	CGPathRef local_shadow = native_create_corner_rounded_rect_path(shadow_x, shadow_y,
		shadow_width, shadow_height, shadow_top_left_x, shadow_top_left_y,
		shadow_top_right_x, shadow_top_right_y, shadow_bottom_right_x,
		shadow_bottom_right_y, shadow_bottom_left_x, shadow_bottom_left_y);
	CGPathRef local_content = native_create_corner_rounded_rect_path(content_x, content_y,
		content_width, content_height, content_top_left_x, content_top_left_y,
		content_top_right_x, content_top_right_y, content_bottom_right_x,
		content_bottom_right_y, content_bottom_left_x, content_bottom_left_y);
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	CGPathRef canvas_shadow = CGPathCreateCopyByTransformingPath(local_shadow, &to_canvas);
	CGPathRef canvas_content = CGPathCreateCopyByTransformingPath(local_content, &to_canvas);
	CGContextSaveGState(context);
	CGContextAddRect(context, CGContextGetClipBoundingBox(context));
	CGContextAddPath(context, canvas_content);
	CGContextEOClip(context);
	CGColorRef cg_color = native_srgb_color(color);
	// The fallback paths are already in canvas coordinates. Skia above instead
	// consumes local geometry and applies this transform to its blur mask too.
	float canvas_blur = blur * fminf(hypotf(transform_a, transform_b),
		hypotf(transform_c, transform_d));
	native_fill_blurred_path(context, canvas_shadow, false, canvas_blur, cg_color);
	CGColorRelease(cg_color);
	CGContextRestoreGState(context);
	CGPathRelease(canvas_content);
	CGPathRelease(canvas_shadow);
	CGPathRelease(local_content);
	CGPathRelease(local_shadow);
}

int native_begin_inset_decorations(float x, float y, float width, float height,
    float canvas_width, float canvas_height, float page_y, float scroll_y) {
    return 0;
}

int native_begin_deferred_inset_decorations(float x, float y, float width, float height,
    float canvas_width, float canvas_height, float page_y, float scroll_y) {
    // Completed bundles with the preceding bridge keep the ordinary group.
    return native_begin_inset_decorations(x, y, width, height,
        canvas_width, canvas_height, page_y, scroll_y);
}

void native_end_inset_decorations(void) {
}

int native_end_deferred_inset_decorations(void) {
    native_end_inset_decorations();
    return 1;
}

void native_draw_inner_box_shadow_corners_srgb(float outer_x, float outer_y,
	float outer_width, float outer_height, float outer_top_left_x,
	float outer_top_left_y, float outer_top_right_x, float outer_top_right_y,
	float outer_bottom_right_x, float outer_bottom_right_y, float outer_bottom_left_x,
	float outer_bottom_left_y, float inner_x, float inner_y, float inner_width,
	float inner_height, float inner_top_left_x, float inner_top_left_y,
	float inner_top_right_x, float inner_top_right_y, float inner_bottom_right_x,
	float inner_bottom_right_y, float inner_bottom_left_x, float inner_bottom_left_y,
	float content_x, float content_y, float content_width, float content_height,
	float content_top_left_x, float content_top_left_y, float content_top_right_x,
	float content_top_right_y, float content_bottom_right_x, float content_bottom_right_y,
	float content_bottom_left_x, float content_bottom_left_y, float clip_top_left_x,
	float clip_top_left_y, float clip_top_right_x, float clip_top_right_y,
	float clip_bottom_right_x, float clip_bottom_right_y, float clip_bottom_left_x,
	float clip_bottom_left_y, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_width, float canvas_height, float blur, gg__Color color) {
	if (outer_width <= 0.0f || outer_height <= 0.0f || content_width <= 0.0f
		|| content_height <= 0.0f)
		return;
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL)
		return;
	CGPathRef local_outer = native_create_corner_rounded_rect_path(outer_x, outer_y,
		outer_width, outer_height, outer_top_left_x, outer_top_left_y, outer_top_right_x,
		outer_top_right_y, outer_bottom_right_x, outer_bottom_right_y, outer_bottom_left_x,
		outer_bottom_left_y);
	CGPathRef local_inner = NULL;
	if (inner_width > 0.0f && inner_height > 0.0f) {
		local_inner = native_create_corner_rounded_rect_path(inner_x, inner_y, inner_width,
			inner_height, inner_top_left_x, inner_top_left_y, inner_top_right_x,
			inner_top_right_y, inner_bottom_right_x, inner_bottom_right_y,
			inner_bottom_left_x, inner_bottom_left_y);
	}
	CGPathRef local_content = native_create_corner_rounded_rect_path(content_x, content_y,
		content_width, content_height, content_top_left_x, content_top_left_y,
		content_top_right_x, content_top_right_y, content_bottom_right_x,
		content_bottom_right_y, content_bottom_left_x, content_bottom_left_y);
	CGPathRef local_clip = native_create_corner_rounded_rect_path(content_x, content_y,
		content_width, content_height, clip_top_left_x, clip_top_left_y,
		clip_top_right_x, clip_top_right_y, clip_bottom_right_x, clip_bottom_right_y,
		clip_bottom_left_x, clip_bottom_left_y);
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	CGPathRef canvas_outer = CGPathCreateCopyByTransformingPath(local_outer, &to_canvas);
	CGPathRef canvas_inner = local_inner == NULL
		? NULL : CGPathCreateCopyByTransformingPath(local_inner, &to_canvas);
	CGPathRef canvas_content = CGPathCreateCopyByTransformingPath(local_content, &to_canvas);
	CGPathRef canvas_clip = CGPathCreateCopyByTransformingPath(local_clip, &to_canvas);
	CGContextSaveGState(context);
	// ScopedCornerRadiusClip intersects the shrunk padding radii, then the Skia
	// command itself clips to its retained content radii.
	CGContextAddPath(context, canvas_clip);
	CGContextClip(context);
	CGContextAddPath(context, canvas_content);
	CGContextClip(context);
	CGColorRef cg_color = native_srgb_color(color);
	CGMutablePathRef compound_path = CGPathCreateMutable();
	CGPathAddPath(compound_path, NULL, canvas_outer);
	if (canvas_inner != NULL)
		CGPathAddPath(compound_path, NULL, canvas_inner);
	native_fill_blurred_path(context, compound_path, true, blur, cg_color);
	CGPathRelease(compound_path);
	CGColorRelease(cg_color);
	CGContextRestoreGState(context);
	CGPathRelease(canvas_clip);
	CGPathRelease(canvas_content);
	if (canvas_inner != NULL)
		CGPathRelease(canvas_inner);
	CGPathRelease(canvas_outer);
	CGPathRelease(local_clip);
	CGPathRelease(local_content);
	if (local_inner != NULL)
		CGPathRelease(local_inner);
	CGPathRelease(local_outer);
}

// NSBitmapImageRep does not advance animated image frames merely because it is
// drawn into a retained browser display list. Keep one timeline per shared
// NSImage so every CSS consumer observes the same current frame.
static void native_update_animated_image_frame(NSImage *image) {
	if (image == nil)
		return;
	NSBitmapImageRep *animated_representation = nil;
	for (NSImageRep *representation in image.representations) {
		if ([representation isKindOfClass:[NSBitmapImageRep class]]) {
			NSNumber *frame_count = [(NSBitmapImageRep *)representation valueForProperty:NSImageFrameCount];
			if (frame_count.integerValue > 1) {
				animated_representation = (NSBitmapImageRep *)representation;
				break;
			}
		}
	}
	if (animated_representation == nil)
		return;
	// The native image timeline advances independently of DOM invalidation.
	// Keep its visible frames on complete replay rather than retaining a still.
	native_scroll_raster_independent_content();
	native_stationary_raster_independent_content();
	NSInteger frame_count = [[animated_representation valueForProperty:NSImageFrameCount] integerValue];
	// The screenshot JavaScript host resolves its image-animation checkpoint at
	// frame 1. Keep native decoding at the same checkpoint; otherwise the capture
	// delay can wrap a looping GIF back to frame 0 after the test has completed.
	if (vox_apply_image_capture_policy(animated_representation,
		getenv("VOX_CAPTURE_IMAGE_ANIMATION_POLICY"),
		getenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS") != NULL)) {
		return;
	}
	static NSMutableDictionary<NSValue *, NSNumber *> *animation_start_times;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		animation_start_times = [[NSMutableDictionary alloc] init];
	});
	NSValue *key = [NSValue valueWithPointer:(__bridge void *)image];
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	NSNumber *stored_start = animation_start_times[key];
	if (stored_start == nil) {
		stored_start = @(now);
		animation_start_times[key] = stored_start;
	}
	NSMutableArray<NSNumber *> *durations = [NSMutableArray arrayWithCapacity:(NSUInteger)frame_count];
	NSTimeInterval total_duration = 0.0;
	for (NSInteger frame = 0; frame < frame_count; ++frame) {
		[animated_representation setProperty:NSImageCurrentFrame withValue:@(frame)];
		NSTimeInterval duration = [[animated_representation valueForProperty:NSImageCurrentFrameDuration] doubleValue];
		if (!isfinite(duration) || duration <= 0.0)
			duration = 0.1;
		[durations addObject:@(duration)];
		total_duration += duration;
	}
	if (total_duration <= 0.0)
		return;
	NSTimeInterval elapsed = MAX(0.0, now - stored_start.doubleValue);
	NSInteger loop_count = [[animated_representation valueForProperty:NSImageLoopCount] integerValue];
	if (loop_count > 0 && elapsed >= total_duration * loop_count) {
		[animated_representation setProperty:NSImageCurrentFrame withValue:@(frame_count - 1)];
		return;
	}
	NSTimeInterval cycle_position = fmod(elapsed, total_duration);
	NSInteger selected_frame = frame_count - 1;
	for (NSInteger frame = 0; frame < frame_count; ++frame) {
		if (cycle_position < durations[(NSUInteger)frame].doubleValue) {
			selected_frame = frame;
			break;
		}
		cycle_position -= durations[(NSUInteger)frame].doubleValue;
	}
	[animated_representation setProperty:NSImageCurrentFrame withValue:@(selected_frame)];
}

#include "native/include/native_float_image.h"

static CGImageRef native_copy_cg_image(gg__Image *image) {
	if (image == NULL || image->data == NULL || image->width <= 0 || image->height <= 0) {
		return NULL;
	}
	if (image->nr_channels == VOX_FLOAT_RGBA_CHANNEL_MARKER)
		return native_copy_float_rgba_image(image->data, image->width, image->height);
	if (image->path.len > 0) {
		NSImage *native_image = (__bridge NSImage *)image->data;
		native_update_animated_image_frame(native_image);
		CGImageRef cg_image = [native_image CGImageForProposedRect:NULL context:nil hints:nil];
		return cg_image == NULL ? NULL : CGImageCreateCopy(cg_image);
	}
	// create_image_from_byte_array() stores stb-decoded RGBA pixels rather than
	// an NSImage in Image.data. Wrap those bytes directly instead of treating
	// their first machine word as an Objective-C object.
	if (image->nr_channels < 4 || (image->nr_channels > 7
	    && image->nr_channels != VOX_PNG_ICC_CHANNEL_MARKER)) {
		return NULL;
	}
	size_t bytes_per_row = (size_t)image->width * 4;
	NSData *icc_profile = image->nr_channels == VOX_PNG_ICC_CHANNEL_MARKER
	    ? native_image_icc_profile(image->data, image->width, image->height) : nil;
	NSData *icc_pixels = nil;
	VoxImageColorProfile icc_color_profile = { 0 };
	CGDataProviderRef provider = icc_pixels
	    ? CGDataProviderCreateWithCFData((__bridge CFDataRef)icc_pixels)
	    : CGDataProviderCreateWithData(NULL, image->data,
	        bytes_per_row * (size_t)image->height, NULL);
	CGColorSpaceRef color_space = icc_profile && (!icc_pixels || icc_color_profile.values[0] == -1)
	    ? CGColorSpaceCreateWithICCData((__bridge CFDataRef)icc_profile) : NULL;
	if (!color_space) color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	CGImageRef cg_image = CGImageCreate((size_t)image->width, (size_t)image->height,
		8, 32, bytes_per_row, color_space,
		((icc_pixels || image->nr_channels == 5 || image->nr_channels == 7)
			? kCGImageAlphaPremultipliedLast : kCGImageAlphaLast)
			| kCGBitmapByteOrder32Big, provider, NULL, false,
		kCGRenderingIntentDefault);
	CGColorSpaceRelease(color_space);
	CGDataProviderRelease(provider);
	return cg_image;
}



int native_draw_svg_image_pattern(gg__Image *image, const float *path, int count,
    int even_odd, const float *outer, const float *inner, const float *tile,
    const float *destination, const float *clip, float page_x, float page_y,
    float scroll_y, float canvas_width, float canvas_height, float opacity, int nearest) {
    return 0;
}

static void native_prepare_image_cpu_fallback(CGContextRef context) {
    (void)context;
}

#include "native/include/native_rounded_image_clip.h"
#include "native/include/native_rounded_image_pixels.h"
#include "native/include/native_sampled_png_darwin.h"

static void native_draw_image_part_in_context(CGContextRef context, gg__Image *image,
	float destination_x, float destination_y, float destination_width,
	float destination_height, float source_x, float source_y, float source_width,
	float source_height, float clip_x, float clip_y, float clip_width,
	float clip_height, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x,
	float page_y, float scroll_y, float canvas_width, float canvas_height, float opacity,
	int nearest_neighbor, float const *clip_radii, int image_flags) {
	if (context == NULL || image == NULL || image->data == NULL
		|| destination_width <= 0 || destination_height <= 0
		|| source_width <= 0 || source_height <= 0
		|| clip_width <= 0 || clip_height <= 0) {
		return;
	}
	if (native_try_v_rounded_image(context, image, destination_x, destination_y,
		destination_width, destination_height, source_x, source_y, source_width, source_height,
		clip_x, clip_y, clip_width, clip_height, transform_a, transform_b, transform_c, transform_d,
		transform_e, transform_f, page_x, page_y, scroll_y, canvas_width, canvas_height, opacity, clip_radii, image_flags)) return;
	CGImageRef image_copy = native_copy_cg_image(image);
	if (image_copy == NULL) {
		return;
	}
	CGFloat pixel_scale_x = (CGFloat)CGImageGetWidth(image_copy) / image->width;
	CGFloat pixel_scale_y = (CGFloat)CGImageGetHeight(image_copy) / image->height;
	CGRect source_rect = CGRectMake(source_x * pixel_scale_x,
		source_y * pixel_scale_y, source_width * pixel_scale_x,
		source_height * pixel_scale_y);
	CGImageRef source_image = CGImageCreateWithImageInRect(image_copy, source_rect);
	CGImageRelease(image_copy);
	if (source_image == NULL) {
		return;
	}
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	CGContextSaveGState(context);
	CGContextConcatCTM(context, to_canvas);
	if (clip_radii && vox_apply_rounded_image_clip(context,
		CGRectMake(clip_x, clip_y, clip_width, clip_height), clip_radii)) {
		// V coverage is installed; keep the existing image sampling below.
	} else if (clip_radii) {
		CGPathRef path = native_create_corner_rounded_rect_path(clip_x, clip_y, clip_width, clip_height,
			clip_radii[0], clip_radii[1], clip_radii[2], clip_radii[3],
			clip_radii[4], clip_radii[5], clip_radii[6], clip_radii[7]);
		CGContextAddPath(context, path);
		CGContextClip(context);
		CGPathRelease(path);
	} else {
		CGContextClipToRect(context, CGRectMake(clip_x, clip_y, clip_width, clip_height));
	}
	CGContextSetAlpha(context, MIN(MAX(opacity, 0.0f), 1.0f));
	CGContextSetInterpolationQuality(context, nearest_neighbor == 1
		? kCGInterpolationNone
		: nearest_neighbor == 2 ? kCGInterpolationLow : kCGInterpolationHigh);
	// Quartz images use y-up image space. Flip only the destination image inside
	// the surrounding CSS y-down transform so its first decoded row stays on top.
	CGContextTranslateCTM(context, destination_x, destination_y + destination_height);
	CGContextScaleCTM(context, 1.0, -1.0);
	CGContextDrawImage(context, CGRectMake(0, 0, destination_width,
		destination_height), source_image);
	CGContextRestoreGState(context);
	CGImageRelease(source_image);
}

void native_draw_image_part(gg__Image *image, float destination_x, float destination_y,
	float destination_width, float destination_height, float source_x, float source_y,
	float source_width, float source_height, float canvas_height, float opacity) {
	if (image == NULL || image->data == NULL || destination_width <= 0 || destination_height <= 0
	    || source_width <= 0 || source_height <= 0) {
		return;
	}
	if (image->path.len == 0) {
		CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
		native_draw_image_part_in_context(context, image, destination_x, destination_y,
			destination_width, destination_height, source_x, source_y, source_width,
			source_height, destination_x, destination_y, destination_width,
			destination_height, 1, 0, 0, 1, 0, 0, 0, 0, 0,
			destination_x + destination_width, canvas_height,
			opacity, 1, NULL, 0);
		return;
	}
	NSImage *native_image = (__bridge NSImage *)image->data;
	native_update_animated_image_frame(native_image);
	NSRect destination = NSMakeRect(destination_x,
		canvas_height - destination_y - destination_height, destination_width, destination_height);
	// CSS image coordinates start at the top-left. NSImage source rectangles use
	// the native bottom-left coordinate system.
	NSRect source = NSMakeRect(source_x, image->height - source_y - source_height,
		source_width, source_height);
	[native_image drawInRect:destination
	              fromRect:source
	             operation:NSCompositingOperationSourceOver
	              fraction:MIN(MAX(opacity, 0.0f), 1.0f)
	        respectFlipped:NO
	                 hints:@{ NSImageHintInterpolation: @(NSImageInterpolationNone) }];
}

void native_set_image_resource_identity(const char *value, int length) {
}

void native_add_image_decoding_hint(const char *value, int length, int async) {
}

void native_begin_image_decode_frame(const void *document, uint64_t paint_generation,
    uint64_t navigation) {
}

void native_set_image_decode_scope(uint64_t scope) {
}

void native_draw_image_part_transformed(gg__Image *image, float destination_x,
	float destination_y, float destination_width, float destination_height,
	float source_x, float source_y, float source_width, float source_height,
	float clip_x, float clip_y, float clip_width, float clip_height,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_width, float canvas_height, float opacity, int nearest_neighbor, float const *clip_radii) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	native_draw_image_part_in_context(context, image, destination_x, destination_y,
		destination_width, destination_height, source_x, source_y, source_width,
		source_height, clip_x, clip_y, clip_width, clip_height, transform_a,
		transform_b, transform_c, transform_d, transform_e, transform_f, page_x,
		page_y, scroll_y, canvas_width, canvas_height, opacity, nearest_neighbor, clip_radii, 0);
}

void native_draw_image_part_transformed_background(gg__Image *image, float destination_x,
	float destination_y, float destination_width, float destination_height,
	float source_x, float source_y, float source_width, float source_height,
	float clip_x, float clip_y, float clip_width, float clip_height,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_width, float canvas_height, float opacity,
	int nearest_neighbor, float const *clip_radii, int unclamped_source) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	native_draw_image_part_in_context(context, image, destination_x, destination_y,
		destination_width, destination_height, source_x, source_y, source_width,
		source_height, clip_x, clip_y, clip_width, clip_height, transform_a,
		transform_b, transform_c, transform_d, transform_e, transform_f, page_x,
		page_y, scroll_y, canvas_width, canvas_height, opacity, nearest_neighbor,
		clip_radii, unclamped_source ? VOX_GRAPHITE_IMAGE_UNCLAMPED_SOURCE : 0);
}

void native_draw_image_part_transformed_clipped(gg__Image *image, float destination_x,
	float destination_y, float destination_width, float destination_height,
	float source_x, float source_y, float source_width, float source_height,
	float clip_x, float clip_y, float clip_width, float clip_height,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_width, float canvas_height, float opacity, int nearest_neighbor, float const *clip_radii, int explicit_rectangle_clip) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	native_draw_image_part_in_context(context, image, destination_x, destination_y,
		destination_width, destination_height, source_x, source_y, source_width,
		source_height, clip_x, clip_y, clip_width, clip_height, transform_a,
		transform_b, transform_c, transform_d, transform_e, transform_f, page_x,
		page_y, scroll_y, canvas_width, canvas_height, opacity, nearest_neighbor, clip_radii, explicit_rectangle_clip ? VOX_GRAPHITE_IMAGE_EXPLICIT_RECT_CLIP : 0);
}

// Replay a validated background/image/opaque rounded CSS-mask scope atomically.
// Source normalization and color profiles match ordinary replaced-image draws.
int native_draw_rounded_masked_image(gg__Image *image, const float *rects,
    const float *clip, const float *transform, float page_x, float page_y,
    float canvas_width, float canvas_height, gg__Color background, int nearest) {
    return 0;
}

// A gapless background crossing a tile boundary is one image shader. Cropping
// and clamping separate tiles loses the bilinear samples from the next repeat.
int native_draw_image_pattern_transformed(gg__Image *image,
	float tile_x, float tile_y, float tile_width, float tile_height,
	float bounds_x, float bounds_y, float bounds_width, float bounds_height,
	float clip_x, float clip_y, float clip_width, float clip_height,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_width, float canvas_height, float opacity,
	int nearest_neighbor, float const *clip_radii, int pattern_flags) {
	return 0;
}

// A background's tiles, eight floats each: the destination and source
// rectangles native_draw_image_part_transformed() would receive. The GPU
// painter draws them in one pass; otherwise each tile is drawn on its own.
void native_draw_image_tiles_transformed(gg__Image *image, float const *tiles,
	int tile_count, float clip_x, float clip_y, float clip_width, float clip_height,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_width, float canvas_height, float opacity,
	int nearest_neighbor, float const *clip_radii) {
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context == NULL || image == NULL || image->data == NULL || tiles == NULL
		|| tile_count <= 0) {
		return;
	}
	for (int index = 0; index < tile_count; ++index) {
		float const *tile = tiles + (size_t)index * 8;
		native_draw_image_part_in_context(context, image, tile[0], tile[1], tile[2],
			tile[3], tile[4], tile[5], tile[6], tile[7], clip_x, clip_y, clip_width,
			clip_height, transform_a, transform_b, transform_c, transform_d,
			transform_e, transform_f, page_x, page_y, scroll_y, canvas_width,
			canvas_height, opacity, nearest_neighbor, clip_radii, 0);
	}
}

void native_draw_repeated_image_transformed(gg__Image *image,
	float destination_x, float destination_y, float destination_width,
	float destination_height, float clip_x, float clip_y, float clip_width,
	float clip_height, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x,
	float page_y, float scroll_y, float canvas_height, float opacity,
	int nearest_neighbor, int repeat_x, int repeat_y) {
	if (image == NULL || image->data == NULL || destination_width <= 0.0f
		|| destination_height <= 0.0f || clip_width <= 0.0f
		|| clip_height <= 0.0f || (!repeat_x && !repeat_y)) {
		return;
	}
	CGImageRef image_copy = native_copy_cg_image(image);
	if (image_copy == NULL) {
		return;
	}
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	CGContextSaveGState(context);
	CGContextConcatCTM(context, to_canvas);
	CGContextClipToRect(context, CGRectMake(clip_x, clip_y, clip_width, clip_height));
	if (!repeat_x) {
		CGContextClipToRect(context, CGRectMake(destination_x, clip_y,
			destination_width, clip_height));
	}
	if (!repeat_y) {
		CGContextClipToRect(context, CGRectMake(clip_x, destination_y,
			clip_width, destination_height));
	}
	CGContextSetAlpha(context, MIN(MAX(opacity, 0.0f), 1.0f));
	CGContextSetInterpolationQuality(context,
		nearest_neighbor ? kCGInterpolationNone : kCGInterpolationMedium);
	// Keep the same CSS-y-down to Quartz-image orientation as the single-image
	// primitive, but tile the complete clipped extent in one Quartz operation.
	CGContextTranslateCTM(context, destination_x,
		destination_y + destination_height);
	CGContextScaleCTM(context, 1.0, -1.0);
	CGContextDrawTiledImage(context,
		CGRectMake(0, 0, destination_width, destination_height), image_copy);
	CGContextRestoreGState(context);
	CGImageRelease(image_copy);
}

void native_add_svg_content_mask_image(gg__Image *image, float destination_x,
	float destination_y, float destination_width, float destination_height,
	float source_x, float source_y, float source_width, float source_height,
	float clip_x, float clip_y, float clip_width, float clip_height,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_height, int nearest_neighbor) {
	if (native_svg_clip_image != NULL || native_svg_clip_build_context == NULL) {
		return;
	}
	native_draw_image_part_in_context(native_svg_clip_build_context, image,
		destination_x, destination_y, destination_width, destination_height,
		source_x, source_y, source_width, source_height, clip_x, clip_y,
		clip_width, clip_height, transform_a, transform_b, transform_c,
		transform_d, transform_e, transform_f, page_x, page_y, scroll_y,
		(float)CGBitmapContextGetWidth(native_svg_clip_build_context),
		canvas_height, 1.0f, nearest_neighbor ? 1 : 2, NULL, 0);
}

#define NATIVE_SVG_PATTERN_CACHE_SIZE 8
#define NATIVE_SVG_PATTERN_STACK_SIZE 16

typedef struct {
	uint64_t key;
	CGImageRef image;
	uint64_t last_use;
} NativeSVGPatternCacheEntry;

typedef struct {
	uint64_t key;
	CGContextRef context;
	CGImageRef image;
	float width;
	float height;
} NativeSVGPatternBuild;

static NativeSVGPatternCacheEntry native_svg_pattern_cache[NATIVE_SVG_PATTERN_CACHE_SIZE];
static NativeSVGPatternBuild native_svg_pattern_stack[NATIVE_SVG_PATTERN_STACK_SIZE];
static int native_svg_pattern_stack_depth;
static uint64_t native_svg_pattern_cache_clock;

static CGContextRef native_svg_pattern_context(void) {
	if (native_css_filter_stack_depth > 0) {
		NativeCSSFilterLayer const *filter =
			&native_css_filter_stack[native_css_filter_stack_depth - 1];
		if (filter->routes_pattern_paint && filter->active) {
			return filter->context;
		}
	}
	if (native_svg_pattern_stack_depth <= 0) {
		return NULL;
	}
	return native_svg_pattern_stack[native_svg_pattern_stack_depth - 1].context;
}

void native_begin_svg_pattern_filter_layer(float canvas_width,
	float canvas_height) {
	if (native_css_filter_stack_depth >= NATIVE_CSS_FILTER_MAX_DEPTH) {
		native_css_filter_overflow_depth++;
		return;
	}
	CGContextRef destination = native_svg_pattern_context();
	NativeCSSFilterLayer layer = {
		.destination = destination,
		.canvas_width = canvas_width,
		.canvas_height = canvas_height,
		.scale = 1.0,
		.routes_pattern_paint = 1,
	};
	if (destination != NULL && canvas_width > 0.0f && canvas_height > 0.0f) {
		CGAffineTransform transform = CGContextGetCTM(destination);
		CGFloat scale_x = hypot(transform.a, transform.b);
		CGFloat scale_y = hypot(transform.c, transform.d);
		layer.scale = MAX(MAX(scale_x, scale_y), 1.0);
		size_t width = (size_t)MAX(1.0, ceil(canvas_width * layer.scale));
		size_t height = (size_t)MAX(1.0, ceil(canvas_height * layer.scale));
		CGColorSpaceRef color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
		layer.context = CGBitmapContextCreate(NULL, width, height, 8, width * 4,
			color_space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
		CGColorSpaceRelease(color_space);
		if (layer.context != NULL) {
			CGContextScaleCTM(layer.context, layer.scale, layer.scale);
			CGContextSetShouldAntialias(layer.context, true);
			CGContextSetInterpolationQuality(layer.context, kCGInterpolationHigh);
			layer.active = 1;
		}
	}
	native_css_filter_stack[native_css_filter_stack_depth++] = layer;
}

void native_end_svg_pattern_filter_layer(void) {
	if (native_css_filter_overflow_depth > 0) {
		native_css_filter_overflow_depth--;
		return;
	}
	if (native_css_filter_stack_depth <= 0) {
		return;
	}
	NativeCSSFilterLayer layer =
		native_css_filter_stack[--native_css_filter_stack_depth];
	if (!layer.routes_pattern_paint || !layer.active) {
		if (layer.context != NULL) {
			CGContextRelease(layer.context);
		}
		free(layer.operations);
		native_free_svg_filter_graph(&layer);
		return;
	}
	CGContextFlush(layer.context);
	CGImageRef source_image = CGBitmapContextCreateImage(layer.context);
	CGContextRelease(layer.context);
	if (source_image == NULL) {
		free(layer.operations);
		native_free_svg_filter_graph(&layer);
		return;
	}
	@autoreleasepool {
		native_initialize_css_filter_renderer();
		CIImage *output = native_apply_css_filter_layer(&layer, source_image);
		CGRect source_rect = CGRectMake(0, 0, CGImageGetWidth(source_image),
			CGImageGetHeight(source_image));
		CGImageRef filtered_image = [native_css_filter_ci_context
			createCGImage:output fromRect:source_rect format:kCIFormatRGBA8
			colorSpace:native_css_filter_color_space];
		if (filtered_image != NULL && layer.destination != NULL) {
			CGContextDrawImage(layer.destination,
				CGRectMake(0, 0, layer.canvas_width, layer.canvas_height),
				filtered_image);
			CGImageRelease(filtered_image);
		}
	}
	CGImageRelease(source_image);
	free(layer.operations);
	native_free_svg_filter_graph(&layer);
}

void native_begin_svg_pattern_tile(unsigned long long input_key, float tile_width,
	float tile_height, float content_scale_x, float content_scale_y) {
	if (native_svg_pattern_stack_depth >= NATIVE_SVG_PATTERN_STACK_SIZE) {
		return;
	}
	NativeSVGPatternBuild build = { 0 };
	build.width = tile_width;
	build.height = tile_height;
	CGFloat backing_scale = native_svg_mask_backing_scale();
	content_scale_x = isfinite(content_scale_x) && content_scale_x > 0.0f
		? content_scale_x : 1.0f;
	content_scale_y = isfinite(content_scale_y) && content_scale_y > 0.0f
		? content_scale_y : 1.0f;
	CGFloat scale_x = backing_scale * content_scale_x;
	CGFloat scale_y = backing_scale * content_scale_y;
	uint64_t key = native_svg_clip_hash_float((uint64_t)input_key, (float)backing_scale);
	key = native_svg_clip_hash_float(key, content_scale_x);
	key = native_svg_clip_hash_float(key, content_scale_y);
	key = native_svg_clip_hash_float(key, tile_width);
	key = native_svg_clip_hash_float(key, tile_height);
	build.key = key;
	native_svg_pattern_cache_clock++;
	for (int index = 0; index < NATIVE_SVG_PATTERN_CACHE_SIZE; ++index) {
		if (native_svg_pattern_cache[index].image != NULL
			&& native_svg_pattern_cache[index].key == key) {
			native_svg_pattern_cache[index].last_use = native_svg_pattern_cache_clock;
			build.image = CGImageRetain(native_svg_pattern_cache[index].image);
			native_svg_pattern_stack[native_svg_pattern_stack_depth++] = build;
			return;
		}
	}
	if (!isfinite(tile_width) || !isfinite(tile_height) || tile_width <= 0.0f
		|| tile_height <= 0.0f) {
		native_svg_pattern_stack[native_svg_pattern_stack_depth++] = build;
		return;
	}
	size_t width = (size_t)MAX(1.0, ceil(tile_width * scale_x));
	size_t height = (size_t)MAX(1.0, ceil(tile_height * scale_y));
	CGColorSpaceRef color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	build.context = CGBitmapContextCreate(NULL, width, height, 8, width * 4,
		color_space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	CGColorSpaceRelease(color_space);
	if (build.context != NULL) {
		CGContextScaleCTM(build.context, scale_x, scale_y);
		CGContextSetShouldAntialias(build.context, true);
		CGContextSetInterpolationQuality(build.context, kCGInterpolationHigh);
	}
	native_svg_pattern_stack[native_svg_pattern_stack_depth++] = build;
}

void native_begin_svg_pattern_opacity(float opacity) {
	CGContextRef context = native_svg_pattern_context();
	if (context == NULL) {
		return;
	}
	CGContextSaveGState(context);
	CGContextSetAlpha(context, fminf(fmaxf(opacity, 0.0f), 1.0f));
	native_begin_tracked_transparency_layer(context, NULL);
}

void native_end_svg_pattern_opacity(void) {
	CGContextRef context = native_svg_pattern_context();
	if (context == NULL) {
		return;
	}
	native_end_tracked_transparency_layer(context);
	CGContextRestoreGState(context);
}

void native_add_svg_pattern_path(const float *data, int segment_count,
	int even_odd, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float canvas_height,
	gg__Color fill_color, int has_fill, gg__Color stroke_color, int has_stroke,
	float stroke_width, int line_cap, int line_join, float miter_limit,
	int stroke_first) {
	CGContextRef context = native_svg_pattern_context();
	if (context == NULL || data == NULL || segment_count <= 0
		|| (!has_fill && !has_stroke)) {
		return;
	}
	CGMutablePathRef path = native_create_path_from_data(data, segment_count);
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, transform_e, canvas_height - transform_f);
	CGContextSaveGState(context);
	CGContextConcatCTM(context, to_canvas);
	CGColorRef fill = NULL;
	CGColorRef stroke = NULL;
	if (has_fill) {
		fill = native_srgb_color(fill_color);
		CGContextSetFillColorWithColor(context, fill);
	}
	if (has_stroke) {
		stroke = native_srgb_color(stroke_color);
		CGContextSetStrokeColorWithColor(context, stroke);
		CGContextSetLineWidth(context, MAX(stroke_width, 0.0));
		CGContextSetLineCap(context, line_cap == 1 ? kCGLineCapRound
			: line_cap == 2 ? kCGLineCapSquare : kCGLineCapButt);
		CGContextSetLineJoin(context, line_join == 1 ? kCGLineJoinRound
			: line_join == 2 ? kCGLineJoinBevel : kCGLineJoinMiter);
		CGContextSetMiterLimit(context, MAX(miter_limit, 1.0));
	}
	if (stroke_first && has_stroke) {
		native_draw_svg_mask_path_part(context, path, 0, even_odd);
	}
	if (has_fill) {
		native_draw_svg_mask_path_part(context, path, 1, even_odd);
	}
	if (!stroke_first && has_stroke) {
		native_draw_svg_mask_path_part(context, path, 0, even_odd);
	}
	if (fill != NULL) CGColorRelease(fill);
	if (stroke != NULL) CGColorRelease(stroke);
	CGContextRestoreGState(context);
	CGPathRelease(path);
}

void native_add_svg_pattern_linear_gradient_path(const float *data,
	int segment_count, int even_odd, float transform_a, float transform_b,
	float transform_c, float transform_d, float transform_e, float transform_f,
	float canvas_height, int stroke, float stroke_width, int line_cap,
	int line_join, float miter_limit, float start_x, float start_y, float end_x,
	float end_y, float gradient_a, float gradient_b, float gradient_c,
	float gradient_d, float gradient_e, float gradient_f, int spread_method,
	int linear_color_space, const float *stop_data, int stop_count, float opacity) {
	native_draw_svg_linear_gradient_path_in_context(native_svg_pattern_context(),
		data, segment_count, even_odd, transform_a, transform_b, transform_c,
		transform_d, transform_e, transform_f, 0, 0, 0, canvas_height, stroke,
		stroke_width, line_cap, line_join, miter_limit, start_x, start_y, end_x,
		end_y, gradient_a, gradient_b, gradient_c, gradient_d, gradient_e,
		gradient_f, spread_method, linear_color_space, stop_data, stop_count,
		opacity);
}

void native_add_svg_pattern_radial_gradient_path(const float *data,
	int segment_count, int even_odd, float transform_a, float transform_b,
	float transform_c, float transform_d, float transform_e, float transform_f,
	float canvas_height, int stroke, float stroke_width, int line_cap,
	int line_join, float miter_limit, float start_x, float start_y,
	float start_radius, float end_x, float end_y, float end_radius,
	float gradient_a, float gradient_b, float gradient_c, float gradient_d,
	float gradient_e, float gradient_f, int spread_method, int linear_color_space,
	const float *stop_data, int stop_count, float opacity) {
	native_draw_svg_radial_gradient_path_in_context(native_svg_pattern_context(),
		data, segment_count, even_odd, transform_a, transform_b, transform_c,
		transform_d, transform_e, transform_f, 0, 0, 0, canvas_height, stroke,
		stroke_width, line_cap, line_join, miter_limit, start_x, start_y,
		start_radius, end_x, end_y, end_radius, gradient_a, gradient_b, gradient_c,
		gradient_d, gradient_e, gradient_f, spread_method, linear_color_space,
		stop_data, stop_count, opacity);
}

void native_add_svg_pattern_image(gg__Image *image, float destination_x,
	float destination_y, float destination_width, float destination_height,
	float source_x, float source_y, float source_width, float source_height,
	float clip_x, float clip_y, float clip_width, float clip_height,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float canvas_height, float opacity,
	int nearest_neighbor) {
	native_draw_image_part_in_context(native_svg_pattern_context(), image,
		destination_x, destination_y, destination_width, destination_height,
		source_x, source_y, source_width, source_height, clip_x, clip_y, clip_width,
		clip_height, transform_a, transform_b, transform_c, transform_d,
		transform_e, transform_f, 0, 0, 0,
		(float)CGBitmapContextGetWidth(native_svg_pattern_context()), canvas_height, opacity,
		nearest_neighbor, NULL, 0);
}

static void native_cache_svg_pattern_image(uint64_t key, CGImageRef image) {
	int slot = -1;
	uint64_t oldest = UINT64_MAX;
	for (int index = 0; index < NATIVE_SVG_PATTERN_CACHE_SIZE; ++index) {
		if (native_svg_pattern_cache[index].image == NULL) {
			slot = index;
			break;
		}
		if (native_svg_pattern_cache[index].last_use < oldest) {
			oldest = native_svg_pattern_cache[index].last_use;
			slot = index;
		}
	}
	if (slot < 0) return;
	if (native_svg_pattern_cache[slot].image != NULL) {
		CGImageRelease(native_svg_pattern_cache[slot].image);
	}
	native_svg_pattern_cache[slot].key = key;
	native_svg_pattern_cache[slot].image = CGImageRetain(image);
	native_svg_pattern_cache[slot].last_use = native_svg_pattern_cache_clock;
}

void native_finish_svg_pattern_path(const float *data, int segment_count,
	int even_odd, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x,
	float page_y, float scroll_y, float canvas_height, int stroke,
	float stroke_width, int line_cap, int line_join, float miter_limit,
	float tile_x, float tile_y, float tile_width, float tile_height,
	float pattern_a, float pattern_b, float pattern_c, float pattern_d,
	float pattern_e, float pattern_f, float opacity, int content_mask) {
	if (native_svg_pattern_stack_depth <= 0) return;
	NativeSVGPatternBuild build =
		native_svg_pattern_stack[--native_svg_pattern_stack_depth];
	CGImageRef image = build.image;
	if (image == NULL && build.context != NULL) {
		image = CGBitmapContextCreateImage(build.context);
		CGContextRelease(build.context);
		if (image != NULL) native_cache_svg_pattern_image(build.key, image);
	}
	if (image == NULL || data == NULL || segment_count <= 0) {
		if (image != NULL) CGImageRelease(image);
		return;
	}
	CGContextRef destination = NULL;
	if (native_svg_pattern_stack_depth > 0) {
		destination = native_svg_pattern_context();
	} else if (content_mask) {
		if (native_svg_clip_image == NULL) destination = native_svg_clip_build_context;
	} else {
		destination = [[NSGraphicsContext currentContext] CGContext];
	}
	if (destination == NULL) {
		CGImageRelease(image);
		return;
	}
	CGMutablePathRef path = native_create_path_from_data(data, segment_count);
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	CGAffineTransform pattern_transform = CGAffineTransformMake(pattern_a,
		pattern_b, pattern_c, pattern_d, pattern_e, pattern_f);
	CGContextSaveGState(destination);
	CGContextConcatCTM(destination, to_canvas);
	CGContextAddPath(destination, path);
	if (stroke) {
		CGContextSetLineWidth(destination, MAX(stroke_width, 0.0));
		CGContextSetLineCap(destination, line_cap == 1 ? kCGLineCapRound
			: line_cap == 2 ? kCGLineCapSquare : kCGLineCapButt);
		CGContextSetLineJoin(destination, line_join == 1 ? kCGLineJoinRound
			: line_join == 2 ? kCGLineJoinBevel : kCGLineJoinMiter);
		CGContextSetMiterLimit(destination, MAX(miter_limit, 1.0));
		CGContextReplacePathWithStrokedPath(destination);
		CGContextClip(destination);
	} else if (even_odd) {
		CGContextEOClip(destination);
	} else {
		CGContextClip(destination);
	}
	CGContextSetAlpha(destination, fminf(fmaxf(opacity, 0.0f), 1.0f));
	// The tile surface already includes both the backing scale and the target's
	// accumulated content scale. Replay it without a second interpolation pass.
	CGContextSetInterpolationQuality(destination, kCGInterpolationNone);
	CGContextConcatCTM(destination, pattern_transform);
	// CGImage rows have the opposite vertical convention from the Skia tile
	// surface. Reflect each repeating cell around its own center so asymmetric
	// edge coverage and non-symmetric pattern content retain SVG y-down order.
	CGContextTranslateCTM(destination, 0, 2.0f * tile_y + tile_height);
	CGContextScaleCTM(destination, 1, -1);
	CGContextDrawTiledImage(destination,
		CGRectMake(tile_x, tile_y, tile_width, tile_height), image);
	CGContextRestoreGState(destination);
	CGPathRelease(path);
	CGImageRelease(image);
}

static void native_schedule_screenshot(string output_path, BOOL document_only,
                                       double top, double width, double height,
                                       void *owner, void (*callback)(void *)) {
	NSString *path = native_capture_string(output_path);
	const char *delay_value = getenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS");
	double delay = delay_value == NULL ? 0.1 : strtod(delay_value, NULL);
	if (delay < 0.0) {
		delay = 0.0;
	}
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
	               dispatch_get_main_queue(), ^{
		native_when_document_work_idle(^{
		native_capture_instruction_checkpoint("capture_started");
		NSView *view = native_browser_view();
		[view displayIfNeeded];
		NSRect bounds = [view bounds];
		if (document_only) {
			// The caller supplies logical document dimensions and an inset measured
			// from the top of the content view, regardless of its coordinate direction.
			if (!isfinite(top) || !isfinite(width) || !isfinite(height)
			    || !isfinite(bounds.origin.x) || !isfinite(bounds.origin.y)
			    || !isfinite(bounds.size.width) || !isfinite(bounds.size.height)
			    || top < 0.0 || width <= 0.0 || height <= 0.0
			    || width > bounds.size.width || top > bounds.size.height
			    || height > bounds.size.height - top) {
				fprintf(stderr, "Ladybird V: invalid document screenshot bounds top=%g %gx%g in %gx%g\n",
				        top, width, height, bounds.size.width, bounds.size.height);
				[NSApp terminate:nil];
				return;
			}
			bounds.origin.y += [view isFlipped] ? top : bounds.size.height - top - height;
			bounds.size = NSMakeSize(width, height);
			double scaled_width = width * native_screenshot_scale();
			double scaled_height = height * native_screenshot_scale();
			if (!isfinite(bounds.origin.y) || !isfinite(scaled_width) || !isfinite(scaled_height)
			    || scaled_width >= (double)NSIntegerMax / 4.0
			    || scaled_height >= (double)NSIntegerMax) {
				fprintf(stderr, "Ladybird V: document screenshot dimensions overflow\n");
				[NSApp terminate:nil];
				return;
			}
		}
		// Headless Ladybird paints one device pixel per CSS pixel. Capture the native
		// viewer at the same scale instead of snapshotting its Retina backing store
		// and resampling it afterwards; resampling changes every antialiased edge.
		NSInteger pixels_wide = (NSInteger)llround(bounds.size.width * native_screenshot_scale());
		NSInteger pixels_high = (NSInteger)llround(bounds.size.height * native_screenshot_scale());
		if (pixels_wide <= 0 || pixels_high <= 0) {
			fprintf(stderr, "Ladybird V: invalid screenshot dimensions %.0fx%.0f\n",
			        bounds.size.width, bounds.size.height);
			[NSApp terminate:nil];
			return;
		}
		NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
			initWithBitmapDataPlanes:NULL
			              pixelsWide:pixels_wide
			              pixelsHigh:pixels_high
			           bitsPerSample:8
			         samplesPerPixel:4
			                hasAlpha:YES
			                isPlanar:NO
			          colorSpaceName:NSDeviceRGBColorSpace
			             bytesPerRow:pixels_wide * 4
			            bitsPerPixel:32];
		[bitmap setSize:bounds.size];
		if (bitmap == nil) {
			fprintf(stderr, "Ladybird V: could not allocate a bitmap for the window screenshot\n");
			[NSApp terminate:nil];
			return;
		}
		NSBitmapImageRep *presented = native_presented_capture_bitmap(view, bounds, pixels_wide, pixels_high);
		if (presented) bitmap = presented;
		else native_cache_display_in_bitmap(view, bounds, bitmap);
		native_capture_instruction_checkpoint("capture_cached");
		// The backing store follows the display profile (usually Display P3 on modern Macs).
		// Normalize captures to sRGB so pixel comparisons do not report a page-sized color-space
		// delta against Ladybird's untagged screenshot output.
		NSBitmapImageRep *encodedBitmap = presented ?:
		    [bitmap bitmapImageRepByConvertingToColorSpace:[NSColorSpace sRGBColorSpace]
		                                  renderingIntent:NSColorRenderingIntentRelativeColorimetric];
		if (encodedBitmap == nil) {
			encodedBitmap = bitmap;
		}
		native_capture_instruction_checkpoint("capture_converted");
		NSData *png = native_encode_snapshot_png(encodedBitmap);
		if (!document_only) native_capture_instruction_checkpoint("capture_encoded");
		if (png == nil) {
			fprintf(stderr, "Ladybird V: could not encode the window screenshot as PNG\n");
			[NSApp terminate:nil];
			return;
		}
		if (document_only) {
			vox_coalition_instruction_checkpoint("capture_document_encoded");
			native_capture_instruction_checkpoint("capture_document_encoded");
		}
		NSError *write_error = nil;
		BOOL saved = [png writeToFile:path options:NSDataWritingAtomic error:&write_error];
		if (!saved) {
			write_error = nil;
			saved = [png writeToFile:path options:0 error:&write_error];
		}
		if (saved) {
			fprintf(stdout, "Saved Ladybird V window screenshot: %s\n", [path fileSystemRepresentation]);
			fflush(stdout);
			if (callback != NULL) callback(owner);
		} else {
			fprintf(stderr, "Ladybird V: could not save screenshot to %s: %s\n",
			        [path fileSystemRepresentation],
			        write_error == nil ? "unknown error" : [[write_error localizedDescription] UTF8String]);
		}
		[NSApp terminate:nil];
		});
	});
}

void schedule_native_screenshot(string output_path) {
	native_schedule_screenshot(output_path, NO, 0.0, 0.0, 0.0, NULL, NULL);
}

void schedule_native_document_screenshot(string output_path, double top, double width, double height,
                                         void *owner, void (*callback)(void *)) {
	native_schedule_screenshot(output_path, YES, top, width, height, owner, callback);
}

// Cocoa imports tgmath macros; V emits the C math declarations after this file.
// Leave the ordinary function names available for those declarations.
#ifdef remainder
#undef remainder
#endif
#ifdef fma
#undef fma
#endif
