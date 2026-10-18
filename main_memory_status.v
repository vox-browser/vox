module main

import adblock
import gg
import processmetrics
import time

$if macos {
	#include "native_memory_status_darwin.m"

	fn C.native_use_static_memory_label(width f32, status_y f32, height f32) int
	fn C.native_disable_static_memory_label()
}

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

fn (app &BrowserApp) use_native_memory_status(window_width int, status_y int) bool {
	$if macos {
		if app.uses_static_native_memory_policy()
			&& C.native_use_static_memory_label(f32(window_width), f32(status_y), f32(status_bar_height)) != 0 {
			return true
		}
		C.native_disable_static_memory_label()
	}
	return false
}

fn (mut app BrowserApp) draw_memory_status(window_width int, status_y int) {
	if app.use_native_memory_status(window_width, status_y) { return }
	if app.memory_status.refresh_if_due(time.sys_mono_now()) {
		$if macos {
			C.native_wake_browser_after(1000)
		}
	}
	// Reserve an opaque area so long URLs and console messages cannot overlap
	// the readout. GG's default-size width leaves extra room around 12px text.
	width := app.ctx.text_width(app.memory_status.label) + 24
	draw_srgb_rect(app.ctx, f32(window_width - width), f32(status_y), f32(width),
		f32(status_bar_height), gg.rgb(30, 41, 59))
	app.ctx.draw_text(window_width - 12, status_y + 4, app.memory_status.label,
		color: gg.rgb(203, 213, 225)
		size:  12
		align: .right
	)
}

// Include the live default-filter helper in both native and legacy RAM chrome.
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
	return processmetrics.MemorySnapshot{bytes: snapshot.bytes + worker, available: true}
}
