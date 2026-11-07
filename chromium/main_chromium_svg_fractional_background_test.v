module main

import dom
import html
import layout
import encoding.base64

fn fractional_svg_background_test_command(svg string, size string, width string, height string) (layout.PaintCommand, &dom.Document) {
	url := 'data:image/svg+xml;base64,' + base64.encode_str(svg)
	mut document := html.parse_document('<!doctype html><style>body{margin:0}div{width:${width}px;height:${height}px;background-image:url("${url}");background-size:${size}}</style><div></div>')
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	for command in layout.display_list_commands(document.record_display_list() or { panic('paint') }) {
		if command.kind == 'draw_background_image' { return command, document }
	}
	panic('background')
}

fn test_svg_cover_picture_keeps_fractional_container_geometry() {
	command, mut document := fractional_svg_background_test_command('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 562 316"><rect width="562" height="316" fill="#f8f8f8"/><path d="M227 108H327V208H227Z" fill="#b1b1b1"/></svg>', 'cover', '245.125', '137.875')
	defer { document.finalize() }
	pattern := chromium_svg_fractional_background(&command) or { panic('picture pattern') }
	assert pattern.commands.len == 2
	assert pattern.tile.width >= 245.125 && pattern.tile.height >= 137.875
	assert pattern.tile.height == 137.875
	image := command.image_data.background_svg_document or { panic('SVG document') }
	assert image.viewport_rect().width == pattern.tile.width
	assert image.viewport_rect().height == pattern.tile.height
	// Internal SVG curves affect the shader image, not adjacent parent images.
	assert chromium_svg_background_msaa_rects(command).len == 0
	automatic, mut auto_document := fractional_svg_background_test_command('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 562 316"><rect width="562" height="316" fill="#f8f8f8"/></svg>', 'auto', '245.125', '137.875')
	defer { auto_document.finalize() }
	assert chromium_svg_fractional_background(&automatic) != none
	assert chromium_svg_background_msaa_rects(automatic).len == 0
}

fn test_svg_cover_pattern_retains_effect_clip_and_unsupported_shape_fallbacks() {
	command, mut document := fractional_svg_background_test_command('<svg xmlns="http://www.w3.org/2000/svg" width="20" height="12"><rect width="20" height="12" fill="#f8f8f8"/></svg>', 'cover', '40.125', '24.125')
	defer { document.finalize() }
	assert chromium_svg_fractional_background(&command) != none
	for changed in [layout.PaintCommand{ ...command, opacity: .5 },
		layout.PaintCommand{ ...command, group_opacity: .5 }, layout.PaintCommand{ ...command, blur: 1 },
		layout.PaintCommand{ ...command, apply_force_dark_to_image: true },
		layout.PaintCommand{ ...command, image_data: &layout.PaintImageData{ ...command.image_data, background_blend_mode: .multiply } },
		layout.PaintCommand{ ...command, image_data: &layout.PaintImageData{ ...command.image_data, image_attachment: 'fixed' } },
		layout.PaintCommand{ ...command, image_data: &layout.PaintImageData{ ...command.image_data, image_clip_radii: layout.BoxRadii{ top_left: layout.CornerRadius{4, 4} } } }] {
		assert chromium_svg_fractional_background(&changed) == none
	}
	for svg in [
		'<svg xmlns="http://www.w3.org/2000/svg" width="20" height="12"><path d="M2 2L18 10" stroke="black"/></svg>',
		'<svg xmlns="http://www.w3.org/2000/svg" width="20" height="12"><defs><linearGradient id="g"><stop stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient></defs><rect width="20" height="12" fill="url(#g)"/></svg>',
	] {
		other, mut owner := fractional_svg_background_test_command(svg, 'cover', '40.125', '24.125')
		assert chromium_svg_fractional_background(&other) == none
		owner.finalize()
	}
}

fn test_ordinary_svg_background_paths_keep_the_parent_multisample_policy() {
	command, mut document := fractional_svg_background_test_command('<svg xmlns="http://www.w3.org/2000/svg" width="20" height="12"><path d="M2 2L18 6L2 10Z" fill="black"/></svg>', '20px 12px', '40', '24')
	defer { document.finalize() }
	assert chromium_svg_fractional_background(&command) == none
	assert chromium_svg_background_msaa_rects(command).len > 0
}
