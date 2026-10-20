module main

import css
import dom
import layout
import math
import painting

// SVG backgrounds replay as vector pictures into their owning raster layer.
// Inspect their actual recorded paths, using the same tile and viewport
// geometry as native playback; they are not opaque bitmap-only operations.
fn chromium_svg_background_msaa_ranges(command layout.PaintCommand) [][]f64 {
	return chromium_svg_background_msaa_rects(command).map([it.y, it.y + it.height])
}

fn chromium_svg_background_msaa_rects(command layout.PaintCommand) []layout.LayoutRect {
	mut triggers := []ChromiumMSAATrigger{}
	append_chromium_svg_background_msaa_triggers(command, 0, mut triggers)
	return triggers.map(layout.LayoutRect{x: it.left, y: it.top, width: it.right - it.left, height: it.bottom - it.top})
}

fn append_chromium_svg_background_msaa_triggers(command layout.PaintCommand, index int,
	mut triggers []ChromiumMSAATrigger) {
	if command.image_data == unsafe { nil } || command.opacity <= 0 { return }
	image := command.image_data
	svg_document := image.background_svg_document or { return }
	data := image.background_layer_data or { return }
	natural := layout.svg_background_natural_size(svg_document)
	layer := painting.resolve_background_layer_with_natural_size(data.layer, image.image_url, painting.Rect{command.x, command.y, command.width, command.height},
		data.resolution_context, natural) or { return }
	clip :=
		painting.Rect{image.image_clip_x, image.image_clip_y, image.image_clip_width, image.image_clip_height}
	plan :=
		painting.background_tile_plan(layer, painting.Point{command.image_scroll_offset_x, command.image_scroll_offset_y}, clip)
	mut document := unsafe { &dom.Document(svg_document) }
	document.set_svg_image_color_scheme(css.preferred_color_scheme_to_string(image.background_svg_color_scheme))
	outer := command.transform
	converter := painting.new_device_pixel_converter(1.0) or { return }
	for tile in painting.background_tiles_from_plan_limited(plan, clip, 4096) {
		destination := converter.rounded_device_rect(tile)
		replay := if !plan.repeat_x && !plan.repeat_y {
			chromium_svg_background_replay(tile, outer)
		} else {
			ChromiumSVGBackgroundReplay{math.max(1, destination.width), math.max(1,
				destination.height), outer}
		}
		offset := if !plan.repeat_x && !plan.repeat_y {
			painting.IntPoint{}
		} else {
			painting.IntPoint{destination.x, destination.y}
		}
		list := svg_image_document_display_list(svg_document, replay.viewport_width,
			replay.viewport_height) or { continue }
		viewport_bounds := transformed_raster_bounds(replay.transform, f64(offset.x), f64(offset.y),
			f64(replay.viewport_width), f64(replay.viewport_height))
		for nested in layout.display_list_commands(list) {
			transformed := layout.paint_command_for_nested_viewport(nested, replay.transform,
				offset, command.opacity)
			bounds := chromium_msaa_trigger_rect(transformed) or { continue }
			top := math.max(bounds.y, viewport_bounds.y)
			bottom := math.min(bounds.y + bounds.height, viewport_bounds.y + viewport_bounds.height)
			left := math.max(bounds.x, viewport_bounds.x)
			right := math.min(bounds.x + bounds.width, viewport_bounds.x + viewport_bounds.width)
			if bottom > top && right > left {
				triggers << ChromiumMSAATrigger{index, top, bottom, left, right}
			}
		}
	}
}

// Only tiles which can appear in this frame need an SVG picture prepared.
// Keep a complete tile of fringe, since an offscreen path can multisample a
// tile whose border rows are visible. Fetching and filtering remain unchanged.
fn chromium_svg_background_intersects_raster_viewport(command layout.PaintCommand,
	viewport ChromiumMSAAViewport) bool {
	if command.image_data == unsafe { nil } { return false }
	image := command.image_data
	if image.image_clip_width <= 0 || image.image_clip_height <= 0
		|| (command.has_clip && (command.clip_width <= 0 || command.clip_height <= 0)) {
		return false
	}
	bounds := transformed_raster_bounds(command.transform, image.image_clip_x, image.image_clip_y,
		image.image_clip_width, image.image_clip_height)
	if math.is_nan(bounds.y) || math.is_inf(bounds.y, 0) || math.is_nan(bounds.height)
		|| math.is_inf(bounds.height, 0) {
		return true
	}
	scroll := if command.fixed_to_viewport { 0.0 } else { viewport.scroll_y }
	return bounds.y + bounds.height >= scroll - viewport.fringe
		&& bounds.y <= scroll + viewport.height + viewport.fringe
}
