module main

import gg

#include "native_layer_presentation_test_darwin.h"

fn C.native_test_parent_tick_frame_ownership(fn (voidptr), voidptr) int
fn C.native_test_capture_copy_preserves_pixels_and_skips_redundant_frames() int
fn C.native_test_layer_retains_immutable_frame_without_copying_pixels() int

fn test_native_layer_retains_snapshot_ownership_and_still_runs_the_frame_callback() {
	$if macos {
		assert C.native_test_layer_retains_immutable_frame_without_copying_pixels() == 63
	}
}

fn test_capture_copies_the_presented_raster_and_still_renders_real_invalidations() {
	$if macos {
		assert C.native_test_capture_copy_preserves_pixels_and_skips_redundant_frames() == 31
	}
}

fn native_parent_tick_frame(target voidptr) {
	mut app := unsafe { &BrowserApp(target) }
	app.draw()
}

fn test_native_parent_ticks_do_not_run_document_frames_without_a_paint_context() {
	$if macos {
		mut app := &BrowserApp{ctx: &gg.Context{native_rendering: true}}
		assert C.native_test_parent_tick_frame_ownership(native_parent_tick_frame, app) == 7
		assert !app.initial_window_frame_presented
		assert !app.document_presented
		assert app.navigation_work_depth == 0
	}
}

fn C.native_test_layer_uses_document_capture_density() int
fn C.native_test_layer_capture_frame_invalidation() int

fn test_native_capture_reuses_only_current_matching_frames() {
	$if macos {
		assert C.native_test_layer_capture_frame_invalidation() == 4095
	}
}

fn test_native_layer_presentation_uses_the_same_density_as_the_document() {
	$if macos {
		assert C.native_test_layer_uses_document_capture_density() == 31
	}
}

fn C.native_test_layer_frame_scale_capture_and_callbacks() int

fn test_native_layer_frames_preserve_pixels_scale_resize_capture_and_parent_callbacks() {
	$if macos {
		assert C.native_test_layer_frame_scale_capture_and_callbacks() == 1023
	}
}
