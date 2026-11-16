module main

import ggshape
import math
import os

// A compositor picture snaps its origin in the presenting device's grid.
// A lower-density capture can therefore sample that picture between texels.
__global compositor_raster_phase = [2]f64{}

const compositor_phase_diagnostics = os.getenv('VOX_DIAGNOSTIC_COMPOSITOR_PHASE') == '1'

fn select_compositor_raster_phase(x f64, y f64, device_scale f64, capture_scale f64, enabled bool) {
	compositor_raster_phase = [2]f64{}
	if !enabled || device_scale <= capture_scale || capture_scale <= 0
		|| !math.is_finite(x) || !math.is_finite(y)
		|| !math.is_finite(device_scale) || !math.is_finite(capture_scale) {
		return
	}
	compositor_raster_phase = [
		(math.floor(x * device_scale) / device_scale - math.floor(x * capture_scale) / capture_scale) * capture_scale,
		(math.floor(y * device_scale) / device_scale - math.floor(y * capture_scale) / capture_scale) * capture_scale,
	]!
	for value in compositor_raster_phase {
		if !math.is_finite(value) || value <= -1 || value >= 1 {
			compositor_raster_phase = [2]f64{}
			return
		}
	}
	if compositor_phase_diagnostics && compositor_raster_phase != [f64(0), 0]! {
		eprintln('VOX_COMPOSITOR_PHASE_ORIGIN x=${x} y=${y} device=${device_scale} capture=${capture_scale} phase=${compositor_raster_phase}')
	}
}

// Disjoint SVG foregrounds and a uniform opaque backdrop are independent of
// the other leaves' coverage. Overlaps need a shared unresolved surface.
fn publish_compositor_svg_phase(pixels &u8, width int, height int, pitch int, source []u8, precise []f64) bool {
	phase := compositor_raster_phase
	source_width := width + 2
	x0 := int(math.floor(1 - phase[0]))
	y0 := int(math.floor(1 - phase[1]))
	fx := 1 - phase[0] - x0
	fy := 1 - phase[1] - y0
	mut output := []u8{len: height * pitch}
	unsafe { vmemcpy(output.data, pixels, output.len) }
	mut backdrop := ?[4]u8(none)
	for y in 0 .. height {
		for x in 0 .. width {
			mut sample := [4]f64{}
			for k in 0 .. 4 {
				ia := ((y + y0) * source_width + x + x0) * 4 + k
				ib := ia + 4
				ic := ia + source_width * 4
				id := ic + 4
				a := if precise.len == source.len { precise[ia] } else { f64(source[ia]) }
				b := if precise.len == source.len { precise[ib] } else { f64(source[ib]) }
				c := if precise.len == source.len { precise[ic] } else { f64(source[ic]) }
				d := if precise.len == source.len { precise[id] } else { f64(source[id]) }
				sample[k] = (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
			}
			offset := y * pitch + x * 4
			if sample[3] == 0 { continue }
			background := unsafe {
				[pixels[offset], pixels[offset + 1], pixels[offset + 2], pixels[offset + 3]]!
			}
			if background[3] != 0 && background[3] != 255 { return false }
			if previous := backdrop {
				if previous != background { return false }
			} else {
				backdrop = background
			}
			for k in 0 .. 4 {
				output[offset + k] = u8(math.min(255, math.floor(sample[k] +
					f64(background[k]) * (1 - sample[3] / 255) + 0.5)))
			}
		}
	}
	unsafe { vmemcpy(pixels, output.data, output.len) }
	if compositor_phase_diagnostics {
		eprintln('VOX_COMPOSITOR_SVG_PHASE x=${phase[0]} y=${phase[1]} width=${width} height=${height} precise=${precise.len == source.len}')
	}
	return true
}

// An opaque solid curve's four MSAA samples carry an integer coverage count.
// The BGRA8 resolve encodes those five counts as 0/64/128/191/255. Recover them
// only when every channel agrees with the original paint and sample count.
// Interpolate that coverage before the final byte conversion: interpolating
// already rounded alpha bytes would turn 5/8 coverage into 160 instead of 159.
// Clipped, gradient, translucent and overlapping-path sources keep byte data.
fn compositor_msaa_coverage(source []u8, path &C.VoxGraphitePath) []f64 {
	if path.gradient != 0 || path.stroke != 0 || path.has_clip != 0 || path.has_ancestor_clip != 0 {
		return []f64{}
	}
	mut curved := false
	for i in 0 .. int(path.segment_count) {
		kind := unsafe { int(path.segments[i * 12]) }
		if kind == 6 { return []f64{} }
		if kind in [2, 3, 4] { curved = true }
	}
	if !curved { return []f64{} }
	mut color := [f64(path.blue) / 255, f64(path.green) / 255, f64(path.red) / 255,
		f64(path.alpha) / 255]!
	if path.has_float_color != 0 {
		color = [f64(path.float_color[2]), f64(path.float_color[1]), f64(path.float_color[0]),
			f64(path.float_color[3])]!
	}
	if path.has_float_alpha != 0 { color[3] = f64(path.opacity) }
	if color[3] != 1 { return []f64{} }
	for value in color {
		if !math.is_finite(value) || value < 0 || value > 1 { return []f64{} }
	}
	mut result := []f64{len: source.len}
	for pixel in 0 .. source.len / 4 {
		count := match source[pixel * 4 + 3] {
			0 { 0 }
			64 { 1 }
			128 { 2 }
			191 { 3 }
			255 { 4 }
			else { return []f64{} }
		}
		for channel in 0 .. 4 {
			value := color[channel] * f64(count) * 255 / 4
			if u8(math.floor(value + 0.5)) != source[pixel * 4 + channel] { return []f64{} }
			result[pixel * 4 + channel] = value
		}
	}
	return result
}

fn draw_compositor_phase_path(pixels &u8, width i32, height i32, pitch i32, path &C.VoxGraphitePath) bool {
	phase := compositor_raster_phase
	if phase == [f64(0), 0]! || !compositor_phase_translation(path.matrix) { return false }
	mut source := []u8{len: (int(width) + 2) * (int(height) + 2) * 4}
	mut draw := *path
	draw.matrix[2] += f32(1 - phase[0])
	draw.matrix[5] += f32(1 - phase[1])
	if ggshape.draw_multisampled_path(source.data, width + 2, height + 2, (width + 2) * 4, 0, &draw) == 0 {
		return false
	}
	return publish_compositor_svg_phase(pixels, int(width), int(height), int(pitch), source,
		compositor_msaa_coverage(source, path))
}

fn draw_compositor_phase_svg(pixels &u8, width i32, height i32, pitch i32,
	paths &C.VoxGraphitePath, count i32, parent &f32, viewport &f32, clip &f32) bool {
	phase := compositor_raster_phase
	if phase == [f64(0), 0]! { return false }
	// A transformed compositor surface has a separate raster scale policy.
	// Keep the established path unless the combined device mapping translates.
	for i in 0 .. int(count) {
		path := unsafe { &paths[i] }
		mut combined := [9]f32{}
		for row in 0 .. 3 {
			for col in 0 .. 3 {
				for inner in 0 .. 3 {
					combined[row * 3 + col] += unsafe { parent[row * 3 + inner] } * path.matrix[inner * 3 + col]
				}
			}
		}
		if !compositor_phase_translation(combined) { return false }
	}
	mut source := []u8{len: (int(width) + 2) * (int(height) + 2) * 4}
	mut matrix := [9]f32{}
	for i in 0 .. 9 { matrix[i] = unsafe { parent[i] } }
	matrix[2] += f32(1 - phase[0])
	matrix[5] += f32(1 - phase[1])
	if ggshape.draw_svg_image(source.data, width + 2, height + 2, (width + 2) * 4, 2 | 4,
		paths, count, &matrix[0], viewport, clip) == 0 {
		return false
	}
	precise := if count == 1 { compositor_msaa_coverage(source, paths) } else { []f64{} }
	return publish_compositor_svg_phase(pixels, int(width), int(height), int(pitch), source, precise)
}

fn compositor_phase_translation(matrix [9]f32) bool {
	return matrix[0] == 1 && matrix[1] == 0 && matrix[3] == 0 && matrix[4] == 1
		&& matrix[6] == 0 && matrix[7] == 0 && matrix[8] == 1
		&& math.is_finite(matrix[2]) && math.is_finite(matrix[5])
}
