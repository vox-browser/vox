module main

import platform
import gg

$if macos {
	import os
}

$if macos {
	#include "native_navigation_work_darwin.h"
}

fn C.vox_service_navigation_ui() int
fn C.vox_set_navigation_work_active(int)
fn C.vox_native_frame_consumed_redraws() int

struct DeferredNavigationInput {
	address       string
	add_history   bool
	history_delta int
	is_history    bool
}

struct NavigationWorkScope {
mut:
	app  &BrowserApp = unsafe { nil }
	host platform.CooperativeWorkScope
	heap platform.BrowserActivityHeapScope
}

struct DeferredPageInput {
	event      gg.Event
	document   voidptr
	generation int
}

fn service_navigation_ui(context voidptr) {
	mut app := unsafe { &BrowserApp(context) }
	if app.ctx == unsafe { nil } { return }
	// Checkpoints can run while a paint/layout arena is entered. Input queues
	// and editable browser chrome belong to the shell across those checkpoints.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	$if macos {
		if C.vox_service_navigation_ui() != 0 {
			app.navigation_work_yielded = true
		}
	}
}

fn (mut app BrowserApp) begin_navigation_work() NavigationWorkScope {
	if app.ctx == unsafe { nil } { return NavigationWorkScope{} }
	heap := platform.begin_browser_activity_heap_scope()
	if app.navigation_work_depth == 0 { app.navigation_work_yielded = false }
	app.navigation_work_depth++
	$if macos {
		if app.navigation_work_depth == 1 { C.vox_set_navigation_work_active(1) }
	}
	return NavigationWorkScope{
		app:  &app
		host: platform.begin_cooperative_work(voidptr(&app), service_navigation_ui)
		heap: heap
	}
}

fn (mut scope NavigationWorkScope) finish() {
	if scope.app == unsafe { nil } { return }
	defer { scope.heap.finish() }
	mut app := scope.app
	scope.app = unsafe { nil }
	app.navigation_work_depth--
	scope.host.finish()
	if app.navigation_work_depth == 0 {
		$if macos {
			C.vox_set_navigation_work_active(0)
			if (app.navigation_work_yielded && !app.native_frame_consumed_work())
				|| app.deferred_navigation_input != none || app.deferred_page_input.len > 0 {
				C.native_wake_browser()
			}
		}
	}
}

fn (app &BrowserApp) native_frame_consumed_work() bool {
	$if macos {
		if os.getenv('VOX_TRACE_REDRAWS') != '' {
			eprintln('Vox frame work: checkpoint=${C.vox_native_frame_consumed_redraws()} resources=${app.background_resource_pending.len} navigation=${app.pending_navigation != none} paint=${app.paint_commands_pending} script=${app.js_runtime != unsafe { nil } && app.js_runtime.has_pending_document_state()}')
		}
		if C.vox_native_frame_consumed_redraws() == 0 { return false }
		// A wake consumed during preparation needs no duplicate frame only when
		// all document work reached that frame. Keep unadopted asynchronous work.
		if app.document == unsafe { nil } || app.background_resource_pending.len > 0
			|| app.pending_navigation != none || app.paint_commands_pending { return false }
		// Fetches can finish after the resource poll, while a layout checkpoint
		// consumes their wake. Their buffered responses still need another frame.
		if loader := app.image_request_loader {
			if loader.results.len > 0 { return false }
		}
		if app.js_runtime != unsafe { nil } && app.js_runtime.has_pending_document_state() {
			return false
		}
		return !app.document.needs_style_update_after_layout()
			&& app.document.layout_is_up_to_date() && !app.javascript_tasks_have_unadopted_paint()
	}
	return false
}

fn (mut app BrowserApp) defer_page_input(event &gg.Event) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	input := DeferredPageInput{ event: *event, document: voidptr(app.document), generation: app.navigation_generation }
	last := app.deferred_page_input.len - 1
	if event.typ == .mouse_move && last >= 0 && app.deferred_page_input[last].event.typ == .mouse_move {
		app.deferred_page_input[last] = input
	} else {
		app.deferred_page_input << input
	}
}

fn (mut app BrowserApp) poll_deferred_page_input() {
	if app.navigation_work_depth > 0 { return }
	pending := app.deferred_page_input
	app.deferred_page_input = []DeferredPageInput{}
	for input in pending {
		// Coordinates from an old page must never activate its replacement.
		if input.document != voidptr(app.document) || input.generation != app.navigation_generation {
			continue
		}
		if input.event.typ in [.key_down, .char] && app.address_active { continue }
		app.handle_event(&input.event)
		match input.event.typ {
			.key_down { app.handle_key(input.event.key_code, unsafe { gg.Modifier(input.event.modifiers) }) }
			.char { app.handle_character(input.event.char_code) }
			else {}
		}
	}
}

fn (mut app BrowserApp) poll_deferred_navigation_input() {
	if app.navigation_work_depth > 0 { return }
	input := app.deferred_navigation_input or { return }
	address := input.address
	defer {
		$if gcboehm ? { C.GC_reachable_here(address.str) }
	}
	app.deferred_navigation_input = none
	if input.is_history {
		app.history_go(input.history_delta)
	} else {
		app.navigate(address, input.add_history)
	}
}
