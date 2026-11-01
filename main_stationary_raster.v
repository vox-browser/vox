module main

import layout
import os

const disable_static_media_raster_reuse = os.getenv('VOX_DISABLE_STATIC_MEDIA_RASTER_REUSE') != ''

fn C.native_begin_stationary_raster(u64, u64, u64, f64, f64, f64, f64, i32) i32
fn C.native_end_stationary_raster()
fn C.native_discard_stationary_raster()

fn stationary_document_raster_eligible(commands []layout.PaintCommand) bool {
	return stationary_document_raster_commands_eligible(commands, 0)
}

fn stationary_document_raster_commands_eligible(commands []layout.PaintCommand, depth int) bool {
	if depth > 32 { return false }
	for command in commands {
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
		return C.native_begin_stationary_raster(u64(app.document.unique_id().value()),
			app.document.paint_content_revision(), app.paint_generation, app.scroll_y,
			f64(app.page_top()), app.page_zoom, app.overlay_scrollbars.paint_opacity,
			i32(eligible)) != 0
	}
	return false
}
