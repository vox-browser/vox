#include <Cocoa/Cocoa.h>
#include "native_test_window_darwin.h"
#include <CoreImage/CoreImage.h>
#include <CoreText/CoreText.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <execinfo.h>
#include <unistd.h>
#include "processmetrics/instruction_counter_darwin.h"

static void native_capture_instruction_checkpoint(const char *label) {
    if (!getenv("VOX_PROFILE_INSTRUCTIONS")) return;
    uint64_t instructions = 0;
    if (vox_process_instructions(&instructions) == 0)
        fprintf(stderr, "Vox instructions cumulative: %s %llu\n", label,
            (unsigned long long)instructions);
}

#include "native_layer_presentation_darwin.h"
#include "native_deferred_font_darwin.h"
#include "native_svg_mask_layer_darwin.h"

#include "native_ffmpeg_darwin.h"
#include "native_webp_darwin.h"
#include "native_jpeg_darwin.h"
#include "native_png_color_darwin.h"
#include "native_opacity_group_darwin.h"

int native_prefers_overlay_scrollbars(void) {
	return [NSScroller preferredScrollerStyle] == NSScrollerStyleOverlay;
}

#ifdef LADYBIRD_V_HAS_SKIA_TEXT
extern void ladybird_v_skia_set_chromium_painting(int active);
extern void ladybird_v_skia_release_unused_graphics_memory(void);
extern int ladybird_v_skia_configure_font(const char *path, int slot);
extern void ladybird_v_skia_set_image_color_profile(const float *profile);
extern void ladybird_v_skia_set_root_raster_scroll_y(double scroll_y);
extern void ladybird_v_skia_set_msaa_tiles(const int *tiles, int count, int tile_rows);
extern void ladybird_v_skia_set_rect_clip_outs(const float *rects, int count);
extern void ladybird_v_skia_set_rounded_rect_underlay(const float *rect, uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha);
extern int ladybird_v_skia_register_system_face(const char *key, const char *path,
	const char *postscript_name, const uint32_t *axis_tags, const float *axis_values, int axis_count);
extern int ladybird_v_skia_draw_glyph_run(CGContextRef destination,
	const char *font_path, int face_index, const uint16_t *glyphs, const double *packed_positions, int glyph_count,
	float font_size, int font_weight, int emoji_face, float baseline_x,
	float baseline_y, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x,
	float page_y, float scroll_y, float canvas_width, float canvas_height,
	uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha,
	int font_smoothing);
extern int ladybird_v_skia_draw_glyph_shadow_run(CGContextRef destination,
	const char *font_path, int face_index, const uint16_t *glyphs, const double *packed_positions, int glyph_count,
	float font_size, int font_weight, int emoji_face, float baseline_x,
	float baseline_y, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x,
	float page_y, float scroll_y, float canvas_width, float canvas_height,
	uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha,
	int font_smoothing, float blur);
extern int ladybird_v_skia_draw_canvas_glyph_run(uint8_t *destination_pixels,
	int width, int height, int pitch, int pixels_are_premultiplied,
	const char *font_path, int face_index,
	const uint16_t *glyphs, const double *packed_positions, int glyph_count,
	float font_size, int font_weight, float baseline_x, float baseline_y,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, uint8_t red, uint8_t green,
	uint8_t blue, uint8_t alpha, float gradient_x0, float gradient_y0,
	float gradient_x1, float gradient_y1, const float *gradient_stops,
	int gradient_stop_count, float global_alpha, int stroke, int use_outline,
	float stroke_width);
extern int ladybird_v_skia_draw_line(CGContextRef destination,
	float from_x, float from_y, float to_x, float to_y, float thickness,
	int line_style, float canvas_width, float canvas_height, uint8_t red,
	uint8_t green, uint8_t blue, uint8_t alpha);
extern int ladybird_v_skia_draw_rounded_rect(CGContextRef destination,
	float x, float y, float width, float height, float top_left_x,
	float top_left_y, float top_right_x, float top_right_y, float bottom_right_x,
	float bottom_right_y, float bottom_left_x, float bottom_left_y,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_width, float canvas_height, uint8_t red,
	uint8_t green, uint8_t blue, uint8_t alpha, int fill, float thickness,
	int anti_alias, int opaque_backdrop);
extern int ladybird_v_skia_draw_outer_box_shadow(CGContextRef destination,
	float shadow_x, float shadow_y, float shadow_width, float shadow_height,
	float shadow_top_left_x, float shadow_top_left_y, float shadow_top_right_x,
	float shadow_top_right_y, float shadow_bottom_right_x,
	float shadow_bottom_right_y, float shadow_bottom_left_x,
	float shadow_bottom_left_y, float content_x, float content_y,
	float content_width, float content_height, float content_top_left_x,
	float content_top_left_y, float content_top_right_x,
	float content_top_right_y, float content_bottom_right_x,
	float content_bottom_right_y, float content_bottom_left_x,
	float content_bottom_left_y, float transform_a, float transform_b,
	float transform_c, float transform_d, float transform_e, float transform_f,
	float page_x, float page_y, float scroll_y, float canvas_width,
	float canvas_height, float blur, uint8_t red, uint8_t green, uint8_t blue,
	uint8_t alpha, int opaque_backdrop);
extern int ladybird_v_skia_draw_svg_path(CGContextRef destination,
	const float *data, int segment_count, int even_odd,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_width, float canvas_height,
	uint8_t fill_red, uint8_t fill_green, uint8_t fill_blue, uint8_t fill_alpha,
	int has_fill, uint8_t stroke_red, uint8_t stroke_green, uint8_t stroke_blue,
	uint8_t stroke_alpha, int has_stroke, float stroke_width, int line_cap,
	int line_join, float miter_limit, int non_scaling_stroke,
	const double *dash_data, int dash_count, double dash_offset, int opaque_backdrop);
extern int ladybird_v_skia_draw_svg_linear_gradient_path(
	CGContextRef destination, const float *data, int segment_count, int even_odd,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_width, float canvas_height, int stroke,
	float stroke_width, int line_cap, int line_join, float miter_limit,
	float start_x, float start_y, float end_x, float end_y, float gradient_a,
	float gradient_b, float gradient_c, float gradient_d, float gradient_e,
	float gradient_f, int spread_method, int linear_color_space,
	const float *stop_data, int stop_count, float opacity, int opaque_backdrop);
extern int ladybird_v_skia_draw_svg_radial_gradient_path(
	CGContextRef destination, const float *data, int segment_count, int even_odd,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_width, float canvas_height, int stroke,
	float stroke_width, int line_cap, int line_join, float miter_limit,
	float start_x, float start_y, float start_radius, float end_x, float end_y,
	float end_radius, float gradient_a, float gradient_b, float gradient_c,
	float gradient_d, float gradient_e, float gradient_f, int spread_method,
	int linear_color_space, const float *stop_data, int stop_count, float opacity,
	int opaque_backdrop);
extern int ladybird_v_skia_draw_rgba_image(CGContextRef destination,
	const uint8_t *pixels, int image_width, int image_height, int image_pitch,
	float destination_x, float destination_y, float destination_width,
	float destination_height, float source_x, float source_y, float source_width,
	float source_height, float clip_x, float clip_y, float clip_width,
	float clip_height, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x,
	float page_y, float scroll_y, float canvas_width, float canvas_height,
	float opacity, int nearest_neighbor, int image_flags, float const *clip_radii);
extern int ladybird_v_skia_draw_rgba_image_tiles(CGContextRef destination,
	const uint8_t *pixels, int image_width, int image_height, int image_pitch,
	float const *tiles, int tile_count, float clip_x, float clip_y, float clip_width,
	float clip_height, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x,
	float page_y, float scroll_y, float canvas_width, float canvas_height,
	float opacity, int nearest_neighbor, int image_flags, float const *clip_radii);
extern int ladybird_v_skia_draw_drop_shadow(CGContextRef destination,
	CGImageRef source, float canvas_width, float canvas_height, float scale,
	float offset_x, float offset_y, float standard_deviation, uint8_t red,
	uint8_t green, uint8_t blue, uint8_t alpha);
extern int ladybird_v_skia_draw_masked_image(CGContextRef destination,
	CGImageRef content, CGImageRef mask, float destination_x,
	float destination_y, float destination_width, float destination_height);
extern int ladybird_v_skia_begin_command_group(CGContextRef destination,
	float x, float y, float width, float height, float transform_a,
	float transform_b, float transform_c, float transform_d, float transform_e,
	float transform_f, float page_x, float page_y, float scroll_y,
	float canvas_width, float canvas_height);
extern int ladybird_v_skia_end_command_group(CGContextRef destination);
extern int ladybird_v_skia_generate_svg_turbulence(uint8_t *destination_pixels,
	int width, int height, float base_frequency_x, float base_frequency_y,
	int num_octaves, float seed, int fractal_noise, int tile_width,
	int tile_height, float origin_x, float origin_y);
#endif

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
	if (native_cached_browser_view != nil) {
		NSSize cached_size = [native_cached_browser_view bounds].size;
		if (cached_size.width > 0.0 && cached_size.height > 0.0) {
			return native_cached_browser_view;
		}
	}
	NSWindow *window = [NSApp mainWindow];
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
	if (largest_view != nil) {
		native_cached_browser_view = largest_view;
	}
	return native_cached_browser_view;
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
static CGFontRef native_document_glyph_font;
static CGFontRef native_document_bold_glyph_font;
static VoxDeferredFont native_emoji_font;

static NSFont *native_document_font(float size, int bold, int italic, int monospace) {
	NSFont *font = nil;
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

void native_configure_document_font(string path_value) {
	NSString *path = native_capture_string(path_value);
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	ladybird_v_skia_configure_font([path fileSystemRepresentation], 0);
#endif
	CGDataProviderRef provider = CGDataProviderCreateWithFilename([path fileSystemRepresentation]);
	if (provider == NULL) {
		return;
	}
	CGFontRef font = CGFontCreateWithDataProvider(provider);
	CGDataProviderRelease(provider);
	if (font == NULL) {
		return;
	}
	if (native_document_glyph_font != NULL) {
		CGFontRelease(native_document_glyph_font);
	}
	native_document_glyph_font = CGFontRetain(font);
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
	CGFontRelease(font);
}

void native_configure_document_bold_font(string path_value) {
	NSString *path = native_capture_string(path_value);
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	ladybird_v_skia_configure_font([path fileSystemRepresentation], 1);
#endif
	CGDataProviderRef provider = CGDataProviderCreateWithFilename([path fileSystemRepresentation]);
	if (provider == NULL) {
		return;
	}
	CGFontRef font = CGFontCreateWithDataProvider(provider);
	CGDataProviderRelease(provider);
	if (font == NULL) {
		return;
	}
	if (native_document_bold_glyph_font != NULL) {
		CGFontRelease(native_document_bold_glyph_font);
	}
	native_document_bold_glyph_font = font;
}

void native_configure_emoji_font(string path_value) {
	native_deferred_font_configure(&native_emoji_font, native_capture_string(path_value));
}

static void native_load_skia_emoji_font(const char *path) {
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	ladybird_v_skia_configure_font(path, 2);
#else
	(void)path;
#endif
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

static void native_request_browser_redraw(void) {
	++native_layer_redraw_generation;
	native_trace_browser_redraw("deliver");
	// An asynchronous resource can complete while the application has no main
	// or key window. Keep redrawing the window that owns our retained drawable.
	NSWindow *window = [native_browser_view() window];
	if (window == nil) {
		window = [NSApp mainWindow];
		if (window == nil) {
			window = [NSApp keyWindow];
		}
	}
	NSMutableArray<NSView *> *views = [NSMutableArray array];
	if ([window contentView] != nil) {
		[views addObject:[window contentView]];
	}
	while ([views count] > 0) {
		NSView *view = [views lastObject];
		[views removeLastObject];
		[view setNeedsDisplay:YES];
		[views addObjectsFromArray:[view subviews]];
	}
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

void native_wake_browser_after(int milliseconds) {
	native_trace_browser_redraw("schedule timer");
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
		(int64_t)MAX(milliseconds, 0) * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
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
		native_cache_display_in_bitmap(view, bounds, bitmap);
		NSBitmapImageRep *encoded_bitmap =
		    [bitmap bitmapImageRepByConvertingToColorSpace:[NSColorSpace sRGBColorSpace]
		                                  renderingIntent:NSColorRenderingIntentRelativeColorimetric];
		if (encoded_bitmap == nil) {
			encoded_bitmap = bitmap;
		}
		NSData *png = [encoded_bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
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

void native_draw_rect_srgb(float x, float y, float width, float height, gg__Color color) {
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
	CGContextFillRect(context, CGRectMake(x, y, width, height));
	CGColorRelease(cgColor);
}

static CGContextRef native_font_compositing_context;
static int native_font_compositing_transparency_depth;

static void native_begin_tracked_transparency_layer(CGContextRef context, CFDictionaryRef info) {
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

// A Chromium-profile opacity group with normal blending paints into its own
// bitmap, which shares the compositing canvas's format and device space. Its
// leaves therefore keep their exact Skia compositing, and the group is drawn
// over the backdrop with Chromium's floating-point layer composite.
typedef struct {
	int offscreen;
	CGContextRef parent;
	CGContextRef context;
	uint8_t *pixels;
	float opacity;
	int left, top, right, bottom;
} NativeOpacityGroup;

#define NATIVE_OPACITY_GROUP_MAX_DEPTH 64
static NativeOpacityGroup native_opacity_groups[NATIVE_OPACITY_GROUP_MAX_DEPTH];
static int native_opacity_group_depth;
static int native_opacity_group_overflow_depth;

static int native_compositing_canvas_is_readable(CGContextRef context) {
	CGAffineTransform ctm = CGContextGetCTM(context);
	return context != NULL && context == native_font_compositing_context
		&& native_font_compositing_transparency_depth == 0
		&& CGBitmapContextGetData(context) != NULL
		&& CGBitmapContextGetBitsPerPixel(context) == 32
		&& CGBitmapContextGetAlphaInfo(context) == kCGImageAlphaPremultipliedLast
		&& (CGBitmapContextGetBitmapInfo(context) & kCGBitmapByteOrderMask) == kCGBitmapByteOrder32Big
		&& ctm.a > 0 && ctm.d > 0 && ctm.b == 0 && ctm.c == 0 && ctm.tx == 0 && ctm.ty == 0;
}

static int native_begin_offscreen_opacity_group(NativeOpacityGroup *group, CGContextRef parent,
	float opacity) {
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
	uint8_t *pixels = calloc(height, width * 4);
	if (pixels == NULL) {
		return 0;
	}
	CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4,
		CGBitmapContextGetColorSpace(parent),
		kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	if (context == NULL) {
		free(pixels);
		return 0;
	}
	CGContextConcatCTM(context, CGContextGetCTM(parent));
	CGContextClipToRect(context, clip);
	CGContextSetShouldAntialias(context, true);
	CGContextSetInterpolationQuality(context, CGContextGetInterpolationQuality(parent));
	BOOL flipped = [[NSGraphicsContext currentContext] isFlipped];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:
		[NSGraphicsContext graphicsContextWithCGContext:context flipped:flipped]];
	*group = (NativeOpacityGroup){
		.offscreen = 1, .parent = parent, .context = context, .pixels = pixels,
		.opacity = MIN(MAX(opacity, 0.0f), 1.0f),
		.left = left, .top = top, .right = right, .bottom = bottom,
	};
	native_font_compositing_context = context;
	return 1;
}

static void native_end_offscreen_opacity_group(NativeOpacityGroup *group) {
	[NSGraphicsContext restoreGraphicsState];
	native_font_compositing_context = group->parent;
	native_font_compositing_transparency_depth = 0;
	CGContextFlush(group->context);
	CGContextFlush(group->parent);
	size_t width = CGBitmapContextGetWidth(group->parent);
	size_t height = CGBitmapContextGetHeight(group->parent);
	size_t layer_pitch = width * 4;
	size_t parent_pitch = CGBitmapContextGetBytesPerRow(group->parent);
	const uint8_t *backdrop = CGBitmapContextGetData(group->parent);
	int left, top, right, bottom;
	if (native_opacity_layer_ink_bounds(group->pixels, layer_pitch, group->left, group->top,
			group->right, group->bottom, &left, &top, &right, &bottom)) {
		size_t ink_width = (size_t)(right - left), ink_height = (size_t)(bottom - top);
		uint8_t *result = malloc(ink_width * ink_height * 4);
		CGColorSpaceRef color_space = CGBitmapContextGetColorSpace(group->parent);
		CGContextRef result_context = result == NULL ? NULL
			: CGBitmapContextCreate(result, ink_width, ink_height, 8, ink_width * 4, color_space,
				kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
		if (result_context != NULL) {
			for (size_t row = 0; row < ink_height; ++row) {
				native_composite_opacity_pixels(
					group->pixels + (top + row) * layer_pitch + (size_t)left * 4,
					backdrop + (top + row) * parent_pitch + (size_t)left * 4,
					result + row * ink_width * 4, ink_width, group->opacity);
			}
			CGImageRef image = CGBitmapContextCreateImage(result_context);
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
			CGContextRelease(result_context);
		}
		free(result);
	}
	CGContextRelease(group->context);
	free(group->pixels);
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
		if (blend_mode == 0 && native_begin_offscreen_opacity_group(group, context, opacity)) {
			return;
		}

	} else {
		native_opacity_group_overflow_depth++;
	}
	CGContextSetAlpha(context, opacity);
	CGContextSetBlendMode(context, native_compositing_operator(blend_mode));
	native_begin_tracked_transparency_layer(context, NULL);
}

void native_end_css_effect_layer(void) {
	if (native_opacity_group_overflow_depth > 0) {
		native_opacity_group_overflow_depth--;
	} else if (native_opacity_group_depth > 0) {
		NativeOpacityGroup group = native_opacity_groups[--native_opacity_group_depth];
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

// Register a CoreText-selected face for retained glyph replay under `key`.
int native_register_system_face(string key, string path, string postscript_name,
	const uint32_t *axis_tags, const float *axis_values, int axis_count) {
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	NSString *key_string = native_capture_string(key);
	NSString *path_string = native_capture_string(path);
	NSString *postscript_string = native_capture_string(postscript_name);
	return ladybird_v_skia_register_system_face([key_string UTF8String],
		[path_string fileSystemRepresentation], [postscript_string UTF8String],
		axis_tags, axis_values, axis_count);
#else
	(void)key; (void)path; (void)postscript_name; (void)axis_tags; (void)axis_values; (void)axis_count;
	return 0;
#endif
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
	CGFontRef graphics_font = emoji_face
		? native_deferred_font_resolve(&native_emoji_font, native_load_skia_emoji_font)
		: (font_weight >= 600 && native_document_bold_glyph_font != NULL
			? native_document_bold_glyph_font : native_document_glyph_font);
	if (graphics_font == NULL) {
		return 0;
	}
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	if ((!shadow_only && blur <= 0.0f) || (shadow_only && blur >= 0.0f && (font_smoothing & 16))) {
		const CGFloat *components = CGColorGetComponents(color);
		if (components != NULL && CGColorGetNumberOfComponents(color) == 4) {
            int flags = font_smoothing
                | (((font_smoothing & 16) && context == native_font_compositing_context
                    && native_font_compositing_transparency_depth == 0) ? 32 : 0);
            uint8_t red = (uint8_t)lrint(components[0] * 255.0);
            uint8_t green = (uint8_t)lrint(components[1] * 255.0);
            uint8_t blue = (uint8_t)lrint(components[2] * 255.0);
            uint8_t alpha = (uint8_t)lrint(components[3] * 255.0);
            int drawn = shadow_only
                ? ladybird_v_skia_draw_glyph_shadow_run(context, font_path, face_index, glyphs, packed_positions,
                    glyph_count, font_size, font_weight, emoji_face, baseline_x, baseline_y,
                    transform_a, transform_b, transform_c, transform_d, transform_e, transform_f,
                    page_x, page_y, scroll_y, canvas_width, canvas_height, red, green, blue, alpha, flags, blur)
                : ladybird_v_skia_draw_glyph_run(context, font_path, face_index, glyphs, packed_positions,
                    glyph_count, font_size, font_weight, emoji_face, baseline_x, baseline_y,
                    transform_a, transform_b, transform_c, transform_d, transform_e, transform_f,
                    page_x, page_y, scroll_y, canvas_width, canvas_height, red, green, blue, alpha, flags);
            if (drawn) return 1;
        }
	}
#endif
	CTFontRef font = CTFontCreateWithGraphicsFont(graphics_font,
		MAX(font_size, 0.0f), NULL, NULL);
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
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	if (native_font_compositing_context != NULL) {
		float rx = width / 2.0f, ry = height / 2.0f;
		CGRect clip = CGContextGetClipBoundingBox(context);
		if (ladybird_v_skia_draw_rounded_rect(context, x, y, width, height,
			rx, ry, rx, ry, rx, ry, rx, ry, transform_a, transform_b, transform_c,
			transform_d, transform_e, transform_f, page_x, page_y, scroll_y,
			MAX(CGRectGetMaxX(clip), width), canvas_height,
			color.r, color.g, color.b, color.a, fill, thickness, 1,
			context == native_font_compositing_context
				&& native_font_compositing_transparency_depth == 0)) return;
	}
#endif
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
	int did_draw = native_draw_retained_glyph_run(context, [font_path fileSystemRepresentation], face_index, glyphs, positions, glyph_count,
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
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	NSString *font_path = native_capture_string(font_path_value);
	return ladybird_v_skia_draw_canvas_glyph_run(pixels, width, height, pitch,
		pixels_are_premultiplied,
		[font_path fileSystemRepresentation], face_index, glyphs, positions,
		glyph_count, font_size, font_weight, baseline_x, baseline_y, transform_a,
		transform_b, transform_c, transform_d, transform_e, transform_f, red,
		green, blue, alpha, gradient_x0, gradient_y0, gradient_x1, gradient_y1,
		gradient_stops, gradient_stop_count, global_alpha, stroke, use_outline,
		stroke_width);
#else
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
#endif
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
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	if (ladybird_v_skia_draw_line(context, from_x, from_y, to_x, to_y,
		thickness, line_style, canvas_width, canvas_height, color.r, color.g,
		color.b, color.a)) {
		return 1;
	}
#endif
	// Keep the native backend independent of GG's immediate-mode GPU pipeline,
	// including builds without the optional Skia bridge.
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

void native_draw_svg_path_srgb(const float *data, int segment_count, int even_odd,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_width, float canvas_height, gg__Color fill_color, int has_fill,
	gg__Color stroke_color, int has_stroke, float stroke_width, int line_cap,
	int line_join, float miter_limit, int non_scaling_stroke,
	const double *dash_data, int dash_count, double dash_offset) {
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
	float resolved_stroke_width = non_scaling_stroke ? stroke_width / host_scale + 2.0f / 512.0f : stroke_width;
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	if (ladybird_v_skia_draw_svg_path(context, data, segment_count, even_odd,
		transform_a, transform_b, transform_c, transform_d, transform_e,
		transform_f, page_x, page_y, scroll_y, canvas_width, canvas_height,
		fill_color.r, fill_color.g, fill_color.b, fill_color.a, has_fill,
		stroke_color.r, stroke_color.g, stroke_color.b, stroke_color.a, has_stroke,
		resolved_stroke_width, line_cap, line_join, miter_limit, non_scaling_stroke,
		dash_data, dash_count, dash_offset,
		context == native_font_compositing_context
			&& native_font_compositing_transparency_depth == 0)) {
		return;
	}
#endif
	CGMutablePathRef path = native_create_path_from_data(data, segment_count);
	CGAffineTransform to_canvas = CGAffineTransformMake(transform_a, -transform_b,
		transform_c, -transform_d, page_x + transform_e,
		canvas_height - page_y + scroll_y - transform_f);
	if (non_scaling_stroke && has_stroke) {
		if (has_fill) {
			CGColorRef fill = native_srgb_color(fill_color);
			CGContextSaveGState(context);
			CGContextConcatCTM(context, to_canvas);
			CGContextAddPath(context, path);
			CGContextSetFillColorWithColor(context, fill);
			CGContextDrawPath(context, even_odd ? kCGPathEOFill : kCGPathFill);
			CGContextRestoreGState(context);
			CGColorRelease(fill);
		}
		CGPathRef transformed_path = CGPathCreateCopyByTransformingPath(path, &to_canvas);
		CGColorRef stroke = native_srgb_color(stroke_color);
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
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	float canvas_width = (float)[native_browser_view() bounds].size.width;
	if (ladybird_v_skia_draw_svg_linear_gradient_path(context, data,
		segment_count, even_odd, transform_a, transform_b, transform_c,
		transform_d, transform_e, transform_f, page_x, page_y, scroll_y,
		canvas_width, canvas_height, stroke, stroke_width, line_cap, line_join,
		miter_limit, start_x, start_y, end_x, end_y, gradient_a, gradient_b,
		gradient_c, gradient_d, gradient_e, gradient_f, spread_method,
		linear_color_space, stop_data, stop_count, opacity,
		context == native_font_compositing_context
			&& native_font_compositing_transparency_depth == 0)) {
		return;
	}
#endif
	native_draw_svg_linear_gradient_path_in_context(context, data, segment_count,
		even_odd, transform_a, transform_b, transform_c, transform_d, transform_e,
		transform_f, page_x, page_y, scroll_y, canvas_height, stroke, stroke_width,
		line_cap, line_join, miter_limit, start_x, start_y, end_x, end_y,
		gradient_a, gradient_b, gradient_c, gradient_d, gradient_e, gradient_f,
		spread_method, linear_color_space, stop_data, stop_count, opacity);
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
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	float canvas_width = (float)[native_browser_view() bounds].size.width;
	if (ladybird_v_skia_draw_svg_radial_gradient_path(context, data,
		segment_count, even_odd, transform_a, transform_b, transform_c,
		transform_d, transform_e, transform_f, page_x, page_y, scroll_y,
		canvas_width, canvas_height, stroke, stroke_width, line_cap, line_join,
		miter_limit, start_x, start_y, start_radius, end_x, end_y, end_radius,
		gradient_a, gradient_b, gradient_c, gradient_d, gradient_e, gradient_f,
		spread_method, linear_color_space, stop_data, stop_count, opacity,
		context == native_font_compositing_context
			&& native_font_compositing_transparency_depth == 0)) {
		return;
	}
#endif
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
static int native_svg_clip_build_is_color;
static int native_svg_clip_build_is_luminance;

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
} NativeCSSFilterLayer;

static NativeCSSFilterLayer native_css_filter_stack[NATIVE_CSS_FILTER_MAX_DEPTH];
static int native_css_filter_stack_depth;
static int native_css_filter_overflow_depth;
static CIContext *native_css_filter_ci_context;
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

static void native_release_unused_graphics_memory(void) {
	if (![NSThread isMainThread]) return;
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	ladybird_v_skia_release_unused_graphics_memory();
#endif
	// A page without filters never creates this renderer. Preserve that lazy
	// behavior while returning unused textures from existing filter contexts.
	if (native_css_filter_ci_context != nil) {
		[native_css_filter_ci_context reclaimResources];
		[native_css_filter_ci_context clearCaches];
	}
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

// Keep root scrolling distinct from the per-command transform.
void native_set_chromium_raster_scroll_y(double scroll_y) {
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
    ladybird_v_skia_set_root_raster_scroll_y(scroll_y);
#else
    (void)scroll_y;
#endif
}

// The Chromium raster tiles whose GPU render pass is multisampled in this
// frame; their anti-aliased shapes take multisampled coverage.
void native_set_chromium_msaa_tiles(const int *tiles, int count, int tile_rows) {
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	ladybird_v_skia_set_msaa_tiles(tiles, count, tile_rows);
#else
	(void)tiles; (void)count; (void)tile_rows;
#endif
}

// Whether the next native rounded rectangle can draw an underlay in its pass.
int native_rounded_rect_underlay_supported(void) {
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	return 1;
#else
	return 0;
#endif
}

// The filled rounded rectangle, as x, y, width, height and four corner radius
// pairs, that the next native rounded rectangle draws first in its own pass.
void native_set_rounded_rect_underlay(const float *rect, gg__Color color) {
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	ladybird_v_skia_set_rounded_rect_underlay(rect, color.r, color.g, color.b, color.a);
#else
	(void)rect; (void)color;
#endif
}

// Rectangles clipped out of the next anti-aliased rectangle, as left, top,
// right and bottom; a count of zero clears them.
void native_set_rect_clip_outs(const double *rects, int count) {
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	int used = rects != NULL && count > 0 ? count : 0;
	float *values = used > 0 ? malloc(sizeof(float) * 4 * (size_t)used) : NULL;
	if (used > 0 && values == NULL) {
		used = 0;
	}
	for (int index = 0; index < used * 4; ++index) {
		values[index] = (float)rects[index];
	}
	ladybird_v_skia_set_rect_clip_outs(values, used);
	free(values);
#else
	(void)rects; (void)count;
#endif
}

void native_begin_font_compositing_layer(float width, float height) {
	native_begin_css_filter_layer(width, height);
	native_font_compositing_context = [[NSGraphicsContext currentContext] CGContext];
	native_font_compositing_transparency_depth = 0;
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	ladybird_v_skia_set_chromium_painting(1);
#endif
}

void native_end_font_compositing_layer(void) {
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	ladybird_v_skia_set_chromium_painting(0);
#endif
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
	if (source_outside_current_filter && native_css_filter_stack_depth > 0) {
		NativeCSSFilterLayer const *current_filter =
			&native_css_filter_stack[native_css_filter_stack_depth - 1];
		if (current_filter->destination != NULL) {
			source = current_filter->destination;
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
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	if (ladybird_v_skia_generate_svg_turbulence(pixels, (int)width,
		(int)height, node->first / coordinate_scale,
		node->second / coordinate_scale, octave_count, node->fourth,
		node->mode == 1, (int)lround(node->fifth * coordinate_scale),
		(int)lround(node->sixth * coordinate_scale), 0.0f, 0.0f)) {
		CGColorSpaceRef color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
		CIImage *image = [CIImage imageWithBitmapData:bitmap bytesPerRow:width * 4
			size:CGSizeMake(width, height) format:kCIFormatRGBA8
			colorSpace:color_space];
		CGColorSpaceRelease(color_space);
		return [image imageByApplyingTransform:CGAffineTransformMakeTranslation(
			extent.origin.x, extent.origin.y)];
	}
#endif
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

static CIImage *native_apply_css_filter_layer(NativeCSSFilterLayer const *layer,
	CGImageRef source_image) {
	CIImage *output = [CIImage imageWithCGImage:source_image];
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

void native_end_css_filter_layer(void) {
	if (native_css_filter_overflow_depth > 0) {
		native_css_filter_overflow_depth--;
		return;
	}
	if (native_css_filter_stack_depth <= 0) {
		return;
	}
	NativeCSSFilterLayer layer =
		native_css_filter_stack[--native_css_filter_stack_depth];
	if (!layer.active) {
		free(layer.operations);
		native_free_svg_filter_graph(&layer);
		return;
	}
	CGContextFlush(layer.context);
	CGImageRef source_image = CGBitmapContextCreateImage(layer.context);
	CGContextRelease(layer.context);
	[NSGraphicsContext restoreGraphicsState];
	if (source_image == NULL) {
		free(layer.operations);
		native_free_svg_filter_graph(&layer);
		return;
	}
	@autoreleasepool {
		CGRect source_rect = CGRectMake(0, 0,
			CGImageGetWidth(source_image), CGImageGetHeight(source_image));
		CGImageRef filtered_image = NULL;
		int rendered_with_skia = 0;
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
		if (layer.operation_count == 1 && layer.graph_node_count == 0
			&& layer.operations[0].kind == 1 && layer.destination != NULL) {
			NativeCSSFilterOperation operation = layer.operations[0];
			rendered_with_skia = ladybird_v_skia_draw_drop_shadow(layer.destination,
				source_image, layer.canvas_width, layer.canvas_height, layer.scale,
				operation.first, operation.second, operation.third,
				(uint8_t)lrintf(operation.red * 255.0f),
				(uint8_t)lrintf(operation.green * 255.0f),
				(uint8_t)lrintf(operation.blue * 255.0f),
				(uint8_t)lrintf(operation.alpha * 255.0f));
		}
#endif
		if (rendered_with_skia) {
			// The bridge composited the Skia filter result directly.
		} else if (layer.operation_count == 0 && layer.graph_node_count == 0) {
			filtered_image = CGImageRetain(source_image);
		} else {
			native_initialize_css_filter_renderer();
			CIImage *output = native_apply_css_filter_layer(&layer, source_image);
			filtered_image = [native_css_filter_ci_context createCGImage:output
				fromRect:source_rect format:kCIFormatRGBA8
				colorSpace:native_css_filter_color_space];
		}
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
static int native_background_text_clip_active;

void native_begin_background_text_clip(float canvas_width, float canvas_height,
	float clip_x, float clip_y, float clip_width, float clip_height) {
	if (native_background_text_content_context != NULL) {
		CGContextRelease(native_background_text_content_context);
		native_background_text_content_context = NULL;
	}
	native_background_text_destination = NULL;
	if (native_background_text_clip_build_context != NULL) {
		CGContextRelease(native_background_text_clip_build_context);
		native_background_text_clip_build_context = NULL;
	}
	if (native_background_text_clip_image != NULL) {
		CGImageRelease(native_background_text_clip_image);
		native_background_text_clip_image = NULL;
	}
	CGRect canvas_rect = CGRectMake(0, 0, canvas_width, canvas_height);
	native_background_text_clip_rect = CGRectIntersection(
		CGRectStandardize(CGRectMake(clip_x, clip_y, clip_width, clip_height)), canvas_rect);
	if (CGRectIsNull(native_background_text_clip_rect)
		|| CGRectIsEmpty(native_background_text_clip_rect)) {
		native_background_text_clip_rect = CGRectZero;
	}
	CGFloat scale = native_svg_mask_backing_scale();
	size_t width = (size_t)MAX(1.0,
		ceil(native_background_text_clip_rect.size.width * scale));
	size_t height = (size_t)MAX(1.0,
		ceil(native_background_text_clip_rect.size.height * scale));
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
		-native_background_text_clip_rect.origin.x,
		-native_background_text_clip_rect.origin.y);
	CGContextSetShouldAntialias(native_background_text_clip_build_context, true);
}

void native_add_background_text_clip_run(float x, float y, string value,
	float size, int bold, int italic, int monospace) {
	if (native_background_text_clip_build_context == NULL) {
		return;
	}
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

int native_add_background_glyph_clip_run(const uint16_t *glyphs,
	const double *positions, int glyph_count, float font_size, int font_weight, int emoji_face,
	float baseline_x, float baseline_y, float transform_a, float transform_b,
	float transform_c, float transform_d, float transform_e, float transform_f,
	float page_x, float page_y, float scroll_y, float canvas_width, float canvas_height,
	string font_path_value, int face_index, int font_smoothing) {
	if (native_background_text_clip_build_context == NULL) {
		return 0;
	}
	// Upstream records text-mask glyphs in black. Skia's text contrast/gamma
	// adjustment is paint-color dependent even though DestinationIn later uses
	// only alpha, so using white here produces a substantially heavier edge.
	CGColorRef black = CGColorCreateGenericRGB(0.0, 0.0, 0.0, 1.0);
	NSString *font_path = native_capture_string(font_path_value);
	int did_draw = native_draw_retained_glyph_run(native_background_text_clip_build_context,
		[font_path fileSystemRepresentation], face_index, glyphs, positions, glyph_count, font_size, font_weight, emoji_face, baseline_x,
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
		return;
	}
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	if (native_background_text_clip_image != NULL
		&& !CGRectIsEmpty(native_background_text_clip_rect)) {
		size_t width = CGImageGetWidth(native_background_text_clip_image);
		size_t height = CGImageGetHeight(native_background_text_clip_image);
		CGColorSpaceRef color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
		native_background_text_content_context = CGBitmapContextCreate(NULL, width,
			height, 8, width * 4, color_space,
			kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
		CGColorSpaceRelease(color_space);
		if (native_background_text_content_context != NULL) {
			CGFloat scale_x = width / native_background_text_clip_rect.size.width;
			CGFloat scale_y = height / native_background_text_clip_rect.size.height;
			CGContextScaleCTM(native_background_text_content_context, scale_x, scale_y);
			CGContextTranslateCTM(native_background_text_content_context,
				-native_background_text_clip_rect.origin.x,
				-native_background_text_clip_rect.origin.y);
			native_background_text_destination = destination;
			[NSGraphicsContext saveGraphicsState];
			[NSGraphicsContext setCurrentContext:[NSGraphicsContext
				graphicsContextWithCGContext:native_background_text_content_context
				flipped:NO]];
			native_background_text_clip_active = 2;
			return;
		}
	}
#endif
	CGContextSaveGState(destination);
	if (native_background_text_clip_image != NULL
		&& !CGRectIsEmpty(native_background_text_clip_rect)) {
		CGContextClipToRect(destination, native_background_text_clip_rect);
		CGContextClipToMask(destination, native_background_text_clip_rect,
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
		CGContextRelease(native_background_text_content_context);
		native_background_text_content_context = NULL;
		[NSGraphicsContext restoreGraphicsState];
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
		if (content != NULL && native_background_text_clip_image != NULL
			&& native_background_text_destination != NULL) {
			ladybird_v_skia_draw_masked_image(native_background_text_destination,
				content, native_background_text_clip_image,
				native_background_text_clip_rect.origin.x,
				native_background_text_clip_rect.origin.y,
				native_background_text_clip_rect.size.width,
				native_background_text_clip_rect.size.height);
		}
#endif
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
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	if (ladybird_v_skia_draw_svg_path(native_svg_clip_build_context, data,
		segment_count, even_odd, transform_a, transform_b, transform_c,
		transform_d, transform_e, transform_f, page_x, page_y, scroll_y,
		canvas_width, canvas_height, 255, 255, 255, 255, 1,
		0, 0, 0, 0, 0, 0.0f, 0, 0, 4.0f, 0, NULL, 0, 0.0, 0)) {
		return;
	}
#endif
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
	CGContextSaveGState(native_svg_clip_build_context);
	CGContextSetAlpha(native_svg_clip_build_context, fminf(fmaxf(opacity, 0.0f), 1.0f));
	native_begin_tracked_transparency_layer(native_svg_clip_build_context, NULL);
}

void native_end_svg_mask_opacity(void) {
	if (native_svg_clip_image != NULL || native_svg_clip_build_context == NULL) {
		return;
	}
	native_end_tracked_transparency_layer(native_svg_clip_build_context);
	CGContextRestoreGState(native_svg_clip_build_context);
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
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	int order[] = { stroke_first ? 1 : 0, stroke_first ? 0 : 1 };
	int used_skia = 1;
	for (int index = 0; index < 2; ++index) {
		int draw_stroke = order[index];
		if ((draw_stroke && !has_stroke) || (!draw_stroke && !has_fill)) {
			continue;
		}
		gg__Color color = draw_stroke ? stroke_color : fill_color;
		if (!ladybird_v_skia_draw_svg_path(native_svg_clip_build_context, data,
			segment_count, even_odd, transform_a, transform_b, transform_c,
			transform_d, transform_e, transform_f, page_x, page_y, scroll_y,
			canvas_width, canvas_height,
			color.r, color.g, color.b, color.a, draw_stroke ? 0 : 1,
			color.r, color.g, color.b, color.a, draw_stroke ? 1 : 0,
			stroke_width, line_cap, line_join, miter_limit, 0, NULL, 0, 0.0, 0)) {
			used_skia = 0;
			break;
		}
	}
	if (used_skia) {
		return;
	}
#endif
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
			for (size_t y = 0; y < height; ++y) {
				for (size_t x = 0; x < width; ++x) {
					uint8_t alpha;
					if (native_svg_clip_build_is_color) {
						uint8_t *pixel = source + y * source_stride + x * 4;
						alpha = native_svg_clip_build_is_luminance
							? (uint8_t)((54u * pixel[0] + 183u * pixel[1]
								+ 19u * pixel[2]) >> 8)
							: pixel[3];
					} else {
						alpha = source[y * source_stride + x];
					}
					uint8_t *output = mask + y * mask_stride + x * 4;
					// Premultiplied white mask pixels have RGB == alpha.
					output[0] = alpha;
					output[1] = alpha;
					output[2] = alpha;
					output[3] = alpha;
				}
			}
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

void native_begin_skia_command_group(float x, float y, float width, float height,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_width, float canvas_height) {
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context != NULL) {
		ladybird_v_skia_begin_command_group(context, x, y, width, height,
			transform_a, transform_b, transform_c, transform_d, transform_e,
			transform_f, page_x, page_y, scroll_y, canvas_width, canvas_height);
	}
#else
	(void)x; (void)y; (void)width; (void)height;
	(void)transform_a; (void)transform_b; (void)transform_c; (void)transform_d;
	(void)transform_e; (void)transform_f; (void)page_x; (void)page_y;
	(void)scroll_y; (void)canvas_width; (void)canvas_height;
#endif
}

void native_end_skia_command_group(void) {
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	if (context != NULL) {
		ladybird_v_skia_end_command_group(context);
	}
#endif
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
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	if (ladybird_v_skia_draw_rounded_rect(context, x, y, width, height,
		top_left_x, top_left_y, top_right_x, top_right_y, bottom_right_x,
		bottom_right_y, bottom_left_x, bottom_left_y, transform_a, transform_b,
		transform_c, transform_d, transform_e, transform_f, page_x, page_y,
		scroll_y, canvas_width, canvas_height, color.r, color.g, color.b, color.a,
		fill, thickness, anti_alias,
		context == native_font_compositing_context
			&& native_font_compositing_transparency_depth == 0)) {
		return;
	}
#endif
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
	CGContextAddPath(context, canvas_path);
	if (fill) {
		CGContextSetFillColorWithColor(context, cg_color);
		CGContextFillPath(context);
	} else {
		CGContextSetStrokeColorWithColor(context, cg_color);
		CGContextSetLineWidth(context, MAX(thickness, 0.0f));
		CGContextStrokePath(context);
	}
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
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	if (ladybird_v_skia_draw_outer_box_shadow(context, shadow_x, shadow_y,
		shadow_width, shadow_height, shadow_top_left_x, shadow_top_left_y,
		shadow_top_right_x, shadow_top_right_y, shadow_bottom_right_x,
		shadow_bottom_right_y, shadow_bottom_left_x, shadow_bottom_left_y,
		content_x, content_y, content_width, content_height, content_top_left_x,
		content_top_left_y, content_top_right_x, content_top_right_y,
		content_bottom_right_x, content_bottom_right_y, content_bottom_left_x,
		content_bottom_left_y, transform_a, transform_b, transform_c, transform_d,
		transform_e, transform_f, page_x, page_y, scroll_y, canvas_width,
		canvas_height, blur, color.r, color.g, color.b, color.a,
		context == native_font_compositing_context
			&& native_font_compositing_transparency_depth == 0))
		return;
#endif
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
	native_fill_blurred_path(context, canvas_shadow, false, blur, cg_color);
	CGColorRelease(cg_color);
	CGContextRestoreGState(context);
	CGPathRelease(canvas_content);
	CGPathRelease(canvas_shadow);
	CGPathRelease(local_content);
	CGPathRelease(local_shadow);
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
	float scroll_y, float canvas_height, float blur, gg__Color color) {
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
	NSInteger frame_count = [[animated_representation valueForProperty:NSImageFrameCount] integerValue];
	// The screenshot JavaScript host resolves its image-animation checkpoint at
	// frame 1. Keep native decoding at the same checkpoint; otherwise the capture
	// delay can wrap a looping GIF back to frame 0 after the test has completed.
	if (getenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS") != NULL) {
		[animated_representation setProperty:NSImageCurrentFrame withValue:@(MIN(1, frame_count - 1))];
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

static CGImageRef native_copy_cg_image(gg__Image *image) {
	if (image == NULL || image->data == NULL || image->width <= 0 || image->height <= 0) {
		return NULL;
	}
	if (image->path.len > 0) {
		NSImage *native_image = (__bridge NSImage *)image->data;
		native_update_animated_image_frame(native_image);
		CGImageRef cg_image = [native_image CGImageForProposedRect:NULL context:nil hints:nil];
		return cg_image == NULL ? NULL : CGImageCreateCopy(cg_image);
	}
	// create_image_from_byte_array() stores stb-decoded RGBA pixels rather than
	// an NSImage in Image.data. Wrap those bytes directly instead of treating
	// their first machine word as an Objective-C object.
	if (image->nr_channels < 4 || image->nr_channels > 7) {
		return NULL;
	}
	size_t bytes_per_row = (size_t)image->width * 4;
	CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, image->data,
		bytes_per_row * (size_t)image->height, NULL);
	CGColorSpaceRef color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	CGImageRef cg_image = CGImageCreate((size_t)image->width, (size_t)image->height,
		8, 32, bytes_per_row, color_space,
		((image->nr_channels == 5 || image->nr_channels == 7)
			? kCGImageAlphaPremultipliedLast : kCGImageAlphaLast)
			| kCGBitmapByteOrder32Big, provider, NULL, false,
		kCGRenderingIntentDefault);
	CGColorSpaceRelease(color_space);
	CGDataProviderRelease(provider);
	return cg_image;
}

#ifdef LADYBIRD_V_HAS_SKIA_TEXT
static int native_draw_cg_image_part_with_skia(CGContextRef destination,
	CGImageRef source_image, gg__Image *image, float destination_x,
	float destination_y, float destination_width, float destination_height,
	float source_x, float source_y, float source_width, float source_height,
	float clip_x, float clip_y, float clip_width, float clip_height,
	float transform_a, float transform_b, float transform_c, float transform_d,
	float transform_e, float transform_f, float page_x, float page_y,
	float scroll_y, float canvas_width, float canvas_height, float opacity,
	int nearest_neighbor, float const *clip_radii) {
	size_t width = CGImageGetWidth(source_image);
	size_t height = CGImageGetHeight(source_image);
	if (width == 0 || height == 0 || width > INT_MAX / 4 || height > SIZE_MAX / (width * 4))
		return 0;
	size_t pitch = width * 4;
	uint8_t *pixels = calloc(height, pitch);
	if (pixels == NULL)
		return 0;
	CGColorSpaceRef color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	CGContextRef decode = CGBitmapContextCreate(pixels, width, height, 8, pitch,
		color_space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	CGColorSpaceRelease(color_space);
	if (decode == NULL) {
		free(pixels);
		return 0;
	}
	// CGImage scanlines are already top-down in a newly created bitmap context.
	// A view-coordinate flip here would reflect them before Skia samples them.
	CGContextSetBlendMode(decode, kCGBlendModeCopy);
	CGContextDrawImage(decode, CGRectMake(0, 0, width, height), source_image);
	CGContextRelease(decode);
	// Keep the decoded premultiplied texels intact through image filtering.
	float scale_x = image->width > 0 ? (float)width / image->width : 1.0f;
	float scale_y = image->height > 0 ? (float)height / image->height : 1.0f;
	int drawn = ladybird_v_skia_draw_rgba_image(destination, pixels, (int)width,
		(int)height, (int)pitch, destination_x, destination_y, destination_width,
		destination_height, source_x * scale_x, source_y * scale_y,
		source_width * scale_x, source_height * scale_y, clip_x, clip_y,
		clip_width, clip_height, transform_a, transform_b, transform_c,
		transform_d, transform_e, transform_f, page_x, page_y, scroll_y,
		canvas_width, canvas_height, opacity, nearest_neighbor,
		1 | ((destination == native_font_compositing_context
			&& native_font_compositing_transparency_depth == 0) ? 2 : 0), clip_radii);
	free(pixels);
	return drawn;
}
#endif

#ifdef LADYBIRD_V_HAS_SKIA_TEXT
// The pixels, row pitch and image flags the Skia bridge draws a gg image from.
typedef struct {
	uint8_t const *pixels;
	uint8_t *flipped_pixels;
	int pitch;
	int flags;
} NativeSkiaImageSource;

static int native_begin_skia_image_source(CGContextRef context, gg__Image *image,
	NativeSkiaImageSource *source) {
	// Markers 8 to 10 retain planar YUV rather than packed RGBA for native
	// sampling: limited-range 4:2:0, full-range 4:2:0 and full-range 4:4:4.
	if (image->path.len != 0 || image->nr_channels < 4 || image->nr_channels > 10) {
		return 0;
	}
	size_t pitch = (size_t)image->width * 4;
	size_t byte_count = (size_t)image->height <= SIZE_MAX / pitch
	    ? pitch * (size_t)image->height
	    : 0;
	int needs_vertical_flip = image->nr_channels == 4 || image->nr_channels == 5;
	uint8_t *flipped_pixels = needs_vertical_flip && byte_count > 0
	    ? malloc(byte_count) : NULL;
	uint8_t const *source_pixels = needs_vertical_flip ? flipped_pixels
	    : (uint8_t const *)image->data;
	if (source_pixels == NULL) {
		return 0;
	}
	// composite_pixels() publishes its first row through a Quartz image in
	// bottom-up view coordinates. Reflect Quartz-ordered bitmap rows once;
	// FFmpeg and copied video-canvas rows are already top-down.
	if (needs_vertical_flip) {
		for (int row = 0; row < image->height; ++row) {
			memcpy(flipped_pixels + (size_t)row * pitch,
			    (uint8_t const *)image->data
			        + (size_t)(image->height - row - 1) * pitch,
			    pitch);
		}
	}
	VoxPngColorProfile color_profile;
	ladybird_v_skia_set_image_color_profile(
	    native_image_color_profile(image->data, image->width, image->height,
	        &color_profile) ? color_profile.values : NULL);
	*source = (NativeSkiaImageSource){
		.pixels = source_pixels,
		.flipped_pixels = flipped_pixels,
		.pitch = (int)pitch,
		.flags = (image->nr_channels == 5 || image->nr_channels == 7)
		    | (image->nr_channels == 8 ? 4 : 0)
		    | (image->nr_channels == 9 ? 12 : 0)
		    | (image->nr_channels == 10 ? 28 : 0)
		    | ((context == native_font_compositing_context
		        && native_font_compositing_transparency_depth == 0) ? 2 : 0),
	};
	return 1;
}

static void native_end_skia_image_source(NativeSkiaImageSource *source) {
	ladybird_v_skia_set_image_color_profile(NULL);
	free(source->flipped_pixels);
	source->flipped_pixels = NULL;
}
#endif

static void native_draw_image_part_in_context(CGContextRef context, gg__Image *image,
	float destination_x, float destination_y, float destination_width,
	float destination_height, float source_x, float source_y, float source_width,
	float source_height, float clip_x, float clip_y, float clip_width,
	float clip_height, float transform_a, float transform_b, float transform_c,
	float transform_d, float transform_e, float transform_f, float page_x,
	float page_y, float scroll_y, float canvas_width, float canvas_height, float opacity,
	int nearest_neighbor, float const *clip_radii) {
	if (context == NULL || image == NULL || image->data == NULL
		|| destination_width <= 0 || destination_height <= 0
		|| source_width <= 0 || source_height <= 0
		|| clip_width <= 0 || clip_height <= 0) {
		return;
	}
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	NativeSkiaImageSource source;
	if (native_begin_skia_image_source(context, image, &source)) {
		int drawn = ladybird_v_skia_draw_rgba_image(context, source.pixels,
		    image->width, image->height, source.pitch, destination_x,
		    destination_y, destination_width, destination_height, source_x,
		    source_y, source_width, source_height, clip_x, clip_y, clip_width,
		    clip_height, transform_a, transform_b, transform_c, transform_d,
		    transform_e, transform_f, page_x, page_y, scroll_y, canvas_width,
		    canvas_height, opacity, nearest_neighbor, source.flags, clip_radii);
		native_end_skia_image_source(&source);
		if (drawn)
			return;
	}
#endif
	CGImageRef image_copy = native_copy_cg_image(image);
	if (image_copy == NULL) {
		return;
	}
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	if (native_draw_cg_image_part_with_skia(context, image_copy, image,
		destination_x, destination_y, destination_width, destination_height,
		source_x, source_y, source_width, source_height, clip_x, clip_y,
		clip_width, clip_height, transform_a, transform_b, transform_c,
		transform_d, transform_e, transform_f, page_x, page_y, scroll_y,
		canvas_width, canvas_height, opacity, nearest_neighbor, clip_radii)) {
		CGImageRelease(image_copy);
		return;
	}
#endif
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
	if (clip_radii) {
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
			opacity, 1, NULL);
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
		page_y, scroll_y, canvas_width, canvas_height, opacity, nearest_neighbor, clip_radii);
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
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	NativeSkiaImageSource source;
	if (native_begin_skia_image_source(context, image, &source)) {
		int drawn = ladybird_v_skia_draw_rgba_image_tiles(context, source.pixels,
		    image->width, image->height, source.pitch, tiles, tile_count, clip_x,
		    clip_y, clip_width, clip_height, transform_a, transform_b, transform_c,
		    transform_d, transform_e, transform_f, page_x, page_y, scroll_y,
		    canvas_width, canvas_height, opacity, nearest_neighbor, source.flags,
		    clip_radii);
		native_end_skia_image_source(&source);
		if (drawn)
			return;
	}
#endif
	for (int index = 0; index < tile_count; ++index) {
		float const *tile = tiles + (size_t)index * 8;
		native_draw_image_part_in_context(context, image, tile[0], tile[1], tile[2],
			tile[3], tile[4], tile[5], tile[6], tile[7], clip_x, clip_y, clip_width,
			clip_height, transform_a, transform_b, transform_c, transform_d,
			transform_e, transform_f, page_x, page_y, scroll_y, canvas_width,
			canvas_height, opacity, nearest_neighbor, clip_radii);
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
		canvas_height, 1.0f, nearest_neighbor ? 1 : 2, NULL);
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
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
	NativeSVGPatternBuild const *build =
		&native_svg_pattern_stack[native_svg_pattern_stack_depth - 1];
	if (ladybird_v_skia_draw_svg_path(context, data, segment_count, even_odd,
		transform_a, transform_b, transform_c, transform_d, transform_e,
		transform_f, 0, 0, 0, build->width, canvas_height, fill_color.r,
		fill_color.g, fill_color.b, fill_color.a, has_fill, stroke_color.r,
		stroke_color.g, stroke_color.b, stroke_color.a, has_stroke, stroke_width,
		line_cap, line_join, miter_limit, 0, NULL, 0, 0, 0)) {
		return;
	}
#endif
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
		nearest_neighbor, NULL);
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

void schedule_native_screenshot(string output_path) {
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
		native_cache_display_in_bitmap(view, bounds, bitmap);
		native_capture_instruction_checkpoint("capture_cached");
		// The backing store follows the display profile (usually Display P3 on modern Macs).
		// Normalize captures to sRGB so pixel comparisons do not report a page-sized color-space
		// delta against Ladybird's untagged screenshot output.
		NSBitmapImageRep *encodedBitmap =
		    [bitmap bitmapImageRepByConvertingToColorSpace:[NSColorSpace sRGBColorSpace]
		                                  renderingIntent:NSColorRenderingIntentRelativeColorimetric];
		if (encodedBitmap == nil) {
			encodedBitmap = bitmap;
		}
		native_capture_instruction_checkpoint("capture_converted");
		NSData *png = [encodedBitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
		native_capture_instruction_checkpoint("capture_encoded");
		if (png == nil) {
			fprintf(stderr, "Ladybird V: could not encode the window screenshot as PNG\n");
			[NSApp terminate:nil];
			return;
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
		} else {
			fprintf(stderr, "Ladybird V: could not save screenshot to %s: %s\n",
			        [path fileSystemRepresentation],
			        write_error == nil ? "unknown error" : [[write_error localizedDescription] UTF8String]);
		}
		[NSApp terminate:nil];
		});
	});
}
