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
