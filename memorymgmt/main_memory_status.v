module main

import adblock
import platform
import ui2
import processmetrics
import time

struct BrowserMemoryStatus {
mut:
	sampled        bool
	next_sample_ns i64
	label          string
}

// Schedule only one wakeup per sample, even when animation frames are frequent.
fn (mut status BrowserMemoryStatus) refresh_if_due(now_ns i64) bool {
	if status.sampled && now_ns < status.next_sample_ns {
		return false
	}
	status.sampled = true
	status.next_sample_ns = now_ns + i64(time.second)
	status.label = browser_memory_snapshot().ram_label()
	return true
}

fn (mut app BrowserApp) start_browser_memory_chrome() {
	app.stop_browser_memory_chrome()
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut state := app.browser_ui()
	owner := voidptr(&app)
	state.memory_timer = platform.Timer.create_repeating(1000, fn [owner] () {
		mut app := unsafe { &BrowserApp(owner) }
		app.sample_browser_memory_chrome()
	})
	state.memory_timer.start()
	app.sample_browser_memory_chrome()
}

fn (mut app BrowserApp) stop_browser_memory_chrome() {
	if app.browser_ui_ == unsafe { nil } { return }
	mut state := app.browser_ui()
	if state.memory_timer != unsafe { nil } {
		state.memory_timer.stop()
		state.memory_timer = unsafe { nil }
	}
}

fn (mut app BrowserApp) sample_browser_memory_chrome() {
	$if vox_ui2 ? {
		if !app.native_address_bar || !ui2.embedded_control_attached('memory') {
			app.stop_browser_memory_chrome()
			return
		}
	}
	// Formatting and native string copies stay in a disposable scratch scope.
	// set_text updates only the UI2 label; it never invalidates the document.
	scratch := platform.begin_thread_scratch('UI2 memory label')
	defer { scratch.finish() }
	label := browser_memory_snapshot().ram_label()
	$if vox_ui2 ? {
		if ui2.text('memory') != label { ui2.set_text('memory', label) }
	}
	$if linux || ui2_custom_rendering ? {
		mut state := app.browser_ui()
		if state.memory_label != label {
			persistent := platform.enter_persistent()
			state.memory_label = label.clone()
			platform.leave_persistent(persistent)
			request_browser_frame()
		}
	}
}

// Include the live default-filter helper in every UI2 backend.
// An unavailable child sample must not silently under-report an active worker.
fn browser_memory_snapshot() processmetrics.MemorySnapshot {
	snapshot := processmetrics.memory_snapshot()
	worker := adblock.default_worker_memory_bytes() or { return processmetrics.MemorySnapshot{} }
	return browser_memory_snapshot_including_worker(snapshot, worker, true)
}

fn browser_memory_snapshot_including_worker(snapshot processmetrics.MemorySnapshot, worker u64, worker_available bool) processmetrics.MemorySnapshot {
	if !snapshot.available || !worker_available || worker > ~u64(0) - snapshot.bytes {
		return processmetrics.MemorySnapshot{}
	}
	return processmetrics.MemorySnapshot{ bytes: snapshot.bytes + worker, available: true }
}
