module main

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

@[params]
struct RetainedGlyphGeometryOptions {
	glyph_geometry &layout.RetainedGlyphReplayGeometry = unsafe { nil }
}

fn reserve_retained_glyph_geometry(commands []layout.PaintCommand) ([]layout.RetainedGlyphReplayGeometry,
	[]f32) {
	if commands.len == 0 || serial_retained_glyph_geometry
		|| commands.len > retained_glyph_geometry_command_limit {
		return []layout.RetainedGlyphReplayGeometry{}, []f32{}
	}
	if packed_retained_glyph_geometry {
		return plan_packed_retained_glyph_geometry(commands), []f32{}
	}
	count := commands.len * retained_glyph_positions_per_command
	return []layout.RetainedGlyphReplayGeometry{len: commands.len},
		[]f32{len: if count < retained_glyph_geometry_position_limit { count } else { retained_glyph_geometry_position_limit }}
}

fn plan_packed_retained_glyph_geometry(commands []layout.PaintCommand) []layout.RetainedGlyphReplayGeometry {
	mut counts := []int{len: commands.len}
	mut total := 0
	for index in 0 .. commands.len {
		command := unsafe { &commands[index] }
		if command.kind != 'draw_text' { continue }
		length := layout.retained_glyph_geometry_position_count(command)
		if length > retained_glyph_geometry_position_limit - total { continue }
		counts[index] = length
		total += length
	}
	if total == 0 { return [] }
	positions := []f32{len: total}
	mut result := []layout.RetainedGlyphReplayGeometry{len: commands.len}
	mut start := 0
	for index, count in counts {
		if count == 0 { continue }
		result[index].positions = positions[start..start + count]
		start += count
	}
	return result
}
