// Draws the descriptors saved by graphite_shape_oracle.mm with ggshape.draw
// (the VOX_GG_SHAPES=1 adapter) and compares every byte with libVoxGraphite's
// output. Build from the repository root:
//   v -enable-globals -path "$PWD|@vlib|@vmodules" -o Build/gg-oracle/shape-bridge-check \
//     tools/gg_migration/shape_bridge_check.v
module main

import ggshape
import os

fn main() {
	if os.args.len != 2 {
		eprintln('usage: shape_bridge_check ORACLE_DIRECTORY')
		exit(2)
	}
	directory := os.args[1]
	mut names := os.ls(directory) or { panic(err) }
	names.sort()
	mut exact, mut declined, mut different := 0, 0, 0
	for file in names {
		if !file.ends_with('.shape.bin') {
			continue
		}
		name := file.all_before('.shape.bin')
		bytes := os.read_bytes(os.join_path(directory, file)) or { panic(err) }
		if bytes.len != int(sizeof(C.VoxGraphiteShape)) {
			panic('${file}: ${bytes.len} bytes, expected ${sizeof(C.VoxGraphiteShape)}')
		}
		mut shape := C.VoxGraphiteShape{
			clip_outs: unsafe { nil }
		}
		unsafe { vmemcpy(&shape, bytes.data, bytes.len) }
		// Replayed browser dumps carry their surface size and clip-outs.
		clips := os.read_bytes(os.join_path(directory, '${name}.clips.bin')) or { []u8{} }
		shape.clip_outs = if shape.clip_out_count > 0 && clips.len >= 16 * shape.clip_out_count {
			unsafe { &f32(clips.data) }
		} else {
			unsafe { nil }
		}
		mut pixels := os.read_bytes(os.join_path(directory, '${name}.backdrop.bgra')) or {
			panic(err)
		}
		expected := os.read_bytes(os.join_path(directory, '${name}.expected.bgra')) or {
			panic(err)
		}
		// The oracle's own surfaces are 64x48 with a tightly packed backdrop that
		// is transparent exactly when it has none.
		mut width, mut height := 64, 48
		mut has_background := if pixels.any(it != 0) { 1 } else { 0 }
		if args := os.read_file(os.join_path(directory, '${name}.args')) {
			fields := args.fields()
			width, height, has_background = fields[0].int(), fields[1].int(), fields[3].int()
		}
		if pixels.len != width * height * 4 || expected.len != pixels.len {
			panic('${name}: unexpected image size')
		}
		if ggshape.draw(pixels.data, width, height, width * 4, has_background, &shape) == 0 {
			declined++
			println('${name}: declined')
		} else if pixels == expected {
			exact++
			println('${name}: exact')
		} else {
			different++
			mut count := 0
			for i in 0 .. pixels.len / 4 {
				if pixels[i * 4..i * 4 + 4] != expected[i * 4..i * 4 + 4] {
					count++
				}
			}
			println('${name}: ${count} pixels differ')
		}
	}
	println('exact ${exact}, declined ${declined}, different ${different}')
	if different > 0 {
		exit(1)
	}
}
