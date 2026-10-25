module layout

import dom
import html
import painting
import platform
import stbi

__global chromium_broken_image_bitmaps = map[int]&dom.Bitmap_{}

fn chromium_broken_image_fallback_scale(node &Node) f64 {
	if !node.is_image_box() || node.document().font_rendering_policy() != .chromium {
		return 0
	}
	dom_node := node.dom_node() or { return 0 }
	element := dom_node.as_element() or { return 0 }
	computed := node.computed_values()
	if !element.as_node().is_html_image_element() || element.get_attribute_value('alt') != ''
		|| computed.size_value(.width).is_auto() || computed.size_value(.height).is_auto() {
		return 0
	}
	model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	return if model.renders_as_alt_text() { node.document().layout_coordinate_scale() } else { 0 }
}

fn chromium_broken_image_bitmap(scale f64) ?&dom.Bitmap_ {
	resolution := if scale >= 2 { 2 } else { 1 }
	if bitmap := chromium_broken_image_bitmaps[resolution] { return bitmap }
	// The cache outlives each document and its retained-paint arena.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	bytes := if resolution == 2 {
		$embed_file('resources/chromium/broken-image-200.png').to_bytes()
	} else {
		$embed_file('resources/chromium/broken-image-100.png').to_bytes()
	}
	image := stbi.load_from_memory(bytes.data, bytes.len) or { return none }
	defer { image.free() }
	bitmap := &dom.Bitmap_{
		width:                             image.width
		height:                            image.height
		pitch:                             image.width * 4
		data:                              unsafe { image.data.vbytes(image.width * image.height * 4).clone() }
		native_rows_are_top_down:          true
		native_resource_replay_compatible: true
	}
	chromium_broken_image_bitmaps[resolution] = bitmap
	return bitmap
}

// Blink's fixed-size fallback has a silver inner border, one pixel of
// padding, and a 16px icon floated towards the inline start. Small images
// suppress both the border and icon. Fetching images never enter this path.
fn append_chromium_broken_image(mut commands []PaintCommand, paintable &painting.ImagePaintable,
	opacity f64) {
	scale := paintable.broken_image_fallback_scale
	// Blink snaps the complete fallback frame to device pixels before painting.
	converter := painting.new_device_pixel_converter(1) or { return }
	snapped := converter.rounded_device_rect(paintable.image_rect)
	r := painting.Rect{f64(snapped.x), f64(snapped.y), f64(snapped.width), f64(snapped.height)}
	if r.width < 18 * scale || r.height < 18 * scale { return }
	commands << PaintCommand{
		kind:         'stroke_rounded_rect'
		x:            r.x + scale / 2
		y:            r.y + scale / 2
		width:        r.width - scale
		height:       r.height - scale
		stroke_width: scale
		color:        'rgb(192 192 192)'
		opacity:      opacity
	}
	bitmap := chromium_broken_image_bitmap(scale) or { return }
	icon := painting.Rect{
		x:      if paintable.broken_image_fallback_rtl {
			r.x + r.width - 18 * scale
		} else {
			r.x + 2 * scale
		}
		y:      r.y + 2 * scale
		width:  16 * scale
		height: 16 * scale
	}
	commands << PaintCommand{
		kind:                  'draw_replaced_image'
		x:                     icon.x
		y:                     icon.y
		width:                 icon.width
		height:                icon.height
		opacity:               opacity
		replaced_image_bitmap: bitmap
		image_paintable:       &painting.ImagePaintable{ image_rect: icon }
	}
}
