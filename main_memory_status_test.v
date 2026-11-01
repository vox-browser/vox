module main

import processmetrics

$if vox_ui2 ? {
	import ui2
	#include "native_address_bar_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(voidptr) voidptr
	fn C.native_test_address_close(voidptr)
}

fn test_memory_status_refreshes_once_per_second_across_idle_and_busy_frames() {
	mut status := BrowserMemoryStatus{}
	assert status.refresh_if_due(0)
	assert status.label.starts_with('RAM: ')
	assert status.next_sample_ns == 1_000_000_000
	first_label := status.label
	assert !status.refresh_if_due(16_000_000)
	assert !status.refresh_if_due(999_999_999)
	assert status.label == first_label
	assert status.refresh_if_due(1_000_000_000)
	assert status.next_sample_ns == 2_000_000_000
	// A delayed frame schedules from the current time without catching up.
	assert status.refresh_if_due(5_000_000_000)
	assert status.next_sample_ns == 6_000_000_000
}

fn test_memory_status_counts_live_worker_and_returns_to_browser_only_after_stop() {
	browser := processmetrics.MemorySnapshot{ bytes: 100_000_000, available: true }
	assert browser_memory_snapshot_including_worker(browser, 0, true).ram_label() == 'RAM: 100.0 MB'
	assert browser_memory_snapshot_including_worker(browser, 25_000_000, true).ram_label() == 'RAM: 125.0 MB'
	assert browser_memory_snapshot_including_worker(browser, 0, true) == browser
}

fn test_memory_status_does_not_hide_child_failure_or_overflow() {
	browser := processmetrics.MemorySnapshot{ bytes: 100_000_000, available: true }
	assert !browser_memory_snapshot_including_worker(browser, 0, false).available
	assert !browser_memory_snapshot_including_worker(processmetrics.MemorySnapshot{}, 1, true).available
	maximum := processmetrics.MemorySnapshot{ bytes: ~u64(0), available: true }
	assert browser_memory_snapshot_including_worker(maximum, 0, true) == maximum
	assert !browser_memory_snapshot_including_worker(maximum, 1, true).available
}

fn test_ui2_memory_timer_updates_only_its_label_and_stops_on_unmount() {
	$if vox_ui2 ? {
		window := C.native_test_address_window()
		mut app := &BrowserApp{}
		app.mount_ui2_chrome(C.native_test_address_parent(window), 800, 600)!
		timer := app.browser_ui().memory_timer
		assert timer != unsafe { nil } && timer.is_active()
		label := ui2.embedded_browser_control('memory')
		generation := app.navigation_generation
		paint_count := app.paint_commands.len
		for _ in 0 .. 3 { app.sample_browser_memory_chrome() }
		assert ui2.embedded_browser_control('memory') == label
		assert ui2.text('memory').starts_with('RAM: ')
		assert app.navigation_generation == generation && app.paint_commands.len == paint_count
		app.unmount_address_bar()
		assert !timer.is_active() && app.browser_ui().memory_timer == unsafe { nil }
		app.sample_browser_memory_chrome()
		app.unmount_address_bar()
		C.native_test_address_close(window)
	}
}
