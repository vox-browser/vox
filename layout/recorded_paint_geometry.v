module layout

import dom
import os

const record_canvas_ink_bounds = os.getenv('VOX_RECORD_CANVAS_INK_BOUNDS') == '1'
const record_glyph_replay_geometry = os.getenv('VOX_RECORD_GLYPH_REPLAY_GEOMETRY') == '1'
	&& os.getenv('VOX_SERIAL_RETAINED_GLYPH_GEOMETRY') != '1'
	&& os.getenv('VOX_PACKED_RETAINED_GLYPH_GEOMETRY') != '1'
// A command owns its slice even when prefix projection changes the worker
// ranges. Runs that need more coordinates use replay's ordinary preparation.
const recorded_glyph_coordinates_per_command = 32

struct RecordedPaintGeometry {
	prepare_canvas_ink bool
	prepare_glyphs bool
mut:
	raster_bounds RecordedRasterBounds
	canvas_ink    []RecordedCanvasInk
	glyphs        []RetainedGlyphReplayGeometry
	glyph_coordinates []f32
}

pub struct RecordedCanvasInk {
	bounds LayoutRect
	ready  bool
}

fn (geometry &RecordedPaintGeometry) canvas_ink_data() &RecordedCanvasInk {
	return unsafe {
		if geometry.canvas_ink.len > 0 { &RecordedCanvasInk(geometry.canvas_ink.data) } else { nil }
	}
}

fn (geometry &RecordedPaintGeometry) glyph_data() &RetainedGlyphReplayGeometry {
	return unsafe {
		if geometry.glyphs.len > 0 { &RetainedGlyphReplayGeometry(geometry.glyphs.data) } else { nil }
	}
}

fn record_canvas_leaf_ink(command &PaintCommand) RecordedCanvasInk {
	// These commands use retained value geometry or immutable glyph runs.
	// Media, child viewports and background resources can change during replay.
	if command.kind !in ['draw_text', 'fill_rect', 'fill_rounded_rect', 'fill_ellipse',
		'stroke_rounded_rect', 'stroke_ellipse', 'draw_line', 'fill_polygon'] {
		return RecordedCanvasInk{}
	}
	return RecordedCanvasInk{
		bounds: paint_canvas_leaf_ink_bounds(command) or { LayoutRect{} }
		ready: true
	}
}

// The caller keeps the corresponding display-list scene alive while reading.
pub fn display_list_canvas_ink(display_list &dom.DisplayList, commands []PaintCommand) []RecordedCanvasInk {
	if record_canvas_ink_bounds {
		if recording := display_list_recording(display_list) {
			if recording.commands.data == commands.data
				&& recording.geometry.canvas_ink.len == commands.len {
				return recording.geometry.canvas_ink
			}
		}
	}
	return []
}

// The caller keeps the corresponding display-list scene alive while reading.
pub fn display_list_glyph_geometry(display_list &dom.DisplayList, commands []PaintCommand) []RetainedGlyphReplayGeometry {
	if record_glyph_replay_geometry {
		if recording := display_list_recording(display_list) {
			if recording.commands.data == commands.data && recording.geometry.glyphs.len == commands.len {
				return recording.geometry.glyphs
			}
		}
	}
	return []
}

pub fn (ink &RecordedCanvasInk) prepared() bool {
	return ink.ready
}

pub fn (ink &RecordedCanvasInk) outside_canvas(page_x f64, page_y f64, width f64, height f64) bool {
	return paint_canvas_is_testable(page_x, page_y, width, height)
		&& paint_ink_is_outside_canvas(ink.bounds, page_x, page_y, width, height)
}
