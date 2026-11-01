module main

import dom
import css
import layout
import math
import painting
import platform

fn svg_background_paint_commands(image &layout.PaintImageData, width int, height int) ?[]layout.PaintCommand {
	if resource := image.background_static_svg_resource {
		return layout.static_svg_background_commands(resource, width, height)
	}
	svg_document := image.background_svg_document or { return none }
	mut document := unsafe { &dom.Document(svg_document) }
	persistent := platform.enter_persistent()
	document.set_svg_image_color_scheme(css.preferred_color_scheme_to_string(image.background_svg_color_scheme))
	platform.leave_persistent(persistent)
	list := svg_image_document_display_list(document, width, height) or { return none }
	return layout.display_list_commands(list)
}

fn svg_background_natural_metrics(image &layout.PaintImageData) ?css.SizeWithAspectRatio {
	if resource := image.background_static_svg_resource { return resource.natural_metrics() }
	if document := image.background_svg_document {
		return layout.svg_background_natural_size(document)
	}
	return none
}

// The display list of an SVG image document laid out at `width`×`height`.
// SVG backgrounds are replayed, and inspected for MSAA, for every tile of
// every recording; a document already laid out at that size keeps its list.
fn svg_image_document_display_list(svg_document &dom.Document, width int, height int) ?&dom.DisplayList {
	mut document := unsafe { &dom.Document(svg_document) }
	viewport := document.viewport_rect()
	if viewport.width == f64(width) && viewport.height == f64(height)
		&& document.layout_is_up_to_date() && !document.needs_style_update_after_layout() {
		if list := document.cached_display_list() {
			return list
		}
	}
	mut owner := document.native_storage()
	persistent := platform.enter_persistent_if(owner == unsafe { nil })
	defer { platform.leave_persistent(persistent) }
	mut allocations := if owner != unsafe { nil } {
		owner.enter_nested()
	} else {
		platform.RetainedArenaScope{}
	}
	defer { allocations.finish() }
	layout.enable_native_paint_tree_storage(svg_document)
	_ = layout.run_document_layout(svg_document, f64(width), f64(height)) or { return none }
	return document.record_display_list()
}

struct ChromiumSVGBackgroundReplay {
	viewport_width  int
	viewport_height int
	transform       [6]f64
}

// Native replay keeps these paths in the current picture. Inspect the actual
// resolved SVG rather than treating every vector background as a bitmap barrier.
// Inspect every visible tile with the same rounded viewport as native replay.
// Effects and rounded image clips retain the ordinary fallback.
fn chromium_svg_background_can_share_recording(command &layout.PaintCommand) bool {
	if command.kind != 'draw_background_image' || command.image_data == unsafe { nil }
		|| command.opacity != 1 || command.group_opacity != 1 {
		return false
	}
	image := command.image_data
	if image.background_blend_mode != .normal || image.image_attachment == 'fixed'
		|| image.image_clip_radii != layout.BoxRadii{} {
		return false
	}
	natural := svg_background_natural_metrics(image) or { return false }
	background := image.background_layer_data or { return false }
	layer := background.resolve_image(image.image_url,
		painting.Rect{command.x, command.y, command.width, command.height}, natural) or { return false }
	clip := painting.Rect{image.image_clip_x, image.image_clip_y, image.image_clip_width, image.image_clip_height}
	if clip.width <= 0 || clip.height <= 0 { return false }
	plan := painting.background_tile_plan(layer,
		painting.Point{command.image_scroll_offset_x, command.image_scroll_offset_y}, clip)
	converter := painting.new_device_pixel_converter(1.0) or { return false }
	mut tiles := painting.background_tile_iterator(plan, clip, 4097)
	mut count := 0
	for {
		tile := tiles.next() or { break }
		count++
		if count > 4096 { return false }
		destination := converter.rounded_device_rect(tile)
		replay := if !plan.repeat_x && !plan.repeat_y {
			chromium_svg_background_replay(tile, normalized_paint_transform(command.transform))
		} else {
			ChromiumSVGBackgroundReplay{math.max(1, destination.width), math.max(1, destination.height), command.transform}
		}
		commands := svg_background_paint_commands(image, replay.viewport_width, replay.viewport_height) or { return false }
		if commands.len == 0 || commands.len > 32768 { return false }
		for index in 0 .. commands.len {
			if !chromium_svg_solid_path_supported(&commands[index]) { return false }
		}
	}
	return count > 0
}

// Non-repeating SVG backgrounds lay out in an independently rounded container.
// Blink maps that picture to the snapped destination, whose dimensions match
// the rounded container; fractional CSS tile dimensions do not scale it again.
fn chromium_svg_background_replay(tile painting.Rect, outer [6]f64) ChromiumSVGBackgroundReplay {
	width := math.max(f64(1.0 / 64.0), math.trunc(tile.width * 64) / 64)
	height := math.max(f64(1.0 / 64.0), math.trunc(tile.height * 64) / 64)
	viewport_width := math.max(1, int(math.floor(width + .5)))
	viewport_height := math.max(1, int(math.floor(height + .5)))
	local := [f64(1), f64(0), 0, f64(1), math.floor(tile.x + .5), math.floor(tile.y + .5)]!
	return ChromiumSVGBackgroundReplay{viewport_width, viewport_height, [
		outer[0] * local[0],
		outer[1] * local[0],
		outer[2] * local[3],
		outer[3] * local[3],
		outer[0] * local[4] + outer[2] * local[5] + outer[4],
		outer[1] * local[4] + outer[3] * local[5] + outer[5],
	]!}
}
