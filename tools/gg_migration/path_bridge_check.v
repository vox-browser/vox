// Draws random VoxGraphitePath descriptors with libVoxGraphite's
// vox_graphite_draw_path_pixels() and with ggshape.draw_path (the
// VOX_GG_PATHS=1 adapter) and compares every byte. Build from the repository
// root:
//   v -memory-limit 10G -enable-globals -d vox_gg_canvas \
//     -path "$PWD|@vlib|@vmodules" -o Build/gg-oracle/path-bridge-check \
//     tools/gg_migration/path_bridge_check.v
// Usage: path-bridge-check LIBVOXGRAPHITE [COUNT [SEED]] [--gradients] [--svg]
// With --gradients most descriptors also get a linear or two-point conical
// gradient from a separate random stream (the paths stay the same). With --svg
// it draws SVG images instead: one to five descriptors after a parent matrix
// and inside a viewport, with vox_graphite_draw_svg_image_pixels() and
// ggshape.draw_svg_image, and the same images with
// vox_graphite_draw_svg_image_region_pixels() and the bridge's region wrapper.
module main

import ggshape
import math
import os
import rand
import rand.pcg32

fn C.dlopen(path &char, mode int) voidptr
fn C.dlsym(handle voidptr, symbol &char) voidptr

type DrawPathFn = fn (pixels &u8, width i32, height i32, pitch i32, has_background i32, path &C.VoxGraphitePath) i32

type DrawSvgImageFn = fn (pixels &u8, width i32, height i32, pitch i32, flags i32, paths &C.VoxGraphitePath, count i32, parent &f32, viewport &f32, rounded_clip &f32) i32

@[typedef]
struct C.VoxGraphitePixelRegion {
mut:
	x      i32
	y      i32
	width  i32
	height i32
	pitch  i32
	pixels &u8
}

type DrawSvgImageRegionFn = fn (region &C.VoxGraphitePixelRegion, width i32, height i32, flags i32, paths &C.VoxGraphitePath, count i32, parent &f32, viewport &f32, rounded_clip &f32) i32

const matrices = [
	[f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!,
	[f32(1), 0, 0.375, 0, 1, -0.625, 0, 0, 1]!,
	[f32(2), 0, 0.25, 0, 2, 0.5, 0, 0, 1]!,
	[f32(0.5), 0, 3, 0, 0.5, 2.25, 0, 0, 1]!,
	[f32(0.8660254), -0.5, 20, 0.5, 0.8660254, -6, 0, 0, 1]!,
	[f32(1), 0.3, 0, 0.1, 1, 0, 0, 0, 1]!,
]

fn backdrop(width int, height int, has_background bool) []u8 {
	mut pixels := []u8{len: width * height * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			i := (y * width + x) * 4
			alpha := if has_background { 128 + (x * 7 + y * 3) % 128 } else { 0 }
			pixels[i] = u8((x * 13) % (alpha + 1))
			pixels[i + 1] = u8((y * 29) % (alpha + 1))
			pixels[i + 2] = u8(((x + y) * 5) % (alpha + 1))
			pixels[i + 3] = u8(alpha)
		}
	}
	return pixels
}

struct Segments {
mut:
	data []f32
}

fn (mut s Segments) add(kind int, values []f32) {
	mut row := [f32(kind)]
	row << values
	for row.len < 12 {
		row << 0
	}
	s.data << row
}

fn (s Segments) count() int {
	return s.data.len / 12
}

fn random_segments(mut rng rand.PRNG, width int, height int) Segments {
	mut s := Segments{}
	cx := rng.f32_in_range(0, f32(width)) or { 0 }
	cy := rng.f32_in_range(0, f32(height)) or { 0 }
	size := if rng.u32() % 3 == 0 {
		rng.f32_in_range(2, 12) or { 2 }
	} else {
		rng.f32_in_range(10, f32(math.max(width, height))) or { 10 }
	}
	pt := fn [mut rng, cx, cy, size] () (f32, f32) {
		return rng.f32_in_range(cx - size, cx + size) or { cx }, rng.f32_in_range(cy - size,
			cy + size) or { cy }
	}
	match rng.u32() % 5 {
		0 {
			// A polygon, sometimes concave or self-intersecting.
			n := 3 + int(rng.u32() % 6)
			for i in 0 .. n {
				x, y := pt()
				s.add(if i == 0 { 0 } else { 1 }, [x, y])
			}
			s.add(5, [])
		}
		1 {
			// Curves and SVG arcs.
			x, y := pt()
			s.add(0, [x, y])
			for _ in 0 .. 1 + int(rng.u32() % 4) {
				ex, ey := pt()
				match rng.u32() % 4 {
					0 {
						s.add(1, [ex, ey])
					}
					1 {
						qx, qy := pt()
						s.add(2, [ex, ey, qx, qy])
					}
					2 {
						c1x, c1y := pt()
						c2x, c2y := pt()
						s.add(3, [ex, ey, c1x, c1y, c2x, c2y])
					}
					else {
						rx := rng.f32_in_range(0, size) or { 1 }
						ry := rng.f32_in_range(0, size) or { 1 }
						angle := rng.f32_in_range(-3.2, 3.2) or { 0 }
						s.add(4, [ex, ey, 0, 0, 0, 0, rx, ry, angle, f32(rng.u32() % 2),
							f32(rng.u32() % 2)])
					}
				}
			}
			if rng.u32() % 5 != 0 {
				s.add(5, [])
			}
		}
		2 {
			// Several closed contours (closing restarts at the last move).
			for _ in 0 .. 2 + int(rng.u32() % 2) {
				x, y := pt()
				s.add(0, [x, y])
				for _ in 0 .. 2 + int(rng.u32() % 3) {
					lx, ly := pt()
					s.add(1, [lx, ly])
				}
				s.add(5, [])
			}
		}
		3 {
			// An SVG circle or ellipse.
			l, t := pt()
			s.add(6, [l, t, l + (rng.f32_in_range(1, size) or { 1 }), t +
				(rng.f32_in_range(1, size) or { 1 })])
		}
		else {
			// A rectangle-shaped path.
			l, t := pt()
			r := l + (rng.f32_in_range(1, size) or { 1 })
			b := t + (rng.f32_in_range(1, size) or { 1 })
			s.add(0, [l, t])
			s.add(1, [r, t])
			s.add(1, [r, b])
			s.add(1, [l, b])
			s.add(5, [])
		}
	}
	return s
}

// random_gradient fills the descriptor's gradient fields like the bridge's
// SVG gradients and returns its stops (R G B A position per stop).
fn random_gradient(mut rng rand.PRNG, mut path C.VoxGraphitePath, width int, height int) []f32 {
	w, h := f32(width), f32(height)
	path.gradient = if rng.u32() % 5 < 3 { 1 } else { 2 }
	path.tile_mode = [i32(0), 0, 0, 0, 1, 2, 3][int(rng.u32() % 7)]
	path.gradient_premul = i32(rng.u32() % 2)
	path.linear_color_space = i32(rng.u32() % 25 == 0)
	path.opacity = if rng.u32() % 10 == 0 { f32(0.5) } else { f32(1) }
	if path.gradient == 1 {
		path.gradient_points = [rng.f32_in_range(-10, w + 10) or { 0 },
			rng.f32_in_range(-10, h + 10) or { 0 }, rng.f32_in_range(-10, w + 10) or { 0 },
			rng.f32_in_range(-10, h + 10) or { 0 }, 0, 0]!
	} else {
		cx := rng.f32_in_range(0, w) or { 0 }
		cy := rng.f32_in_range(0, h) or { 0 }
		r := rng.f32_in_range(1, w) or { 1 }
		path.gradient_points = if rng.u32() % 10 == 0 {
			[cx, cy, f32(2), cx + 3, cy, r]!
		} else {
			[cx, cy, f32(0), cx, cy, r]!
		}
	}
	path.gradient_matrix = [[f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!, [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!,
		[f32(2), 0, -3, 0, 0.5, 4, 0, 0, 1]!, [f32(0.8660254), -0.5, 10, 0.5, 0.8660254, -4, 0,
			0, 1]!][int(rng.u32() % 4)]
	count := [2, 2, 2, 3, 4, 5, 8, 10][int(rng.u32() % 8)]
	mode := rng.u32() % 4
	mut stops := []f32{}
	mut positions := []f32{len: count, init: rng.f32()}
	if mode == 0 {
		positions = []f32{len: count, init: f32(index) / f32(count - 1)}
	} else if mode != 3 {
		positions.sort()
		if mode == 1 {
			positions[0] = 0
			positions[count - 1] = 1
		}
	}
	translucent := rng.u32() % 4 == 0
	for position in positions {
		stops << [rng.f32(), rng.f32(), rng.f32(), if translucent { rng.f32() } else { f32(1) },
			position]
	}
	path.stop_count = i32(count)
	path.stops = unsafe { &f32(stops.data) }
	return stops
}

fn random_rrect(mut rng rand.PRNG, width int, height int) [12]f32 {
	x := rng.f32_in_range(-4, f32(width) * 0.6) or { 0 }
	y := rng.f32_in_range(-4, f32(height) * 0.6) or { 0 }
	w := rng.f32_in_range(4, f32(width)) or { 4 }
	h := rng.f32_in_range(4, f32(height)) or { 4 }
	r := rng.f32_in_range(0, f32(math.min(w, h)) / 2) or { 0 }
	return [x, y, w, h, r, r, r, r, r, r, r, r]!
}

// Descriptor keeps a random descriptor's segments and stops alive with it.
struct Descriptor {
	path     C.VoxGraphitePath
	segments Segments
	stops    []f32
}

// random_descriptor draws a descriptor's fields in a fixed order from `rng`
// (and its gradient from `gradient_rng`).
fn random_descriptor(mut rng rand.PRNG, mut gradient_rng rand.PRNG, gradients bool, width int, height int) Descriptor {
	segments := random_segments(mut rng, width, height)
	mut path := C.VoxGraphitePath{
		segments: unsafe { &f32(segments.data.data) }
		stops:    unsafe { nil }
	}
	path.segment_count = i32(segments.count())
	path.matrix = matrices[int(rng.u32() % u32(matrices.len))]
	path.even_odd = i32(rng.u32() % 3 == 0)
	path.red = u8(rng.u32())
	path.green = u8(rng.u32())
	path.blue = u8(rng.u32())
	path.alpha = [u8(255), 255, 128, 200][int(rng.u32() % 4)]
	if rng.u32() % 4 == 0 {
		path.has_float_color = 1
		path.float_color = [rng.f32(), rng.f32(), rng.f32(), [f32(1), 0.5, 0.25][int(rng.u32() % 3)]]!
	}
	if rng.u32() % 5 == 0 {
		path.has_float_alpha = 1
		path.opacity = rng.f32()
	}
	if rng.u32() % 2 == 0 {
		// Strokes of every join and cap, including hairlines.
		path.stroke = 1
		path.stroke_width = [f32(0), 1, 2.5, 6, rng.f32_in_range(0.5, 10) or { 1 }][int(rng.u32() % 5)]
		path.line_cap = i32(rng.u32() % 3)
		path.line_join = i32(rng.u32() % 3)
		path.miter_limit = [f32(4), 1, 1.5, 10][int(rng.u32() % 4)]
	}
	if rng.u32() % 4 == 0 {
		path.has_clip = 1
		path.clip = random_rrect(mut rng, width, height)
	}
	stops := if gradients && gradient_rng.u32() % 4 != 0 {
		random_gradient(mut gradient_rng, mut path, width, height)
	} else {
		[]f32{}
	}
	return Descriptor{path, segments, stops}
}

// svg_check compares SVG images drawn by libVoxGraphite and by gg.canvas.
fn svg_check(library voidptr, count int, mut rng rand.PRNG, mut gradient_rng rand.PRNG, gradients bool) {
	draw := DrawSvgImageFn(C.dlsym(library, c'vox_graphite_draw_svg_image_pixels'))
	draw_region := DrawSvgImageRegionFn(C.dlsym(library, c'vox_graphite_draw_svg_image_region_pixels'))
	mut exact, mut declined, mut different, mut failed := 0, 0, 0, 0
	for index in 0 .. count {
		width, height := if rng.u32() % 3 == 0 { 160, 120 } else { 64, 48 }
		flags := i32(rng.u32() % 4)
		mut descriptors := []Descriptor{}
		for _ in 0 .. 1 + int(rng.u32() % 5) {
			descriptors << random_descriptor(mut rng, mut gradient_rng, gradients, width, height)
		}
		paths := descriptors.map(it.path)
		parent := matrices[int(rng.u32() % u32(matrices.len))]
		viewport := [rng.f32_in_range(-4, f32(width) / 2) or { 0 },
			rng.f32_in_range(-4, f32(height) / 2) or { 0 }, rng.f32_in_range(8, f32(width)) or { 8 },
			rng.f32_in_range(8, f32(height)) or { 8 }]
		// A rounded clip needs a save layer, which gg.canvas declines.
		rounded := random_rrect(mut rng, width, height)
		rounded_clip := if rng.u32() % 8 == 0 {
			unsafe { &rounded[0] }
		} else {
			unsafe { &f32(nil) }
		}
		region_x := int(rng.u32() % u32(width / 2))
		region_y := int(rng.u32() % u32(height / 2))
		region_w := 1 + int(rng.u32() % u32(width - region_x))
		region_h := 1 + int(rng.u32() % u32(height - region_y))
		for region in [false, true] {
			mut expected := backdrop(if region { region_w } else { width }, if region {
				region_h
			} else {
				height
			}, flags & 1 != 0)
			mut actual := expected.clone()
			row := i32(if region { region_w } else { width } * 4)
			mut ok := 0
			mut gg := 0
			if region {
				mut view := C.VoxGraphitePixelRegion{i32(region_x), i32(region_y), i32(region_w), i32(region_h), row, expected.data}
				ok = draw_region(&view, i32(width), i32(height), flags, paths.data, i32(paths.len), &parent[0], &viewport[0], rounded_clip)
				// The bridge's gg_draw_svg_image_region_pixels(): a whole
				// surface holding the region's pixels as its backdrop.
				mut surface := []u8{len: width * height * 4}
				if flags & 1 != 0 {
					for y in 0 .. region_h {
						for x in 0 .. region_w * 4 {
							surface[((region_y + y) * width + region_x) * 4 + x] = actual[y * region_w * 4 + x]
						}
					}
				}
				gg = ggshape.draw_svg_image(surface.data, i32(width), i32(height), i32(width * 4), flags, paths.data, i32(paths.len), &parent[0], &viewport[0], rounded_clip)
				if gg != 0 {
					for y in 0 .. region_h {
						for x in 0 .. region_w * 4 {
							actual[y * region_w * 4 + x] = surface[((region_y + y) * width + region_x) * 4 + x]
						}
					}
				}
			} else {
				ok = draw(expected.data, i32(width), i32(height), row, flags, paths.data, i32(paths.len), &parent[0], &viewport[0], rounded_clip)
				gg = ggshape.draw_svg_image(actual.data, i32(width), i32(height), row, flags, paths.data, i32(paths.len), &parent[0], &viewport[0], rounded_clip)
			}
			name := 'svg-${index:04d}${if region { '-region' } else { '' }}'
			if ok == 0 {
				failed++
				println('${name}: original backend failed')
			} else if gg == 0 {
				declined++
				println('${name}: declined')
			} else if actual == expected {
				exact++
			} else {
				different++
				mut n := 0
				for i in 0 .. actual.len / 4 {
					if actual[i * 4..i * 4 + 4] != expected[i * 4..i * 4 + 4] {
						n++
					}
				}
				println('${name}: ${n} pixels differ')
			}
		}
		_ = descriptors
	}
	println('svg exact ${exact}, declined ${declined}, different ${different}, original failed ${failed}')
	if different > 0 {
		exit(1)
	}
}

fn main() {
	if os.args.len < 2 {
		eprintln('usage: path-bridge-check LIBVOXGRAPHITE [COUNT [SEED]]')
		exit(2)
	}
	library := C.dlopen(&char(os.args[1].str), 1)
	if library == unsafe { nil } {
		panic('cannot open ${os.args[1]}')
	}
	draw := DrawPathFn(C.dlsym(library, c'vox_graphite_draw_path_pixels'))
	count := if os.args.len > 2 { os.args[2].int() } else { 200 }
	seed := if os.args.len > 3 { u32(os.args[3].int()) } else { u32(20261105) }
	mut rng := &rand.PRNG(&pcg32.PCG32RNG{})
	rng.seed([seed, seed + 1, seed + 2, seed + 3])
	gradients := '--gradients' in os.args
	mut gradient_rng := &rand.PRNG(&pcg32.PCG32RNG{})
	gradient_rng.seed([seed + 7, seed + 8, seed + 9, seed + 10])
	if '--svg' in os.args {
		svg_check(library, count, mut rng, mut gradient_rng, gradients)
		return
	}
	mut exact, mut declined, mut different, mut failed := 0, 0, 0, 0
	mut gradient_exact := 0
	for index in 0 .. count {
		width, height := if rng.u32() % 3 == 0 { 160, 120 } else { 64, 48 }
		has_background := rng.u32() % 2 == 0
		d := random_descriptor(mut rng, mut gradient_rng, gradients, width, height)
		path := d.path
		mut expected := backdrop(width, height, has_background)
		mut actual := expected.clone()
		bg := i32(has_background)
		if draw(expected.data, i32(width), i32(height), i32(width * 4), bg, &path) == 0 {
			failed++
			println('path-${index:04d}: original backend failed')
			continue
		}
		if ggshape.draw_path(actual.data, i32(width), i32(height), i32(width * 4), bg, &path) == 0 {
			declined++
			println('path-${index:04d}: declined')
		} else if actual == expected {
			exact++
			if path.gradient != 0 {
				gradient_exact++
			}
		} else {
			different++
			mut n := 0
			for i in 0 .. actual.len / 4 {
				if actual[i * 4..i * 4 + 4] != expected[i * 4..i * 4 + 4] {
					n++
				}
			}
			println('path-${index:04d}: ${n} pixels differ')
		}
	}
	println('exact ${exact} (${gradient_exact} with gradients), declined ${declined}, different ${different}, original failed ${failed}')
	if different > 0 {
		exit(1)
	}
}
