module main

import cpuraster
import layout
import os

const serial_retained_glyph_geometry = os.getenv('VOX_SERIAL_RETAINED_GLYPH_GEOMETRY') == '1'
const retained_glyph_geometry_diagnostics = os.getenv('VOX_RETAINED_GLYPH_GEOMETRY_DIAGNOSTICS') == '1'
const retained_glyph_geometry_position_limit = 128 * 1024
const retained_glyph_geometry_command_limit = 16 * 1024

struct RetainedGlyphReplayGeometry {
mut:
	positions []f32
	bounds    cpuraster.Rect
}

@[params]
struct RetainedGlyphGeometryOptions {
	glyph_geometry &RetainedGlyphReplayGeometry = unsafe { nil }
}

fn plan_retained_glyph_geometry(commands []layout.PaintCommand) []RetainedGlyphReplayGeometry {
	if serial_retained_glyph_geometry || commands.len > retained_glyph_geometry_command_limit {
		return []
	}
	mut counts := []int{len: commands.len}
	mut total := 0
	for index in 0 .. commands.len {
		command := unsafe { &commands[index] }
		if command.kind != 'draw_text' || command.glyph_orientation != .horizontal { continue }
		run := command.glyph_run or { continue }
		if run.font() == unsafe { nil } { continue }
		length := run.glyph_positions().len
		if length == 0 || length != run.glyph_indices().len * 2 { continue }
		if length > retained_glyph_geometry_position_limit - total { continue }
		counts[index] = length
		total += length
	}
	if total == 0 { return [] }
	positions := []f32{len: total}
	mut result := []RetainedGlyphReplayGeometry{len: commands.len}
	mut start := 0
	for index, count in counts {
		if count == 0 { continue }
		result[index].positions = positions[start..start + count]
		start += count
	}
	return result
}

fn (mut geometry RetainedGlyphReplayGeometry) prepare(command &layout.PaintCommand) {
	if geometry.positions.len == 0 { return }
	run := command.glyph_run or { return }
	chromium := run.font().font_rendering_policy == .chromium
	geometry.bounds = cpuraster.prepare_retained_glyph_positions(run.glyph_positions(),
		mut geometry.positions, f32(command.glyph_translation_x), f32(command.glyph_translation_y),
		chromium)
}
