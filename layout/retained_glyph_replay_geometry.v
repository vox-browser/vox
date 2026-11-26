module layout

import cpuraster
import os

pub const serial_retained_glyph_validation = os.getenv('VOX_SERIAL_RETAINED_GLYPH_VALIDATION') == '1'

pub struct RetainedGlyphReplayGeometry {
pub mut:
	positions []f32
	bounds    cpuraster.Rect
	validation cpuraster.GlyphPositionValidation
}

pub fn retained_glyph_geometry_position_count(command &PaintCommand) int {
	if command.glyph_orientation != .horizontal { return 0 }
	run := command.glyph_run or { return 0 }
	if run.font() == unsafe { nil } { return 0 }
	length := run.glyph_positions().len
	return if length == run.glyph_indices().len * 2 { length } else { 0 }
}

pub fn (mut geometry RetainedGlyphReplayGeometry) prepare_in_range(command &PaintCommand,
	storage []f32, first int, end int) int {
	length := retained_glyph_geometry_position_count(command)
	if length == 0 || length > end - first { return first }
	// Each worker owns this range. V slicing updates shared backing-buffer
	// metadata, so publish a fixed view of the range directly.
	geometry.positions = unsafe {
		array{
			data: &f32(storage.data) + first
			len: length
			cap: length
			element_size: int(sizeof(f32))
			flags: .nofree | .nogrow | .noshrink
		}
	}
	geometry.prepare(command)
	return first + length
}

pub fn (mut geometry RetainedGlyphReplayGeometry) prepare(command &PaintCommand) {
	if geometry.positions.len == 0 { return }
	run := command.glyph_run or { return }
	chromium := run.font().font_rendering_policy == .chromium
	baseline_x := f32(command.glyph_translation_x)
	baseline_y := f32(command.glyph_translation_y)
	if serial_retained_glyph_validation {
		geometry.bounds = cpuraster.prepare_retained_glyph_positions(run.glyph_positions(),
			mut geometry.positions, baseline_x, baseline_y, chromium)
	} else {
		geometry.bounds, geometry.validation = cpuraster.prepare_checked_retained_glyph_positions(
			run.glyph_positions(), mut geometry.positions, baseline_x, baseline_y, chromium)
	}
}
