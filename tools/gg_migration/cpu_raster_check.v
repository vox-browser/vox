// Compares the Skia-free cpuraster module with the original LibWeb Skia calls
// in skia_cpu_oracle.cpp, byte for byte.
module main

import cpuraster
import os
import rand

fn C.dlopen(path &char, mode int) voidptr
fn C.dlsym(handle voidptr, symbol &char) voidptr

type OracleReadPixels = fn (source &u8, destination &u8, values &i32) i32

struct Oracle {
	read_pixels OracleReadPixels = unsafe { nil }
}

fn load_oracle(path string) Oracle {
	library := C.dlopen(path.str, 2)
	if library == unsafe { nil } {
		panic('could not load the Skia CPU oracle ${path}')
	}
	return Oracle{
		read_pixels: unsafe { OracleReadPixels(oracle_symbol(library, 'oracle_read_pixels')) }
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
	row_bytes := if read.destination_pitch > columns * 4 { read.destination_pitch } else { columns * 4 }
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

fn main() {
	if os.args.len < 2 {
		eprintln('usage: cpu_raster_check SKIA_CPU_ORACLE [COUNT]')
		exit(2)
	}
	oracle := load_oracle(os.args[1])
	count := if os.args.len > 2 { os.args[2].int() } else { 20000 }
	rand.seed([u32(20261106), 7])
	exhaustive := check_read_pixels_exhaustive(oracle) or {
		eprintln(err.msg())
		exit(1)
	}
	random := check_read_pixels_random(oracle, count) or {
		eprintln(err.msg())
		exit(1)
	}
	println('read_pixels: ${exhaustive} exhaustive and ${random} random comparisons exact')
}
