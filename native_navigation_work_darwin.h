#pragma once
#import <Cocoa/Cocoa.h>
#include "native_layer_presentation_darwin.h"

static void vox_set_navigation_work_active(int active) {
	native_layer_document_work_active = active != 0;
}

static int vox_native_frame_consumed_redraws(void) {
	return native_layer_presenting && native_layer_paint_started
		&& native_layer_paint_generation == native_layer_redraw_generation;
}

static int vox_service_navigation_ui(void) {
	if (!NSThread.isMainThread || !NSApp) return 0;
	uint64_t generation = native_layer_redraw_generation;
	@autoreleasepool {
		NSGraphicsContext *previous = NSGraphicsContext.currentContext;
		@try {
		// A zero-duration run-loop pass can leave input posted by another
		// thread in AppKit's source until this entire document operation ends.
		// Give that source a bounded opportunity before inspecting the queue.
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.001, true);
		// Native input may edit chrome or queue a replacement navigation. The
		// V owner guards document input and translated timers during this pump.
		for (unsigned i = 0; i < 16; ++i) {
			NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny
				untilDate:NSDate.distantPast inMode:NSDefaultRunLoopMode dequeue:YES];
			if (!event) break;
			[NSApp sendEvent:event];
		}
		[NSApp updateWindows];
		} @finally {
			NSGraphicsContext.currentContext = previous;
		}
	}
	// A pump can consume a resource's wake while document work suppresses its
	// native frame. Preserve that redraw, but never turn pumping alone into a
	// request for another frame: slow static frames must eventually become idle.
	return native_layer_redraw_generation != generation;
}
