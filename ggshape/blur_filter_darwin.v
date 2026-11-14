module ggshape

import gg.canvas
import math

#include "@DIR/blur_filter_darwin.m"

fn C.vox_shadow_filter_pass(&u8, i32, i32, &u8, i32, i32, &f32, &f32, i32, i32) i32
fn C.expf(f32) f32

struct ShadowMask {
	pixels []u8
	width  int
	height int
}

struct ShadowBounds {
	left   f32
	top    f32
	right  f32
	bottom f32
}

fn shadow_mask_pass(source ShadowMask, width int, height int, mapping [4]f32,
	pairs [56]f32, count int, direction int) !ShadowMask {
	if width <= 0 || height <= 0 || width > 16384 || height > 16384
		|| width * height > 16 * 1024 * 1024 {
		return error('Shadow filter exceeds bounded surface size')
	}
	mut output := []u8{len: width * height}
	if C.vox_shadow_filter_pass(source.pixels.data, i32(source.width), i32(source.height),
		output.data, i32(width), i32(height), &mapping[0], &pairs[0], i32(count), i32(direction)) == 0 {
		return error('Shadow filter GPU pass failed')
	}
	return ShadowMask{output, width, height}
}

// ShaderBlurAlgorithm's normalized Gaussian, packed into bilinear tap pairs.
// Preserve f32 arithmetic and the center/negative/positive tap ordering.
fn shadow_linear_kernel(sigma f32) ([56]f32, int) {
	radius := int(math.ceil(f64(f32(3) * sigma)))
	mut full := []f32{len: radius * 2 + 1}
	denominator := f32(1) / (f32(2) * sigma * sigma)
	mut total := f32(0)
	for i in 0 .. full.len {
		x := f32(i - radius)
		full[i] = C.expf(-(x * x * denominator))
		total += full[i]
	}
	scale := f32(1) / total
	for mut value in full { value *= scale }
	mut result := [56]f32{}
	half_size := radius + 1
	half_radius := half_size / 2
	mut low := half_radius - 1
	mut index := radius
	if radius % 2 != 0 {
		weight := full[index] * f32(0.5) + full[index + 1]
		offset := full[index + 1] / weight
		result[half_radius * 2] = offset
		result[half_radius * 2 + 1] = weight
		result[low * 2] = -offset
		result[low * 2 + 1] = weight
		index++
		low--
	} else {
		result[half_radius * 2 + 1] = full[index]
	}
	index++
	for high in half_radius + 1 .. half_size {
		weight := full[index] + full[index + 1]
		offset := full[index + 1] / weight + f32(index - radius)
		result[high * 2] = offset
		result[high * 2 + 1] = weight
		result[low * 2] = -offset
		result[low * 2 + 1] = weight
		index += 2
		low--
	}
	for i in half_size .. 28 { result[i * 2] = result[(half_size - 1) * 2] }
	for count in [4, 8, 12, 16, 20, 28] {
		if count >= half_size { return result, count }
	}
	return result, 28
}

// Small Gaussian kernels fit in one pass. Resolving each axis to A8 instead
// would introduce an intermediate quantization absent from Chromium's filter.
fn shadow_small_kernel(sigma f32, radius int) ([56]f32, int) {
	width := 2 * radius + 1
	mut kernel := [56]f32{}
	denominator := f32(1) / (f32(2) * sigma * sigma)
	mut total := f32(0)
	for x in 0 .. width {
		x_term := f32(x - radius) * f32(x - radius) * denominator
		for y in 0 .. width {
			y_term := f32(y - radius)
			value := C.expf(-(x_term + y_term * y_term * denominator))
			kernel[y * width + x] = value
			total += value
		}
	}
	scale := f32(1) / total
	for i in 0 .. width * width { kernel[i] *= scale }
	return kernel, width * width
}

// Bounded A8 image filtering requires a positive, uniform axis-aligned scale.
// Round rectangles use a nine-patch; capsule corners use the general mask.
fn affine_shadow_supported(shape &C.VoxGraphiteShape) bool {
	m := shape.matrix
	for value in m {
		if math.is_nan(f64(value)) || math.is_inf(f64(value), 0) { return false }
	}
	for value in shape.rect {
		if math.is_nan(f64(value)) || math.is_inf(f64(value), 0) { return false }
	}
	if m[0] <= 0 || m[4] <= 0 || m[1] != 0 || m[3] != 0
		|| m[6] != 0 || m[7] != 0 || m[8] != 1
		|| math.abs(m[0] - m[4]) > f32(0.00001) {
		return false
	}
	sigma := shape.thickness * f32(0.5) * m[0]
	return sigma >= f32(.5) && sigma <= 135
}

fn capsule_shadow_supported(shape &C.VoxGraphiteShape) bool {
	if !affine_shadow_supported(shape) { return false }
	if shape.rect[2] <= shape.rect[3] || shape.rect[3] <= 0 { return false }
	for i in 4 .. 12 {
		if math.abs(shape.rect[i] - shape.rect[3] * f32(0.5)) > f32(0.00001) { return false }
	}
	return true
}

fn ellipse_shadow(shape &C.VoxGraphiteShape) bool {
	for value in shape.rect {
		if math.is_nan(f64(value)) || math.is_inf(f64(value), 0) { return false }
	}
	if shape.rect[2] <= 0 || shape.rect[3] <= 0 { return false }
	for i in 0 .. 4 {
		if math.abs(shape.rect[4 + 2*i] - shape.rect[2] * f32(.5)) > f32(.00001)
			|| math.abs(shape.rect[5 + 2*i] - shape.rect[3] * f32(.5)) > f32(.00001) {
			return false
		}
	}
	return true
}

// An isotropic blur rotates with its source. Shear and unequal scales require
// a different kernel and retain the existing fallback.
fn shadow_filter_scale(shape &C.VoxGraphiteShape) ?f32 {
	if affine_shadow_supported(shape) { return shape.matrix[0] }
	if !ellipse_shadow(shape) { return none }
	m := shape.matrix
	for value in m {
		if math.is_nan(f64(value)) || math.is_inf(f64(value), 0) { return none }
	}
	if m[6] != 0 || m[7] != 0 || m[8] != 1 { return none }
	first := m[0]*m[0] + m[3]*m[3]
	second := m[1]*m[1] + m[4]*m[4]
	if first <= 0 || math.abs(first-second) > first * f32(.00001)
		|| math.abs(m[0]*m[1] + m[3]*m[4]) > first * f32(.00001) { return none }
	scale := f32(math.sqrt(f64(first)))
	sigma := shape.thickness * f32(.5) * scale
	if math.is_nan(f64(sigma)) || math.is_inf(f64(sigma), 0)
		|| sigma < f32(.5) || sigma > 135 { return none }
	return scale
}

fn rounded_shadow_mask(shape &C.VoxGraphiteShape, width int, height int) ![]u8 {
	if affine_shadow_supported(shape) {
		if patch := rounded_shadow_nine_patch(shape, width, height) { return patch }
		if shape.rect[4..12].any(it > 0) {
			return shadow_filter_mask(shape, width, height, none, canvas.Point{})
		}
	}
	if !capsule_shadow_supported(shape) && !ellipse_shadow(shape) {
		return error('Unsupported blurred shadow geometry')
	}
	return shadow_filter_mask(shape, width, height, none, canvas.Point{})
}

fn shadow_filter_mask(shape &C.VoxGraphiteShape, width int, height int,
	source_path ?canvas.Path, source_offset canvas.Point) ![]u8 {
	scale_factor := shadow_filter_scale(shape) or { return error('Unsupported shadow filter transform') }
	m := shape.matrix
	sigma := shape.thickness * f32(0.5) * scale_factor
	mut x0, mut y0 := f32(math.inf(1)), f32(math.inf(1))
	mut x1, mut y1 := f32(math.inf(-1)), f32(math.inf(-1))
	for i in 0 .. 4 {
		x := shape.rect[0] + if i & 1 != 0 { shape.rect[2] } else { f32(0) }
		y := shape.rect[1] + if i & 2 != 0 { shape.rect[3] } else { f32(0) }
		dx, dy := x*m[0] + y*m[1] + m[2], x*m[3] + y*m[4] + m[5]
		x0, y0 = math.min(x0,dx), math.min(y0,dy)
		x1, y1 = math.max(x1,dx), math.max(y1,dy)
	}
	mut left, mut top := f32(math.floor(f64(x0))), f32(math.floor(f64(y0)))
	mut right, mut bottom := f32(math.ceil(f64(x1))), f32(math.ceil(f64(y1)))
	if affine_shadow_supported(shape) {
		// The filter layer needs only the tile's input footprint. Keeping the
		// whole offscreen box changes the centered downsampling grid. Rotated
		// filter layers need their own layer-space bounds and retain replay.
		pad := f32(math.ceil(f64(f32(3) * sigma)))
		left, top = math.max(left, -pad), math.max(top, -pad)
		right, bottom = math.min(right, f32(width) + pad), math.min(bottom, f32(height) + pad)
	}
	original := ShadowBounds{left, top, right, bottom}
	source_width := int(right - left)
	source_height := int(bottom - top)
	if source_width <= 0 || source_height <= 0 || source_width > 16384 || source_height > 16384
		|| source_width * source_height > 16 * 1024 * 1024 {
		return error('Shadow source exceeds bounded surface size')
	}
	mut ctx := context()!
	mut source := ctx.new_surface(width: source_width, height: source_height)!
	defer { source.free() }
	source.clear(canvas.Color4f{})
	mut source_matrix := [9]f32{}
	for i in 0 .. 9 { source_matrix[i] = m[i] }
	source_matrix[2] += source_offset.x * m[0] + source_offset.y * m[1] - left
	source_matrix[5] += source_offset.x * m[3] + source_offset.y * m[4] - top
	source.set_matrix(canvas.Matrix.values(source_matrix))
	white := canvas.Paint{ color: canvas.Color4f{1, 1, 1, 1}, anti_alias: shape.anti_alias != 0 }
	if path := source_path {
		source.draw_path(path, white)!
	} else {
		source.draw_rrect(rounded_rect(shape.rect), white)!
	}
	mut rgba := []u8{len: source_width * source_height * 4}
	source.read_pixels(rgba.data, source_width * 4)!
	mut alpha := []u8{len: source_width * source_height}
	for i in 0 .. alpha.len { alpha[i] = rgba[i * 4 + 3] }
	mut image := ShadowMask{alpha, source_width, source_height}
	mut bounds := original
	mut pixels := original
	mut steps := 0
	mut power := f32(1)
	scale := if sigma > 4 { f32(4) / sigma } else { f32(1) }
	for power < f32(1) / scale {
		power *= 2
		steps++
	}
	if steps > 0 {
		last_scale := scale * (power * f32(0.5))
		if last_scale >= (if steps == 1 { f32(0.999) } else { f32(0.9) }) { steps-- }
	}
	for steps > 0 {
		sx := if steps > 1 {
			f32(0.5)
		} else {
			(original.right - original.left) * scale / (bounds.right - bounds.left)
		}
		sy := if steps > 1 {
			f32(0.5)
		} else {
			(original.bottom - original.top) * scale / (bounds.bottom - bounds.top)
		}
		cx := f32(0.5) * bounds.left + f32(0.5) * bounds.right
		cy := f32(0.5) * bounds.top + f32(0.5) * bounds.bottom
		next := ShadowBounds{(bounds.left - cx) * sx, (bounds.top - cy) * sy, (bounds.right - cx) * sx, (bounds.bottom - cy) * sy}
		pixel_bounds := ShadowBounds{f32(math.floor(f64(next.left))), f32(math.floor(f64(next.top))), f32(math.ceil(f64(next.right))), f32(math.ceil(f64(next.bottom)))}
		image = shadow_mask_pass(image, int(pixel_bounds.right - pixel_bounds.left),
			int(pixel_bounds.bottom - pixel_bounds.top), [f32(1) / sx, f32(1) / sy,
				pixel_bounds.left / sx + cx - pixels.left, pixel_bounds.top / sy + cy - pixels.top]!, [56]f32{}, 0, 0)!
		bounds = next
		pixels = pixel_bounds
		steps--
	}
	low_sigma := f32(math.min(f64(sigma * (bounds.right - bounds.left) / (original.right - original.left)), 4))
	radius := f32(math.ceil(f64(f32(3) * low_sigma)))
	blur_width := image.width + int(radius) * 2
	blur_height := image.height + int(radius) * 2
	if (2 * int(radius) + 1) * (2 * int(radius) + 1) <= 28 {
		kernel, count := shadow_small_kernel(low_sigma, int(radius))
		image = shadow_mask_pass(image, blur_width, blur_height,
			[f32(1), 1, -radius, -radius]!, kernel, count, 2)!
	} else {
		pairs, count := shadow_linear_kernel(low_sigma)
		image = shadow_mask_pass(image, blur_width, blur_height, [f32(1), 1, -radius, -radius]!, pairs, count, 0)!
		image = shadow_mask_pass(image, blur_width, blur_height, [f32(1), 1, 0, 0]!, pairs, count, 1)!
	}
	pixels = ShadowBounds{pixels.left - radius, pixels.top - radius, pixels.right + radius, pixels.bottom + radius}
	sx := (bounds.right - bounds.left) / (original.right - original.left)
	sy := (bounds.bottom - bounds.top) / (original.bottom - original.top)
	// Resolve back to an A8 image before the paint color is applied. Fusing
	// upscale and color multiplication skips this required quantization.
	resolved := shadow_mask_pass(image, width, height, [sx, sy,
		bounds.left - original.left * sx - pixels.left, bounds.top - original.top * sy - pixels.top]!, [56]f32{}, 0, 0)!
	return resolved.pixels
}

// Graphite AnalyticBlurMask::MakeRRect: blur a small rounded rectangle, then
// sample its nine-patch with nearest filtering. Keep the A8 sample intact until
// draw_alpha_mask multiplies it by the floating-point paint color.
fn rounded_shadow_nine_patch(shape &C.VoxGraphiteShape, width int, height int) ?[]u8 {
	m := shape.matrix
	sigma := shape.thickness * f32(.5) * m[0]
	radius := shape.rect[4] * m[0]
	if radius <= 0 { return none }
	for i in 5 .. 12 { if shape.rect[i] * m[0] != radius { return none } }
	blur_radius := f32(3) * f32(math.ceil(f64(sigma - f32(1) / 6)))
	corner := f32(math.ceil(f64(radius)))
	if shape.rect[2] * m[0] <= 2 * (corner + blur_radius)
		|| shape.rect[3] * m[0] <= 2 * (corner + blur_radius) {
		return none
	}
	size := 2 * blur_radius + 2 * corner + 1
	dimension := int(size + 2 * blur_radius)
	if dimension <= 0 || dimension > 4096 { return none }
	patch_shape := C.VoxGraphiteShape{
		matrix:    [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
		rect:      [blur_radius, blur_radius, size, size, corner, corner, corner, corner, corner,
			corner, corner, corner]!
		thickness: sigma * 2
	}
	patch := shadow_filter_mask(&patch_shape, dimension, dimension, none, canvas.Point{}) or { return none }
	left := shape.rect[0] * m[0] + m[2] - blur_radius
	top := shape.rect[1] * m[4] + m[5] - blur_radius
	center_x := (shape.rect[2] * m[0] + 2 * blur_radius) * f32(.5)
	center_y := (shape.rect[3] * m[4] + 2 * blur_radius) * f32(.5)
	edge := 2 * blur_radius + radius + f32(.5)
	mut output := []u8{len: width * height}
	for y in 0 .. height {
		dy := f32(y) + f32(.5) - top - center_y
		py := f32(math.max(0, f64(math.abs(dy) - (center_y - edge)))) * (if dy < 0 {
			f32(-1)
		} else if dy > 0 {
			f32(1)
		} else {
			f32(0)
		}) + edge
		iy := int(contour_clamp(f32(math.floor(f64(py / (2 * edge) * f32(dimension)))), 0, f32(dimension - 1)))
		for x in 0 .. width {
			dx := f32(x) + f32(.5) - left - center_x
			px := f32(math.max(0, f64(math.abs(dx) - (center_x - edge)))) * (if dx < 0 {
				f32(-1)
			} else if dx > 0 {
				f32(1)
			} else {
				f32(0)
			}) + edge
			ix := int(contour_clamp(f32(math.floor(f64(px / (2 * edge) * f32(dimension)))), 0, f32(dimension - 1)))
			output[y * width + x] = patch[iy * dimension + ix]
		}
	}
	return output
}
