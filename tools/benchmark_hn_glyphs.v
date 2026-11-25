// Replay the retained text captured from the archived Hacker News homepage by
// VOX_TEXT_RASTER_DUMP. Time the CPU glyph renderer with a fresh strike cache
// and report a digest of all output buffers. The input excludes page-wide
// work such as layout, Quartz compositing and screenshot encoding.
module main

import cpuraster
import crypto.sha256
import json2
import os
import time

struct GlyphCapture {
	index          int
	font           string
	face           int
	size           f32
	glyphs         []u16
	positions      []f32
	translation    []f32
	transform      []f32
	geometry       []int
	color          u32
	smoothing      int
	backdrop       bool
	paint_color    ?[]f32
	destination_p3 bool
}

struct GlyphReplay {
	run       cpuraster.CanvasGlyphRun
	transform [6]f32
	color     u32
	width     int
	height    int
mut:
	pixels []u8
}

fn load_glyph_replay(directory string) ![]GlyphReplay {
	mut output := []GlyphReplay{}
	mut registered := map[string]bool{}
	for line in os.read_lines(os.join_path(directory, 'runs.jsonl'))! {
		row := json2.decode[GlyphCapture](line)!
		if row.index != output.len || row.transform.len != 6 || row.translation.len != 2
			|| row.geometry.len != 7 || row.positions.len != 2 * row.glyphs.len
			|| row.destination_p3 || row.paint_color != none {
			return error('Unexpected Hacker News text raster inputs at run ${row.index}')
		}
		width, height := row.geometry[2], row.geometry[3]
		if width < 1 || height < 1 || i64(width) * height > 64 * 1024 * 1024 {
			return error('Invalid raster dimensions at run ${row.index}')
		}
		if row.font.starts_with('vox-system-face:') && row.font !in registered {
			spec := row.font.all_after('vox-system-face:')
			path := spec.all_before('|').all_before_last('#')
			if !cpuraster.register_glyph_face(row.font, path, spec.all_after('|'), [], []) {
				return error('Could not open ${row.font}')
			}
			registered[row.font] = true
		}
		pixels := if row.backdrop {
			os.read_bytes(os.join_path(directory, '${row.index}.rgba'))!
		} else {
			[]u8{len: width * height * 4}
		}
		if pixels.len != width * height * 4 { return error('Invalid backdrop at run ${row.index}') }
		output << GlyphReplay{
			run:       cpuraster.CanvasGlyphRun{
				font_path:         row.font
				face_index:        row.face
				font_size:         row.size
				glyphs:            row.glyphs
				positions:         row.positions
				translation:       [row.translation[0], row.translation[1]]!
				baseline_snap:     true
				smoothing:         row.smoothing & 15
				retained:          true
				chromium_coverage: row.smoothing & 16 != 0
			}
			transform: [row.transform[0], row.transform[1], row.transform[2], row.transform[3],
				row.transform[4], row.transform[5]]!
			color:     row.color
			width:     width
			height:    height
			pixels:    pixels
		}
	}
	if output.len == 0 { return error('Empty glyph capture') }
	return output
}

fn main() {
	if os.args.len != 2 { panic('Usage: benchmark_hn_glyphs GLYPH_DUMP_DIRECTORY') }
	mut draws := load_glyph_replay(os.args[1]) or { panic(err) }
	mut cache := cpuraster.new_glyph_cache()
	start := time.sys_mono_now()
	for mut draw in draws {
		if !cpuraster.fill_canvas_glyphs_cached(mut cache, mut draw.pixels, draw.width, draw.height,
			draw.width * 4, 2, draw.run, draw.transform, draw.color, none, 1, .src_over, [], none) {
			panic('Captured glyph run was declined')
		}
	}
	elapsed := time.sys_mono_now() - start
	mut hash := sha256.new()
	for draw in draws { hash.write(draw.pixels) or { panic(err) } }
	println('runs=${draws.len} raster_ns=${elapsed} rgba_sha256=${hash.sum([]).hex()}')
}
