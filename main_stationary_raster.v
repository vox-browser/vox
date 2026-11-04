module main

import layout
import os

const disable_static_media_raster_reuse = os.getenv('VOX_DISABLE_STATIC_MEDIA_RASTER_REUSE') != ''
const copy_stationary_raster_commands = os.getenv('VOX_COPY_STATIONARY_RASTER_COMMANDS') != ''
const stationary_raster_borrow_diagnostics = os.getenv('VOX_STATIONARY_RASTER_BORROW_DIAGNOSTICS') != ''

__global stationary_raster_borrow_reported bool

fn C.native_begin_stationary_raster(u64, u64, u64, f64, f64, f64, f64, i32) i32
fn C.native_begin_stationary_raster_snapshot(u64, u64, u64, f64, f64, f64, f64, i32, i32) i32
fn C.native_end_stationary_raster()
fn C.native_discard_stationary_raster()

fn stationary_document_raster_eligible(commands []layout.PaintCommand) bool {
	return stationary_document_raster_commands_eligible(commands, 0)
}

fn stationary_document_raster_commands_eligible(commands []layout.PaintCommand, depth int) bool {
	if depth > 32 { return false }
	if copy_stationary_raster_commands {
		// Preserve a same-binary control for the previous value-iteration path.
		for command in commands {
			if !stationary_document_raster_command_eligible(&command, depth) { return false }
		}
		return true
	}
	for index in 0 .. commands.len {
		// Eligibility reads only a few fields. Value iteration copies the entire
		// retained command (including unrelated paint payloads) on every frame.
		if !stationary_document_raster_command_eligible(&commands[index], depth) { return false }
	}
	if stationary_raster_borrow_diagnostics && commands.len > 0 && !stationary_raster_borrow_reported {
		stationary_raster_borrow_reported = true
		eprintln('Vox stationary raster: borrowed command scan')
	}
	return true
}

fn stationary_document_raster_command_eligible(command &layout.PaintCommand, depth int) bool {
	match command.kind {
		'draw_canvas', 'draw_nested_document' { return false }
		'draw_video' {
			// An empty video has no live source or pixels to replay. Poster
			// and representation changes replace its retained paint facts and
			// invalidate the document before this cache is consulted.
			if disable_static_media_raster_reuse || command.video_frame_source != none || command.video_bitmap != none {
				return false
			}
		}
		'paint_nested_display_list' {
			// These are retained snapshots, including SVG images. Only live
			// media within the snapshot can change independently of its key.
			if disable_static_media_raster_reuse || !stationary_document_raster_commands_eligible(command.nested_viewport_commands, depth + 1) {
				return false
			}
		}
		else {}
	}
	return true
}

// Canvas and media can provide new pixels during replay without replacing the
// display list. Animated native images also veto storage while being painted.
fn (app &BrowserApp) begin_stationary_document_raster() bool {
	$if macos {
		// AppKit can request the first frame before navigation creates a document.
		if app.document == unsafe { nil } { return false }
		eligible := stationary_document_raster_eligible(app.paint_commands)
		$if vox_ui2 ? {
			// UI2 updates separate native views after document replay. Nothing
			// else draws into this bitmap, so an immutable frame can supply it.
			return C.native_begin_stationary_raster_snapshot(u64(app.document.unique_id().value()),
				app.document.paint_content_revision(), app.paint_generation, app.scroll_y,
				f64(app.page_top()), app.page_zoom, app.overlay_scrollbars.paint_opacity,
				i32(eligible), 1) != 0
		}
		return C.native_begin_stationary_raster(u64(app.document.unique_id().value()),
			app.document.paint_content_revision(), app.paint_generation, app.scroll_y,
			f64(app.page_top()), app.page_zoom, app.overlay_scrollbars.paint_opacity,
			i32(eligible)) != 0
	}
	return false
}

// Before a document has pixels, each frame is one full-canvas white fill.
// UI2 draws its chrome in separate native views, so later blank frames of the
// same size can present the retained white frame instead of filling a new
// bitmap. The reserved owner never matches a document, whose first frame
// replaces this cache. Other builds draw chrome into the bitmap and keep
// clearing it.
const stationary_blank_raster_owner = u64(0xffff_ffff_ffff_ffff)

fn begin_stationary_blank_raster() bool {
	$if macos {
		$if vox_ui2 ? {
			return C.native_begin_stationary_raster_snapshot(stationary_blank_raster_owner,
				0, 0, 0, 0, 1, 0, 1, 1) != 0
		}
		C.native_discard_stationary_raster()
	}
	return false
}
