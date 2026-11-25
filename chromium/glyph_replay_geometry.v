module main

import cpuraster
import layout
import os

const serial_retained_glyph_geometry = os.getenv('VOX_SERIAL_RETAINED_GLYPH_GEOMETRY') == '1'
const packed_retained_glyph_geometry = os.getenv('VOX_PACKED_RETAINED_GLYPH_GEOMETRY') == '1'
const retained_glyph_geometry_diagnostics = os.getenv('VOX_RETAINED_GLYPH_GEOMETRY_DIAGNOSTICS') == '1'
const retained_glyph_geometry_position_limit = 128 * 1024
const retained_glyph_geometry_command_limit = 16 * 1024
// Reserve for the usual mix of glyph runs and other commands. Longer runs
// that do not fit their worker's slice are prepared on demand.
const retained_glyph_positions_per_command = 24

struct RetainedGlyphReplayGeometry {
mut:
	positions []f32
	bounds    cpuraster.Rect
}

@[params]
struct RetainedGlyphGeometryOptions {
	glyph_geometry &RetainedGlyphReplayGeometry = unsafe { nil }
}

fn retained_glyph_geometry_position_count(command &layout.PaintCommand) int {
	if command.glyph_orientation != .horizontal { return 0 }
	run := command.glyph_run or { return 0 }
	if run.font() == unsafe { nil } { return 0 }
	length := run.glyph_positions().len
	return if length == run.glyph_indices().len * 2 { length } else { 0 }
}

fn reserve_retained_glyph_geometry(commands []layout.PaintCommand) ([]RetainedGlyphReplayGeometry,
	[]f32) {
	if commands.len == 0 || serial_retained_glyph_geometry
		|| commands.len > retained_glyph_geometry_command_limit {
		return []RetainedGlyphReplayGeometry{}, []f32{}
	}
	if packed_retained_glyph_geometry {
		return plan_packed_retained_glyph_geometry(commands), []f32{}
	}
	count := commands.len * retained_glyph_positions_per_command
	return []RetainedGlyphReplayGeometry{len: commands.len},
		[]f32{len: if count < retained_glyph_geometry_position_limit { count } else { retained_glyph_geometry_position_limit }}
}

fn plan_packed_retained_glyph_geometry(commands []layout.PaintCommand) []RetainedGlyphReplayGeometry {
	mut counts := []int{len: commands.len}
	mut total := 0
	for index in 0 .. commands.len {
		command := unsafe { &commands[index] }
		if command.kind != 'draw_text' { continue }
		length := retained_glyph_geometry_position_count(command)
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

fn (mut geometry RetainedGlyphReplayGeometry) prepare_in_range(command &layout.PaintCommand,
	storage []f32, first int, end int) int {
	length := retained_glyph_geometry_position_count(command)
	if length == 0 || length > end - first { return first }
	geometry.positions = storage[first..first + length]
	geometry.prepare(command)
	return first + length
}

fn (mut geometry RetainedGlyphReplayGeometry) prepare(command &layout.PaintCommand) {
	if geometry.positions.len == 0 { return }
	run := command.glyph_run or { return }
	chromium := run.font().font_rendering_policy == .chromium
	geometry.bounds = cpuraster.prepare_retained_glyph_positions(run.glyph_positions(),
		mut geometry.positions, f32(command.glyph_translation_x), f32(command.glyph_translation_y),
		chromium)
}
