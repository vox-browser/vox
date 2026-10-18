#pragma once
#include <Cocoa/Cocoa.h>
#include "processmetrics/memory_darwin.h"
#include "adblock/worker_transport_api.h"

// The control is created and rendered by UI2. Sampling updates only its native
// string, keeping idle RAM updates out of the document renderer and V heap.
static __weak NSTextField *vox_chrome_memory_label;
static dispatch_source_t vox_chrome_memory_timer;
static id vox_chrome_memory_close_observer;

static void native_browser_chrome_stop_memory(void) {
	if (vox_chrome_memory_timer != nil) {
		dispatch_source_cancel(vox_chrome_memory_timer);
		vox_chrome_memory_timer = nil;
	}
	if (vox_chrome_memory_close_observer != nil) {
		[NSNotificationCenter.defaultCenter removeObserver:vox_chrome_memory_close_observer];
		vox_chrome_memory_close_observer = nil;
	}
	vox_chrome_memory_label = nil;
}

static void native_browser_chrome_sample_memory(void) {
	NSTextField *field = vox_chrome_memory_label;
	if (field == nil || field.window == nil) {
		native_browser_chrome_stop_memory();
		return;
	}
	uint64_t browser = 0, worker = 0;
	BOOL available = vox_process_memory_bytes(&browser) == 0
		&& vox_adblock_worker_memory_bytes(&worker) == 0 && UINT64_MAX - browser >= worker;
	uint64_t bytes = available ? browser + worker : 0;
	NSString *value = !available ? @"RAM: unavailable" : bytes >= UINT64_C(1000000000)
		? [NSString stringWithFormat:@"RAM: %.1f GB", (double)bytes / 1000000000.0]
		: [NSString stringWithFormat:@"RAM: %.1f MB", (double)bytes / 1000000.0];
	if (![field.stringValue isEqualToString:value]) field.stringValue = value;
}

static void native_browser_chrome_start_memory(void *control) {
	native_browser_chrome_stop_memory();
	NSTextField *field = (__bridge NSTextField *)control;
	vox_chrome_memory_label = field;
	vox_chrome_memory_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
		dispatch_get_main_queue());
	dispatch_source_set_timer(vox_chrome_memory_timer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
		NSEC_PER_SEC, 20 * NSEC_PER_MSEC);
	dispatch_source_set_event_handler(vox_chrome_memory_timer, ^{
		@autoreleasepool { native_browser_chrome_sample_memory(); }
	});
	vox_chrome_memory_close_observer = [NSNotificationCenter.defaultCenter
		addObserverForName:NSWindowWillCloseNotification object:field.window
		queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *notification) {
			(void)notification;
			native_browser_chrome_stop_memory();
		}];
	dispatch_resume(vox_chrome_memory_timer);
	native_browser_chrome_sample_memory();
}
