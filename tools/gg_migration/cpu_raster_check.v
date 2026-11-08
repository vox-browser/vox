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

type OraclePattern = fn (pixels &u8)

type OracleCanvasBitmap = fn (pixels &u8, values &i32, floats &f32) i32

type OracleFilters = fn (count i32, values &i32, floats &f32)

struct Oracle {
	read_pixels            OracleReadPixels          = unsafe { nil }
	font_typeface_is_valid OracleFontTypefaceIsValid = unsafe { nil }
	bitmap_export          OracleBitmapExport        = unsafe { nil }
	fill_path              OracleFillPath            = unsafe { nil }
	fill_path_bw           OracleFillPath            = unsafe { nil }
	canvas_fill            OracleCanvasFill          = unsafe { nil }
	canvas_stroke          OracleCanvasStroke        = unsafe { nil }
	pattern                OraclePattern             = unsafe { nil }
	canvas_bitmap          OracleCanvasBitmap        = unsafe { nil }
	canvas_bitmap_chromium OracleCanvasBitmap        = unsafe { nil }
	filters                OracleFilters             = unsafe { nil }
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
		fill_path_bw:           unsafe {
			OracleFillPath(oracle_symbol(library, 'oracle_fill_path_bw'))
		}
		canvas_fill:            unsafe { OracleCanvasFill(oracle_symbol(library, 'oracle_canvas_fill')) }
		canvas_stroke:          unsafe {
			OracleCanvasStroke(oracle_symbol(library, 'oracle_canvas_stroke'))
		}
		pattern:                unsafe { OraclePattern(oracle_symbol(library, 'oracle_pattern')) }
		canvas_bitmap:          unsafe {
			OracleCanvasBitmap(oracle_symbol(library, 'oracle_canvas_bitmap'))
		}
		canvas_bitmap_chromium: unsafe {
			OracleCanvasBitmap(oracle_symbol(library, 'oracle_canvas_bitmap_chromium'))
		}
		filters:                unsafe { OracleFilters(oracle_symbol(library, 'oracle_filters')) }
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
	return check_path_fills(oracle, count, true)
}

// Random paths filled without anti-aliasing: SkScan::FillPath's edges,
// walkers and clipping.
fn check_bw_fill_paths(oracle Oracle, count int) !(int, int) {
	return check_path_fills(oracle, count, false)
}

fn check_path_fills(oracle Oracle, count int, anti_alias bool) !(int, int) {
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
		if anti_alias {
			oracle.fill_path(expected.data, values.data, floats.data)
		} else {
			oracle.fill_path_bw(expected.data, values.data, floats.data)
		}
		mut actual := initial.clone()
		path := build_path(ops, even_odd)
		mut blitter := cpuraster.new_solid_blitter(mut actual, width * 4, color)
		drawn := if anti_alias {
			cpuraster.anti_fill_path(path.transform(matrix), cpuraster.IRect{0, 0, width, height}, mut
				blitter)
		} else {
			cpuraster.fill_path(path.transform(matrix), cpuraster.IRect{0, 0, width, height}, mut
				blitter)
		}
		if !drawn {
			declined++
			continue
		}
		for j in 0 .. expected.len {
			if expected[j] != actual[j] {
				return error('${if anti_alias { 'fill' } else { 'bw fill' }} ${i}: pixel (${j / 4 % width}, ${j / 4 / width}) channel ${j % 4} is ${actual[j]}, Skia wrote ${expected[j]} (size ${width}x${height}, even-odd ${even_odd}, color ${color:08x}, matrix ${matrix}, ops ${ops})')
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
		compare_canvas_stroke(oracle, initial, StrokeCase{width, height, pitch, alpha_type, segments, transform, color, global_alpha, line_width, miter, cap, join, []f32{}, 0, []ClipCase{}, 0, 0, none, []},
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
	clips        []ClipCase
	composite    int
	blur         f32
	style        ?cpuraster.CanvasPaintStyle
	filters      []cpuraster.CanvasFilterStep
}

// A device-space clip path in skia.Path's segment encoding.
struct ClipCase {
	segments []f32
	even_odd bool
}

// The oracle's clip arguments: the count, a segment count and even-odd flag
// per clip, and their segments.
fn clip_arguments(clips []ClipCase) ([]i32, []f32) {
	mut values := [i32(clips.len)]
	mut floats := []f32{}
	for clip in clips {
		values << i32(clip.segments.len / 12)
		values << i32(int(clip.even_odd))
		floats << clip.segments
	}
	return values, floats
}

fn clip_paths(clips []ClipCase) []cpuraster.Path {
	return clips.map(cpuraster.canvas_path(it.segments, it.even_odd))
}

// Device-space clips as Canvas2D captures them: rects (pixel aligned or not,
// either direction, open or with redundant points), rects past the device,
// empty rects, circles, ellipses, random curved paths with either fill rule
// and thin slivers.
fn random_clips(width int, height int) []ClipCase {
	mut clips := []ClipCase{}
	for _ in 0 .. rand.intn(3) or { 0 } + 1 {
		mut s := []f32{}
		x0 := f32(rand.f64() * f64(width) * 1.2 - f64(width) * 0.1)
		y0 := f32(rand.f64() * f64(height) * 1.2 - f64(height) * 0.1)
		x1 := f32(rand.f64() * f64(width) * 1.2 - f64(width) * 0.1)
		y1 := f32(rand.f64() * f64(height) * 1.2 - f64(height) * 0.1)
		match rand.intn(9) or { 0 } {
			0, 1 {
				// An integral rect, which stays a hard-edged clip.
				l := f32(int(x0))
				t := f32(int(y0))
				r := f32(int(x1))
				b := f32(int(y1))
				s << segment(0, [l, t])
				s << segment(1, [r, t])
				s << segment(1, [r, b])
				s << segment(1, [l, b])
				s << segment(5, [])
			}
			2, 3 {
				// A fractional rect, sometimes open or with an extra point.
				s << segment(0, [x0, y0])
				if rand.intn(3) or { 0 } == 0 {
					s << segment(1, [(x0 + x1) / 2, y0])
				}
				s << segment(1, [x1, y0])
				s << segment(1, [x1, y1])
				s << segment(1, [x0, y1])
				if rand.intn(4) or { 0 } != 0 {
					s << segment(5, [])
				}
			}
			4 {
				// An empty rect.
				s << segment(0, [x0, y0])
				s << segment(1, [x0, y0])
				s << segment(1, [x0, y1])
				s << segment(1, [x0, y0])
				s << segment(5, [])
			}
			5 {
				// A circle or an ellipse from SVG arcs.
				rx := f32(rand.f64() * f64(width) / 2 + 0.5)
				ry := if rand.intn(2) or { 0 } == 0 { rx } else { f32(rand.f64() * f64(height) / 2 + 0.5) }
				rotation := f32(rand.f64() * 3)
				s << segment(0, [x0 + rx, y0])
				s << [f32(4), x0 - rx, y0, 0, 0, 0, 0, rx, ry, rotation, 0, 1]
				s << [f32(4), x0 + rx, y0, 0, 0, 0, 0, rx, ry, rotation, 0, 1]
				s << segment(5, [])
			}
			6 {
				// A thin diagonal sliver.
				w := f32(rand.f64() * 2)
				s << segment(0, [x0, y0])
				s << segment(1, [x1, y1])
				s << segment(1, [x1 + w, y1 + w])
				s << segment(1, [x0 + w, y0 + w])
				s << segment(5, [])
			}
			else {
				s << random_canvas_segments(width, height)
			}
		}
		clips << ClipCase{s, rand.intn(2) or { 0 } == 0}
	}
	return clips
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
	if compare_canvas_stroke_or_decline(oracle, initial, c, label)! {
		return error('${label}: cpuraster declined')
	}
}

// compare_canvas_stroke_or_decline() returns true when cpuraster declined,
// which must leave the pixels untouched.
fn compare_canvas_stroke_or_decline(oracle Oracle, initial []u8, c StrokeCase, label string) !bool {
	mut expected := initial.clone()
	mut floats := c.transform[..].clone()
	floats << [c.global_alpha, c.line_width, c.miter]
	floats << c.segments
	floats << c.dash_offset
	floats << c.dashes
	mut values := [i32(c.width), c.height, c.pitch, c.alpha_type, c.segments.len / 12, i32(c.color),
		c.cap, c.join, c.dashes.len]
	clip_values, clip_floats := clip_arguments(c.clips)
	values << clip_values
	values << i32(c.composite)
	floats << clip_floats
	floats << c.blur
	append_style(oracle, mut values, mut floats, c.style)
	send_filters(oracle, c.filters)
	if oracle.canvas_stroke(expected.data, values.data, floats.data) == 0 {
		return error('${label}: the Skia canvas path failed')
	}
	mut actual := initial.clone()
	path := cpuraster.canvas_path(c.segments, false)
	if !cpuraster.stroke_canvas_path(mut actual, c.width, c.height, c.pitch, c.alpha_type,
		path, c.transform, c.color, c.style, c.global_alpha, canvas_mode(c.composite), c.blur, c.line_width, unsafe { cpuraster.StrokeCap(c.cap) }, unsafe { cpuraster.StrokeJoin(c.join) },
		c.miter, c.dashes, c.dash_offset, clip_paths(c.clips), cpuraster.new_canvas_filter(c.filters)) {
		if actual != initial {
			return error('${label}: cpuraster declined after changing pixels')
		}
		return true
	}
	for j in 0 .. expected.len {
		if expected[j] != actual[j] {
			p := j - j % 4
			save_failure(initial, expected, actual, '${c}')
			return error('${label}: pixel (${j % c.pitch / 4}, ${j / c.pitch}) channel ${j % 4} is ${actual[j]}, Skia wrote ${expected[j]}, from ${initial[p..p + 4]} (${c})')
		}
	}
	return false
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
		global_alpha := random_global_alpha()
		compare_canvas_fill(oracle, initial, FillCase{width, height, pitch, alpha_type, segments, even_odd, transform, color, global_alpha, []ClipCase{}, 0, 0, none, []},
			'canvas ${i}')!
	}
	return count
}

struct FillCase {
	width        int
	height       int
	pitch        int
	alpha_type   int
	segments     []f32
	even_odd     bool
	transform    [6]f32
	color        u32
	global_alpha f32
	clips        []ClipCase
	composite    int
	blur         f32
	style        ?cpuraster.CanvasPaintStyle
	filters      []cpuraster.CanvasFilterStep
}

fn compare_canvas_fill(oracle Oracle, initial []u8, c FillCase, label string) ! {
	if compare_canvas_fill_or_decline(oracle, initial, c, label)! {
		return error('${label}: cpuraster declined')
	}
}

fn compare_canvas_fill_or_decline(oracle Oracle, initial []u8, c FillCase, label string) !bool {
	mut expected := initial.clone()
	mut floats := c.transform[..].clone()
	floats << c.global_alpha
	floats << c.segments
	mut values := [i32(c.width), c.height, c.pitch, c.alpha_type, int(c.even_odd), c.segments.len / 12,
		i32(c.color)]
	clip_values, clip_floats := clip_arguments(c.clips)
	values << clip_values
	values << i32(c.composite)
	floats << clip_floats
	floats << c.blur
	append_style(oracle, mut values, mut floats, c.style)
	send_filters(oracle, c.filters)
	if oracle.canvas_fill(expected.data, values.data, floats.data) == 0 {
		return error('${label}: the Skia canvas path failed')
	}
	mut actual := initial.clone()
	path := cpuraster.canvas_path(c.segments, c.even_odd)
	if !cpuraster.fill_canvas_path(mut actual, c.width, c.height, c.pitch, c.alpha_type, path,
		c.transform, c.color, c.style, c.global_alpha, canvas_mode(c.composite), c.blur, clip_paths(c.clips), cpuraster.new_canvas_filter(c.filters)) {
		if actual != initial {
			return error('${label}: cpuraster declined after changing pixels')
		}
		return true
	}
	for j in 0 .. expected.len {
		if expected[j] != actual[j] {
			p := j - j % 4
			save_failure(initial, expected, actual, '${c}')
			return error('${label}: pixel (${j % c.pitch / 4}, ${j / c.pitch}) channel ${j % 4} is ${actual[j]}, Skia wrote ${expected[j]}, from ${initial[p..p + 4]} (${c})')
		}
	}
	return false
}

// Fills, hairlines, wide and dashed strokes inside anti-aliased and
// hard-edged clips.
fn check_clipped_draws(oracle Oracle, count int) !(int, int) {
	mut strokes := 0
	for i in 0 .. count {
		width := rand.intn(120) or { 0 } + 1
		height := rand.intn(120) or { 0 } + 1
		pitch := width * 4 + 4 * (rand.intn(3) or { 0 })
		alpha_type := if rand.intn(2) or { 0 } == 0 { 1 } else { 2 }
		clips := random_clips(width, height)
		initial := random_canvas_bitmap(width, height, pitch, alpha_type)
		if rand.intn(2) or { 0 } == 0 {
			m := random_matrix()
			compare_canvas_fill(oracle, initial, FillCase{width, height, pitch, alpha_type, random_canvas_segments(width, height), rand.intn(2) or {
				0
			} == 0, [m.a, m.b, m.c, m.d, m.e, m.f]!, random_color(), random_global_alpha(), clips, 0, 0, none, []},
				'clipped fill ${i}')!
			continue
		}
		segments := if rand.intn(2) or { 0 } == 0 {
			random_stroke_shape(width, height)
		} else {
			random_canvas_segments(width, height)
		}
		line_width := match rand.intn(3) or { 0 } {
			0 { f32(1) }
			1 { f32(rand.f64()) }
			else { random_wide_line_width() }
		}
		c := StrokeCase{
			width:        width
			height:       height
			pitch:        pitch
			alpha_type:   alpha_type
			segments:     segments
			transform:    random_stroke_matrix()
			color:        random_color()
			global_alpha: random_global_alpha()
			line_width:   line_width
			miter:        if rand.intn(2) or { 0 } == 0 { f32(10) } else { f32(rand.f64() * 4) }
			cap:          rand.intn(3) or { 0 }
			join:         rand.intn(3) or { 0 }
			dashes:       if rand.intn(3) or { 0 } == 0 { random_dashes() } else { []f32{} }
			dash_offset:  random_dash_offset()
			clips:        clips
		}
		compare_canvas_stroke(oracle, initial, c, 'clipped stroke ${i}')!
		strokes++
	}
	return count, strokes
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
	if os.getenv('CPU_RASTER_CHECKS') == 'exports' {
		table := check_export_exhaustive(oracle) or { panic(err) }
		exports := check_export_random(oracle, count) or { panic(err) }
		println('bitmap export: ${table} exhaustive and ${exports} random exports exact')
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') == 'pathgeometry' {
		check_path_geometry(count)
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') == 'clips' {
		draws, strokes := check_clipped_draws(oracle, count) or {
			eprintln(err.msg())
			exit(1)
		}
		println('clipped canvas draws: ${draws} exact (${strokes} strokes)')
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') == 'strokes' {
		check_stroke_cases(oracle, count)
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') == 'composites' {
		check_composite_cases(oracle, count)
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') == 'shadows' {
		check_shadow_cases(oracle, count)
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') == 'gradients' {
		check_gradient_cases(oracle, count)
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') == 'patterns' {
		check_pattern_cases(oracle, count)
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') == 'clears' {
		check_clear_cases(oracle, count)
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') == 'bwfills' {
		fills, declined := check_bw_fill_paths(oracle, count) or {
			eprintln(err.msg())
			exit(1)
		}
		println('non-anti-aliased path fills: ${fills - declined} exact, ${declined} declined')
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') in ['images', 'imagefilters', 'image-space-layers', 'converted-image-layers', 'fractional-image-layers', 'image-layer-alpha', 'resampled-image-layers', 'clipped-image-layers', 'identity-image-layers', 'identity-image-sampling', 'near-integer-image-layers', 'near-integer-factored-images', 'resampled-image-shadows'] {
		check_image_cases(oracle, count)
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') == 'glyphs' {
		check_glyph_cases(oracle, count)
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') == 'colorfilters' {
		check_color_filter_cases(oracle, count)
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') in ['filterlayers', 'dropshadows', 'mixedshadows', 'mixedblurs'] {
		check_filter_layer_cases(oracle, count)
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') == 'portable-shadows' {
		check_portable_outer_shadow_cases(count)
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') in ['inner-shadows', 'rounded-inner-shadows'] {
		check_portable_inner_shadow_cases(count)
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') == 'text-shadows' {
		check_portable_text_shadow_cases(count)
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') == 'rrects' {
		check_rounded_rect_cases(count)
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') == 'imageblur' {
		check_image_blur_cases(count)
		return
	}
	if os.getenv('CPU_RASTER_CHECKS') == 'mipmaps' {
		check_mipmap_cases(count)
		return
	}
	selection := os.getenv('CPU_RASTER_CHECKS')
	if selection != '' && selection != 'all' {
		eprintln('Unknown CPU_RASTER_CHECKS: ${selection}')
		exit(2)
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
	bw_fills, bw_declined := check_bw_fill_paths(oracle, count) or {
		eprintln(err.msg())
		exit(1)
	}
	println('non-anti-aliased path fills: ${bw_fills - bw_declined} exact, ${bw_declined} declined')
	canvas := check_canvas_fills(oracle, count / 4) or {
		eprintln(err.msg())
		exit(1)
	}
	println('canvas fills: ${canvas} exact')
	check_stroke_cases(oracle, count)
	check_composite_cases(oracle, count / 2)
	check_shadow_cases(oracle, count / 2)
	check_gradient_cases(oracle, count / 2)
	check_pattern_cases(oracle, count / 2)
	check_clear_cases(oracle, count / 2)
	check_image_cases(oracle, count / 2)
	check_glyph_cases(oracle, count / 2)
	check_color_filter_cases(oracle, count / 2)
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
	clipped, clipped_strokes := check_clipped_draws(oracle, count / 2) or {
		eprintln(err.msg())
		exit(1)
	}
	println('clipped canvas draws: ${clipped} exact (${clipped_strokes} strokes)')
}

fn check_composite_cases(oracle Oracle, count int) {
	composites, composite_strokes := check_composite_draws(oracle, count) or {
		eprintln(err.msg())
		exit(1)
	}
	println('composited canvas draws: ${composites} exact (${composite_strokes} strokes)')
}

fn canvas_mode(composite int) cpuraster.BlendMode {
	return cpuraster.canvas_blend_mode(composite) or { panic('composite ${composite}') }
}

// Canvas bitmaps whose pixels reach the blend modes' branches: transparent and
// opaque pixels and channels at zero or at their alpha, among random ones.
fn random_composite_bitmap(width int, height int, pitch int, alpha_type int) []u8 {
	mut bitmap := random_canvas_bitmap(width, height, pitch, alpha_type)
	if rand.intn(4) or { 0 } == 0 {
		return bitmap
	}
	for y in 0 .. height {
		for x in 0 .. width {
			o := y * pitch + x * 4
			match rand.intn(6) or { 0 } {
				0 {
					for c in 0 .. 4 {
						bitmap[o + c] = 0
					}
				}
				1 {
					bitmap[o + 3] = 255
				}
				2 {
					bitmap[o + rand.intn(3) or { 0 }] = bitmap[o + 3]
				}
				3 {
					bitmap[o + rand.intn(3) or { 0 }] = 0
				}
				else {}
			}
		}
	}
	return bitmap
}

fn random_composite_color() u32 {
	return match rand.intn(8) or { 0 } {
		0 { u32(0xff000000) }
		1 { u32(0xffffffff) }
		2 { u32(0) }
		3 { u32(0xff000000) | (rand.u32() & 0xffffff) }
		else { rand.u32() }
	}
}

fn random_composite_alpha() f32 {
	return match rand.intn(6) or { 0 } {
		0 { f32(1) }
		1 { f32(0) }
		// Alphas whose byte is 255 or 0 while the float is not.
		2 { f32(0.999) }
		3 { f32(0.0015) }
		else { f32(rand.f64()) }
	}
}

// Fills and strokes (hairlines at full and partial coverage, thin outlines
// for modes without coverage as alpha, wide and dashed strokes, clipped or
// not) with every SkBlendMode composite operation, through the lowp and
// highp pipeline blitters and the fast paths that keep the legacy blitter.
// Returns the comparisons and how many were strokes.
fn check_composite_draws(oracle Oracle, count int) !(int, int) {
	mut strokes := 0
	for i in 0 .. count {
		width := rand.intn(100) or { 0 } + 1
		height := rand.intn(100) or { 0 } + 1
		pitch := width * 4 + 4 * (rand.intn(3) or { 0 })
		alpha_type := if rand.intn(2) or { 0 } == 0 { 1 } else { 2 }
		composite := rand.intn(28) or { 0 }
		clips := if rand.intn(4) or { 0 } == 0 { random_clips(width, height) } else { []ClipCase{} }
		initial := random_composite_bitmap(width, height, pitch, alpha_type)
		color := random_composite_color()
		global_alpha := random_composite_alpha()
		if rand.intn(2) or { 0 } == 0 {
			m := random_matrix()
			compare_canvas_fill(oracle, initial, FillCase{width, height, pitch, alpha_type, random_canvas_segments(width, height), rand.intn(2) or {
				0
			} == 0, [m.a, m.b, m.c, m.d, m.e, m.f]!, color, global_alpha, clips, composite, 0, none, []},
				'composite fill ${i}')!
			continue
		}
		mut segments := if rand.intn(2) or { 0 } == 0 {
			random_stroke_shape(width, height)
		} else {
			random_canvas_segments(width, height)
		}
		if rand.intn(3) or { 0 } == 0 {
			align_canvas_lines(mut segments)
		}
		line_width := match rand.intn(4) or { 0 } {
			0 { f32(1) }
			1 { f32(rand.f64()) }
			2 { f32(rand.f64() * 0.3) }
			else { random_wide_line_width() }
		}
		c := StrokeCase{
			width:        width
			height:       height
			pitch:        pitch
			alpha_type:   alpha_type
			segments:     segments
			transform:    random_stroke_matrix()
			color:        color
			global_alpha: global_alpha
			line_width:   line_width
			miter:        if rand.intn(2) or { 0 } == 0 { f32(10) } else { f32(rand.f64() * 4) }
			cap:          rand.intn(3) or { 0 }
			join:         rand.intn(3) or { 0 }
			dashes:       if rand.intn(4) or { 0 } == 0 { random_dashes() } else { []f32{} }
			dash_offset:  random_dash_offset()
			clips:        clips
			composite:    composite
		}
		compare_canvas_stroke(oracle, initial, c, 'composite stroke ${i}')!
		strokes++
	}
	return count, strokes
}

// save_failure writes a mismatching case's bitmaps and parameters to
// CPU_RASTER_FAILURE_DIR, when set, for offline probing.
fn save_failure(initial []u8, expected []u8, actual []u8, description string) {
	dir := os.getenv('CPU_RASTER_FAILURE_DIR')
	if dir == '' {
		return
	}
	os.mkdir_all(dir) or { return }
	os.write_file_array(os.join_path(dir, 'initial.bin'), initial) or {}
	os.write_file_array(os.join_path(dir, 'expected.bin'), expected) or {}
	os.write_file_array(os.join_path(dir, 'actual.bin'), actual) or {}
	os.write_file(os.join_path(dir, 'case.txt'), description) or {}
}

// A rect as Canvas2D's rect() or a lineTo outline builds it, integral or
// fractional, small or large, sometimes past the device.
fn random_shadow_rect(width int, height int) Rect4 {
	scale := match rand.intn(4) or { 0 } {
		0 { f64(0.2) }
		1 { f64(1) }
		2 { f64(3) }
		else { f64(rand.intn(300) or { 0 } + 1) / 100 }
	}
	mut x0 := f32((rand.f64() * 1.4 - 0.2) * f64(width))
	mut y0 := f32((rand.f64() * 1.4 - 0.2) * f64(height))
	mut x1 := x0 + f32(rand.f64() * f64(width) * scale)
	mut y1 := y0 + f32(rand.f64() * f64(height) * scale)
	if rand.intn(3) or { 0 } == 0 {
		x0 = f32(int(x0))
		y0 = f32(int(y0))
		x1 = f32(int(x1))
		y1 = f32(int(y1))
	}
	return Rect4{x0, y0, x1, y1}
}

struct Rect4 {
	l f32
	t f32
	r f32
	b f32
}

fn rect_segments(r Rect4, reverse bool) []f32 {
	mut s := []f32{}
	s << segment(0, [r.l, r.t])
	if reverse {
		s << segment(1, [r.l, r.b])
		s << segment(1, [r.r, r.b])
		s << segment(1, [r.r, r.t])
	} else {
		s << segment(1, [r.r, r.t])
		s << segment(1, [r.r, r.b])
		s << segment(1, [r.l, r.b])
	}
	s << segment(5, [])
	return s
}

fn random_shadow_blur() f32 {
	return match rand.intn(9) or { 0 } {
		0 { f32(rand.f64() * 0.8) }
		1, 2 { f32(rand.f64() * 3.4 + 0.6) }
		3 { f32(2.0 / 3.0) }
		4 { f32(4) }
		5, 6 { f32(rand.f64() * 36 + 4) }
		7 { f32(rand.f64() * 260 + 40) }
		else { f32(rand.intn(20) or { 0 } + 1) }
	}
}

// Shapes Skia's blur mask filter treats specially: lone rects (the analytic
// nine-patch), nested rect pairs (the blurred ring nine-patch), rects too
// small or too large for a nine-patch, and other paths blurred as masks.
fn random_shadow_shape(width int, height int) []f32 {
	return match rand.intn(6) or { 0 } {
		0, 1 {
			if rand.intn(10) or { 0 } == 0 {
				rect_segments(Rect4{-40000, f32(rand.intn(height) or { 0 }), f32(rand.intn(width) or { 0 } + 1), f32(height + 5)},
					false)
			} else {
				rect_segments(random_shadow_rect(width, height), rand.intn(2) or { 0 } == 0)
			}
		}
		2 {
			mut outer := random_shadow_rect(width, height)
			if rand.intn(8) or { 0 } == 0 {
				// Past the 32767 limit of the nine-patch.
				outer = Rect4{-20000, -20000, 20000, f32(rand.intn(30000) or { 0 } + 10)}
			}
			mut s := rect_segments(outer, rand.intn(2) or { 0 } == 0)
			if rand.intn(4) or { 0 } == 0 {
				// An open first contour, which the second contour's move closes.
				s = s[..s.len - 12].clone()
			}
			mut inner := random_shadow_rect(width, height)
			if rand.intn(3) or { 0 } != 0 {
				// Inset inside the outer rect.
				w := outer.r - outer.l
				h := outer.b - outer.t
				inner = Rect4{outer.l + w * f32(rand.f64() * 0.4), outer.t + h * f32(rand.f64() * 0.4), outer.r - w * f32(rand.f64() * 0.4), outer.b - h * f32(rand.f64() * 0.4)}
			}
			s << rect_segments(inner, rand.intn(2) or { 0 } == 0)
			s
		}
		3 {
			random_stroke_shape(width, height)
		}
		else {
			random_canvas_segments(width, height)
		}
	}
}

// Canvas2D shadows: fills, hairlines and wide and dashed strokes with a
// shadow blur, through vox_skia_canvas_path()'s SkBlurMaskFilter, with every
// composite operation and inside random clips. Returns the comparisons, how
// many were strokes and how many cpuraster declined (masks that Skia fills
// with SkScan::FillPath()), which must leave the pixels untouched.
fn check_shadow_draws(oracle Oracle, count int) !(int, int, int) {
	mut strokes := 0
	mut declined := 0
	for i in 0 .. count {
		width := rand.intn(100) or { 0 } + 1
		height := rand.intn(100) or { 0 } + 1
		pitch := width * 4 + 4 * (rand.intn(3) or { 0 })
		alpha_type := if rand.intn(2) or { 0 } == 0 { 1 } else { 2 }
		composite := if rand.intn(3) or { 0 } == 0 { rand.intn(28) or { 0 } } else { 0 }
		clips := if rand.intn(4) or { 0 } == 0 { random_clips(width, height) } else { []ClipCase{} }
		initial := random_composite_bitmap(width, height, pitch, alpha_type)
		blur := random_shadow_blur()
		transform := match rand.intn(4) or { 0 } {
			0 { [f32(1), 0, 0, 1, 0, 0]! }
			1 { [f32(1), 0, 0, 1, f32(rand.f64() * 20 - 10), f32(rand.f64() * 20 - 10)]! }
			else { random_stroke_matrix() }
		}
		segments := random_shadow_shape(width, height)
		if rand.intn(2) or { 0 } == 0 {
			if compare_canvas_fill_or_decline(oracle, initial, FillCase{width, height, pitch, alpha_type, segments, rand.intn(4) or {
				0
			} == 0, transform, random_composite_color(), random_composite_alpha(), clips, composite, blur, none, []},
				'shadow fill ${i}')!
			{
				declined++
			}
			continue
		}
		line_width := match rand.intn(4) or { 0 } {
			0 { f32(1) }
			1 { f32(rand.f64()) }
			else { random_wide_line_width() }
		}
		c := StrokeCase{
			width:        width
			height:       height
			pitch:        pitch
			alpha_type:   alpha_type
			segments:     segments
			transform:    transform
			color:        random_composite_color()
			global_alpha: random_composite_alpha()
			line_width:   line_width
			miter:        if rand.intn(2) or { 0 } == 0 { f32(10) } else { f32(rand.f64() * 4) }
			cap:          rand.intn(3) or { 0 }
			join:         rand.intn(3) or { 0 }
			dashes:       if rand.intn(5) or { 0 } == 0 { random_dashes() } else { []f32{} }
			dash_offset:  random_dash_offset()
			clips:        clips
			composite:    composite
			blur:         blur
		}
		if compare_canvas_stroke_or_decline(oracle, initial, c, 'shadow stroke ${i}')! {
			declined++
		}
		strokes++
	}
	return count, strokes, declined
}

fn check_shadow_cases(oracle Oracle, count int) {
	shadows, shadow_strokes, shadow_declined := check_shadow_draws(oracle, count) or {
		eprintln(err.msg())
		exit(1)
	}
	println('blurred canvas shadows: ${shadows - shadow_declined} exact, ${shadow_declined} declined (${shadow_strokes} strokes)')
}

// The oracle's style arguments: for a gradient its kind and stop count, then
// the geometry, angle and stops; for a pattern kind 4, its dimensions, pitch,
// alpha type, color space and repetition, then its transform, with the
// pixels handed to oracle_pattern(); kind 0 for the solid color.
fn append_style(oracle Oracle, mut values []i32, mut floats []f32, style ?cpuraster.CanvasPaintStyle) {
	s := style or {
		values << [i32(0), 0]
		return
	}
	match s {
		cpuraster.CanvasGradient {
			values << i32(s.kind)
			values << i32(s.stops.len / 5)
			floats << [s.x0, s.y0, s.r0, s.x1, s.y1, s.r1, s.angle]
			floats << s.stops
		}
		cpuraster.CanvasPattern {
			oracle.pattern(s.pixels.data)
			values << [i32(4), s.width, s.height, s.pitch, if s.premultiplied { 2 } else { 1 },
				int(s.display_p3), s.repetition]
			floats << s.transform[..]
		}
	}
}

// Gradient stops as Canvas2D hands them over: offsets in order, sometimes
// repeated (hard stops), at 0 and 1 or inside, colors in byte / 255 units,
// opaque, transparent or mixed, from one to nine stops.
fn random_gradient_stops() []f32 {
	count := match rand.intn(6) or { 0 } {
		0 { 1 }
		1, 2 { 2 }
		3 { 3 }
		else { rand.intn(8) or { 0 } + 2 }
	}
	opaque := rand.intn(3) or { 0 } == 0
	mut offsets := []f32{}
	for _ in 0 .. count {
		offsets << match rand.intn(6) or { 0 } {
			0 { f32(0) }
			1 { f32(1) }
			else { f32(rand.intn(21) or { 0 }) / 20 }
		}
	}
	offsets.sort()
	if rand.intn(3) or { 0 } == 0 && count > 1 {
		// Evenly spaced.
		for i in 0 .. count {
			offsets[i] = f32(i) / f32(count - 1)
		}
	}
	mut stops := []f32{}
	for i in 0 .. count {
		stops << offsets[i]
		for _ in 0 .. 3 {
			stops << f32(rand.intn(256) or { 0 }) / 255
		}
		alpha := if opaque { 255 } else { match rand.intn(4) or { 0 } {
				0 { 0 }
				1 { 255 }
				else { rand.intn(256) or { 0 } }
			} }
		stops << f32(alpha) / 255
	}
	return stops
}

// Linear, radial and conic gradients, including degenerate ones: equal
// points, zero and equal radii, concentric circles and focal points on,
// inside and outside the end circle.
fn random_gradient(width int, height int) cpuraster.CanvasGradient {
	kind := rand.intn(3) or { 0 } + 1
	px := fn [width] () f32 {
		return f32(rand.f64() * f64(width) * 1.4 - f64(width) * 0.2)
	}
	py := fn [height] () f32 {
		return f32(rand.f64() * f64(height) * 1.4 - f64(height) * 0.2)
	}
	mut x0 := px()
	mut y0 := py()
	mut x1 := px()
	mut y1 := py()
	mut r0 := f32(rand.f64() * f64(width) * 0.6)
	mut r1 := f32(rand.f64() * f64(width) * 0.8)
	match rand.intn(8) or { 0 } {
		0 {
			x1 = x0
			y1 = y0
		}
		1 {
			r0 = 0
		}
		2 {
			r1 = r0
		}
		3 {
			x1 = x0
			y1 = y0
			r0 = 0
		}
		4 {
			// The focal point on the end circle.
			angle := rand.f64() * 6.283
			x0 = x1 + r1 * f32(math.cos(angle))
			y0 = y1 + r1 * f32(math.sin(angle))
			r0 = 0
		}
		5 {
			// A zero end radius, which SkConicalGradient swaps.
			r1 = 0
		}
		6 {
			// Equal circles: a thin ring at the radius.
			x1 = x0
			y1 = y0
			r1 = r0
		}
		else {
			if rand.intn(10) or { 0 } == 0 {
				r0 = -1
			}
		}
	}
	return cpuraster.CanvasGradient{
		kind:  kind
		x0:    x0
		y0:    y0
		r0:    r0
		x1:    x1
		y1:    y1
		r1:    r1
		angle: f32(rand.f64() * 12.566 - 6.283)
		stops: if rand.intn(40) or { 0 } == 0 { []f32{} } else { random_gradient_stops() }
	}
}

// Gradient fills and strokes through vox_skia_canvas_path()'s
// SkGradientShader, with every composite operation, global alphas and
// clips. Returns the comparisons and how many were strokes.
fn check_gradient_draws(oracle Oracle, count int) !(int, int) {
	return check_style_draws(oracle, count, 'gradient', fn (width int, height int) cpuraster.CanvasPaintStyle {
		return random_gradient(width, height)
	})
}

// Pattern fills and strokes through vox_skia_canvas_path()'s SkImageShader.
fn check_pattern_draws(oracle Oracle, count int) !(int, int) {
	return check_style_draws(oracle, count, 'pattern', fn (width int, height int) cpuraster.CanvasPaintStyle {
		return random_pattern(width, height)
	})
}

fn check_style_draws(oracle Oracle, count int, label string, make_style fn (int, int) cpuraster.CanvasPaintStyle) !(int, int) {
	mut strokes := 0
	for i in 0 .. count {
		width := rand.intn(90) or { 0 } + 1
		height := rand.intn(90) or { 0 } + 1
		pitch := width * 4 + 4 * (rand.intn(3) or { 0 })
		alpha_type := if rand.intn(2) or { 0 } == 0 { 1 } else { 2 }
		composite := if rand.intn(2) or { 0 } == 0 { rand.intn(28) or { 0 } } else { 0 }
		clips := if rand.intn(5) or { 0 } == 0 { random_clips(width, height) } else { []ClipCase{} }
		initial := random_composite_bitmap(width, height, pitch, alpha_type)
		style := ?cpuraster.CanvasPaintStyle(make_style(width, height))
		transform := match rand.intn(40) or { 0 } {
			0 { [f32(1), 0, 0, 0, 3, 2]! }
			1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 { [f32(1), 0, 0, 1, 0, 0]! }
			14, 15, 16, 17, 18 {
				[f32(1), 0, 0, 1, f32(rand.intn(41) or { 0 } - 20), f32(rand.intn(41) or { 0 } - 20)]!
			}
			else { random_stroke_matrix() }
		}
		segments := if rand.intn(3) or { 0 } == 0 {
			rect_segments(Rect4{0, 0, f32(width), f32(height)}, false)
		} else {
			random_canvas_segments(width, height)
		}
		if rand.intn(3) or { 0 } != 0 {
			compare_canvas_fill(oracle, initial, FillCase{width, height, pitch, alpha_type, segments, rand.intn(4) or {
				0
			} == 0, transform, 0, random_composite_alpha(), clips, composite, 0, style, []},
				'${label} fill ${i}')!
			continue
		}
		line_width := match rand.intn(3) or { 0 } {
			0 { f32(1) }
			1 { f32(rand.f64()) }
			else { random_wide_line_width() }
		}
		c := StrokeCase{
			width:        width
			height:       height
			pitch:        pitch
			alpha_type:   alpha_type
			segments:     segments
			transform:    transform
			global_alpha: random_composite_alpha()
			line_width:   line_width
			miter:        10
			cap:          rand.intn(3) or { 0 }
			join:         rand.intn(3) or { 0 }
			clips:        clips
			composite:    composite
			style:        style
		}
		compare_canvas_stroke(oracle, initial, c, '${label} stroke ${i}')!
		strokes++
	}
	return count, strokes
}

fn check_gradient_cases(oracle Oracle, count int) {
	gradients, gradient_strokes := check_gradient_draws(oracle, count) or {
		eprintln(err.msg())
		exit(1)
	}
	println('gradient canvas draws: ${gradients} exact (${gradient_strokes} strokes)')
}

// Pattern images: one-pixel rows, columns and images (whose repeated axes
// clamp), unpremultiplied ones with transparent and opaque pixels,
// premultiplied ones, Display P3 ones, padded rows, every repetition, and
// pattern transforms that are identities, integer translations (nearest
// sampling), fractional ones, scales, rotations, tiny scales that leave the
// 16-bit image range and singular ones.
fn random_pattern(width int, height int) cpuraster.CanvasPattern {
	size := fn () int {
		return match rand.intn(6) or { 0 } {
			0 { 1 }
			1 { 2 }
			else { rand.intn(24) or { 0 } + 1 }
		}
	}
	w := size()
	h := size()
	pitch := w * 4 + 4 * (rand.intn(3) or { 0 })
	premultiplied := rand.intn(2) or { 0 } == 0
	mut pixels := []u8{len: pitch * h}
	for y in 0 .. h {
		for x in 0 .. w {
			o := y * pitch + x * 4
			a := match rand.intn(5) or { 0 } {
				0 { 0 }
				1, 2 { 255 }
				else { rand.intn(256) or { 0 } }
			}
			for i in 0 .. 3 {
				v := rand.intn(256) or { 0 }
				pixels[o + i] = u8(if premultiplied { v * a / 255 } else { v })
			}
			pixels[o + 3] = u8(a)
		}
	}
	transform := match rand.intn(10) or { 0 } {
		0, 1, 2 {
			[f32(1), 0, 0, 1, 0, 0]!
		}
		3, 4 {
			[f32(1), 0, 0, 1, f32(rand.intn(61) or { 0 } - 30), f32(rand.intn(61) or { 0 } - 30)]!
		}
		5 {
			[f32(1), 0, 0, 1, f32(rand.f64() * 40 - 20), f32(rand.f64() * 40 - 20)]!
		}
		6 {
			s := f32(math.pow(10, rand.f64() * 2 - 1))
			[s, 0, 0, s * f32(rand.f64() + 0.5), f32(rand.f64() * 20), f32(rand.f64() * 20)]!
		}
		7 {
			match rand.intn(6) or { 0 } {
				0 { [f32(0.0001), 0, 0, 0.0002, 0, 0]! }
				1 { [f32(0), 0, 0, 1, 0, 0]! }
				// Translations past 2^30, which the legacy context declines
				// to step.
				2 { [f32(1), 0, 0, 1, 3.0e9, -2.0e9]! }
				// One image pixel per device pixel over the unit tile, which
				// SkBitmapProcState::init() snaps to a translation.
				3 { [f32(1.000002) / f32(w), 0, 0, f32(0.999997) / f32(h), f32(rand.f64() * 4), 0.25]! }
				else { [f32(2), 1, 4, 2, 3, -5]! }
			}
		}
		else {
			random_stroke_matrix()
		}
	}
	return cpuraster.CanvasPattern{
		pixels:        pixels
		width:         w
		height:        h
		pitch:         pitch
		premultiplied: premultiplied
		display_p3:    rand.intn(6) or { 0 } == 0
		repetition:    if rand.intn(3) or { 0 } == 0 { 0 } else { rand.intn(4) or { 0 } }
		transform:     transform
	}
}

fn check_pattern_cases(oracle Oracle, count int) {
	patterns, pattern_strokes := check_pattern_draws(oracle, count) or {
		eprintln(err.msg())
		exit(1)
	}
	println('pattern canvas draws: ${patterns} exact (${pattern_strokes} strokes)')
}

// A bitmap command: operation 1 (clearRect) or 2 (drawImage).
struct BitmapCase {
	width        int
	height       int
	pitch        int
	alpha_type   int
	operation    int
	smoothing    bool
	transform    [6]f32
	global_alpha f32
	clips        []ClipCase
	composite    int
	color        u32
	destination  [4]f32
	source       [4]f32
	image        ?cpuraster.CanvasPattern
	filters      []cpuraster.CanvasFilterStep
	chromium     bool
}

// Runs one bitmap command through vox_skia_canvas_path() and cpuraster and
// compares every byte. Returns true when cpuraster declined, which must
// leave the pixels untouched.
fn compare_canvas_bitmap(oracle Oracle, initial []u8, c BitmapCase, label string) !bool {
	mut expected := initial.clone()
	mut floats := c.transform[..].clone()
	floats << c.global_alpha
	floats << c.destination[..]
	floats << c.source[..]
	mut values := [i32(c.width), c.height, c.pitch, c.alpha_type, c.operation, int(c.smoothing)]
	clip_values, clip_floats := clip_arguments(c.clips)
	values << clip_values
	floats << clip_floats
	values << [i32(c.composite), i32(c.color)]
	if image := c.image {
		oracle.pattern(image.pixels.data)
		values << [i32(image.width), image.height, image.pitch, if image.premultiplied { 2 } else { 1 },
			int(image.display_p3)]
	} else {
		values << [i32(0), 0, 0, 0, 0]
	}
	send_filters(oracle, c.filters)
	native := if c.chromium { oracle.canvas_bitmap_chromium } else { oracle.canvas_bitmap }
	if native(expected.data, values.data, floats.data) == 0 {
		return error('${label}: the Skia bitmap command failed')
	}
	mut actual := initial.clone()
	drawn := if c.operation == 1 {
		cpuraster.clear_canvas_rect(mut actual, c.width, c.height, c.pitch, c.alpha_type, c.transform,
			c.destination, c.color, clip_paths(c.clips))
	} else {
		image := c.image or { panic('drawImage without an image') }
		cpuraster.draw_canvas_image_filtered(mut actual, c.width, c.height, c.pitch, c.alpha_type,
			c.transform, cpuraster.CanvasBitmap{
			pixels:        image.pixels
			width:         image.width
			height:        image.height
			pitch:         image.pitch
			premultiplied: image.premultiplied
			display_p3:    image.display_p3
		}, c.source, c.destination, c.smoothing, c.global_alpha, canvas_mode(c.composite),
			clip_paths(c.clips), cpuraster.new_canvas_filter(c.filters), c.chromium)
	}
	if !drawn {
		if actual != initial {
			return error('${label}: cpuraster declined after changing pixels')
		}
		return true
	}
	for j in 0 .. expected.len {
		if expected[j] != actual[j] {
			p := j - j % 4
			save_failure(initial, expected, actual, '${c}')
			return error('${label}: pixel (${j % c.pitch / 4}, ${j / c.pitch}) channel ${j % 4} is ${actual[j]}, Skia wrote ${expected[j]}, from ${initial[p..p + 4]} (${c})')
		}
	}
	return false
}

// A destination or source rect: integral or fractional, inside or past the
// device, negative sizes, empty, huge and occasionally not finite.
fn random_bitmap_rect(width int, height int) [4]f32 {
	x := f32(rand.f64() * f64(width) * 1.4 - f64(width) * 0.2)
	y := f32(rand.f64() * f64(height) * 1.4 - f64(height) * 0.2)
	w := f32(rand.f64() * f64(width) * 1.2 - f64(width) * 0.1)
	h := f32(rand.f64() * f64(height) * 1.2 - f64(height) * 0.1)
	return match rand.intn(12) or { 0 } {
		0, 1, 2 { [f32(int(x)), f32(int(y)), f32(int(w)), f32(int(h))]! }
		3 { [f32(0), 0, f32(width), f32(height)]! }
		4 { [x, y, 0, h]! }
		5 { [f32(-1.0e9), -1.0e9, 3.0e9, 3.0e9]! }
		6 { if rand.intn(4) or { 0 } == 0 { [f32(math.nan()), y, w, h]! } else { [x, y, -w, -h]! } }
		else { [x, y, w, h]! }
	}
}

// Canvas2D clearRect() calls through vox_skia_canvas_path()'s operation 1:
// transparent and opaque black (alpha: false) clears under clips and
// integral, fractional, scaled, flipped and rotated transforms. Returns the
// comparisons and how many cpuraster declined.
fn check_clear_draws(oracle Oracle, count int) !(int, int) {
	mut declined := 0
	for i in 0 .. count {
		width := rand.intn(90) or { 0 } + 1
		height := rand.intn(90) or { 0 } + 1
		pitch := width * 4 + 4 * (rand.intn(3) or { 0 })
		alpha_type := if rand.intn(2) or { 0 } == 0 { 1 } else { 2 }
		initial := random_composite_bitmap(width, height, pitch, alpha_type)
		transform := match rand.intn(8) or { 0 } {
			0, 1, 2 {
				[f32(1), 0, 0, 1, 0, 0]!
			}
			3 {
				[f32(1), 0, 0, 1, f32(rand.intn(41) or { 0 } - 20), f32(rand.f64() * 10 - 5)]!
			}
			4, 5 {
				[f32(rand.f64() * 3 - 1.5), 0, 0, f32(rand.f64() * 3 - 1.5), f32(rand.f64() * 20), f32(rand.f64() * 20)]!
			}
			else {
				random_stroke_matrix()
			}
		}
		c := BitmapCase{
			width:        width
			height:       height
			pitch:        pitch
			alpha_type:   alpha_type
			operation:    1
			transform:    transform
			global_alpha: random_composite_alpha()
			clips:        if rand.intn(4) or { 0 } == 0 { random_clips(width, height) } else { []ClipCase{} }
			composite:    rand.intn(28) or { 0 }
			color:        if rand.intn(3) or { 0 } == 0 { u32(0xff000000) } else { 0 }
			destination:  random_bitmap_rect(width, height)
		}
		if compare_canvas_bitmap(oracle, initial, c, 'clear ${i}')! {
			declined++
		}
	}
	return count, declined
}

fn check_clear_cases(oracle Oracle, count int) {
	clears, declined := check_clear_draws(oracle, count) or {
		eprintln(err.msg())
		exit(1)
	}
	println('canvas clears: ${clears - declined} exact, ${declined} declined')
}

// drawImage() source rects as the canvas rounds them: the whole image,
// subsets at and away from its origin, and rects past its edges.
fn random_image_source(width int, height int) [4]f32 {
	return match rand.intn(4) or { 0 } {
		0 {
			[f32(0), 0, f32(width), f32(height)]!
		}
		1 {
			[f32(0), 0, f32(rand.intn(width) or { 0 } + 1), f32(rand.intn(height) or { 0 } + 1)]!
		}
		else {
			x := rand.intn(width + 4) or { 0 } - 2
			y := rand.intn(height + 4) or { 0 } - 2
			[f32(x), f32(y), f32(rand.intn(width + 3) or { 0 } - 1), f32(rand.intn(height + 3) or {
				0
			} - 1)]!
		}
	}
}

// Canvas2D drawImage() calls through vox_skia_canvas_path()'s operation 2:
// random images, premultiplied or not and in sRGB or Display P3, drawn
// with and without smoothing from whole and partial source rects into
// unscaled (sprite), nearly unscaled, scaled, flipped and quarter-turned
// destinations, under every composite operation, global alphas and clips.
fn check_image_draws(oracle Oracle, count int) !(int, int) {
	mut declined := 0
	fractional := os.getenv('CPU_RASTER_CHECKS') == 'fractional-image-layers'
	alpha_layers := os.getenv('CPU_RASTER_CHECKS') == 'image-layer-alpha'
	identity_layers := os.getenv('CPU_RASTER_CHECKS') == 'identity-image-layers'
	identity_sampling := os.getenv('CPU_RASTER_CHECKS') == 'identity-image-sampling'
	factored := os.getenv('CPU_RASTER_CHECKS') == 'near-integer-factored-images'
	near_integer := factored || os.getenv('CPU_RASTER_CHECKS') == 'near-integer-image-layers'
	shadow_sources := os.getenv('CPU_RASTER_CHECKS') == 'resampled-image-shadows'
	resampled := shadow_sources || near_integer || identity_sampling || identity_layers || os.getenv('CPU_RASTER_CHECKS') == 'resampled-image-layers'
	clipped := os.getenv('CPU_RASTER_CHECKS') == 'clipped-image-layers'
	converted := fractional || alpha_layers || resampled || clipped || os.getenv('CPU_RASTER_CHECKS') == 'converted-image-layers'
	aligned := converted || os.getenv('CPU_RASTER_CHECKS') == 'image-space-layers'
	filtered := aligned || os.getenv('CPU_RASTER_CHECKS') == 'imagefilters'
	mut bitmap_space := 0
	mut image_space := 0
	for i in 0 .. count {
		width := rand.intn(90) or { 0 } + 1
		height := rand.intn(90) or { 0 } + 1
		pitch := width * 4 + 4 * (rand.intn(3) or { 0 })
		alpha_type := if rand.intn(2) or { 0 } == 0 { 1 } else { 2 }
		initial := random_composite_bitmap(width, height, pitch, alpha_type)
		image := random_pattern(width, height)
		source := random_image_source(image.width, image.height)
		mut destination := random_bitmap_rect(width, height)
		match rand.intn(4) or { 0 } {
			// The source's size: a sprite under a translation.
			0 {
				destination = [f32(rand.intn(width) or { 0 } - 4), f32(rand.intn(height) or { 0 } - 4),
					source[2], source[3]]!
			}
			// Within a rounding of it.
			1 {
				destination = [f32(rand.f64() * f64(width)), f32(rand.f64() * f64(height)),
					source[2] + f32(rand.f64() * 0.02 - 0.01), source[3]]!
			}
			else {}
		}
		transform := match rand.intn(10) or { 0 } {
			0, 1, 2 {
				[f32(1), 0, 0, 1, 0, 0]!
			}
			3 {
				[f32(1), 0, 0, 1, f32(rand.intn(41) or { 0 } - 20), f32(rand.intn(41) or { 0 } - 20)]!
			}
			4 {
				[f32(1), 0, 0, 1, f32(rand.f64() * 20 - 10), f32(rand.f64() * 20 - 10)]!
			}
			5 {
				[f32(rand.f64() * 3 - 1.5), 0, 0, f32(rand.f64() * 3 - 1.5), f32(rand.f64() * 40), f32(rand.f64() * 40)]!
			}
			6 {
				[f32(0), 1, -1, 0, f32(width), 0]!
			}
			else {
				random_stroke_matrix()
			}
		}
		mut c := BitmapCase{
			width:        width
			height:       height
			pitch:        pitch
			alpha_type:   alpha_type
			operation:    2
			smoothing:    rand.intn(2) or { 0 } == 0
			transform:    transform
			global_alpha: random_composite_alpha()
			clips:        if rand.intn(4) or { 0 } == 0 { random_clips(width, height) } else { []ClipCase{} }
			composite:    if rand.intn(2) or { 0 } == 0 { rand.intn(28) or { 0 } } else { 0 }
			destination:  destination
			source:       source
			image:        image
			filters: if filtered {
				match rand.intn(3) or { 0 } {
					0 { random_color_filters() }
					1 { random_layer_filters() }
					else { random_shadow_filters() }
				}
			} else { []cpuraster.CanvasFilterStep{} }
			chromium: filtered && (rand.intn(2) or { 0 }) == 0
		}
		if aligned {
			left, top := rand.intn(image.width) or { 0 }, rand.intn(image.height) or { 0 }
			sw := rand.intn(image.width - left) or { 0 } + 1
			sh := rand.intn(image.height - top) or { 0 } + 1
			c = BitmapCase{...c,
				image: if converted { cpuraster.CanvasPattern{...image,
					display_p3: i % 3 != 0} } else {
					cpuraster.CanvasPattern{...image, pixels: random_premultiplied(image.width * image.height),
						pitch: image.width * 4, premultiplied: true, display_p3: false} }
				source: [f32(left), top, sw, sh]!
				destination: [f32(rand.intn(width + 8) or { 0 } - 4), f32(rand.intn(height + 8) or { 0 } - 4), sw, sh]!
				transform: [f32(1), 0, 0, 1, f32(rand.intn(21) or { 0 } - 10), f32(rand.intn(21) or { 0 } - 10)]!
				global_alpha: if alpha_layers || resampled || clipped { random_composite_alpha() } else { f32(1) }
				chromium: false
				filters: if converted { random_converted_image_blurs() } else { match i % 4 {
					0 { random_layer_filters() }
					1 { random_shadow_filters() }
					2 { random_color_blur_chain() }
					else { random_color_shadow_filters() }
				} }
			}
		}
		if fractional || resampled || (alpha_layers && i % 2 == 0) {
			l := f32(rand.f64() * f64(image.width) * .4)
			t := f32(rand.f64() * f64(image.height) * .4)
			r := f32(image.width) - f32(rand.f64() * f64(image.width) * .4)
			b := f32(image.height) - f32(rand.f64() * f64(image.height) * .4)
			sx := f32(rand.f64() * 2 + .25) * if i % 3 == 0 { f32(-1) } else { f32(1) }
			sy := f32(rand.f64() * 2 + .25) * if i % 4 == 0 { f32(-1) } else { f32(1) }
			c = BitmapCase{...c,
				source: if resampled { c.source } else { [l, t, r - l, b - t]! }
				destination: [f32(rand.f64() * f64(width) * .6 - 4), f32(rand.f64() * f64(height) * .6 - 4),
					f32(rand.f64() * f64(width) + 1), f32(rand.f64() * f64(height) + 1)]!
				transform: [sx, 0, 0, sy, if sx < 0 { f32(width) * .8 } else { f32(3.25) },
					if sy < 0 { f32(height) * .8 } else { f32(2.75) }]!
			}
		}
		if clipped {
			iw, ih := f32(image.width), f32(image.height)
			src := match i % 4 {
				0 { [iw + f32(2), f32(0), iw, ih]! }
				1 { [f32(-2), -1, iw, ih]! }
				2 { [f32(1), 1, iw, ih]! }
				else { [f32(-.75), -.5, iw + f32(.5), ih + f32(1.25)]! }
			}
			c = BitmapCase{...c, source: src,
				destination: if i % 3 == 0 { [f32(4), 5, src[2], src[3]]! } else { c.destination },
				transform: if i % 3 == 1 { [f32(1.25), 0, 0, .75, 3.25, 2.75]! } else { c.transform }}
		}
		if identity_layers {
			mut filters := random_color_filters()
			filters << cpuraster.CanvasFilterStep{kind: .blur, sigma: .001}
			filters << random_color_filters()
			if i % 2 == 0 { filters << cpuraster.CanvasFilterStep{kind: .blur} }
			if i % 3 == 0 { filters << random_color_filters() }
			c = BitmapCase{...c, filters: filters}
		}
		if identity_sampling {
			c = BitmapCase{...c, filters: [cpuraster.CanvasFilterStep{kind: .blur, sigma: .001},
				cpuraster.CanvasFilterStep{kind: .blur}]}
		}
		if near_integer {
			sx, sy := f32(1) + f32(rand.f64() * .0018 - .0009), f32(1) + f32(rand.f64() * .0018 - .0009)
			c = BitmapCase{...c,
				transform: [f32(1), 0, 0, 1, 0, 0]!
				destination: [f32(4) + c.source[0] * sx, f32(6) + c.source[1] * sy, c.source[2] * sx, c.source[3] * sy]!
				filters: if i % 2 == 0 { [cpuraster.CanvasFilterStep{kind: .blur, sigma: 1.2}] }
					else { [cpuraster.CanvasFilterStep{kind: .blur, sigma: .001}] }
			}
			if factored {
				mx, my := f32(rand.f64() * 2.75 + .25), f32(rand.f64() * 2.75 + .25)
				tx, ty := f32(rand.f64() * 20 - 10), f32(rand.f64() * 20 - 10)
				lx, ly := (f32(4) - tx) / mx, (f32(6) - ty) / my
				local_sx, local_sy := sx / mx, sy / my
				c = BitmapCase{...c, transform: [mx, 0, 0, my, tx, ty]!,
					destination: [lx + c.source[0] * local_sx, ly + c.source[1] * local_sy,
						c.source[2] * local_sx, c.source[3] * local_sy]!}
			}
			if i % 3 == 0 {
				mut filters := random_color_filters()
				filters << c.filters
				filters << random_color_filters()
				c = BitmapCase{...c, filters: filters}
			}
		}
		if shadow_sources {
			mut filters := if i % 2 == 0 { random_color_shadow_filters() } else { random_shadow_filters() }
			for j, step in filters {
				if step.kind == .drop_shadow && i % 5 != 0 {
					filters[j] = cpuraster.CanvasFilterStep{...step, sigma: f32(rand.f64() * 5 + .2)}
				}
			}
			c = BitmapCase{...c, filters: filters}
		}
		if compare_canvas_bitmap(oracle, initial, c, 'image ${i}')! {
			declined++
		} else if filtered {
			if c.chromium { bitmap_space++ } else { image_space++ }
		}
	}
	if filtered {
		println('filtered image policies: ${image_space} image-space, ${bitmap_space} bitmap-space comparisons exact (includes no-ops)')
	}
	return count, declined
}

fn random_converted_image_blurs() []cpuraster.CanvasFilterStep {
	match rand.intn(4) or { 0 } {
		0 { return random_color_shadow_filters() }
		1 { return random_shadow_filters() }
		else {}
	}
	mut filters := [random_blur_step()]
	if rand.intn(2) or { 0 } == 0 {
		mut before := random_color_filters()
		before << filters
		filters = before.clone()
	}
	for _ in 0 .. rand.intn(3) or { 0 } {
		if rand.intn(2) or { 0 } == 0 { filters << random_color_filters() }
		filters << random_blur_step()
	}
	if rand.intn(2) or { 0 } == 0 { filters << random_color_filters() }
	return filters
}

fn check_image_cases(oracle Oracle, count int) {
	images, declined := check_image_draws(oracle, count) or {
		eprintln(err.msg())
		exit(1)
	}
	println('canvas images: ${images - declined} exact, ${declined} declined')
}

// Fonts for glyph runs: repository fonts (Latin, Cyrillic, Ahem's boxes,
// KaTeX's math), macOS system fonts including collections (first face),
// variable fonts (SF, New York), an OpenType CFF font and the color emoji
// font, when present. CPU_RASTER_GLYPH_FONT selects one font file instead.
fn glyph_fonts(repo string) []string {
	if only := os.getenv_opt('CPU_RASTER_GLYPH_FONT') {
		if !os.is_file(only) { panic('Glyph font not found: ${only}') }
		return [os.real_path(only)]
	}
	list := os.read_lines(os.join_path(repo, 'tools/gg_migration/glyph_fonts.txt')) or { panic(err) }
	mut fonts := []string{}
	for line in list {
		path := line.trim_space()
		if path == '' || path.starts_with('#') { continue }
		fonts << if os.is_abs_path(path) { path } else { os.join_path(repo, path) }
	}
	return fonts.filter(os.is_file(it))
}

struct GlyphCase {
	width        int
	height       int
	pitch        int
	alpha_type   int
	font_path    string
	face_index   int
	font_size    f32
	glyphs       []u16
	positions    []f32
	translation  [2]f32
	transform    [6]f32
	color        u32
	global_alpha f32
	clips        []ClipCase
	composite    int
	style        ?cpuraster.CanvasPaintStyle
	filters      []cpuraster.CanvasFilterStep
}

type OracleCanvasGlyphs = fn (pixels &u8, font_path &char, glyphs &u16, values &i32, floats &f32) i32

// Returns whether cpuraster declined, and whether Skia changed the pixels
// beyond premultiplying them.
fn compare_canvas_glyphs(glyphs OracleCanvasGlyphs, oracle Oracle, initial []u8, c GlyphCase, label string) !(bool, bool) {
	mut expected := initial.clone()
	mut floats := c.transform[..].clone()
	floats << [c.global_alpha, c.font_size, c.translation[0], c.translation[1]]
	floats << c.positions
	mut values := [i32(c.width), c.height, c.pitch, c.alpha_type, i32(c.color), c.glyphs.len, c.face_index]
	clip_values, clip_floats := clip_arguments(c.clips)
	values << clip_values
	values << i32(c.composite)
	floats << clip_floats
	append_style(oracle, mut values, mut floats, c.style)
	send_filters(oracle, c.filters)
	skia_ok := glyphs(expected.data, c.font_path.str, c.glyphs.data, values.data, floats.data) != 0
	mut actual := initial.clone()
	run := cpuraster.CanvasGlyphRun{
		font_path:   c.font_path
		face_index:  c.face_index
		font_size:   c.font_size
		glyphs:      c.glyphs
		positions:   c.positions
		translation: c.translation
	}
	if !cpuraster.fill_canvas_glyphs(mut actual, c.width, c.height, c.pitch, c.alpha_type, run,
		c.transform, c.color, c.style, c.global_alpha, canvas_mode(c.composite), clip_paths(c.clips), cpuraster.new_canvas_filter(c.filters)) {
		if actual != initial {
			return error('${label}: cpuraster declined after changing pixels')
		}
		return true, false
	}
	if !skia_ok {
		return error('${label}: the Skia glyph run failed where cpuraster drew (${c})')
	}
	for j in 0 .. expected.len {
		if expected[j] != actual[j] {
			p := j - j % 4
			save_failure(initial, expected, actual, '${c}')
			return error('${label}: pixel (${j % c.pitch / 4}, ${j / c.pitch}) channel ${j % 4} is ${actual[j]}, Skia wrote ${expected[j]}, from ${initial[p..p + 4]} (${c})')
		}
	}
	mut premultiplied := initial.clone()
	if c.alpha_type != 2 {
		empty := cpuraster.CanvasGlyphRun{
			font_path: c.font_path
			font_size: 1
			glyphs:    [u16(0)]
			positions: [f32(0), 0]
		}
		cpuraster.fill_canvas_glyphs(mut premultiplied, c.width, c.height, c.pitch, c.alpha_type,
			empty, [f32(1), 0, 0, 1, 0, 0]!, 0, none, 1, .src_over, [], none)
	}
	return false, expected != premultiplied
}

// Glyph runs as fillText() shapes them: a baseline of advancing glyphs with
// fractional positions (every quarter-pixel phase), occasionally scattered
// or repeated glyphs and vertical offsets; sizes from tiny to the 256-pixel
// mask limit and past it; identity, translated, scaled, flipped, rotated and
// skewed canvas transforms; solid colors, gradients and patterns, every
// composite operation, global alpha and clips.
fn check_glyph_draws(oracle Oracle, glyphs OracleCanvasGlyphs, repo string, count int) !(int, int, int) {
	fonts := glyph_fonts(repo)
	limit := (os.getenv_opt('CPU_RASTER_GLYPH_LIMIT') or { '120' }).int()
	if limit <= 0 || limit > 65535 { return error('Invalid CPU_RASTER_GLYPH_LIMIT') }
	mut declined := 0
	mut drawn := 0
	mut paths := 0
	for i in 0 .. count {
		width := rand.intn(120) or { 0 } + 1
		height := rand.intn(90) or { 0 } + 1
		pitch := width * 4 + 4 * (rand.intn(3) or { 0 })
		alpha_type := if rand.intn(2) or { 0 } == 0 { 1 } else { 2 }
		composite := if rand.intn(3) or { 0 } == 0 { rand.intn(28) or { 0 } } else { 0 }
		clips := if rand.intn(5) or { 0 } == 0 { random_clips(width, height) } else { []ClipCase{} }
		initial := random_composite_bitmap(width, height, pitch, alpha_type)
		font_size := match rand.intn(12) or { 0 } {
			0 { f32(rand.f64() * 4) }
			1 { f32(rand.intn(300) or { 0 } + 1) }
			2 { f32(int(rand.f64() * 48) + 1) }
			3 { f32(rand.f64() * 400 + 200) }
			else { f32(rand.f64() * 60 + 4) }
		}
		n := match rand.intn(6) or { 0 } {
			0 { 1 }
			1 { 0 }
			else { rand.intn(12) or { 0 } + 1 }
		}
		mut ids := []u16{}
		mut positions := []f32{}
		mut x := f32(rand.f64() * 4)
		for _ in 0 .. n {
			ids << u16(match rand.intn(10) or { 0 } {
				0 { 0 }
				1 { rand.intn(65536) or { 0 } }
				else { rand.intn(limit) or { 0 } + 1 }
			})
			y := if rand.intn(5) or { 0 } == 0 { f32(rand.f64() * 6 - 3) } else { f32(0) }
			positions << [x, y]
			x += match rand.intn(6) or { 0 } {
				0 { f32(0) }
				1 { f32(rand.f64() * 30 - 10) }
				2 { f32(rand.intn(4) or { 0 }) / 4 * font_size }
				else { font_size * f32(0.3 + rand.f64() * 0.5) }
			}
		}
		transform := match rand.intn(10) or { 0 } {
			0, 1, 2, 3 { [f32(1), 0, 0, 1, 0, 0]! }
			4 {
				s := f32(rand.f64() * 3 + 0.2)
				[s, 0, 0, s, f32(rand.f64() * 10 - 5), f32(rand.f64() * 10 - 5)]!
			}
			5 {
				[f32(rand.f64() * 2 - 1), 0, 0, f32(rand.f64() * 2 - 1), f32(rand.f64() * width), f32(rand.f64() * height)]!
			}
			6 {
				angle := rand.f64() * 6.3
				s := rand.f64() * 2 + 0.3
				[f32(math.cos(angle) * s), f32(math.sin(angle) * s), f32(-math.sin(angle) * s), f32(math.cos(angle) * s),
					f32(rand.f64() * width), f32(rand.f64() * height)]!
			}
			else {
				random_stroke_matrix()
			}
		}
		style := match rand.intn(8) or { 0 } {
			0 { ?cpuraster.CanvasPaintStyle(random_gradient(width, height)) }
			1 { ?cpuraster.CanvasPaintStyle(random_pattern(width, height)) }
			else { ?cpuraster.CanvasPaintStyle(none) }
		}
		c := GlyphCase{
			width:        width
			height:       height
			pitch:        pitch
			alpha_type:   alpha_type
			font_path:    fonts[rand.intn(fonts.len) or { 0 }]
			face_index:   if rand.intn(40) or { 0 } == 0 { 1 } else { 0 }
			font_size:    font_size
			glyphs:       ids
			positions:    positions
			translation:  [f32(rand.f64() * f64(width) - 4), f32(rand.f64() * f64(height) * 1.2)]!
			transform:    transform
			color:        random_composite_color()
			global_alpha: random_composite_alpha()
			clips:        clips
			composite:    composite
			style:        style
		}
		was_declined, changed := compare_canvas_glyphs(glyphs, oracle, initial, c, 'glyph run ${i}')!
		if was_declined {
			declined++
		}
		if changed {
			drawn++
			// SkStrikeSpec::ShouldDrawAsPath(), approximately.
			t := c.transform
			x_axis := math.sqrt(f64(t[0]) * t[0] + f64(t[1]) * t[1]) * c.font_size
			y_axis := math.sqrt(f64(t[2]) * t[2] + f64(t[3]) * t[3]) * c.font_size
			if x_axis > 256 || y_axis > 256 {
				paths++
			}
		}
	}
	println('glyph runs that changed pixels as paths: about ${paths}')
	return count, declined, drawn
}

fn check_glyph_cases(oracle Oracle, count int) {
	library := C.dlopen(os.args[1].str, 2)
	glyphs := unsafe { OracleCanvasGlyphs(oracle_symbol(library, 'oracle_canvas_glyphs')) }
	repo := os.real_path(os.join_path(os.dir(@FILE), '..', '..'))
	runs, declined, drawn := check_glyph_draws(oracle, glyphs, repo, count) or {
		eprintln(err.msg())
		exit(1)
	}
	println('canvas glyph runs: ${runs - declined} exact (${drawn} changed pixels), ${declined} declined')
}

// send_filters() hands the oracle the next draw's canvas filters:
// make_filter()'s color matrices (kind 2) with their clamp flags and blurs
// (kind 0) with their radius.
fn send_filters(oracle Oracle, filters []cpuraster.CanvasFilterStep) {
	mut values := []i32{}
	mut floats := []f32{}
	for f in filters {
		if f.kind == .drop_shadow {
			values << [i32(1), 0, i32(f.color)]
			floats << [f.sigma, f.offset_x, f.offset_y]
			floats << []f32{len: 20}
		} else if f.kind == .blur {
			values << [i32(0), 0, 0]
			floats << [f.sigma, 0, 0]
			floats << []f32{len: 20}
		} else {
			values << [i32(2), i32(int(f.matrix.clamp)), 0]
			floats << [f32(0), 0, 0]
			floats << f.matrix.matrix[..]
		}
	}
	values << 0
	floats << 0
	oracle.filters(i32(filters.len), values.data, floats.data)
}

// The CSS filter functions as canvas_skia_filter() builds their matrices,
// with random amounts (sometimes out of range), and occasionally a random
// matrix: some move alpha off transparent black or are not finite.
fn random_color_matrix() cpuraster.MatrixColorFilter {
	a := match rand.intn(5) or { 0 } {
		0 { f32(0) }
		1 { f32(1) }
		2 { f32(rand.f64() * 3) }
		else { f32(rand.f64()) }
	}
	one := f32(1) - a
	return match rand.intn(10) or { 0 } {
		0 {
			radians := f32(f64(a) * 360 * math.pi / 180)
			c := f32(math.cos(radians))
			sn := f32(math.sin(radians))
			cpuraster.MatrixColorFilter{
				matrix: [f32(.213) + c * .787 - sn * .213, .715 - c * .715 - sn * .715, .072 - c * .072 +
					sn * .928, 0, 0, .213 - c * .213 + sn * .143, .715 + c * .285 + sn * .140, .072 - c * .072 - sn * .283,
					0, 0, .213 - c * .213 - sn * .787, .715 - c * .715 + sn * .715, .072 + c * .928 +
					sn * .072, 0, 0, 0, 0, 0, 1, 0]!
			}
		}
		1 {
			cpuraster.MatrixColorFilter{
				matrix: [a, f32(0), 0, 0, 0, 0, a, 0, 0, 0, 0, 0, a, 0, 0, 0, 0, 0, 1, 0]!
			}
		}
		2 {
			i := f32(-(.5 * a) + .5)
			cpuraster.MatrixColorFilter{
				matrix: [a, f32(0), 0, 0, i, 0, a, 0, 0, i, 0, 0, a, 0, i, 0, 0, 0, 1, 0]!
			}
		}
		3 {
			cpuraster.MatrixColorFilter{
				matrix: [f32(1) - 2 * a, 0, 0, 0, a, 0, 1 - 2 * a, 0, 0, a, 0, 0, 1 - 2 * a, 0, a, 0,
					0, 0, 1, 0]!
				clamp:  true
			}
		}
		4 {
			cpuraster.MatrixColorFilter{
				matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, a, 0]!
				clamp:  true
			}
		}
		5 {
			cpuraster.MatrixColorFilter{
				matrix: [f32(.2126) + .7874 * one, .7152 - .7152 * one, .0722 - .0722 * one, 0, 0,
					.2126 - .2126 * one, .7152 + .2848 * one, .0722 - .0722 * one, 0, 0, .2126 - .2126 * one,
					.7152 - .7152 * one, .0722 + .9278 * one, 0, 0, 0, 0, 0, 1, 0]!
				clamp:  true
			}
		}
		6 {
			cpuraster.MatrixColorFilter{
				matrix: [f32(.393) + .607 * one, .769 - .769 * one, .189 - .189 * one, 0, 0, .349 - .349 * one,
					.686 + .314 * one, .168 - .168 * one, 0, 0, .272 - .272 * one, .534 - .534 * one,
					.131 + .869 * one, 0, 0, 0, 0, 0, 1, 0]!
				clamp:  true
			}
		}
		7 {
			cpuraster.MatrixColorFilter{
				matrix: [f32(.213) + .787 * a, .715 - .715 * a, .072 - .072 * a, 0, 0, .213 - .213 * a,
					.715 + .285 * a, .072 - .072 * a, 0, 0, .213 - .213 * a, .715 - .715 * a, .072 +
					.928 * a, 0, 0, 0, 0, 0, 1, 0]!
			}
		}
		else {
			mut m := [20]f32{}
			for k in 0 .. 20 {
				m[k] = f32(rand.f64() * 2.4 - 1.2)
			}
			if rand.intn(3) or { 0 } != 0 {
				m[15], m[16], m[17], m[18], m[19] = 0, 0, 0, f32(rand.f64() * 1.5), 0
			}
			if rand.intn(30) or { 0 } == 0 {
				m[rand.intn(20) or { 0 }] = f32(math.inf(1))
			}
			cpuraster.MatrixColorFilter{
				matrix: m
				clamp:  rand.intn(2) or { 0 } == 0
			}
		}
	}
}

fn random_color_filters() []cpuraster.CanvasFilterStep {
	mut filters := []cpuraster.CanvasFilterStep{}
	for _ in 0 .. rand.intn(3) or { 0 } + 1 {
		filters << cpuraster.CanvasFilterStep{
			kind:   .matrix
			matrix: random_color_matrix()
		}
	}
	return filters
}

// A canvas blur(): its radius is the sigma, sometimes zero, tiny, large
// or invalid (which drops the list before it).
fn random_blur_step() cpuraster.CanvasFilterStep {
	sigma := match rand.intn(8) or { 0 } {
		0 { f32(0) }
		1 { f32(rand.f64() * 0.05) }
		2 { f32(rand.f64() * 40) }
		3 { f32(-1) }
		else { f32(rand.f64() * 6) }
	}
	return cpuraster.CanvasFilterStep{
		kind:  .blur
		sigma: sigma
	}
}

// Fills, strokes (hairlines, thin and wide) and glyph runs under canvas
// filter lists that reduce to color matrices: solid colors (filtered once,
// then legacy or pipeline blitters), gradients and patterns (filter stages
// after the shader), every composite operation and clips. Filters that
// change transparent black need an image filter layer and must decline.
fn check_color_filter_draws(oracle Oracle, glyphs OracleCanvasGlyphs, repo string, count int, make_filters fn () []cpuraster.CanvasFilterStep) !(int, int) {
	fonts := glyph_fonts(repo)
	mut declined := 0
	for i in 0 .. count {
		width := rand.intn(80) or { 0 } + 1
		height := rand.intn(80) or { 0 } + 1
		pitch := width * 4 + 4 * (rand.intn(3) or { 0 })
		alpha_type := if rand.intn(2) or { 0 } == 0 { 1 } else { 2 }
		composite := if rand.intn(2) or { 0 } == 0 { rand.intn(28) or { 0 } } else { 0 }
		clips := if rand.intn(5) or { 0 } == 0 { random_clips(width, height) } else { []ClipCase{} }
		initial := random_composite_bitmap(width, height, pitch, alpha_type)
		style := match rand.intn(6) or { 0 } {
			0 { ?cpuraster.CanvasPaintStyle(random_gradient(width, height)) }
			1 { ?cpuraster.CanvasPaintStyle(random_pattern(width, height)) }
			else { ?cpuraster.CanvasPaintStyle(none) }
		}
		filters := make_filters()
		color := random_composite_color()
		global_alpha := random_composite_alpha()
		transform := match rand.intn(4) or { 0 } {
			0 {
				[f32(1), 0, 0, 1, 0, 0]!
			}
			1 {
				[f32(rand.f64() * 2 + 0.25), 0, 0, f32(rand.f64() * 2 + 0.25), f32(rand.f64() * 20 - 10),
					f32(rand.f64() * 20 - 10)]!
			}
			2 {
				[f32(1), 0, 0, 1, f32(rand.intn(21) or { 0 } - 10), f32(rand.intn(21) or { 0 } - 10)]!
			}
			else {
				random_stroke_matrix()
			}
		}
		match rand.intn(3) or { 0 } {
			0 {
				if compare_canvas_fill_or_decline(oracle, initial, FillCase{width, height, pitch, alpha_type, random_canvas_segments(width, height), rand.intn(2) or {
					0
				} == 0, transform, color, global_alpha, clips, composite, 0, style, filters},
					'filtered fill ${i}')!
				{
					declined++
				}
			}
			1 {
				c := StrokeCase{
					width:        width
					height:       height
					pitch:        pitch
					alpha_type:   alpha_type
					segments:     random_canvas_segments(width, height)
					transform:    transform
					color:        color
					global_alpha: global_alpha
					line_width:   match rand.intn(3) or { 0 } {
						0 { f32(1) }
						1 { f32(rand.f64()) }
						else { random_wide_line_width() }
					}
					miter:        10
					cap:          rand.intn(3) or { 0 }
					join:         rand.intn(3) or { 0 }
					clips:        clips
					composite:    composite
					style:        style
					filters:      filters
				}
				if compare_canvas_stroke_or_decline(oracle, initial, c, 'filtered stroke ${i}')! {
					declined++
				}
			}
			else {
				size := if rand.intn(8) or { 0 } == 0 { f32(rand.f64() * 400 + 200) } else { f32(rand.f64() * 40 + 6) }
				mut ids := []u16{}
				mut positions := []f32{}
				for k in 0 .. rand.intn(6) or { 0 } + 1 {
					ids << u16(rand.intn(120) or { 0 } + 1)
					positions << [f32(k) * size * 0.6 + f32(rand.f64()), 0]
				}
				c := GlyphCase{
					width:        width
					height:       height
					pitch:        pitch
					alpha_type:   alpha_type
					font_path:    fonts[rand.intn(fonts.len) or { 0 }]
					font_size:    size
					glyphs:       ids
					positions:    positions
					translation:  [f32(rand.f64() * f64(width) - 4), f32(rand.f64() * f64(height) * 1.2)]!
					transform:    transform
					color:        color
					global_alpha: global_alpha
					clips:        clips
					composite:    composite
					style:        style
					filters:      filters
				}
				was_declined, _ := compare_canvas_glyphs(glyphs, oracle, initial, c, 'filtered glyph run ${i}')!
				if was_declined {
					declined++
				}
			}
		}
	}
	return count, declined
}

fn check_color_filter_cases(oracle Oracle, count int) {
	library := C.dlopen(os.args[1].str, 2)
	glyphs := unsafe { OracleCanvasGlyphs(oracle_symbol(library, 'oracle_canvas_glyphs')) }
	repo := os.real_path(os.join_path(os.dir(@FILE), '..', '..'))
	draws, declined := check_color_filter_draws(oracle, glyphs, repo, count, random_color_filters) or {
		eprintln(err.msg())
		exit(1)
	}
	println('color-filtered canvas draws: ${draws - declined} exact, ${declined} declined')
}

// Blur filter lists: a lone blur (which draws through an image filter
// layer), occasionally after or before color matrices or an invalid blur.
fn random_layer_filters() []cpuraster.CanvasFilterStep {
	return match rand.intn(8) or { 0 } {
		0 {
			mut f := random_color_filters()
			f << random_blur_step()
			f
		}
		1 {
			mut f := [random_blur_step()]
			f << random_color_filters()
			f
		}
		2 {
			[random_blur_step(), random_blur_step()]
		}
		else {
			[random_blur_step()]
		}
	}
}

fn check_filter_layer_cases(oracle Oracle, count int) {
	library := C.dlopen(os.args[1].str, 2)
	glyphs := unsafe { OracleCanvasGlyphs(oracle_symbol(library, 'oracle_canvas_glyphs')) }
	repo := os.real_path(os.join_path(os.dir(@FILE), '..', '..'))
	mixed := os.getenv('CPU_RASTER_CHECKS') == 'mixedshadows'
	shadows := mixed || os.getenv('CPU_RASTER_CHECKS') == 'dropshadows'
	make_filters := if os.getenv('CPU_RASTER_CHECKS') == 'mixedblurs' { random_color_blur_chain }
		else if mixed { random_color_shadow_filters }
		else if shadows { random_shadow_filters } else { random_layer_filters }
	draws, declined := check_color_filter_draws(oracle, glyphs, repo, count, make_filters) or {
		eprintln(err.msg())
		exit(1)
	}
	label := if shadows { 'drop-shadow' } else { 'blur' }
	println('${label}-filtered canvas draws: ${draws - declined} exact, ${declined} declined')
}

fn random_color_shadow_filters() []cpuraster.CanvasFilterStep {
	mut filters := random_color_filters()
	filters << random_shadow_filters()
	if rand.intn(2) or { 0 } == 0 { filters << random_color_filters() }
	return filters
}

fn random_color_blur_chain() []cpuraster.CanvasFilterStep {
	mut filters := []cpuraster.CanvasFilterStep{}
	for _ in 0 .. rand.intn(3) or { 0 } + 2 {
		if rand.intn(2) or { 0 } == 0 { filters << random_color_filters() }
		filters << random_blur_step()
	}
	if rand.intn(2) or { 0 } == 0 { filters << random_color_filters() }
	return filters
}

fn random_shadow_filters() []cpuraster.CanvasFilterStep {
	offset := fn () f32 {
		return if rand.intn(3) or { 0 } == 0 {
			f32(rand.f64() * 40 - 20)
		} else {
			f32(rand.intn(41) or { 0 } - 20)
		}
	}
	return [cpuraster.CanvasFilterStep{
		kind:     .drop_shadow
		sigma:    random_blur_step().sigma
		offset_x: offset()
		offset_y: offset()
		color:    random_composite_color()
	}]
}

type OracleImageBlur = fn (pixels &u8, values &i32, floats &f32, out &u8, info &i32)

// Image filter blurs through SkImages::MakeWithFilter(): random
// premultiplied images, subsets and clips (inside, overlapping and
// disjoint), and sigmas from effectively zero through the Gaussian pass
// and the three-box pass up to the raster algorithm's 135.
fn check_image_blurs(blur OracleImageBlur, count int) !(int, int) {
	mut empty := 0
	for i in 0 .. count {
		width := rand.intn(48) or { 0 } + 1
		height := rand.intn(48) or { 0 } + 1
		pixels := random_premultiplied(width * height)
		l := rand.intn(width) or { 0 }
		t := rand.intn(height) or { 0 }
		subset := [l, t, l + rand.intn(width - l) or { 0 } + 1, t + rand.intn(height - t) or { 0 } + 1]
		clip := if rand.intn(4) or { 0 } == 0 {
			cl := rand.intn(width + 40) or { 0 } - 20
			ct := rand.intn(height + 40) or { 0 } - 20
			[cl, ct, cl + rand.intn(width + 30) or { 0 }, ct + rand.intn(height + 30) or { 0 }]
		} else {
			// Around the subset, so the blurred edges show.
			[subset[0] - rand.intn(30) or { 0 }, subset[1] - rand.intn(30) or { 0 }, subset[2] + rand.intn(30) or {
				0
			}, subset[3] + rand.intn(30) or { 0 }]
		}
		sigma := fn () f32 {
			return match rand.intn(6) or { 0 } {
				0 { f32(rand.f64() * 0.05) }
				1, 2 { f32(rand.f64() * 2.2) }
				3 { f32(rand.f64() * 135) }
				4 { f32(0) }
				else { f32(rand.f64() * 12) }
			}
		}
		sx := sigma()
		sy := if rand.intn(3) or { 0 } == 0 { sx } else { sigma() }
		mut values := [i32(width), height]
		values << subset.map(i32(it))
		values << clip.map(i32(it))
		floats := [sx, sy]
		mut out := []u8{len: (clip[2] - clip[0] + 2) * (clip[3] - clip[1] + 2) * 4 + 16}
		mut info := []i32{len: 5}
		blur(pixels.data, values.data, floats.data, out.data, info.data)
		src := cpuraster.BlurImage{pixels, width, height}
		got, gx, gy := cpuraster.image_with_blur_filter(src, cpuraster.IRect{subset[0], subset[1], subset[2], subset[3]},
			cpuraster.IRect{clip[0], clip[1], clip[2], clip[3]}, sx, sy) or {
			if info[0] != 0 {
				return error('image blur ${i}: cpuraster has no result, Skia ${info} (sigma ${sx} ${sy}, subset ${subset}, clip ${clip}, ${width}x${height})')
			}
			empty++
			continue
		}
		if info[0] == 0 {
			return error('image blur ${i}: Skia has no result, cpuraster ${got.width}x${got.height} at ${gx},${gy}')
		}
		if got.width != info[1] || got.height != info[2] || gx != info[3] || gy != info[4] {
			return error('image blur ${i}: cpuraster ${got.width}x${got.height} at ${gx},${gy}, Skia ${info[1..]} (sigma ${sx} ${sy}, subset ${subset}, clip ${clip}, ${width}x${height})')
		}
		for j in 0 .. got.pixels.len {
			if got.pixels[j] != out[j] {
				return error('image blur ${i}: pixel ${j / 4} channel ${j % 4} is ${got.pixels[j]}, Skia wrote ${out[j]} (sigma ${sx} ${sy}, subset ${subset}, clip ${clip}, ${width}x${height})')
			}
		}
	}
	return count, empty
}

fn check_image_blur_cases(count int) {
	library := C.dlopen(os.args[1].str, 2)
	blur := unsafe { OracleImageBlur(oracle_symbol(library, 'oracle_image_blur')) }
	blurs, empty := check_image_blurs(blur, count) or {
		eprintln(err.msg())
		exit(1)
	}
	println('image filter blurs: ${blurs} exact (${empty} empty)')
}

type OracleRoundedRect = fn (&f32, &i32, &f32)
type OracleDifferenceClip = fn (&u8, &i32, &f32)

type OracleOuterShadow = fn (&u8, &i32, &f32) i32

fn random_shadow_rrect() []f32 {
	mut out := [f32(rand.f64() * 80 - 20), f32(rand.f64() * 80 - 20), f32(rand.f64() * 70), f32(rand.f64() * 70)]
	for _ in 0 .. 8 { out << f32(rand.f64() * 40) }
	match rand.intn(4) or { 0 } {
		0 { for i in 4 .. 12 { out[i] = 0 } }
		1 { for i in 4 .. 12 { out[i] = 5 } }
		2 { for i in 4 .. 12 { out[i] = 100 } }
		else {}
	}
	return out
}

fn shadow_rrect_from_values(f []f32) cpuraster.RoundedRect {
	return cpuraster.rounded_rect(cpuraster.Rect{f[0], f[1], f[0] + f[2], f[1] + f[3]},
		[f[4], f[5], f[6], f[7], f[8], f[9], f[10], f[11]]!)
}

fn check_portable_outer_shadow_cases(count int) {
	library := C.dlopen(os.args[1].str, 2)
	oracle := unsafe { OracleOuterShadow(oracle_symbol(library, 'oracle_outer_shadow')) }
	mut drawn := 0
	for trial in 0 .. count {
		w := rand.intn(80) or { 0 } + 1
		h := rand.intn(80) or { 0 } + 1
		outer := random_shadow_rrect()
		content := if trial % 2 == 0 { outer } else { random_shadow_rrect() }
		t := if trial % 3 == 0 { [f32(1), 0, 0, 1, 0, 0]! } else { random_stroke_matrix() }
		blur := match rand.intn(8) or { 0 } {
			0 { f32(0) }
			1 { f32(-1) }
			2 { f32(1e-5) }
			else { f32(rand.f64() * 20) }
		}
		color := random_composite_color()
		mut floats := outer.clone()
		floats << content
		floats << t[..]
		floats << blur
		mut clips := []cpuraster.Path{}
		clip_count := rand.intn(3) or { 0 }
		for _ in 0 .. clip_count {
			shape := random_shadow_rrect()
			ct := random_stroke_matrix()
			floats << shape
			floats << ct[..]
			clips << shadow_rrect_from_values(shape).clip_path(cpuraster.Matrix{ct[0], ct[1], ct[2], ct[3], ct[4], ct[5]})
		}
		values := [i32(w), h, i32(color), clip_count]
		mut expected := []u8{len: w*h*4}
		if oracle(expected.data, values.data, floats.data) == 0 { panic('native shadow failed') }
		if expected.any(it != 0) { drawn++ }
		actual := cpuraster.rasterize_outer_shadow(w, h, shadow_rrect_from_values(outer), shadow_rrect_from_values(content), t, color, blur, clips) or { panic('portable shadow declined at ${trial}') }
		if actual != expected {
			for i in 0 .. actual.len { if actual[i] != expected[i] {
				eprintln('outer shadow ${trial}: (${i % (w*4) / 4}, ${i / (w*4)}) channel ${i%4} ${actual[i]} != ${expected[i]}, values ${values}, floats ${floats}')
				break
			} }
			save_failure([]u8{len: actual.len}, expected, actual, '${values}, ${floats}')
			exit(1)
		}
	}
	println('${count} portable outer shadows exact (${drawn} painted)')
}

fn check_portable_inner_shadow_cases(count int) {
	library := C.dlopen(os.args[1].str, 2)
	oracle := unsafe { OracleOuterShadow(oracle_symbol(library, 'oracle_inner_shadow')) }
	path_oracle := unsafe { OracleRoundedRect(oracle_symbol(library, 'oracle_inner_shadow_path')) }
	rounded := os.getenv('CPU_RASTER_CHECKS') == 'rounded-inner-shadows'
	mut painted := 0
	for trial in 0 .. count {
		w := rand.intn(80) or { 0 } + 1
		h := rand.intn(80) or { 0 } + 1
		mut inner := random_shadow_rrect()
		mut pad := f32(rand.f64()*20 + 1)
		if rounded && trial % 2 == 0 {
			// Exact integer/half-pixel centers exercise concentric insets
			// whose bounding-box corners lie outside the outer ellipse.
			for i in 0 .. 4 { inner[i] = f32(int(inner[i])) }
			inner[2], inner[3] = math.max(inner[2], f32(4)), math.max(inner[3], f32(4))
			for i in 4 .. 12 {
				limit := inner[if i % 2 == 0 { 2 } else { 3 }] * f32(.5)
				inner[i] = math.min(limit, math.max(f32(1), f32(int(inner[i]))))
			}
			pad = f32(int(pad))
		}
		mut outer := [inner[0] - pad, inner[1] - pad, inner[2] + pad*2, inner[3] + pad*2,
			f32(0), 0, 0, 0, 0, 0, 0, 0]
		if rounded {
			for i in 4 .. 12 {
				outer[i] = if trial % 2 == 0 { inner[i] + pad } else { pad * f32(rand.f64() * 3) }
			}
		}
		content := if trial % 2 == 0 { inner } else { random_shadow_rrect() }
		t := if trial % 3 == 0 { [f32(1), 0, 0, 1, 0, 0]! } else { random_stroke_matrix() }
		blur := if trial % 7 == 0 { f32(0) } else { f32(rand.f64()*20) }
		color := random_composite_color()
		mut floats := outer.clone()
		floats << inner
		floats << content
		floats << t[..]
		floats << blur
		values := [i32(w), h, i32(color)]
		mut expected := []u8{len: w*h*4}
		if oracle(expected.data, values.data, floats.data) == 0 { panic('native inner shadow failed') }
		if expected.any(it != 0) { painted++ }
		actual := cpuraster.rasterize_inner_shadow(w, h, shadow_rrect_from_values(outer),
			shadow_rrect_from_values(inner), shadow_rrect_from_values(content), t, color, blur, []) or { panic('inner shadow declined ${trial}') }
		if actual != expected {
			mut info := []i32{len: 67}
			mut out := []f32{len: 192}
			path_oracle(floats.data, info.data, out.data)
			eprintln('difference path: ${info[..3 + int(info[0])]}, ${out[..int(info[1])*2 + 4]}')
			for i in 0 .. actual.len { if actual[i] != expected[i] {
				eprintln('inner shadow ${trial}: (${i % (w*4) / 4}, ${i / (w*4)}) channel ${i%4} ${actual[i]} != ${expected[i]}, values ${values}, floats ${floats}')
				break
			} }
			save_failure([]u8{len: actual.len}, expected, actual, '${values}, ${floats}')
			exit(1)
		}
	}
	println('${count} portable inner shadows exact (${painted} painted)')
}

type OracleTextShadow = fn (pixels &u8, values &i32, floats &f32, font &char, glyphs &u16, positions &f32) i32

fn check_portable_text_shadow_cases(count int) {
	library := C.dlopen(os.args[1].str, 2)
	oracle := unsafe { OracleTextShadow(oracle_symbol(library, 'oracle_text_shadow')) }
	fonts := glyph_fonts(os.real_path(@VMODROOT))
	mut painted := 0
	for trial in 0 .. count {
		w := rand.intn(100) or { 0 } + 1
		h := rand.intn(90) or { 0 } + 1
		font := fonts[rand.intn(fonts.len) or { 0 }]
		size := if trial % 17 == 0 { f32(rand.f64()*400+200) } else { f32(rand.f64()*55+4) }
		n := rand.intn(6) or { 0 } + 1
		mut glyphs := []u16{}
		mut positions := []f32{}
		for i in 0 .. n { glyphs << u16(rand.intn(120) or { 0 }); positions << [f32(i)*size*f32(0.6), f32(rand.f64()*4)] }
		t := [if trial%3 == 0 { f32(1) } else { f32(rand.f64()*3 - 1) }, f32(0), 0,
			if trial%3 == 0 { f32(1) } else { f32(rand.f64()*3 - 1) },
			f32(rand.f64()*10-5), f32(rand.f64()*10-5)]!
		blur := match trial % 11 {
			0 { f32(0) }
			1 { f32(-1) }
			2 { f32(1e-5) }
			else { f32(rand.f64()*20) }
		}
		color := random_composite_color()
		translation := [f32(rand.f64()*w-20), f32(rand.f64()*h)]!
		mut floats := t[..].clone()
		floats << [blur, size, translation[0], translation[1]]
		smoothing := if only := os.getenv_opt('CPU_RASTER_TEXT_SMOOTHING') { only.int() } else { rand.intn(4) or { 0 } }
		mut clips := []cpuraster.Path{}
		clip_count := rand.intn(3) or { 0 }
		for _ in 0 .. clip_count {
			shape := random_shadow_rrect()
			ct := random_stroke_matrix()
			floats << shape
			floats << ct[..]
			clips << shadow_rrect_from_values(shape).clip_path(cpuraster.Matrix{ct[0], ct[1], ct[2], ct[3], ct[4], ct[5]})
		}
		values := [i32(w), h, i32(color), n, smoothing, 0, clip_count]
		mut expected := []u8{len: w*h*4}
		if oracle(expected.data, values.data, floats.data, font.str, glyphs.data, positions.data) == 0 { panic('native text shadow failed ${font}') }
		if expected.any(it != 0) { painted++ }
		run := cpuraster.CanvasGlyphRun{font_path: font, font_size: size, glyphs: glyphs, positions: positions, translation: translation, smoothing: smoothing}
		actual := cpuraster.rasterize_text_shadow(w, h, run, t, color, blur, clips) or { panic('text shadow declined ${trial} ${font}') }
		if actual != expected {
			for i in 0 .. actual.len { if actual[i] != expected[i] {
				eprintln('text shadow ${trial}: (${i % (w*4) / 4}, ${i / (w*4)}) channel ${i%4} ${actual[i]} != ${expected[i]}, ${font}, values ${values}, floats ${floats}, glyphs ${glyphs}, positions ${positions}')
				break
			} }
			save_failure([]u8{len: actual.len}, expected, actual, '${font}, ${values}, ${floats}, ${glyphs}, ${positions}')
			exit(1)
		}
	}
	println('${count} portable text shadows exact (${painted} painted)')
}

fn check_rounded_rect_cases(count int) {
	library := C.dlopen(os.args[1].str, 2)
	oracle := unsafe { OracleRoundedRect(oracle_symbol(library, 'oracle_rounded_rect')) }
	difference := unsafe { OracleDifferenceClip(oracle_symbol(library, 'oracle_difference_clip')) }
	for trial in 0 .. count {
		mut paths := []cpuraster.Path{}
		mut floats := []f32{}
		for _ in 0 .. 2 {
			mut f := []f32{}
			for _ in 0 .. 4 { f << f32(rand.f64() * 80 - 20) }
			for _ in 0 .. 8 { f << f32(rand.f64() * 80 - 10) }
			if trial % 5 == 0 { for i in 4 .. 12 { f[i] = 0 } }
			if trial % 5 == 1 { for i in 4 .. 12 { f[i] = 5 } }
			if trial % 11 == 0 { f[4] = 1e20 }
			if trial % 13 == 0 { for i in 4 .. 12 { f[i] = 100 } }
			mut info := []i32{len: 35}
			mut out := []f32{len: 96}
			oracle(f.data, info.data, out.data)
			r := cpuraster.rounded_rect(cpuraster.Rect{f[0], f[1], f[2], f[3]}, [f[4], f[5], f[6], f[7], f[8], f[9], f[10], f[11]]!)
			p := r.path()
			mut actual := [r.bounds.left, r.bounds.top, r.bounds.right, r.bounds.bottom]
			actual << r.radii[..]
			for point in p.points { actual << [point.x, point.y] }
			actual << p.weights
			if info[0] != p.verbs.len || info[1] != p.points.len || info[2] != p.weights.len
				|| p.verbs.map(int(it)) != info[3..3 + p.verbs.len].map(int(it)) || actual != out[..actual.len] {
				eprintln('rounded rect ${trial}: ${f}\nexpected ${info}, ${out[..12 + int(info[1])*2 + int(info[2])]}\nactual ${p}, normalized ${actual}')
				exit(1)
			}
			t := if trial % 2 == 0 { random_stroke_matrix() } else { [f32(1), 0, 0, 1, 0, 0]! }
			paths << r.clip_path(cpuraster.Matrix{t[0], t[1], t[2], t[3], t[4], t[5]})
			floats << f
			floats << t[..]
		}
		mut expected := []u8{len: 48*40*4}
		values := [i32(48), 40]
		difference(expected.data, values.data, floats.data)
		mut actual := []u8{len: expected.len}
		mut clip := cpuraster.canvas_raster_clip(48, 40, [paths[0]])
		clip.subtract_path(paths[1])
		cpuraster.fill_clipped_color(mut actual, 48, 40, 192, 0xffffffff, clip)
		if actual != expected {
			for j in 0 .. actual.len { if actual[j] != expected[j] {
				eprintln('difference clip ${trial}: (${j % 192 / 4}, ${j / 192}) actual ${actual[j]}, expected ${expected[j]}: ${floats}')
				break
			} }
			save_failure([]u8{len: actual.len}, expected, actual, '${floats}')
			exit(1)
		}
	}
	println('${count} normalized rounded rectangles and difference clips exact')
}

type OracleMipmap = fn (source &u8, destination &u8, values &i32)

fn check_mipmap_cases(count int) {
	library := C.dlopen(os.args[1].str, 2)
	oracle := unsafe { OracleMipmap(oracle_symbol(library, 'oracle_mipmap')) }
	for trial in 0 .. count {
		mut w := rand.intn(65) or { 0 } + 1
		h := rand.intn(65) or { 0 } + 1
		if w == 1 && h == 1 { w = 2 }
		pitch := w*4 + 4*(rand.intn(3) or { 0 })
		source := random_composite_bitmap(w, h, pitch, 2)
		mut levels := 0
		for n := math.max(w,h); n > 1; n >>= 1 { levels++ }
		level := (rand.intn(levels) or { 0 }) + 1
		bitmap := cpuraster.CanvasBitmap{pixels: source, width: w, height: h, pitch: pitch, premultiplied: true}
		actual := cpuraster.build_image_mipmap(bitmap, level) or { panic('mipmap declined') }
		mut expected := []u8{len: actual.width*actual.height*4}
		values := [i32(w), h, pitch, actual.width, actual.height]
		oracle(source.data, expected.data, values.data)
		if actual.pixels != expected {
			for i in 0 .. expected.len { if actual.pixels[i] != expected[i] {
				eprintln('mipmap ${trial}: ${w}x${h}, level ${level}, byte ${i} = ${actual.pixels[i]}, expected ${expected[i]}')
				break
			} }
			exit(1)
		}
	}
	println('${count} raster mipmap levels exact')
}

type OraclePathGeometry = fn (&f32, &i32, &u8, &f32, &f32, &i32)

fn check_path_geometry(count int) {
	library := C.dlopen(os.args[1].str, 2)
	oracle := unsafe { OraclePathGeometry(oracle_symbol(library, 'oracle_canvas_path_geometry')) }
	for trial in 0 .. count {
		segments := random_canvas_segments(80, 60)
		path := cpuraster.canvas_path(segments, false)
		capacity := segments.len*8+64
		mut verbs := []u8{len: capacity}
		mut points := []f32{len: capacity*2}
		mut weights := []f32{len: capacity}
		mut info := [3]i32{}
		args := [i32(segments.len/12),0,i32(capacity)]
		oracle(segments.data,args.data,verbs.data,points.data,weights.data,&info[0])
		actual_verbs := path.verbs.map(u8(it))
		if actual_verbs != verbs[..info[0]] || path.points.len != info[1] || path.weights.len != info[2] {
			panic('path geometry ${trial}: structure ${actual_verbs} != ${verbs[..info[0]]}, points ${path.points.len} != ${info[1]}, weights ${path.weights.len} != ${info[2]}, segments ${segments}')
		}
		for i,p in path.points {
			if math.f32_bits(p.x) != math.f32_bits(points[i*2]) || math.f32_bits(p.y) != math.f32_bits(points[i*2+1]) {
				panic('path geometry ${trial}: point ${i} ${p} != (${points[i*2]},${points[i*2+1]}), segments ${segments}')
			}
		}
		for i,w in path.weights {
			if math.f32_bits(w) != math.f32_bits(weights[i]) {
				panic('path geometry ${trial}: weight ${i} ${w} != ${weights[i]}, segments ${segments}')
			}
		}
	}
	println('${count} canvas path geometries exact')
}
