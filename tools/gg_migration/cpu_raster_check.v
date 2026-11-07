// Compares the Skia-free cpuraster module with the original LibWeb Skia calls
// in skia_cpu_oracle.cpp, byte for byte.
module main

import cpuraster
import gfxfont
import math
import os
import rand

fn C.dlopen(path &char, mode int) voidptr
fn C.dlsym(handle voidptr, symbol &char) voidptr

type OracleReadPixels = fn (source &u8, destination &u8, values &i32) i32

type OracleFontTypefaceIsValid = fn (data &u8, size uint, index i32) i32

type OracleBitmapExport = fn (pixels &u8, output &u8, values &i32) i32

type OracleFillPath = fn (pixels &u8, values &i32, floats &f32)

type OracleCanvasFill = fn (pixels &u8, values &i32, floats &f32) i32

type OracleCanvasStroke = fn (pixels &u8, values &i32, floats &f32) i32

struct Oracle {
	read_pixels            OracleReadPixels          = unsafe { nil }
	font_typeface_is_valid OracleFontTypefaceIsValid = unsafe { nil }
	bitmap_export          OracleBitmapExport        = unsafe { nil }
	fill_path              OracleFillPath            = unsafe { nil }
	canvas_fill            OracleCanvasFill          = unsafe { nil }
	canvas_stroke          OracleCanvasStroke        = unsafe { nil }
}

fn load_oracle(path string) Oracle {
	library := C.dlopen(path.str, 2)
	if library == unsafe { nil } {
		panic('could not load the Skia CPU oracle ${path}')
	}
	return Oracle{
		read_pixels:            unsafe { OracleReadPixels(oracle_symbol(library, 'oracle_read_pixels')) }
		font_typeface_is_valid: unsafe {
			OracleFontTypefaceIsValid(oracle_symbol(library,
				'oracle_font_typeface_is_valid'))
		}
		bitmap_export:          unsafe {
			OracleBitmapExport(oracle_symbol(library, 'oracle_bitmap_export'))
		}
		fill_path:              unsafe { OracleFillPath(oracle_symbol(library, 'oracle_fill_path')) }
		canvas_fill:            unsafe { OracleCanvasFill(oracle_symbol(library, 'oracle_canvas_fill')) }
		canvas_stroke:          unsafe {
			OracleCanvasStroke(oracle_symbol(library, 'oracle_canvas_stroke'))
		}
	}
}

fn oracle_symbol(library voidptr, name string) voidptr {
	symbol := C.dlsym(library, name.str)
	if symbol == unsafe { nil } {
		panic('Skia CPU oracle entry point ${name} missing')
	}
	return symbol
}

fn random_bytes(length int) []u8 {
	mut bytes := []u8{len: length}
	for i in 0 .. length {
		bytes[i] = u8(rand.u32() & 255)
	}
	return bytes
}

struct ReadCase {
	width              int
	height             int
	pitch              int
	alpha_type         int
	destination_width  int
	destination_height int
	destination_pitch  int
	x                  int
	y                  int
}

// Returns an error naming the first difference between Skia and cpuraster.
fn compare_read(oracle Oracle, source []u8, read ReadCase, label string) ! {
	columns := if read.destination_width > 0 { read.destination_width } else { 1 }
	rows := if read.destination_height > 0 { read.destination_height } else { 1 }
	row_bytes := if read.destination_pitch > columns * 4 {
		read.destination_pitch
	} else {
		columns * 4
	}
	initial := random_bytes(row_bytes * rows + 16)
	mut expected := initial.clone()
	mut actual := initial.clone()
	values := [i32(read.width), read.height, read.pitch, read.alpha_type, read.destination_width,
		read.destination_height, read.destination_pitch, read.x, read.y]
	expected_result := oracle.read_pixels(source.data, expected.data, values.data) != 0
	actual_result := cpuraster.read_pixels(source, read.width, read.height, read.pitch,
		read.alpha_type, mut actual, read.destination_width, read.destination_height,
		read.destination_pitch, read.x, read.y)
	if expected_result != actual_result {
		return error('${label}: Skia returned ${expected_result}, cpuraster ${actual_result} for ${read}')
	}
	for i in 0 .. expected.len {
		if expected[i] != actual[i] {
			return error('${label}: byte ${i} is ${actual[i]}, Skia wrote ${expected[i]} for ${read}')
		}
	}
}

// Every premultiplied channel/alpha pair, through NEON's eight-pixel blocks
// (256-pixel rows) and the scalar tail (seven-pixel reads).
fn check_read_pixels_exhaustive(oracle Oracle) !int {
	source := premultiplied_table()
	mut comparisons := 0
	for alpha_type in [1, 2] {
		compare_read(oracle, source, ReadCase{256, 256, 1024, alpha_type, 256, 256, 1024, 0, 0},
			'block')!
		comparisons++
		for x := 0; x < 256; x += 7 {
			compare_read(oracle, source, ReadCase{256, 256, 1024, alpha_type, 7, 256, 28, x, 0},
				'tail')!
			comparisons++
		}
	}
	return comparisons
}

fn random_dimension() int {
	return match rand.intn(8) or { 0 } {
		0 { 0 }
		1 { -rand.intn(3) or { 0 } - 1 }
		else { rand.intn(24) or { 0 } + 1 }
	}
}

fn random_pitch(width int) int {
	minimum := if width > 0 { width * 4 } else { 0 }
	return match rand.intn(8) or { 0 } {
		0 { 0 }
		1 { minimum - 4 }
		2 { minimum + 1 + rand.intn(3) or { 0 } }
		3, 4 { minimum + 4 * (rand.intn(4) or { 0 }) }
		else { minimum }
	}
}

fn random_offset() int {
	return match rand.intn(16) or { 0 } {
		0 { min_i32 }
		1 { max_i32 - 2 }
		2 { min_i32 + 1 }
		else { rand.intn(40) or { 0 } - 20 }
	}
}

// Random geometry, including invalid dimensions, pitches and offsets. Skia
// writes outside the destination for negative destination pitches, so those
// are not compared; cpuraster rejects them.
fn check_read_pixels_random(oracle Oracle, count int) !int {
	for i in 0 .. count {
		width := random_dimension()
		height := random_dimension()
		pitch := random_pitch(width)
		source_rows := if height > 0 { height } else { 1 }
		source_columns := if width > 0 { width } else { 1 }
		source_pitch := if pitch > source_columns * 4 { pitch } else { source_columns * 4 }
		source := random_bytes(source_pitch * source_rows + 16)
		destination_width := random_dimension()
		destination_height := random_dimension()
		mut destination_pitch := random_pitch(destination_width)
		if destination_width <= 0 || destination_height <= 0 || destination_pitch < 0 {
			// Skia rejects these before touching the destination.
			destination_pitch = 4
		}
		read := ReadCase{width, height, pitch, rand.intn(4) or { 0 }, destination_width, destination_height, destination_pitch, random_offset(), random_offset()}
		compare_read(oracle, source, read, 'random ${i}')!
	}
	return count
}

fn compare_font(oracle Oracle, data []u8, index int, label string) ! {
	expected := oracle.font_typeface_is_valid(data.data, uint(data.len), i32(index)) != 0
	actual := gfxfont.typeface_data_is_valid(data, index)
	if expected != actual {
		return error('${label} index ${index}: Skia accepts ${expected}, gfxfont ${actual}')
	}
}

fn font_files() []string {
	mut files := []string{}
	for directory in ['/System/Library/Fonts', '/System/Library/Fonts/Supplemental', '/Library/Fonts'] {
		for name in os.ls(directory) or { []string{} } {
			if name.to_lower().all_after_last('.') in ['ttf', 'otf', 'ttc', 'dfont'] {
				files << os.join_path(directory, name)
			}
		}
	}
	files.sort()
	return files
}

// Every installed font at collection indices 0 and 1, truncated and corrupted
// copies, decoded WOFF/WOFF2 test fonts and non-font data.
fn check_font_validation(oracle Oracle, repo string) !(int, int) {
	mut comparisons := 0
	mut accepted := 0
	mut samples := map[string][]u8{}
	for path in font_files() {
		samples[path] = os.read_bytes(path) or { continue }
	}
	for name in os.ls(os.join_path(repo, 'gfxfont/testdata')) or { []string{} } {
		bytes := os.read_bytes(os.join_path(repo, 'gfxfont/testdata', name)) or { continue }
		decoded := if name.ends_with('.woff2') {
			gfxfont.convert_woff2_to_sfnt(bytes) or { bytes }
		} else {
			gfxfont.convert_woff_to_sfnt(bytes) or { bytes }
		}
		samples[name] = decoded
	}
	samples['empty'] = []u8{}
	samples['truetype magic'] = [u8(0), 1, 0, 0]
	samples['OTTO magic'] = 'OTTO'.bytes()
	samples['random'] = random_bytes(4096)
	for label, data in samples {
		for index in [0, 1] {
			compare_font(oracle, data, index, label)!
			comparisons++
			if gfxfont.typeface_data_is_valid(data, index) {
				accepted++
			}
		}
		if data.len < 16 {
			continue
		}
		for length in [12, data.len / 2, data.len - 1] {
			compare_font(oracle, data[..length], 0, '${label} truncated to ${length}')!
			comparisons++
		}
		for _ in 0 .. 3 {
			mut corrupted := data.clone()
			for _ in 0 .. 8 {
				corrupted[rand.intn(math_min(data.len, 512)) or { 0 }] = u8(rand.u32() & 255)
			}
			compare_font(oracle, corrupted, 0, '${label} with corrupted tables')!
			comparisons++
		}
	}
	return comparisons, accepted
}

fn math_min(a int, b int) int {
	return if a < b { a } else { b }
}

struct ExportCase {
	source      cpuraster.BitmapSource
	format      cpuraster.BitmapExportFormat
	flip        bool
	premultiply bool
	width       ?int
	height      ?int
}

// The removed skia.export_bitmap_to_byte_buffer() wrapper around the oracle.
fn oracle_export(oracle Oracle, export ExportCase) !cpuraster.BitmapExport {
	bitmap := export.source
	mut width := export.width or { bitmap.width }
	mut height := export.height or { bitmap.height }
	if width < 0 || height < 0 {
		return cpuraster.BitmapExport{
			width:  width
			height: height
		}
	}
	if export.format == .rgb888 && (width != bitmap.width || height != bitmap.height) {
		width = bitmap.width
		height = bitmap.height
	}
	bytes_per_pixel := match export.format {
		.gray8, .alpha8 { 1 }
		.rgb565, .rgba5551, .rgba4444 { 2 }
		.rgb888 { 3 }
		.rgba8888 { 4 }
	}
	length := u64(width) * u64(height) * u64(bytes_per_pixel)
	mut output := []u8{len: int(length)}
	if length == 0 {
		return cpuraster.BitmapExport{
			width:  width
			height: height
			pixels: output
		}
	}
	pitch := if bitmap.pitch == 0 { bitmap.width * 4 } else { bitmap.pitch }
	if bitmap.width <= 0 || bitmap.height <= 0 || pitch < bitmap.width * 4
		|| u64(pitch) * u64(bitmap.height) > u64(bitmap.pixels.len) {
		return error('Invalid bitmap storage')
	}
	flags := int(export.premultiply) + 2 * int(export.flip)
	values := [i32(bitmap.width), bitmap.height, pitch, bitmap.layout, bitmap.alpha_type,
		bitmap.color_space, int(export.format), flags, width, height]
	if oracle.bitmap_export(bitmap.pixels.data, output.data, values.data) != 1 {
		return error('Failed to export the bitmap')
	}
	return cpuraster.BitmapExport{
		width:  width
		height: height
		pixels: output
	}
}

fn compare_export(oracle Oracle, export ExportCase, label string) ! {
	expected := oracle_export(oracle, export) or {
		if _ := cpuraster.export_bitmap_to_byte_buffer(export.source, export.format, export.flip,
			export.premultiply, export.width, export.height)
		{
			return error('${label}: Skia failed (${err.msg()}) but cpuraster exported')
		}
		return
	}
	actual := cpuraster.export_bitmap_to_byte_buffer(export.source, export.format, export.flip,
		export.premultiply, export.width, export.height) or {
		return error('${label}: cpuraster failed (${err.msg()}) but Skia exported')
	}
	if expected.width != actual.width || expected.height != actual.height
		|| expected.pixels.len != actual.pixels.len {
		return error('${label}: size ${actual.width}x${actual.height}/${actual.pixels.len}, Skia ${expected.width}x${expected.height}/${expected.pixels.len}')
	}
	for i in 0 .. expected.pixels.len {
		if expected.pixels[i] != actual.pixels[i] {
			return error('${label}: byte ${i} is ${actual.pixels[i]}, Skia wrote ${expected.pixels[i]}')
		}
	}
}

const export_formats = [cpuraster.BitmapExportFormat.gray8, .alpha8, .rgb565, .rgba5551, .rgba4444,
	.rgb888, .rgba8888]

// Every channel/alpha pair in every source layout, alpha type and color space,
// for each export format, premultiplication and flip.
fn check_export_exhaustive(oracle Oracle) !int {
	source := premultiplied_table()
	mut comparisons := 0
	for layout in 0 .. 4 {
		for alpha_type in [1, 2] {
			for color_space in [0, 1] {
				bitmap := cpuraster.BitmapSource{
					width:       256
					height:      256
					pitch:       1024
					layout:      layout
					alpha_type:  alpha_type
					color_space: color_space
					pixels:      source
				}
				for format in export_formats {
					for premultiply in [false, true] {
						for flip in [false, true] {
							compare_export(oracle, ExportCase{bitmap, format, flip, premultiply, none, none},
								'table layout ${layout} alpha ${alpha_type} space ${color_space} ${format} premultiply ${premultiply} flip ${flip}')!
							comparisons++
						}
					}
				}
			}
		}
	}
	return comparisons
}

fn premultiplied_table() []u8 {
	mut source := []u8{len: 256 * 256 * 4}
	for alpha in 0 .. 256 {
		for value in 0 .. 256 {
			offset := (alpha * 256 + value) * 4
			source[offset] = u8(value)
			source[offset + 1] = u8(255 - value)
			source[offset + 2] = u8(value ^ 0x5a)
			source[offset + 3] = u8(alpha)
		}
	}
	return source
}

fn random_target() ?int {
	return match rand.intn(10) or { 0 } {
		0 { none }
		1 { 0 }
		2 { -1 }
		else { rand.intn(70) or { 0 } + 1 }
	}
}

// Random pixels, sizes, pitches, targets and configurations, plus targets
// wider and taller than Skia's 8191-pixel draw tiles.
fn check_export_random(oracle Oracle, count int) !int {
	for i in 0 .. count {
		width := rand.intn(24) or { 0 } + 1
		height := rand.intn(24) or { 0 } + 1
		pitch := match rand.intn(6) or { 0 } {
			0 { 0 }
			1 { width * 4 + 4 * (rand.intn(3) or { 0 } + 1) }
			2 { width * 4 + rand.intn(3) or { 0 } + 1 }
			else { width * 4 }
		}
		storage := if pitch > width * 4 { pitch } else { width * 4 }
		bitmap := cpuraster.BitmapSource{
			width:       width
			height:      height
			pitch:       pitch
			layout:      rand.intn(4) or { 0 }
			alpha_type:  rand.intn(2) or { 0 } + 1
			color_space: rand.intn(2) or { 0 }
			pixels:      random_bytes(storage * height)
		}
		export := ExportCase{bitmap, export_formats[rand.intn(export_formats.len) or { 0 }], rand.intn(2) or {
			0
		} == 1, rand.intn(2) or { 0 } == 1, random_target(), random_target()}
		compare_export(oracle, export, 'random ${i} ${export.format} ${width}x${height} pitch ${pitch} layout ${bitmap.layout} alpha ${bitmap.alpha_type} space ${bitmap.color_space} flip ${export.flip} premultiply ${export.premultiply} target ${export.width}x${export.height}')!
	}
	mut tiled := 0
	for format in [cpuraster.BitmapExportFormat.rgba8888, .gray8] {
		for color_space in [0, 1] {
			for flip in [false, true] {
				bitmap := cpuraster.BitmapSource{
					width:       7
					height:      5
					layout:      0
					color_space: color_space
					pixels:      random_bytes(7 * 5 * 4)
				}
				compare_export(oracle, ExportCase{bitmap, format, flip, false, 8300, 3},
					'wide tiles ${format} space ${color_space} flip ${flip}')!
				compare_export(oracle, ExportCase{bitmap, format, flip, true, 2, 8400},
					'tall tiles ${format} space ${color_space} flip ${flip}')!
				tiled += 2
			}
		}
	}
	return count + tiled
}

// One path op: kind (0 move, 1 line, 2 quad, 3 conic, 4 cubic, 5 close) and
// up to six coordinates, the conic weight last.
struct PathOp {
	kind int
	v    [6]f32
}

fn random_coordinate(extent int) f32 {
	return match rand.intn(10) or { 0 } {
		0 { f32(rand.f64() * f64(extent) * 3 - f64(extent)) }
		1 { f32(rand.intn(extent + 1) or { 0 }) }
		2 { f32(rand.intn(extent + 1) or { 0 }) + f32(0.5) }
		else { f32(rand.f64() * f64(extent) * 1.2 - f64(extent) * 0.1) }
	}
}

fn random_path_ops(width int, height int) []PathOp {
	mut ops := []PathOp{}
	contours := rand.intn(3) or { 0 } + 1
	for _ in 0 .. contours {
		ops << PathOp{0, [random_coordinate(width), random_coordinate(height), 0, 0, 0, 0]!}
		segments := rand.intn(7) or { 0 } + 1
		for _ in 0 .. segments {
			kind := match rand.intn(10) or { 0 } {
				0, 1, 2, 3 { 1 }
				4, 5 { 2 }
				6 { 3 }
				7, 8 { 4 }
				else {
					if rand.intn(2) or { 0 } == 0 { 5 } else { 0 }
				}
			}
			mut v := [6]f32{}
			for i in 0 .. 6 {
				v[i] = if i % 2 == 0 { random_coordinate(width) } else { random_coordinate(height) }
			}
			if kind == 3 {
				v[4] = f32(rand.f64() * 3)
			}
			ops << PathOp{kind, v}
		}
		if rand.intn(2) or { 0 } == 0 {
			ops << PathOp{5, [6]f32{}}
		}
	}
	return ops
}

fn build_path(ops []PathOp, even_odd bool) cpuraster.Path {
	mut b := cpuraster.PathBuilder{}
	for op in ops {
		match op.kind {
			0 { b.move_to(op.v[0], op.v[1]) }
			1 { b.line_to(op.v[0], op.v[1]) }
			2 { b.quad_to(op.v[0], op.v[1], op.v[2], op.v[3]) }
			3 { b.conic_to(op.v[0], op.v[1], op.v[2], op.v[3], op.v[4]) }
			4 { b.cubic_to(op.v[0], op.v[1], op.v[2], op.v[3], op.v[4], op.v[5]) }
			else { b.close() }
		}
	}
	b.fill_type = if even_odd { .even_odd } else { .winding }
	return b.detach()
}

fn random_matrix() cpuraster.Matrix {
	return match rand.intn(10) or { 0 } {
		0, 1, 2, 3 {
			cpuraster.Matrix{}
		}
		4, 5, 6 {
			cpuraster.Matrix{
				a: f32(rand.f64() * 2 + 0.25)
				d: f32(rand.f64() * 2 + 0.25)
				e: f32(rand.f64() * 20 - 10)
				f: f32(rand.f64() * 20 - 10)
			}
		}
		else {
			angle := rand.f64() * 6.283185307
			scale := rand.f64() * 1.5 + 0.5
			cpuraster.Matrix{
				a: f32(math.cos(angle) * scale)
				b: f32(math.sin(angle) * scale)
				c: f32(-math.sin(angle) * scale + rand.f64() * 0.3)
				d: f32(math.cos(angle) * scale)
				e: f32(rand.f64() * 30)
				f: f32(rand.f64() * 30)
			}
		}
	}
}

fn random_color() u32 {
	return match rand.intn(6) or { 0 } {
		0 { u32(0xff000000) }
		1, 2 { u32(0xff000000) | (rand.u32() & 0xffffff) }
		3 { u32(0) | (rand.u32() & 0xffffff) }
		else { rand.u32() }
	}
}

fn random_premultiplied(count int) []u8 {
	mut pixels := []u8{len: count * 4}
	for i in 0 .. count {
		a := u8(rand.u32() & 255)
		pixels[i * 4 + 3] = a
		for c in 0 .. 3 {
			pixels[i * 4 + c] = if a == 0 { 0 } else { u8(rand.u32() % (u32(a) + 1)) }
		}
	}
	return pixels
}

// Anti-aliased solid path fills, through Skia's mask and run-length additive
// blitters, its convex and general edge walkers and every solid blitter.
fn check_fill_paths(oracle Oracle, count int) !(int, int) {
	mut declined := 0
	for i in 0 .. count {
		small := rand.intn(2) or { 0 } == 0
		width := if small { rand.intn(30) or { 0 } + 2 } else { rand.intn(150) or { 0 } + 20 }
		height := if small { rand.intn(30) or { 0 } + 2 } else { rand.intn(150) or { 0 } + 20 }
		ops := random_path_ops(width, height)
		even_odd := rand.intn(2) or { 0 } == 0
		matrix := random_matrix()
		color := random_color()
		initial := random_premultiplied(width * height)
		mut expected := initial.clone()
		mut floats := [matrix.a, matrix.b, matrix.c, matrix.d, matrix.e, matrix.f]
		for op in ops {
			floats << f32(op.kind)
			for v in op.v {
				floats << v
			}
		}
		values := [i32(width), height, int(even_odd), ops.len, i32(color)]
		oracle.fill_path(expected.data, values.data, floats.data)
		mut actual := initial.clone()
		path := build_path(ops, even_odd)
		mut blitter := cpuraster.new_solid_blitter(mut actual, width * 4, color)
		if !cpuraster.anti_fill_path(path.transform(matrix), cpuraster.IRect{0, 0, width, height}, mut
			blitter)
		{
			declined++
			continue
		}
		for j in 0 .. expected.len {
			if expected[j] != actual[j] {
				return error('fill ${i}: pixel (${j / 4 % width}, ${j / 4 / width}) channel ${j % 4} is ${actual[j]}, Skia wrote ${expected[j]} (size ${width}x${height}, even-odd ${even_odd}, color ${color:08x}, matrix ${matrix}, ops ${ops})')
			}
		}
	}
	return count, declined
}

// Canvas2D path segments in skia.Path's encoding, with SVG arcs.
fn random_canvas_segments(width int, height int) []f32 {
	mut segments := []f32{}
	for op in random_path_ops(width, height) {
		if op.kind != 0 && op.kind != 5 && rand.intn(3) or { 0 } == 0 {
			// An SVG arc: radii (sometimes zero or too small), rotation in
			// radians, and large-arc and sweep flags.
			rx := if rand.intn(8) or { 0 } == 0 { f32(0) } else { f32(rand.f64() * f64(width)) }
			ry := f32(rand.f64() * f64(height))
			rotation := f32(rand.f64() * 12.566 - 6.283)
			segments << [f32(4), op.v[0], op.v[1], 0, 0, 0, 0, rx, ry, rotation,
				f32(rand.intn(2) or { 0 }), f32(rand.intn(2) or { 0 })]
			continue
		}
		match op.kind {
			0 { segments << [f32(0), op.v[0], op.v[1], 0, 0, 0, 0, 0, 0, 0, 0, 0] }
			1 { segments << [f32(1), op.v[0], op.v[1], 0, 0, 0, 0, 0, 0, 0, 0, 0] }
			2, 3 {
				segments << [f32(2), op.v[2], op.v[3], op.v[0], op.v[1], 0, 0, 0, 0, 0, 0, 0]
			}
			4 {
				segments << [f32(3), op.v[4], op.v[5], op.v[0], op.v[1], op.v[2], op.v[3], 0, 0,
					0, 0, 0]
			}
			else { segments << [f32(5), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] }
		}
	}
	return segments
}

// Random bytes, premultiplied when alpha_type is 2, with padded rows.
fn random_canvas_bitmap(width int, height int, pitch int, alpha_type int) []u8 {
	mut bitmap := random_bytes(pitch * height)
	if alpha_type == 2 {
		premultiplied := random_premultiplied(width * height)
		for y in 0 .. height {
			for x in 0 .. width * 4 {
				bitmap[y * pitch + x] = premultiplied[y * width * 4 + x]
			}
		}
	}
	return bitmap
}

fn random_global_alpha() f32 {
	return match rand.intn(4) or { 0 } {
		0 { f32(1) }
		1 { f32(0) }
		else { f32(rand.f64()) }
	}
}

// Lines along an axis or of zero length, so hairlines take their horizontal
// and vertical walkers and draw degenerate caps.
fn align_canvas_lines(mut segments []f32) {
	mut last := [f32(0), 0]!
	for i := 0; i + 11 < segments.len; i += 12 {
		kind := int(segments[i])
		if kind == 1 {
			match rand.intn(6) or { 0 } {
				0 { segments[i + 1] = last[0] }
				1 { segments[i + 2] = last[1] }
				2 {
					segments[i + 1] = last[0]
					segments[i + 2] = last[1]
				}
				else {}
			}
		}
		if kind != 5 {
			last = [segments[i + 1], segments[i + 2]]!
		}
	}
}

// Canvas2D strokes through the production vox_skia_canvas_path(): SkDraw
// turns them into hairlines when the line width is at most a device pixel and
// strokes the rest with SkStroke. Returns the comparisons and how many were
// hairlines.
fn check_canvas_strokes(oracle Oracle, count int) !(int, int) {
	mut hairlines := 0
	for i in 0 .. count {
		width := rand.intn(120) or { 0 } + 1
		height := rand.intn(120) or { 0 } + 1
		pitch := width * 4 + 4 * (rand.intn(3) or { 0 })
		alpha_type := if rand.intn(2) or { 0 } == 0 { 1 } else { 2 }
		mut segments := random_canvas_segments(width, height)
		align_canvas_lines(mut segments)
		if rand.intn(8) or { 0 } == 0 {
			// Lines thousands of pixels long, some past the 26.6 fixed-point
			// range hairlines chop to.
			factor := f32(if rand.intn(2) or { 0 } == 0 { 40 } else { 900 })
			for k := 0; k + 11 < segments.len; k += 12 {
				for c in 1 .. 9 {
					segments[k + c] *= factor
				}
			}
		}
		m := random_matrix()
		transform := [m.a, m.b, m.c, m.d, m.e, m.f]!
		color := random_color()
		initial := random_canvas_bitmap(width, height, pitch, alpha_type)
		global_alpha := random_global_alpha()
		line_width := match rand.intn(5) or { 0 } {
			0, 1 { f32(1) }
			2 { f32(rand.f64()) }
			3 { f32(rand.f64() * 0.2) }
			else { f32(rand.f64() * 2) }
		}
		miter := if rand.intn(2) or { 0 } == 0 { f32(10) } else { f32(rand.f64() * 12) }
		cap := rand.intn(3) or { 0 }
		join := rand.intn(3) or { 0 }
		compare_canvas_stroke(oracle, initial, StrokeCase{width, height, pitch, alpha_type, segments, transform, color, global_alpha, line_width, miter, cap, join, []f32{}, 0},
			'stroke ${i}')!
		if is_hairline(transform, line_width) {
			hairlines++
		}
	}
	return count, hairlines
}

struct StrokeCase {
	width        int
	height       int
	pitch        int
	alpha_type   int
	segments     []f32
	transform    [6]f32
	color        u32
	global_alpha f32
	line_width   f32
	miter        f32
	cap          int
	join         int
	dashes       []f32
	dash_offset  f32
}

// SkDraw's DrawTreatAsHairline() test for a positive width.
fn is_hairline(transform [6]f32, line_width f32) bool {
	if !(line_width > 0) {
		return true
	}
	fast := fn (x f32, y f32) f32 {
		mut ax := f32(math.abs(x))
		mut ay := f32(math.abs(y))
		if ax < ay {
			ax, ay = ay, ax
		}
		return ax + ay * f32(0.5)
	}
	return fast(line_width * transform[0], line_width * transform[1]) <= 1
		&& fast(line_width * transform[2], line_width * transform[3]) <= 1
}

// Strokes one case through vox_skia_canvas_path() and stroke_canvas_path()
// and compares every byte.
fn compare_canvas_stroke(oracle Oracle, initial []u8, c StrokeCase, label string) ! {
	mut expected := initial.clone()
	mut floats := c.transform[..].clone()
	floats << [c.global_alpha, c.line_width, c.miter]
	floats << c.segments
	floats << c.dash_offset
	floats << c.dashes
	values := [i32(c.width), c.height, c.pitch, c.alpha_type, c.segments.len / 12, i32(c.color),
		c.cap, c.join, c.dashes.len]
	if oracle.canvas_stroke(expected.data, values.data, floats.data) == 0 {
		return error('${label}: the Skia canvas path failed')
	}
	mut actual := initial.clone()
	path := cpuraster.canvas_path(c.segments, false)
	if !cpuraster.stroke_canvas_path(mut actual, c.width, c.height, c.pitch, c.alpha_type,
		path, c.transform, c.color, c.global_alpha, c.line_width, unsafe { cpuraster.StrokeCap(c.cap) }, unsafe { cpuraster.StrokeJoin(c.join) },
		c.miter, c.dashes, c.dash_offset) {
		return error('${label}: cpuraster declined')
	}
	for j in 0 .. expected.len {
		if expected[j] != actual[j] {
			return error('${label}: pixel (${j % c.pitch / 4}, ${j / c.pitch}) channel ${j % 4} is ${actual[j]}, Skia wrote ${expected[j]} (${c})')
		}
	}
}

fn segment(kind int, values []f32) []f32 {
	mut s := [f32(kind)]
	s << values
	for s.len < 12 {
		s << 0
	}
	return s
}

// Contours SkStroke treats specially: closed rects (strokeRect) in both
// directions, as trivial four-point rects and with redundant points;
// collinear and degenerate curves; cusps; zero-length contours, which only
// round and square caps draw; and sharp turns that exceed miter limits.
fn random_stroke_shape(width int, height int) []f32 {
	mut x0 := f32(rand.f64() * f64(width))
	mut y0 := f32(rand.f64() * f64(height))
	x1 := f32(rand.f64() * f64(width))
	y1 := f32(rand.f64() * f64(height))
	mut s := []f32{}
	match rand.intn(12) or { 0 } {
		0 {
			// A rect: moveTo, three lines, close.
			cw := rand.intn(2) or { 0 } == 0
			s << segment(0, [x0, y0])
			if cw {
				s << segment(1, [x1, y0])
				s << segment(1, [x1, y1])
				s << segment(1, [x0, y1])
			} else {
				s << segment(1, [x0, y1])
				s << segment(1, [x1, y1])
				s << segment(1, [x1, y0])
			}
			if rand.intn(3) or { 0 } == 0 {
				// Back to the start before closing.
				s << segment(1, [x0, y0])
			}
			if rand.intn(6) or { 0 } != 0 {
				s << segment(5, [])
			}
		}
		1 {
			// A rect with a midpoint on one side.
			s << segment(0, [x0, y0])
			s << segment(1, [(x0 + x1) / 2, y0])
			s << segment(1, [x1, y0])
			s << segment(1, [x1, y1])
			s << segment(1, [x0, y1])
			s << segment(5, [])
		}
		2 {
			// Collinear quads and cubics, with control points past the ends.
			t := f32(rand.f64() * 3 - 1)
			u := f32(rand.f64() * 3 - 1)
			s << segment(0, [x0, y0])
			s << segment(2, [x1, y1, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t])
			s << segment(3, [x0, y0, x1 + (x0 - x1) * t, y1 + (y0 - y1) * t, x0 + (x1 - x0) * u,
				y0 + (y1 - y0) * u])
		}
		3 {
			// A cubic whose control polygon crosses itself: a cusp or loop.
			s << segment(0, [x0, y0])
			s << segment(3, [x1, y0, x1, y1, x0, y1])
			s << segment(3, [x0, y1, x0, y0, x1, y0])
		}
		4 {
			// Zero-length contours: a lone move and close, repeated points, and
			// a degenerate quad.
			s << segment(0, [x0, y0])
			s << segment(5, [])
			s << segment(0, [x1, y1])
			s << segment(1, [x1, y1])
			s << segment(1, [x1, y1])
			if rand.intn(2) or { 0 } == 0 {
				s << segment(5, [])
			}
			s << segment(0, [x0, y1])
			s << segment(2, [x0, y1, x0, y1])
		}
		5 {
			// A zigzag with sharp turns.
			s << segment(0, [x0, y0])
			for k in 0 .. rand.intn(6) or { 0 } + 2 {
				dy := f32(rand.f64() * 8 + 1)
				x := x0 + f32(k + 1) * (x1 - x0) / 6
				y := if k % 2 == 0 { y0 + dy } else { y0 - dy }
				s << segment(1, [x, y])
			}
			if rand.intn(2) or { 0 } == 0 {
				s << segment(5, [])
			}
		}
		6 {
			// A U-turn: a line straight back along itself.
			s << segment(0, [x0, y0])
			s << segment(1, [x1, y1])
			s << segment(1, [x0, y0])
			if rand.intn(2) or { 0 } == 0 {
				s << segment(1, [x1, y1])
			}
		}
		8 {
			// Nearly straight cubics, bending a fraction of a pixel, some only a
			// fraction of a pixel long.
			e := f32(rand.f64() * 0.02 - 0.01)
			length := if rand.intn(2) or { 0 } == 0 { f32(1) } else { f32(rand.f64() * 0.01) }
			dx := (x1 - x0) * length
			dy := (y1 - y0) * length
			s << segment(0, [x0, y0])
			s << segment(3, [x1, y1, x0 + dx / 3 - dy * e, y0 + dy / 3 + dx * e, x0 + 2 * dx / 3 + dy * e,
				y0 + 2 * dy / 3 - dx * e])
		}
		9 {
			// A rect much smaller than the stroke width, sometimes so small near
			// the origin that its outset collapses to a circle.
			tiny := rand.intn(2) or { 0 } == 0
			ox := if tiny { f32(rand.f64() * 0.001) } else { x0 }
			oy := if tiny { f32(rand.f64() * 0.001) } else { y0 }
			shrink := if tiny { f32(math.pow(10, -rand.f64() * 6)) } else { f32(1) }
			w := f32(rand.f64() * 0.05) * shrink + f32(1e-12)
			h := f32(rand.f64() * 0.05) * shrink + f32(1e-12)
			x0 = ox
			y0 = oy
			s << segment(0, [x0, y0])
			s << segment(1, [x0 + w, y0])
			s << segment(1, [x0 + w, y0 + h])
			s << segment(1, [x0, y0 + h])
			s << segment(5, [])
		}
		10 {
			// Cubics a fraction of a pixel across.
			size := f32(rand.f64() * 0.5)
			s << segment(0, [x0, y0])
			mut c := []f32{}
			for _ in 0 .. 6 {
				c << f32(rand.f64() - 0.5) * size
			}
			s << segment(3, [x0 + c[4], y0 + c[5], x0 + c[0], y0 + c[1], x0 + c[2], y0 + c[3]])
		}
		7 {
			// A tight quad and cubic, whose stroke folds over the curve.
			s << segment(0, [x0, y0])
			s << segment(2, [x0 + 2, y0, x1, y1])
			s << segment(3, [x0, y0 + 1, x1 + 1, y1, x1, y1 + 1])
		}
		else {
			// A circle from SVG arcs.
			r := f32(rand.f64() * f64(width) / 3 + 1)
			s << segment(0, [x0 + r, y0])
			s << [f32(4), x0 - r, y0, 0, 0, 0, 0, r, r, 0, 0, 1]
			s << [f32(4), x0 + r, y0, 0, 0, 0, 0, r, r, 0, 0, 1]
			s << segment(5, [])
		}
	}
	return s
}

fn random_stroke_matrix() [6]f32 {
	match rand.intn(6) or { 0 } {
		0 {
			// Quarter turns keep rects axis aligned.
			turn := rand.intn(4) or { 0 }
			scale := f32(rand.f64() * 1.5 + 0.5)
			c := [f32(1), 0, -1, 0]![turn] * scale
			sn := [f32(0), 1, 0, -1]![turn] * scale
			return [c, sn, -sn, c, f32(rand.f64() * 40), f32(rand.f64() * 40)]!
		}
		1 {
			// Strong anisotropic scale, changing the resolution scale.
			return [f32(rand.f64() * 4 + 0.1), 0, 0, f32(rand.f64() * 4 + 0.1), f32(rand.f64() * 20),
				f32(rand.f64() * 20)]!
		}
		else {
			m := random_matrix()
			return [m.a, m.b, m.c, m.d, m.e, m.f]!
		}
	}
}

fn random_wide_line_width() f32 {
	return match rand.intn(6) or { 0 } {
		0 { f32(rand.f64() * 2 + 1) }
		1 { f32(rand.intn(12) or { 0 } + 2) }
		2 { f32(rand.f64() * 40) }
		3 { f32(rand.f64() * 0.5 + 1) }
		4 { f32(rand.f64() * 10) }
		else { f32(rand.f64() * 6 + 0.5) }
	}
}

// Wide Canvas2D strokes: random paths and the contours SkStroke treats
// specially, under random transforms, with every cap and join and miter limits
// around their thresholds.
fn check_wide_strokes(oracle Oracle, count int) !(int, int) {
	mut hairlines := 0
	for i in 0 .. count {
		width := rand.intn(120) or { 0 } + 1
		height := rand.intn(120) or { 0 } + 1
		pitch := width * 4 + 4 * (rand.intn(3) or { 0 })
		alpha_type := if rand.intn(2) or { 0 } == 0 { 1 } else { 2 }
		mut segments := if rand.intn(2) or { 0 } == 0 {
			random_stroke_shape(width, height)
		} else {
			random_canvas_segments(width, height)
		}
		if rand.intn(4) or { 0 } == 0 {
			align_canvas_lines(mut segments)
		}
		transform := random_stroke_matrix()
		miter := match rand.intn(5) or { 0 } {
			0 { f32(10) }
			1 { f32(rand.f64() * 2) }
			2 { f32(1.41421356) }
			3 { f32(rand.f64() * 0.5 + 1.2) }
			else { f32(rand.f64() * 12) }
		}
		c := StrokeCase{
			width:        width
			height:       height
			pitch:        pitch
			alpha_type:   alpha_type
			segments:     segments
			transform:    transform
			color:        random_color()
			global_alpha: random_global_alpha()
			line_width:   random_wide_line_width()
			miter:        miter
			cap:          rand.intn(3) or { 0 }
			join:         rand.intn(3) or { 0 }
		}
		mut stroke := c
		if rand.intn(25) or { 0 } == 0 {
			// Widths and coordinates far beyond the device, where the
			// stroker's recursion limits and non-finite projections apply.
			x := f32(rand.f64() * f64(width))
			y := f32(rand.f64() * f64(height))
			scale := f32(math.pow(10, rand.f64() * 38.5))
			mut extreme := []f32{}
			extreme << segment(0, [x, y + 1])
			extreme << segment(2, [x, y + 3, x + 1, y + 6])
			if rand.intn(2) or { 0 } == 0 {
				extreme << segment(3, [x + scale, y - scale, x - scale, y, x, y + scale])
			}
			stroke = StrokeCase{
				...c
				segments:   extreme
				line_width: f32(math.pow(10, rand.f64() * 9))
				transform:  if rand.intn(2) or { 0 } == 0 {
					[f32(1), 0, 0, 1, 0, 0]!
				} else {
					c.transform
				}
			}
		}
		compare_canvas_stroke(oracle, random_canvas_bitmap(width, height, pitch, alpha_type),
			stroke, 'wide stroke ${i}')!
		if is_hairline(transform, c.line_width) {
			hairlines++
		}
	}
	return count, hairlines
}

// Canvas2D solid fills through the production vox_skia_canvas_path(),
// premultiplied or unpremultiplied bitmaps with padded rows.
fn check_canvas_fills(oracle Oracle, count int) !int {
	for i in 0 .. count {
		width := rand.intn(120) or { 0 } + 1
		height := rand.intn(120) or { 0 } + 1
		pitch := width * 4 + 4 * (rand.intn(3) or { 0 })
		alpha_type := if rand.intn(2) or { 0 } == 0 { 1 } else { 2 }
		segments := random_canvas_segments(width, height)
		even_odd := rand.intn(2) or { 0 } == 0
		m := random_matrix()
		transform := [m.a, m.b, m.c, m.d, m.e, m.f]!
		color := random_color()
		initial := random_canvas_bitmap(width, height, pitch, alpha_type)
		mut expected := initial.clone()
		global_alpha := random_global_alpha()
		mut floats := transform[..].clone()
		floats << global_alpha
		floats << segments
		values := [i32(width), height, pitch, alpha_type, int(even_odd), segments.len / 12, i32(color)]
		if oracle.canvas_fill(expected.data, values.data, floats.data) == 0 {
			return error('canvas ${i}: the Skia canvas path failed')
		}
		mut actual := initial.clone()
		path := cpuraster.canvas_path(segments, even_odd)
		if !cpuraster.fill_canvas_path(mut actual, width, height, pitch, alpha_type, path,
			transform, cpuraster.canvas_fill_color(color, global_alpha)) {
			return error('canvas ${i}: cpuraster declined')
		}
		for j in 0 .. expected.len {
			if expected[j] != actual[j] {
				return error('canvas ${i}: byte ${j} is ${actual[j]}, Skia wrote ${expected[j]} (${width}x${height} pitch ${pitch} alpha ${alpha_type})')
			}
		}
	}
	return count
}

fn main() {
	if os.args.len < 2 {
		eprintln('usage: cpu_raster_check SKIA_CPU_ORACLE [COUNT] [SEED]')
		exit(2)
	}
	oracle := load_oracle(os.args[1])
	count := if os.args.len > 2 { os.args[2].int() } else { 20000 }
	seed := if os.args.len > 3 { u32(os.args[3].int()) } else { u32(20261106) }
	rand.seed([seed, 7])
	if os.getenv('CPU_RASTER_CHECKS') == 'strokes' {
		check_stroke_cases(oracle, count)
		return
	}
	exhaustive := check_read_pixels_exhaustive(oracle) or {
		eprintln(err.msg())
		exit(1)
	}
	random := check_read_pixels_random(oracle, count) or {
		eprintln(err.msg())
		exit(1)
	}
	println('read_pixels: ${exhaustive} exhaustive and ${random} random comparisons exact')
	repo := os.real_path(os.join_path(os.dir(@FILE), '..', '..'))
	fonts, accepted := check_font_validation(oracle, repo) or {
		eprintln(err.msg())
		exit(1)
	}
	println('typeface validation: ${fonts} comparisons equal (${accepted} accepted)')
	table := check_export_exhaustive(oracle) or {
		eprintln(err.msg())
		exit(1)
	}
	exports := check_export_random(oracle, count) or {
		eprintln(err.msg())
		exit(1)
	}
	println('bitmap export: ${table} exhaustive and ${exports} random exports exact')
	fills, declined := check_fill_paths(oracle, count) or {
		eprintln(err.msg())
		exit(1)
	}
	println('path fills: ${fills - declined} exact, ${declined} declined')
	canvas := check_canvas_fills(oracle, count / 4) or {
		eprintln(err.msg())
		exit(1)
	}
	println('canvas fills: ${canvas} exact')
	check_stroke_cases(oracle, count)
}

fn random_dashes() []f32 {
	mut dashes := []f32{}
	n := match rand.intn(10) or { 0 } {
		0 { 0 }
		1 { 1 }
		2 { 3 }
		3, 4, 5 { 2 }
		6, 7 { 4 }
		else { 6 }
	}
	for _ in 0 .. n {
		dashes << match rand.intn(12) or { 0 } {
			0 { f32(0) }
			1 { f32(rand.f64() * 0.5) }
			2 { f32(rand.intn(10) or { 0 } + 1) }
			else { f32(rand.f64() * 20 + 0.25) }
		}
	}
	match rand.intn(40) or { 0 } {
		0 {
			if dashes.len > 0 {
				dashes[0] = -1
			}
		}
		1 {
			if dashes.len > 0 {
				dashes[dashes.len - 1] = f32(math.inf(1))
			}
		}
		2 {
			for i in 0 .. dashes.len {
				dashes[i] = 0
			}
		}
		else {}
	}
	return dashes
}

fn random_dash_offset() f32 {
	return match rand.intn(8) or { 0 } {
		0 { f32(0) }
		1 { f32(rand.f64() * -60) }
		2 { f32(rand.f64() * 600) }
		3 { f32(rand.intn(20) or { 0 }) }
		4 { if rand.intn(10) or { 0 } == 0 { f32(math.nan()) } else { f32(-1e7) } }
		else { f32(rand.f64() * 40) }
	}
}

// Lines along an axis that run past the device, which SkDashPath trims to
// the cull rect, and rects, which it trims side by side.
fn random_dash_shape(width int, height int) []f32 {
	mut s := []f32{}
	x0 := f32(rand.f64() * f64(width))
	y0 := f32(rand.f64() * f64(height))
	reach := f32(rand.f64() * 4000 + 10)
	match rand.intn(4) or { 0 } {
		0 {
			s << segment(0, [x0 - reach, y0])
			s << segment(1, [x0 + reach, y0])
		}
		1 {
			s << segment(0, [x0, y0 + reach])
			s << segment(1, [x0, y0 - reach])
		}
		2 {
			// A zero-length line, which dashing bumps to draw its caps.
			s << segment(0, [x0, y0])
			s << segment(1, [x0, y0])
		}
		else {
			x1 := x0 + f32(rand.f64() * 2 - 1) * reach
			y1 := y0 + f32(rand.f64() * 2 - 1) * reach / 4
			s << segment(0, [x0, y0])
			s << segment(1, [x1, y0])
			s << segment(1, [x1, y1])
			s << segment(1, [x0, y1])
			if rand.intn(4) or { 0 } != 0 {
				s << segment(5, [])
			}
		}
	}
	return s
}

// Dashed Canvas2D strokes: SkDashPathEffect with random, degenerate and
// invalid intervals and phases over random paths, the special contours
// SkStroke handles, culled lines and rects, at hairline and wider widths.
fn check_dashed_strokes(oracle Oracle, count int) !(int, int) {
	mut hairlines := 0
	for i in 0 .. count {
		width := rand.intn(120) or { 0 } + 1
		height := rand.intn(120) or { 0 } + 1
		pitch := width * 4 + 4 * (rand.intn(3) or { 0 })
		alpha_type := if rand.intn(2) or { 0 } == 0 { 1 } else { 2 }
		segments := match rand.intn(3) or { 0 } {
			0 { random_stroke_shape(width, height) }
			1 { random_dash_shape(width, height) }
			else { random_canvas_segments(width, height) }
		}
		transform := if rand.intn(8) or { 0 } == 0 {
			// A translation, whose inverse SkMatrix::invert() builds directly.
			[f32(1), 0, 0, 1, f32(rand.f64() * 30 - 15), f32(rand.f64() * 30 - 15)]!
		} else {
			random_stroke_matrix()
		}
		line_width := match rand.intn(4) or { 0 } {
			0 { f32(1) }
			1 { f32(rand.f64()) }
			else { random_wide_line_width() }
		}
		mut dashes := random_dashes()
		mut segs := segments.clone()
		if rand.intn(60) or { 0 } == 0 {
			// Too many dashes on a diagonal line, which the cull rect cannot
			// trim: SkDashPath gives up and strokes the undashed path.
			segs = []f32{}
			segs << segment(0, [f32(0), f32(height / 2)])
			segs << segment(1, [f32(3e6), f32(height / 2) + 3000])
			dashes = [f32(1), 1]
		}
		c := StrokeCase{
			width:        width
			height:       height
			pitch:        pitch
			alpha_type:   alpha_type
			segments:     segs
			transform:    transform
			color:        random_color()
			global_alpha: random_global_alpha()
			line_width:   line_width
			miter:        if rand.intn(2) or { 0 } == 0 { f32(10) } else { f32(rand.f64() * 4) }
			cap:          rand.intn(3) or { 0 }
			join:         rand.intn(3) or { 0 }
			dashes:       dashes
			dash_offset:  random_dash_offset()
		}
		compare_canvas_stroke(oracle, random_canvas_bitmap(width, height, pitch, alpha_type),
			c, 'dashed stroke ${i}')!
		if is_hairline(transform, line_width) {
			hairlines++
		}
	}
	return count, hairlines
}

fn check_stroke_cases(oracle Oracle, count int) {
	strokes, hairlines := check_canvas_strokes(oracle, count / 4) or {
		eprintln(err.msg())
		exit(1)
	}
	println('canvas strokes: ${strokes} exact (${hairlines} hairlines)')
	wide, thin := check_wide_strokes(oracle, count / 2) or {
		eprintln(err.msg())
		exit(1)
	}
	println('wide canvas strokes: ${wide} exact (${thin} hairlines)')
	dashed, dashed_hairlines := check_dashed_strokes(oracle, count / 2) or {
		eprintln(err.msg())
		exit(1)
	}
	println('dashed canvas strokes: ${dashed} exact (${dashed_hairlines} hairlines)')
}
