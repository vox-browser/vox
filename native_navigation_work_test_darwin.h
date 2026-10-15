#pragma once
#include "native_layer_presentation_darwin.h"
#include "native_navigation_work_darwin.h"

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
