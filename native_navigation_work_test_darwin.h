#pragma once
#include "native_layer_presentation_darwin.h"
// Exported by navigation/main_navigation_work.v.
int32_t vox_service_navigation_ui(void);

void native_wake_browser(void);

static void vox_test_begin_prepared_frame(void) {
	[NSApplication sharedApplication];
	for (unsigned i = 0; i < 16; ++i) vox_service_navigation_ui();
	native_layer_presenting = YES;
	vox_browser_frame_prepared();
}
static void vox_test_end_prepared_frame(void) {
	native_layer_presenting = NO;
	native_layer_paint_started = NO;
}

static unsigned vox_work_test_draws;
static void vox_work_test_draw(id view, SEL selector, NSRect rect) {
	(void)selector;
	++vox_work_test_draws;
	native_layer_update(view, @selector(updateLayer));
	CGContextRef context = NSGraphicsContext.currentContext.CGContext;
	CGContextSetRGBFillColor(context, 0, 1, 0, 1);
	CGContextFillRect(context, rect);
}

static int vox_test_navigation_frame_guard(void) {
	@autoreleasepool {
		IMP original = native_layer_original_draw;
		NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 8, 8)];
		view.wantsLayer = YES;
		vox_work_test_draws = 0;
		native_layer_original_draw = (IMP)vox_work_test_draw;
		native_layer_update(view, @selector(updateLayer));
		int result = vox_work_test_draws == 1 && !native_layer_presenting ? 1 : 0;
		id frame = view.layer.contents;
		native_layer_document_work_active = YES;
		native_layer_update(view, @selector(updateLayer));
		if (vox_work_test_draws == 1 && view.layer.contents == frame) result |= 2;
		native_layer_document_work_active = NO;
		native_layer_update(view, @selector(updateLayer));
		if (vox_work_test_draws == 2 && view.layer.contents != frame) result |= 4;
		native_layer_original_draw = original;
		return result;
	}
}

static int vox_test_navigation_ui_pump(void) {
	@autoreleasepool {
		[NSApplication sharedApplication];
		__block unsigned received = 0;
		__block double maximum_delay = 0;
		id monitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskApplicationDefined
			handler:^NSEvent *(NSEvent *event) {
				if (event.subtype != 1042) return event;
				++received;
				maximum_delay = fmax(maximum_delay,
					NSProcessInfo.processInfo.systemUptime - event.timestamp);
				return nil;
			}];
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
			@autoreleasepool {
				[NSThread sleepForTimeInterval:0.01];
				NSEvent *event = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
					location:NSZeroPoint modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime
					windowNumber:0 context:nil subtype:1042 data1:0 data2:0];
				[NSApp postEvent:event atStart:NO];
			}
		});
		NSGraphicsContext *previous = NSGraphicsContext.currentContext;
		double deadline = NSProcessInfo.processInfo.systemUptime + 1;
		while (!received && NSProcessInfo.processInfo.systemUptime < deadline)
			vox_service_navigation_ui();
		[NSEvent removeMonitor:monitor];
		int result = received == 1 && maximum_delay < 0.1 ? 1 : 0;
		if (NSGraphicsContext.currentContext == previous) result |= 2;
		return result;
	}
}

static int vox_test_navigation_ui_redraw_generation(void) {
	@autoreleasepool {
		[NSApplication sharedApplication];
		// Earlier test cases may have legitimate queued navigation/input wakes.
		for (unsigned i = 0; i < 16; ++i) {
			if (!vox_service_navigation_ui()) break;
		}
		int result = 0;
		uint64_t idle_generation = native_layer_redraw_generation;
		if (!vox_service_navigation_ui()
			&& native_layer_redraw_generation == idle_generation) result |= 1;
		// Exercise the same wake used after a background fetch posts its result.
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
			@autoreleasepool {
				[NSThread sleepForTimeInterval:0.01];
				native_wake_browser();
			}
		});
		double deadline = NSProcessInfo.processInfo.systemUptime + 1;
		BOOL observed = NO;
		while (!observed && NSProcessInfo.processInfo.systemUptime < deadline)
			observed = vox_service_navigation_ui() != 0;
		if (observed && native_layer_redraw_generation != idle_generation) result |= 2;
		uint64_t completed_generation = native_layer_redraw_generation;
		for (unsigned i = 0; i < 3; ++i) {
			if (vox_service_navigation_ui()
				|| native_layer_redraw_generation != completed_generation) return result;
		}
		return result | 4;
	}
}

static void vox_test_queue_navigation_redraw(void) {
	native_wake_browser();
}

static int vox_test_navigation_native_size_invalidations(void) {
	@autoreleasepool {
		[NSApplication sharedApplication];
		for (unsigned i = 0; i < 16; ++i) {
			if (!vox_service_navigation_ui()) break;
		}
		NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 8, 8)];
		IMP saved_frame_size = native_layer_original_frame_size;
		IMP saved_backing = native_layer_original_backing;
		BOOL saved_work = native_layer_document_work_active;
		native_layer_original_frame_size = method_getImplementation(
			class_getInstanceMethod(NSView.class, @selector(setFrameSize:)));
		native_layer_original_backing = NULL;
		native_layer_document_work_active = YES;
		int result = 0;
		@try {
			uint64_t unchanged_generation = native_layer_redraw_generation;
			native_layer_frame_size_changed(view, @selector(setFrameSize:), NSMakeSize(8, 8));
			if (native_layer_redraw_generation == unchanged_generation) result |= 1;
			// AppKit may consume the resize's native frame during the pump while
			// document work is guarded. The generation must retain that repaint.
			dispatch_async(dispatch_get_main_queue(), ^{
				native_layer_frame_size_changed(view, @selector(setFrameSize:), NSMakeSize(16, 12));
			});
			double deadline = NSProcessInfo.processInfo.systemUptime + 1;
			BOOL observed = NO;
			while (!observed && NSProcessInfo.processInfo.systemUptime < deadline)
				observed = vox_service_navigation_ui() != 0;
			if (observed && native_layer_redraw_generation != unchanged_generation
				&& NSEqualSizes(view.frame.size, NSMakeSize(16, 12))) result |= 2;
			uint64_t resized_generation = native_layer_redraw_generation;
			dispatch_async(dispatch_get_main_queue(), ^{
				native_layer_backing_changed(view, @selector(viewDidChangeBackingProperties));
			});
			deadline = NSProcessInfo.processInfo.systemUptime + 1;
			observed = NO;
			while (!observed && NSProcessInfo.processInfo.systemUptime < deadline)
				observed = vox_service_navigation_ui() != 0;
			if (observed && native_layer_redraw_generation != resized_generation) result |= 4;
		} @finally {
			native_layer_original_frame_size = saved_frame_size;
			native_layer_original_backing = saved_backing;
			native_layer_document_work_active = saved_work;
		}
		return result;
	}
}
