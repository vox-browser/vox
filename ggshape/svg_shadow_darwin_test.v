// vtest build: macos
module ggshape

import gg.canvas
import stbi
import svg

fn svg_shadow_test_path() canvas.Path {
	s := $embed_file('@VMODROOT/Tests/Browser/Brave/input/verge-svg-filter-space.html').to_string()
	parsed := svg.parse_path_data(s.all_after('<path d="').all_before('"')).to_absolute()
	mut b := canvas.PathBuilder{}
	mut x, mut y := f32(0), f32(0)
	for instruction in parsed.instructions {
		d := instruction.data.map(f32(it))
		match instruction.type_ {
			.move {
				x, y = d[0], d[1]
				b.move_to(x, y)
			}
			.line {
				x, y = d[0], d[1]
				b.line_to(x, y)
			}
			.horizontal_line {
				x = d[0]
				b.line_to(x, y)
			}
			.vertical_line {
				y = d[0]
				b.line_to(x, y)
			}
			.curve {
				b.cubic_to(d[0], d[1], d[2], d[3], d[4], d[5])
				x, y = d[4], d[5]
			}
			.elliptical_arc {
				b.arc_to_svg(d[0], d[1], d[2], d[3] != 0, if d[4] != 0 {
					canvas.PathDirection.cw
				} else {
					.ccw
				}, d[5], d[6])
				x, y = d[5], d[6]
			}
			.close_path { b.close() }
			else { panic('unexpected path instruction') }
		}
	}
	return b.detach()
}

// Independent Brave samples exercise the blur, local RGBA merge and final
// rotation across source and raster-tile boundaries. Full PNG equality remains
// an end-to-end gate, including the separately reported residual pixels.
fn test_svg_shadow_local_filter_samples() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/verge-svg-filter-space.png').to_bytes()
	expected := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic(err) }
	defer { expected.free() }
	path := svg_shadow_test_path()
	for row in 0 .. 3 {
		oy := row * 254
		mut pixels := []u8{len: 1024 * 256 * 4, init: 255}
		for y in 0 .. 256 {
			for x in 222 .. 802 {
				if y + oy >= 204 && y + oy < 724 {
					i := (y * 1024 + x) * 4
					pixels[i], pixels[i + 1], pixels[i + 2] = 138, 118, 89
				}
			}
		}
		assert draw_svg_shadow_pixels(pixels.data, 1024, 256, 4096, 4, path,
			[f32(1.6828125), 0, .00546875, 0, 1.6828125, 0, 0, 0, 1]!,
			[f32(0), 1, 143.203125, -1, 0, f32(729.796875 - oy), 0, 0, 1]!,
			[f32(.00546875), 0, 519.994506835938, 117.796875]!, [f32(0), 35, 35, 1, 1, 1, .6]!) == 1
		for point in [[230, 250]!, [245, 250]!, [290, 250]!, [245, 350]!, [275, 350]!, [290, 450]!,
			[230, 550]!, [290, 550]!, [260, 650]!, [350, 650]!] {
			if point[1] < oy || point[1] >= oy + 256 { continue }
			i := ((point[1] - oy) * 1024 + point[0]) * 4
			j := (point[1] * 1024 + point[0]) * 4
			for channel in 0 .. 4 {
				reference := unsafe { expected.data[j + if channel < 3 { 2 - channel } else { 3 }] }
				assert pixels[i + channel] == reference, 'x=${point[0]} y=${point[1]} channel=${channel}'
			}
		}
	}
}

fn test_svg_shadow_declines_unsupported_transforms_without_changing_pixels() {
	path := svg_shadow_test_path()
	source := [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
	bounds := [f32(0), 0, 20, 10]!
	shadow := [f32(0), 1, 2, 1, 1, 1, .6]!
	for frame in [[f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!, [f32(0), 2, 0, -2, 0, 20, 0, 0, 1]!,
		[f32(0), 1, 0, -1, 0, 20, .1, 0, 1]!] {
		mut pixels := []u8{len: 32 * 32 * 4, init: 0xa5}
		assert draw_svg_shadow_pixels(pixels.data, 32, 32, 128, 4, path, source, frame, bounds, shadow) == 0
		assert pixels.all(it == 0xa5)
	}
}

fn test_svg_shadow_declines_overflowing_source_ink_without_changing_pixels() {
	mut builder := canvas.PathBuilder{}
	builder.move_to(-2, 0)
	builder.line_to(20, 0)
	builder.line_to(20, 10)
	builder.line_to(-2, 10)
	builder.close()
	mut pixels := []u8{len: 32 * 32 * 4, init: 0xa5}
	assert draw_svg_shadow_pixels(pixels.data, 32, 32, 128, 4, builder.detach(),
		[f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!, [f32(0), 1, 0, -1, 0, 20, 0, 0, 1]!,
		[f32(0), 0, 20, 10]!, [f32(0), 1, 2, 1, 1, 1, .6]!) == 0
	assert pixels.all(it == 0xa5)
}

fn test_svg_shadow_local_source() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/verge-svg-shadow-source.png').to_bytes()
	expected := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic(err) }
	defer { expected.free() }
	mut ctx := context() or { panic(err) }
	mut surface := ctx.new_surface(width: 1024, height: 768) or { panic(err) }
	defer { surface.free() }
	surface.clear(canvas.Color4f{1, 1, 1, 1})
	surface.set_matrix(canvas.Matrix.values([f32(1.6828125), 0, .00546875, 0, f32(1.6828125), 0,
		0, 0, 1]!))
	surface.draw_path(svg_shadow_test_path(), canvas.Paint{ color: canvas.Color4f{0, 0, 0, 1}, anti_alias: true }) or { panic(err) }
	mut pixels := []u8{len: 1024 * 768 * 4}
	surface.read_pixels(pixels.data, 4096) or { panic(err) }
	mut different, mut largest := 0, 0
	for i in 0 .. 1024 * 768 {
		if pixels[i * 4] != unsafe { expected.data[i * 4] } {
			different++
			d := int(pixels[i * 4]) - int(unsafe { expected.data[i * 4] })
			if d > largest { largest = d }
			if -d > largest { largest = -d }
		}
	}
	assert different == 0, 'source pixels=${different} maximum error=${largest}'
}
