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
	if command.image_data == unsafe { nil } || command.opacity <= 0 { return [][]f64{} }
	image := command.image_data
	svg_document := image.background_svg_document or { return [][]f64{} }
	data := image.background_layer_data or { return [][]f64{} }
	natural := layout.svg_background_natural_size(svg_document)
	layer := painting.resolve_background_layer_with_natural_size(data.layer, image.image_url, painting.Rect{command.x, command.y, command.width, command.height},
		data.resolution_context, natural) or { return [][]f64{} }
	clip :=
		painting.Rect{image.image_clip_x, image.image_clip_y, image.image_clip_width, image.image_clip_height}
	plan :=
		painting.background_tile_plan(layer, painting.Point{command.image_scroll_offset_x, command.image_scroll_offset_y}, clip)
	mut document := unsafe { &dom.Document(svg_document) }
	document.set_svg_image_color_scheme(css.preferred_color_scheme_to_string(image.background_svg_color_scheme))
	mut ranges := [][]f64{}
	outer := command.transform
	converter := painting.new_device_pixel_converter(1.0) or { return ranges }
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
		_ = layout.run_document_layout(svg_document, f64(replay.viewport_width),
			f64(replay.viewport_height)) or { continue }
		list := document.record_display_list() or { continue }
		viewport_rows := transformed_row_bounds(replay.transform, f64(offset.x), f64(offset.y),
			f64(replay.viewport_width), f64(replay.viewport_height))
		for nested in layout.display_list_commands(list) {
			transformed := layout.paint_command_for_nested_viewport(nested, replay.transform,
				offset, command.opacity)
			bounds := chromium_msaa_trigger_bounds(transformed) or { continue }
			top := math.max(bounds[0], viewport_rows[0])
			bottom := math.min(bounds[1], viewport_rows[1])
			if bottom > top { ranges << [top, bottom] }
		}
	}
	return ranges
}
