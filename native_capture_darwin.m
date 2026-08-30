#include <Cocoa/Cocoa.h>
#include <CoreText/CoreText.h>
#include <math.h>
#include <stdlib.h>

static NSString *native_capture_string(string value) {
	return [[NSString alloc] initWithBytes:value.str
	                              length:(NSUInteger)value.len
	                            encoding:NSUTF8StringEncoding];
}

static NSView *native_cached_browser_view;

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

static NSString *native_document_font_name;

void native_configure_document_font(string path_value) {
	NSString *path = native_capture_string(path_value);
	CGDataProviderRef provider = CGDataProviderCreateWithFilename([path fileSystemRepresentation]);
	if (provider == NULL) {
		return;
	}
	CGFontRef font = CGFontCreateWithDataProvider(provider);
	CGDataProviderRelease(provider);
	if (font == NULL) {
		return;
	}
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

int native_window_width(void) {
	return (int)llround([native_browser_view() bounds].size.width);
}

int native_window_height(void) {
	return (int)llround([native_browser_view() bounds].size.height);
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

void native_draw_document_text_srgb(float x, float y, string value, gg__Color color,
	float size, int bold, int italic, int monospace) {
	NSString *text = native_capture_string(value);
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
	NSColor *foreground = [NSColor colorWithSRGBRed:(CGFloat)color.r / 255.0
	                                        green:(CGFloat)color.g / 255.0
	                                         blue:(CGFloat)color.b / 255.0
	                                        alpha:(CGFloat)color.a / 255.0];
	[text drawAtPoint:NSMakePoint(x, y - 15.0)
	      withAttributes:@{ NSForegroundColorAttributeName : foreground, NSFontAttributeName : font }];
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

void native_draw_image_part(gg__Image *image, float destination_x, float destination_y,
	float destination_width, float destination_height, float source_x, float source_y,
	float source_width, float source_height, float canvas_height, float opacity) {
	if (image == NULL || image->data == NULL || destination_width <= 0 || destination_height <= 0
	    || source_width <= 0 || source_height <= 0) {
		return;
	}
	NSImage *native_image = (__bridge NSImage *)image->data;
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

void schedule_native_screenshot(string output_path) {
	NSString *path = native_capture_string(output_path);
	const char *delay_value = getenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS");
	double delay = delay_value == NULL ? 0.1 : strtod(delay_value, NULL);
	if (delay < 0.0) {
		delay = 0.0;
	}
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
	               dispatch_get_main_queue(), ^{
		NSView *view = native_browser_view();
		[view displayIfNeeded];
		NSRect bounds = [view bounds];
		NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:bounds];
		if (bitmap == nil) {
			CGFloat scale = [[view window] backingScaleFactor];
			if (scale <= 0.0) {
				scale = 1.0;
			}
			NSInteger pixels_wide = (NSInteger)llround(bounds.size.width * scale);
			NSInteger pixels_high = (NSInteger)llround(bounds.size.height * scale);
			if (pixels_wide <= 0 || pixels_high <= 0) {
				fprintf(stderr, "Ladybird V: invalid screenshot dimensions %.0fx%.0f at scale %.2f\n",
				        bounds.size.width, bounds.size.height, scale);
				[NSApp terminate:nil];
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
		if (bitmap == nil) {
			fprintf(stderr, "Ladybird V: could not allocate a bitmap for the window screenshot\n");
			[NSApp terminate:nil];
			return;
		}
		[view cacheDisplayInRect:bounds toBitmapImageRep:bitmap];
		// The backing store follows the display profile (usually Display P3 on modern Macs).
		// Normalize captures to sRGB so pixel comparisons do not report a page-sized color-space
		// delta against Ladybird's untagged screenshot output.
		NSBitmapImageRep *encodedBitmap =
		    [bitmap bitmapImageRepByConvertingToColorSpace:[NSColorSpace sRGBColorSpace]
		                                  renderingIntent:NSColorRenderingIntentRelativeColorimetric];
		if (encodedBitmap == nil) {
			encodedBitmap = bitmap;
		}
		NSData *png = [encodedBitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
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
}
