// vtest build: macos
module ggshape

import math
import stbi
import platform

fn C.tanf(f32) f32

// The unchanged Brave scene supplies the reference. Match its recorded snapped
// parent clip and compositor tile origins; inspect fully covered interior pixels.
fn test_rectangular_gradient_clip_keeps_brave_destination_geometry() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/diagnostic/large-orbit-underlay.png').to_bytes()
	ref := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4)!
	assert ref.width == 1024 && ref.height == 768
	defer { ref.free() }
	w, h := f32(958), f32(390)
	radians := (f32(90) - f32(130)) * (f32(math.pi) / f32(180))
	slope := C.tanf(radians)
	perpendicular := f32(-1) / slope
	projected := perpendicular * (w / 2)
	intercept := -h / 2 - projected
	ex := intercept / (slope - perpendicular)
	ey0 := perpendicular * ex
	ey := ey0 + intercept
	linear_stops := [f32(18) / 255, f32(27) / 255, f32(40) / 255, 1, 0, f32(16) / 255, f32(21) / 255,
		f32(30) / 255, 1, .55, f32(23) / 255, f32(34) / 255, f32(51) / 255, 1, 1]
	radial_stops := [f32(67) / 255, f32(105) / 255, f32(149) / 255, f32(87) / 255, 0, f32(67) / 255,
		f32(105) / 255, f32(149) / 255, 0, .65]
	cx, cy := f32(.6) * w, f32(1.1) * h
	aspect := cx / cy
	ys := cy * cy
	ya := ys * aspect
	yaa := ya * aspect
	xs := cx * cx
	rx := f32(math.sqrt(f64(xs + yaa)))
	ry := rx / aspect
	sy := f32(1) / (rx / ry)
	projected_y := cy * sy
	for origin in [384, 638] {
		mut segments := []f32{}
		for entry in [[f32(0), 33, 451]!, [f32(1), 991, 451]!, [f32(1), 991, 841]!, [f32(1), 33,
			841]!, [f32(5), 0, 0]!] {
			segments << entry[..]
			for _ in 0 .. 9 { segments << f32(0) }
		}
		linear := C.VoxGraphitePath{
			matrix:            [f32(1), 0, 0, 0, 1, -f32(origin), 0, 0, 1]!
			segments:          segments.data
			segment_count:     5
			gradient:          1
			gradient_premul:   1
			has_clip:          1
			clip:              [f32(33), 451, 958, 390, 0, 0, 0, 0, 0, 0, 0, 0]!
			has_ancestor_clip: 1
			ancestor_clip:     [f32(33), 451, 958, 3067, 12, 12, 12, 12, 0, 0, 0, 0]!
			gradient_points:   [w / 2 - ex, h / 2 + ey, w / 2 + ex, h / 2 - ey, f32(0), 0]!
			gradient_matrix:   [f32(1), 0, 33, 0, 1, 451, 0, 0, 1]!
			stops:             linear_stops.data
			stop_count:        3
			opacity:           1
		}
		radial := C.VoxGraphitePath{
			...linear
			gradient:        2
			gradient_points: [cx, cy, f32(0), cx, cy, rx]!
			gradient_matrix: [f32(1), 0, 33, 0, sy, f32(451) + (cy - projected_y), 0, 0, 1]!
			stops:           radial_stops.data
			stop_count:      2
		}
		mut pixels := []u8{len: 1024 * 256 * 4}
		for i in 0 .. 1024 * 256 {
			pixels[i * 4] = 34
			pixels[i * 4 + 1] = 23
			pixels[i * 4 + 2] = 16
			pixels[i * 4 + 3] = 255
		}
		identity := [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
		viewport := [f32(0), 0, 1024, 256]!
		for path in [linear, radial] {
			draw := css_gradient_without_redundant_rect_clip(&path)
			assert draw.has_clip == 0
			assert draw_svg_image(pixels.data, 1024, 256, 4096, 7, &draw, 1, &identity[0], &viewport[0], unsafe { nil }) == 1
		}
		mut count := 0
		for y in 1 .. if origin == 384 { 255 } else { 130 } {
			if y + origin < 470 || y + origin >= 768 { continue }
			for x in 46 .. 978 {
				i := (y * 1024 + x) * 4
				j := ((y + origin) * 1024 + x) * 4
				if pixels[i] != unsafe { ref.data[j + 2] } || pixels[i + 1] != unsafe { ref.data[j + 1] } || pixels[i + 2] != unsafe { ref.data[j] } {
					count++
				}
			}
		}
		assert count == 0, 'origin=${origin} differing pixels=${count}'
	}
}

fn test_gradient_clip_elision_requires_the_same_closed_rectangular_fill() {
	mut points := []f32{len: 60}
	corners := [[f32(33), 451]!, [f32(991), 451]!, [f32(991), 841]!, [f32(33), 841]!]
	for i, corner in corners {
		points[i * 12] = if i == 0 { f32(0) } else { f32(1) }
		points[i * 12 + 1], points[i * 12 + 2] = corner[0], corner[1]
	}
	points[48] = 5
	base := C.VoxGraphitePath{
		gradient:      1
		has_clip:      1
		segments:      points.data
		segment_count: 5
		clip:          [f32(33), 451, 958, 390, 0, 0, 0, 0, 0, 0, 0, 0]!
	}
	assert gradient_rect_clip_is_redundant(&base)
	assert gradient_rect_clip_is_redundant(&C.VoxGraphitePath{ ...base, gradient: 2 })
	for path in [C.VoxGraphitePath{ ...base, gradient: 0 }, C.VoxGraphitePath{ ...base, stroke: 1 },
		C.VoxGraphitePath{ ...base, has_clip: 0 }, C.VoxGraphitePath{ ...base, segment_count: 4 },
		C.VoxGraphitePath{ ...base, segment_count: 6 },
		C.VoxGraphitePath{ ...base, segments: unsafe { nil } }] {
		assert !gradient_rect_clip_is_redundant(&path)
	}
	for index in 0 .. 12 {
		mut changed := base
		changed.clip[index] += .5
		assert !gradient_rect_clip_is_redundant(&changed)
	}
	for bad in [f32(math.nan()), f32(math.inf(1)), f32(math.inf(-1))] {
		mut changed := base
		changed.clip[0] = bad
		assert !gradient_rect_clip_is_redundant(&changed)
	}
	for index in [0, 1, 2, 12, 13, 14, 24, 25, 26, 36, 37, 38, 48] {
		mut changed_points := points.clone()
		changed_points[index] += .5
		changed := C.VoxGraphitePath{ ...base, segments: changed_points.data }
		assert !gradient_rect_clip_is_redundant(&changed)
	}
	for direction in [-1, 1] {
		for first in 0 .. 4 {
			mut reordered := points.clone()
			for i in 0 .. 4 {
				corner := corners[(first + direction * i + 4) % 4]
				reordered[i * 12 + 1], reordered[i * 12 + 2] = corner[0], corner[1]
			}
			changed := C.VoxGraphitePath{ ...base, segments: reordered.data }
			assert gradient_rect_clip_is_redundant(&changed)
			elided := css_gradient_without_redundant_rect_clip(&changed)
			assert elided.has_clip == 0
			assert voidptr(elided.segments) == voidptr(changed.segments)
			assert elided.clip == changed.clip
		}
	}
	for indices in [[0, 2, 1, 3], [0, 1, 0, 3]] {
		mut reordered := points.clone()
		for i, index in indices {
			reordered[i * 12 + 1], reordered[i * 12 + 2] = corners[index][0], corners[index][1]
		}
		changed := C.VoxGraphitePath{ ...base, segments: reordered.data }
		assert !gradient_rect_clip_is_redundant(&changed)
	}
	$if prealloc {
		mut arena := platform.new_arena('gradient clip proof')
		entry := arena.enter()
		before := arena.usage().used
		mut valid := true
		for _ in 0 .. 100 {
			elided := css_gradient_without_redundant_rect_clip(&base)
			valid = valid && elided.has_clip == 0
		}
		after := arena.usage().used
		arena.leave(entry)
		arena.release()
		assert valid
		assert after == before
	}
}
