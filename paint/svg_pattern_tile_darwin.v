module main

import cpuraster
import math
import painting

fn C.native_shared_svg_pattern_scale(i32) f64
fn C.native_reuse_shared_svg_pattern_tile(u64) i32
fn C.native_install_shared_svg_pattern_tile(u64, &u8, u64, i32, i32) i32

struct SharedSVGPatternCacheKey {
mut:
	value          u64
	image_scope    bool
	image_lookups  int
	last_image_url string
	last_image_id  u64
}

fn (mut app BrowserApp) add_shared_svg_pattern_images(list &painting.SVGPatternDisplayList,
	mut key SharedSVGPatternCacheKey) bool {
	// The caller has checked the operation and depth limits for this tile.
	mut hidden_depth := 0
	for index in 0 .. list.operations.len {
		operation := &list.operations[index]
		if hidden_depth != 0 {
			match operation.kind {
				.begin_opacity, .begin_filter { hidden_depth++ }
				.end_opacity, .end_filter { hidden_depth-- }
				else {}
			}
			continue
		}
		if operation.kind == .begin_opacity || operation.kind == .begin_filter {
			opacity := if operation.kind == .begin_opacity {
				operation.opacity
			} else {
				filter := operation.filter or { return false }
				filter.opacity_filter_amount() or { continue }
			}
			// Tile lowering replays pure opacity filters as the same isolated layers.
			if cpuraster.canvas_image_opacity_byte(f32(opacity)) == 0 { hidden_depth = 1 }
			continue
		}
		if operation.kind == .image && operation.opacity != 0 {
			image_url := operation.image_url
			if !key.image_scope || image_url != key.last_image_url {
				if !key.image_scope {
					if app.document == unsafe { nil } { return false }
					key.value = (key.value ^ u64(app.document.unique_id().value())) * u64(1099511628211)
					key.value = (key.value ^ u64(voidptr(app.ctx))) * u64(1099511628211)
					key.image_scope = true
				}
				if portable_svg_raster_diagnostics { key.image_lookups++ }
				image := app.background_image(image_url) or { return false }
				key.last_image_url = image_url
				key.last_image_id = u64(image.id)
			}
			// Keep the image IDs in display-list order, including repeated occurrences.
			key.value = (key.value ^ key.last_image_id) * u64(1099511628211)
		}
		// A retained style can be present even when mask replay skips the paint.
		mut fill_list := voidptr(0)
		if pattern := operation.fill_pattern {
			if operation.has_fill && operation.fill_opacity > 0 {
				child := pattern.tile_display_list or { return false }
				if !app.add_shared_svg_pattern_images(child, mut key) { return false }
				fill_list = voidptr(child)
			}
		}
		if pattern := operation.stroke_pattern {
			if operation.has_stroke && f32(operation.stroke_opacity) > 0 {
				child := pattern.tile_display_list or { return false }
				// A shared display list has already contributed its image slots.
				if voidptr(child) != fill_list && !app.add_shared_svg_pattern_images(child, mut key) {
					return false
				}
			}
		}
	}
	return true
}

fn (mut app BrowserApp) prepare_shared_svg_pattern_tile(style &painting.SVGPatternPaintStyle,
	transform [6]f64, content_mask bool) bool {
	list := style.tile_display_list or { return false }
	scale := C.native_shared_svg_pattern_scale(i32(content_mask))
	if !(scale > 0 && math.is_finite(scale)) { return false }
	info := style.shared_tile_info() or {
		return false
	}
	// The linear transform sets the bitmap resolution and stroke metric.
	// Translated styles share a tile, including during scroll.
	device := portable_device_transform(transform, 0, 0, scale)
	matrix := [f32(device.a), f32(device.b), f32(device.c), f32(device.d), 0, 0]!
	if !matrix.all(math.is_finite(f64(it))) { return false }
	mut key := u64(0)
	if style.cache_key != 0 {
		key = style.cache_key ^ u64(0x73766774696c6573)
		for axis in 0 .. 4 {
			key = (key ^ u64(math.f32_bits(matrix[axis]))) * u64(1099511628211)
		}
		// The display list identifies image URLs. Include the decoded image
		// slots so a resource update cannot reuse a tile's earlier pixels.
		if info.has_images {
			mut image_key := SharedSVGPatternCacheKey{value: key}
			complete := app.add_shared_svg_pattern_images(list, mut image_key)
			if portable_svg_raster_diagnostics && image_key.image_scope {
				eprintln('VOX_SHARED_SVG_TILE image_lookups=${image_key.image_lookups} complete=${complete}')
			}
			key = if complete { image_key.value } else { 0 }
		}
		if key != 0 && C.native_reuse_shared_svg_pattern_tile(key) != 0 {
			if portable_svg_raster_diagnostics { eprintln('VOX_SHARED_SVG_TILE cache=hit key=${key}') }
			return true
		}
	}
	mut budget := PortableSVGMaskTileBudget{}
	// Keep the paint's RGBA. The destination mask resolves luminance or alpha
	// after it composites the completed tile.
	raster := app.raster_svg_mask_pattern(style, matrix, true, unsafe { nil }, mut budget) or {
		return false
	}
	tile := raster.pattern
	cache_key := if raster.cacheable { key } else { u64(0) }
	if C.native_install_shared_svg_pattern_tile(cache_key, tile.pixels.data,
		u64(tile.pixels.len), i32(tile.width), i32(tile.height)) == 0 {
		return false
	}
	if portable_svg_raster_diagnostics {
		eprintln('VOX_SHARED_SVG_TILE cache=miss key=${cache_key} tile=${tile.width}x${tile.height}')
	}
	return true
}
