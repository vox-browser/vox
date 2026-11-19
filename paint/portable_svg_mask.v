module main

import cpuraster
import gg
import layout
import math
import os
import painting

const disable_portable_svg_mask = os.getenv('VOX_DISABLE_PORTABLE_SVG_MASK') == '1'
const disable_svg_mask_ramp = os.getenv('VOX_DISABLE_SVG_MASK_RAMP') == '1'
const portable_svg_mask_row_bands = os.getenv('VOX_SVG_MASK_ROW_BANDS') == '1'
const portable_svg_mask_solid_rects = os.getenv('VOX_SVG_MASK_SOLID_RECTS') == '1'
const portable_svg_mask_diagnostics = os.getenv('VOX_PORTABLE_SVG_MASK_DIAGNOSTICS') == '1'
const portable_svg_mask_max_opacity_depth = 4

fn portable_svg_content_mask_supported(mask &layout.PaintClip, portable_group bool) bool {
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
				if !(operation.has_fill || operation.has_stroke) || operation.opacity != 1
					|| operation.path_data.len < layout.compatibility_clip_path_segment_stride
					|| (operation.has_fill && (operation.fill_pattern != none
					|| !portable_svg_mask_gradient_supported(operation, mask.mask_luminance, portable_group)))
					|| (operation.has_stroke && (!portable_group
					|| !portable_svg_mask_stroke_supported(operation, mask.mask_luminance))) {
					return false
				}
			}
			.image { return false }
		}
	}
	return depth == 0
}

fn portable_svg_mask_stroke_supported(operation &layout.PaintMaskOperation, luminance bool) bool {
	width := f32(operation.stroke_width)
	if !(width > 0) || !math.is_finite(f64(width))
		|| !math.is_finite(f64(f32(operation.stroke_miterlimit))) || operation.stroke_pattern != none {
		return false
	}
	if linear := operation.stroke_linear_gradient {
		return portable_svg_raster_linear_supported(&linear, luminance)
	}
	if radial := operation.stroke_radial_gradient {
		return portable_svg_raster_radial_supported(&radial, luminance)
	}
	return true
}

fn portable_svg_mask_gradient_supported(operation &layout.PaintMaskOperation, luminance bool,
	portable_group bool) bool {
	if linear := operation.fill_linear_gradient {
		return (linear.gradient.spread_method == .pad || portable_group)
			&& portable_svg_raster_linear_supported(&linear, luminance)
	}
	if radial := operation.fill_radial_gradient {
		return (radial.gradient.spread_method == .pad || portable_group)
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
	rows    SVGMaskLayerRows
	opacity f32
}

struct SVGMaskLayerRows {
	top    int
	bottom int
}

fn (rows SVGMaskLayerRows) height() int {
	return rows.bottom - rows.top
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
	if operation.has_stroke { return none }
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

fn (mut app BrowserApp) apply_svg_mask_solid_rect(mut image PortableSVGGroupImage,
	operation &layout.PaintMaskOperation, luminance bool, page_x f32, page_y f32, scale f64) bool {
	if operation.kind != .path || operation.has_stroke || operation.fill_linear_gradient != none
		|| operation.fill_radial_gradient != none {
		return false
	}
	device := portable_device_transform(operation.transform, page_x, page_y, scale)
	rect := cpuraster.canvas_pixel_aligned_rect(operation.path_data,
		portable_svg_surface_matrix(device, image.bounds)) or { return false }
	color := app.paint_colors.color(operation.fill_color, operation.fill_opacity)
	mut coverage := color.a
	if luminance {
		// A solid fill over transparent black has the same premultiplied
		// bytes in the native and portable rasterizers.
		paint := cpuraster.premultiply_color(portable_svg_argb(color))
		coverage = svg_mask_luminance(u8(paint), u8(paint >> 8), u8(paint >> 16))
	}
	apply_solid_svg_mask_rect(mut image, rect, coverage)
	if portable_svg_mask_diagnostics {
		eprintln('VOX_SVG_MASK_RECT luminance=${luminance} alpha=${coverage}')
	}
	return true
}

@[direct_array_access]
fn apply_solid_svg_mask_rect(mut image PortableSVGGroupImage, rect cpuraster.IRect, coverage u8) {
	width, height := image.bounds.width, image.bounds.height
	left := math.max(rect.left, 0)
	right := math.min(rect.right, width)
	top := math.max(rect.top, 0)
	bottom := math.min(rect.bottom, height)
	if coverage == 255 && left == 0 && right == width && top == 0 && bottom == height { return }
	has_coverage := coverage != 0 && left < right && top < bottom
	for y in 0 .. height {
		row := y * width * 4 + 3
		if !has_coverage || y < top || y >= bottom {
			for x in 0 .. width {
				image.pixels[row + x * 4] = 0
			}
			continue
		}
		for x in 0 .. left {
			image.pixels[row + x * 4] = 0
		}
		if coverage != 255 {
			for x in left .. right {
				offset := row + x * 4
				image.pixels[offset] = portable_svg_mask_alpha(image.pixels[offset], coverage)
			}
		}
		for x in right .. width {
			image.pixels[row + x * 4] = 0
		}
	}
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
	if portable_svg_mask_solid_rects && mask.mask_operations.len == 1 && app.apply_svg_mask_solid_rect(mut image,
		&mask.mask_operations[0], mask.mask_luminance, page_x, page_y, scale) {
		apply_portable_svg_mask_region(mut image, region)
		return true
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

fn svg_mask_line_path_rows(segments []f32, matrix [6]f32) ?[2]f32 {
	stride := layout.compatibility_clip_path_segment_stride
	if segments.len < stride || segments.len % stride != 0 || segments[0] != 0 { return none }
	transform := cpuraster.Matrix{matrix[0], matrix[1], matrix[2], matrix[3], matrix[4], matrix[5]}
	mut top := f32(math.inf(1))
	mut bottom := f32(math.inf(-1))
	for offset := 0; offset < segments.len; offset += stride {
		match segments[offset] {
			0, 1 {
				point := transform.map_point(cpuraster.Point{segments[offset + 1], segments[offset + 2]})
				if !math.is_finite(point.x) || !math.is_finite(point.y) { return none }
				if portable_svg_mask_row_bands { top = math.min(top, point.y) }
				bottom = math.max(bottom, point.y)
			}
			5 {}
			else { return none }
		}
	}
	return [top, bottom]!
}

fn svg_mask_opacity_layer_rows(operations []layout.PaintMaskOperation, bounds painting.IntRect,
	parent SVGMaskLayerRows, page_x f32, page_y f32, scale f64) SVGMaskLayerRows {
	mut depth := 1
	mut top := f32(math.inf(1))
	mut bottom := f32(math.inf(-1))
	for index in 0 .. operations.len {
		operation := &operations[index]
		match operation.kind {
			.begin_opacity { depth++ }
			.end_opacity {
				depth--
				if depth == 0 {
					if bottom <= f32(parent.top - 1)
						|| (portable_svg_mask_row_bands && top >= f32(parent.bottom + 1)) {
						return SVGMaskLayerRows{}
					}
					if !portable_svg_mask_row_bands {
						return SVGMaskLayerRows{0, int(math.ceil(math.max(0.0, f64(bottom)))) + 1}
					}
					// Keep a guard row beyond each edge. The scan converter
					// still receives the original path and device coordinates.
					candidate_top := int(clamp(math.floor(f64(top)) - 1, f64(parent.top),
						f64(parent.bottom - 1)))
					end := int(clamp(math.ceil(f64(bottom)) + 1, f64(candidate_top + 1),
						f64(parent.bottom)))
					// Small crops leave the cheaper zero-origin fill in place.
					first := if (candidate_top - parent.top) * 4 >= end - parent.top {
						candidate_top
					} else {
						parent.top
					}
					return SVGMaskLayerRows{first, end}
				}
			}
			.path {
				// Centerline bounds omit the caps and joins. Keep the parent
				// surface so an opacity group retains the entire stroke.
				if operation.has_stroke { return parent }
				device := portable_device_transform(operation.transform, page_x, page_y, scale)
				edges := svg_mask_line_path_rows(operation.path_data,
					portable_svg_surface_matrix(device, bounds)) or { return parent }
				top = math.min(top, edges[0])
				bottom = math.max(bottom, edges[1])
				if bottom >= f32(parent.bottom - 1) && (!portable_svg_mask_row_bands
					|| (top - f32(parent.top) - 1) * 4 < f32(parent.height())) { return parent }
			}
			.image { return parent }
		}
	}
	return parent
}

fn svg_mask_opacity_end(operations []layout.PaintMaskOperation, start int) ?int {
	mut nested := 0
	for index in start + 1 .. operations.len {
		match operations[index].kind {
			.begin_opacity { nested++ }
			.end_opacity {
				if nested == 0 { return index }
				nested--
			}
			else {}
		}
	}
	return none
}

// Paint into a cleared premultiplied RGBA surface. Its row stride can include
// pixels outside the mask region when borrowing a native bitmap.
fn (mut app BrowserApp) raster_svg_mask_layers(mut pixels []u8, pitch int, bounds painting.IntRect,
	mask &layout.PaintClip, page_x f32, page_y f32, scale f64) bool {
	layer_pitch := bounds.width * 4
	mut layers := [portable_svg_mask_max_opacity_depth + 1]PortableSVGMaskLayer{}
	layers[0].pixels = pixels
	layers[0].rows = SVGMaskLayerRows{bottom: bounds.height}
	mut depth := 0
	for index := 0; index < mask.mask_operations.len; index++ {
		operation := &mask.mask_operations[index]
		match operation.kind {
			.begin_opacity {
				parent := layers[depth].rows
				opacity := f32(operation.opacity)
				alpha := cpuraster.canvas_image_opacity_byte(opacity)
				rows := if alpha == 0 {
					SVGMaskLayerRows{}
				} else {
					svg_mask_opacity_layer_rows(mask.mask_operations[index + 1..],
						bounds, parent, page_x, page_y, scale)
				}
				if rows.height() == 0 {
					index = svg_mask_opacity_end(mask.mask_operations, index) or { return false }
					if portable_svg_mask_diagnostics {
						eprintln('VOX_SVG_MASK_LAYER_SKIP opacity_byte=${alpha}')
					}
					continue
				}
				depth++
				layers[depth].rows = rows
				layers[depth].opacity = opacity
				byte_count := layer_pitch * rows.height()
				if layers[depth].pixels.len < byte_count {
					layers[depth].pixels = []u8{len: byte_count}
				} else {
					unsafe { vmemset(layers[depth].pixels.data, 0, byte_count) }
				}
				if portable_svg_mask_diagnostics {
					eprintln('VOX_SVG_MASK_LAYER depth=${depth} first_row=${rows.top} rows=${rows.height()} parent_rows=${parent.height()}')
				}
			}
			.end_opacity {
				layer := layers[depth]
				depth--
				bitmap := cpuraster.CanvasBitmap{
					pixels: layer.pixels
					width: bounds.width
					height: layer.rows.height()
					pitch: layer_pitch
					premultiplied: true
				}
				// The children blend in isolation. Apply the opacity once while
				// restoring the mask layer at its original pixel origin.
				parent := layers[depth].rows
				parent_pitch := if depth == 0 { pitch } else { layer_pitch }
				if !cpuraster.restore_canvas_opacity_layer(mut layers[depth].pixels, parent_pitch,
					parent.height(), layer.rows.top - parent.top,
					bitmap, layer.opacity) { return false }
			}
			.path {
				device := portable_device_transform(operation.transform, page_x, page_y, scale)
				if !app.raster_svg_mask_path(mut layers[depth], bounds.width,
					if depth == 0 { pitch } else { layer_pitch }, operation,
					portable_svg_surface_matrix(device, bounds), mask.mask_luminance) { return false }
			}
			.image { return false }
		}
	}
	return true
}

fn (mut app BrowserApp) raster_svg_mask_path(mut layer PortableSVGMaskLayer, width int, pitch int,
	operation &layout.PaintMaskOperation, matrix [6]f32, luminance bool) bool {
	mut style := ?cpuraster.CanvasPaintStyle(none)
	mut fill := u32(0)
	mut opacity := f32(1)
	if operation.has_fill {
		style = portable_svg_mask_gradient(operation, luminance)
		if style != none {
			fill = 0xff000000
			opacity = f32(operation.fill_opacity)
		} else {
			color := app.paint_colors.color(operation.fill_color, operation.fill_opacity)
			fill = portable_svg_mask_argb(color, luminance)
		}
	}
	if fill >> 24 == 0 && !operation.has_stroke { return true }
	if !operation.has_stroke && style == none && fill >> 24 == 255
		&& cpuraster.fill_opaque_canvas_mask_rect(mut layer.pixels, width, layer.rows.top,
			layer.rows.height(), pitch, operation.path_data, matrix, fill) {
		return true
	}
	path := cpuraster.canvas_path(operation.path_data, operation.path_even_odd)
	if operation.has_stroke && operation.stroke_first
		&& !app.raster_svg_mask_stroke(mut layer, width, pitch, operation, path, matrix, luminance) {
		return false
	}
	if fill >> 24 != 0 && !cpuraster.fill_canvas_mask_path(mut layer.pixels, width, layer.rows.top,
		layer.rows.height(), pitch, path, matrix, fill, style, opacity) {
		return false
	}
	return !operation.has_stroke || operation.stroke_first
		|| app.raster_svg_mask_stroke(mut layer, width, pitch, operation, path, matrix, luminance)
}

fn (mut app BrowserApp) raster_svg_mask_stroke(mut layer PortableSVGMaskLayer, width int, pitch int,
	operation &layout.PaintMaskOperation, path cpuraster.Path, matrix [6]f32, luminance bool) bool {
	mut argb := u32(0xff000000)
	mut opacity := f32(operation.stroke_opacity)
	mut style := ?cpuraster.CanvasPaintStyle(none)
	if linear := operation.stroke_linear_gradient {
		style = cpuraster.CanvasPaintStyle(portable_svg_raster_linear_gradient(&linear, luminance))
	} else if radial := operation.stroke_radial_gradient {
		style = cpuraster.CanvasPaintStyle(portable_svg_raster_radial_gradient(&radial, luminance))
	} else {
		color := app.paint_colors.color(operation.stroke_color, operation.stroke_opacity)
		if color.a == 0 { return true }
		argb = portable_svg_mask_argb(color, luminance)
		opacity = 1
	}
	mut local_matrix := matrix
	local_matrix[5] -= f32(layer.rows.top)
	return cpuraster.stroke_canvas_path(mut layer.pixels, width, layer.rows.height(), pitch, 2, path,
		local_matrix, argb, style, opacity, .src_over, 0,
		f32(operation.stroke_width), portable_svg_stroke_cap(operation.stroke_linecap),
		portable_svg_stroke_join(operation.stroke_linejoin),
		f32(math.max(1, operation.stroke_miterlimit)), [], 0, [], none)
}

@[inline]
fn portable_svg_mask_argb(color gg.Color, luminance bool) u32 {
	return if luminance { portable_svg_argb(color) } else { (u32(color.a) << 24) | 0xffffff }
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
