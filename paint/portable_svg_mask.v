module main

import cpuraster
import layout
import math
import os
import painting

const disable_portable_svg_mask = os.getenv('VOX_DISABLE_PORTABLE_SVG_MASK') == '1'
const disable_svg_mask_ramp = os.getenv('VOX_DISABLE_SVG_MASK_RAMP') == '1'
const portable_svg_mask_diagnostics = os.getenv('VOX_PORTABLE_SVG_MASK_DIAGNOSTICS') == '1'
const portable_svg_mask_max_opacity_depth = 4

fn portable_svg_content_mask_supported(mask &layout.PaintClip) bool {
	if mask.is_svg_mask || mask.corner_radii != layout.BoxRadii{} || mask.mask_operations.len > 64
		|| mask.transform[1] != 0 || mask.transform[2] != 0 {
		return false
	}
	mut depth := 0
	for index in 0 .. mask.mask_operations.len {
		operation := &mask.mask_operations[index]
		match operation.kind {
			.begin_opacity {
				if depth == portable_svg_mask_max_opacity_depth
					|| !(operation.opacity >= 0 && operation.opacity <= 1) { return false }
				depth++
			}
			.end_opacity {
				if depth == 0 { return false }
				depth--
			}
			.path {
				if !operation.has_fill || operation.has_stroke || operation.opacity != 1
					|| operation.fill_pattern != none
					|| operation.path_data.len < layout.compatibility_clip_path_segment_stride
					|| !portable_svg_mask_gradient_supported(operation, mask.mask_luminance) {
					return false
				}
			}
			.image { return false }
		}
	}
	return depth == 0
}

fn portable_svg_mask_gradient_supported(operation &layout.PaintMaskOperation, luminance bool) bool {
	if linear := operation.fill_linear_gradient {
		return linear.gradient.spread_method == .pad
			&& portable_svg_raster_linear_supported(&linear, luminance)
	}
	if radial := operation.fill_radial_gradient {
		return radial.gradient.spread_method == .pad
			&& portable_svg_raster_radial_supported(&radial, luminance)
	}
	return true
}

fn portable_svg_mask_gradient(operation &layout.PaintMaskOperation, luminance bool) ?cpuraster.CanvasPaintStyle {
	if linear := operation.fill_linear_gradient {
		return cpuraster.CanvasPaintStyle(portable_svg_raster_linear_gradient(&linear, luminance))
	}
	if radial := operation.fill_radial_gradient {
		return cpuraster.CanvasPaintStyle(portable_svg_raster_radial_gradient(&radial, luminance))
	}
	return none
}

struct PortableSVGMaskLayer {
mut:
	pixels  []u8
	opacity f32
}

struct SVGMaskRamp {
	coverage  painting.IntRect
	vertical  bool
	transform [6]f32
}

fn svg_mask_aligned_rect(operation &layout.PaintMaskOperation, matrix [6]f32) ?painting.IntRect {
	if matrix[1] != 0 || matrix[2] != 0 || matrix[0] == 0 || matrix[3] == 0 { return none }
	rect := svg_background_rectangle_path(operation.path_data) or { return none }
	mut left := f32(rect.x) * matrix[0] + matrix[4]
	mut right := f32(rect.right()) * matrix[0] + matrix[4]
	mut top := f32(rect.y) * matrix[3] + matrix[5]
	mut bottom := f32(rect.bottom()) * matrix[3] + matrix[5]
	for coordinate in [left, right, top, bottom]! {
		value := f64(coordinate)
		if !math.is_finite(value) || value != math.floor(value) || math.abs(value) >= 1048576 {
			return none
		}
	}
	// A reflected rectangle has reversed endpoints. Keep the signed matrix
	// for shading and cache identity, and order only the device bounds.
	if left > right { left, right = right, left }
	if top > bottom { top, bottom = bottom, top }
	return painting.IntRect{int(left), int(top), int(right - left), int(bottom - top)}
}

fn svg_mask_ramp(mask &layout.PaintClip, bounds painting.IntRect, page_x f32, page_y f32,
	scale f64) ?SVGMaskRamp {
	if disable_svg_mask_ramp || mask.mask_operations.len != 1 { return none }
	operation := &mask.mask_operations[0]
	gradient := operation.fill_linear_gradient or { return none }
	same_x := f32(gradient.start_point.x) == f32(gradient.end_point.x)
	same_y := f32(gradient.start_point.y) == f32(gradient.end_point.y)
	if same_x == same_y { return none }
	if local := gradient.gradient.gradient_transform {
		if local.b != 0 || local.c != 0 { return none }
	}
	device := portable_device_transform(operation.transform, page_x, page_y, scale)
	// A reflection reverses sampling along an axis but preserves variation in one dimension.
	matrix := portable_svg_surface_matrix(device, bounds)
	rect := svg_mask_aligned_rect(operation, matrix) or { return none }
	first_column := int(math.max(0, f64(rect.x)))
	end_column := int(math.min(f64(bounds.width), f64(rect.right())))
	first_row := int(math.max(0, f64(rect.y)))
	end_row := int(math.min(f64(bounds.height), f64(rect.bottom())))
	coverage := painting.IntRect{first_column, first_row, end_column - first_column, end_row - first_row}
	if coverage.is_empty() || (same_x && coverage.width <= 1) || (same_y && coverage.height <= 1) {
		return none
	}
	mut strip_matrix := matrix
	if same_x {
		strip_matrix[4] -= f32(coverage.x)
	} else {
		strip_matrix[5] -= f32(coverage.y)
	}
	return SVGMaskRamp{coverage, same_x, strip_matrix}
}

fn shade_svg_mask_strip(mut pixels []u8, length int, operation &layout.PaintMaskOperation,
	ramp SVGMaskRamp, luminance bool) bool {
	path := cpuraster.canvas_path(operation.path_data, operation.path_even_odd)
	style := portable_svg_mask_gradient(operation, luminance)
	width, height := if ramp.vertical { 1, length } else { length, 1 }
	return cpuraster.fill_canvas_path(mut pixels, width, height, width * 4, 2, path,
		ramp.transform, 0xff000000, style, f32(operation.fill_opacity), .src_over, 0, [], none)
}

fn raster_svg_mask_ramp(mut pixels []u8, pitch int, width int, operation &layout.PaintMaskOperation,
	ramp SVGMaskRamp, luminance bool) bool {
	coverage := ramp.coverage
	// Shade a strip on the varying axis using the original CPU shader.
	if ramp.vertical {
		mut column := []u8{len: coverage.bottom() * 4}
		if !shade_svg_mask_strip(mut column, coverage.bottom(), operation, ramp, luminance) {
			return false
		}
		// The surfaces have four-byte pixel offsets and stride.
		unsafe {
			for y in coverage.y .. coverage.bottom() {
				color := (&u32(column.data))[y]
				mut row := &u32(pixels.data) + y * (pitch / 4) + coverage.x
				for x in 0 .. coverage.width {
					row[x] = color
				}
			}
		}
	} else {
		row_bytes := width * 4
		first := coverage.y * pitch
		mut row := pixels[first..first + row_bytes]
		if !shade_svg_mask_strip(mut row, width, operation, ramp, luminance) {
			unsafe { vmemset(row.data, 0, row_bytes) }
			return false
		}
		for y in coverage.y + 1 .. coverage.bottom() {
			offset := y * pitch
			copy(mut pixels[offset..offset + row_bytes], row)
		}
	}
	log_svg_mask_ramp(ramp)
	return true
}

fn log_svg_mask_ramp(ramp SVGMaskRamp) {
	if portable_svg_mask_diagnostics {
		eprintln('VOX_SVG_MASK_RAMP width=${ramp.coverage.width} rows=${ramp.coverage.height} vertical=${ramp.vertical}')
	}
}

@[inline]
fn svg_mask_luminance(red u8, green u8, blue u8) u8 {
	return u8((54 * u32(red) + 183 * u32(green) + 19 * u32(blue)) >> 8)
}

@[direct_array_access]
fn apply_svg_mask_ramp(mut image PortableSVGGroupImage, operation &layout.PaintMaskOperation,
	ramp SVGMaskRamp, luminance bool) bool {
	width, height := image.bounds.width, image.bounds.height
	coverage := ramp.coverage
	length := if ramp.vertical { coverage.bottom() } else { width }
	mut strip := []u8{len: length * 4}
	if !shade_svg_mask_strip(mut strip, length, operation, ramp, luminance) { return false }
	// The strip is premultiplied. Resolve the mask values in its own storage
	// before reusing them across the constant axis.
	for i in 0 .. length {
		offset := i * 4
		strip[i] = if luminance {
			svg_mask_luminance(strip[offset], strip[offset + 1], strip[offset + 2])
		} else {
			strip[offset + 3]
		}
	}
	for y in 0 .. height {
		row := y * width * 4 + 3
		if y < coverage.y || y >= coverage.bottom() {
			for x in 0 .. width {
				image.pixels[row + x * 4] = 0
			}
		} else if ramp.vertical {
			for x in 0 .. coverage.x {
				image.pixels[row + x * 4] = 0
			}
			value := strip[y]
			if value != 255 {
				for x in coverage.x .. coverage.right() {
					offset := row + x * 4
					image.pixels[offset] = portable_svg_mask_alpha(image.pixels[offset], value)
				}
			}
			for x in coverage.right() .. width {
				image.pixels[row + x * 4] = 0
			}
		} else {
			for x in 0 .. width {
				offset := row + x * 4
				image.pixels[offset] = portable_svg_mask_alpha(image.pixels[offset], strip[x])
			}
		}
	}
	log_svg_mask_ramp(ramp)
	return true
}

fn (mut app BrowserApp) apply_portable_svg_content_mask(mut image PortableSVGGroupImage,
	mask &layout.PaintClip, region painting.Rect, page_x f32, page_y f32, scale f64) bool {
	bounds := image.bounds
	if ramp := svg_mask_ramp(mask, bounds, page_x, page_y, scale) {
		if apply_svg_mask_ramp(mut image, &mask.mask_operations[0], ramp, mask.mask_luminance) {
			apply_portable_svg_mask_region(mut image, region)
			return true
		}
	}
	mut coverage := []u8{len: bounds.width * bounds.height * 4}
	if !app.raster_svg_mask_layers(mut coverage, bounds.width * 4, bounds, mask, page_x, page_y,
		scale) { return false }
	if mask.mask_luminance {
		// The mask channels are already premultiplied. Convert the resolved
		// color with the native mask's integer luminance weights.
		for offset := 0; offset < coverage.len; offset += 4 {
			value := svg_mask_luminance(coverage[offset], coverage[offset + 1], coverage[offset + 2])
			image.pixels[offset + 3] = portable_svg_mask_alpha(image.pixels[offset + 3], value)
		}
	} else {
		for offset := 3; offset < coverage.len; offset += 4 {
			image.pixels[offset] = portable_svg_mask_alpha(image.pixels[offset], coverage[offset])
		}
	}
	apply_portable_svg_mask_region(mut image, region)
	return true
}

// The native player needs the full mask surface, including when a strip
// covers the mask region.
fn (mut app BrowserApp) raster_svg_content_mask(mut pixels []u8, pitch int, bounds painting.IntRect,
	mask &layout.PaintClip, page_x f32, page_y f32, scale f64) bool {
	if ramp := svg_mask_ramp(mask, bounds, page_x, page_y, scale) {
		if raster_svg_mask_ramp(mut pixels, pitch, bounds.width, &mask.mask_operations[0], ramp,
			mask.mask_luminance) {
			return true
		}
	}
	return app.raster_svg_mask_layers(mut pixels, pitch, bounds, mask, page_x, page_y, scale)
}

// Paint into a cleared premultiplied RGBA surface. Its row stride can include
// pixels outside the mask region when borrowing a native bitmap.
fn (mut app BrowserApp) raster_svg_mask_layers(mut pixels []u8, pitch int, bounds painting.IntRect,
	mask &layout.PaintClip, page_x f32, page_y f32, scale f64) bool {
	layer_pitch := bounds.width * 4
	byte_count := layer_pitch * bounds.height
	mut layers := [portable_svg_mask_max_opacity_depth + 1]PortableSVGMaskLayer{}
	layers[0].pixels = pixels
	mut depth := 0
	for index in 0 .. mask.mask_operations.len {
		operation := &mask.mask_operations[index]
		match operation.kind {
			.begin_opacity {
				depth++
				layers[depth].opacity = f32(operation.opacity)
				if layers[depth].pixels.len == 0 {
					layers[depth].pixels = []u8{len: byte_count}
				} else {
					unsafe { vmemset(layers[depth].pixels.data, 0, byte_count) }
				}
			}
			.end_opacity {
				layer := layers[depth]
				depth--
				bitmap := cpuraster.CanvasBitmap{
					pixels: layer.pixels
					width: bounds.width
					height: bounds.height
					pitch: layer_pitch
					premultiplied: true
				}
				rect := [f32(0), 0, f32(bounds.width), f32(bounds.height)]!
				// The children blend in isolation. Apply the opacity once while
				// restoring the complete mask layer, without resampling it.
				if !cpuraster.draw_canvas_image(mut layers[depth].pixels, bounds.width, bounds.height,
					if depth == 0 { pitch } else { layer_pitch }, 2,
					[f32(1), 0, 0, 1, 0, 0]!, bitmap, rect, rect, false,
					layer.opacity, .src_over, []) { return false }
			}
			.path {
				style := portable_svg_mask_gradient(operation, mask.mask_luminance)
				mut argb := u32(0xff000000)
				mut opacity := f32(operation.fill_opacity)
				if style == none {
					color := app.paint_colors.color(operation.fill_color, operation.fill_opacity)
					if color.a == 0 { continue }
					argb = if mask.mask_luminance { portable_svg_argb(color) } else { (u32(color.a) << 24) | 0xffffff }
					opacity = 1
				}
				path := cpuraster.canvas_path(operation.path_data, operation.path_even_odd)
				transform := portable_device_transform(operation.transform, page_x, page_y, scale)
				if !cpuraster.fill_canvas_path(mut layers[depth].pixels, bounds.width, bounds.height,
					if depth == 0 { pitch } else { layer_pitch }, 2,
					path, portable_svg_surface_matrix(transform, bounds), argb, style, opacity,
					.src_over, 0, [], none) { return false }
			}
			.image { return false }
		}
	}
	return true
}

@[inline]
fn portable_svg_mask_alpha(alpha u8, coverage u8) u8 {
	return u8((u32(alpha) * u32(coverage) + 127) / 255)
}

// The texture bounds enclose the region's fractional edges. Apply their
// coverage once after compositing the mask operations.
fn apply_portable_svg_mask_region(mut image PortableSVGGroupImage, mask_region painting.Rect) {
	bounds := image.bounds
	region := mask_region.intersection(painting.Rect{f64(bounds.x), f64(bounds.y),
		f64(bounds.width), f64(bounds.height)})
	columns := [int(math.floor(region.x)), int(math.ceil(region.right())) - 1]!
	for index, x in columns {
		if x < bounds.x || x >= bounds.right() || (index == 1 && x == columns[0]) { continue }
		coverage := portable_svg_mask_edge_coverage(x, region.x, region.right())
		if coverage == 255 { continue }
		for row in 0 .. bounds.height {
			offset := (row * bounds.width + x - bounds.x) * 4 + 3
			image.pixels[offset] = portable_svg_mask_alpha(image.pixels[offset], coverage)
		}
	}
	rows := [int(math.floor(region.y)), int(math.ceil(region.bottom())) - 1]!
	for index, y in rows {
		if y < bounds.y || y >= bounds.bottom() || (index == 1 && y == rows[0]) { continue }
		coverage := portable_svg_mask_edge_coverage(y, region.y, region.bottom())
		if coverage == 255 { continue }
		row := (y - bounds.y) * bounds.width
		for column in 0 .. bounds.width {
			offset := (row + column) * 4 + 3
			image.pixels[offset] = portable_svg_mask_alpha(image.pixels[offset], coverage)
		}
	}
}

fn portable_svg_mask_edge_coverage(pixel int, start f64, end f64) u8 {
	return u8(math.round(255 * (math.min(end, f64(pixel + 1)) - math.max(start, f64(pixel)))))
}
