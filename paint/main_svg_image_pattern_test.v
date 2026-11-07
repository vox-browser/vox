module main

import painting

fn test_single_image_svg_patterns_require_a_complete_supported_paint_record() {
	image := painting.SVGMaskPaintOperation{
		kind: .image
		image_url: 'data:image/png;base64,test'
	}
	style := painting.SVGPatternPaintStyle{
		tile_rect: painting.Rect{0, 0, 200, 120}
		tile_display_list: &painting.SVGPatternDisplayList{
			operations: [image]
		}
	}
	assert (single_svg_pattern_image(&style) or { panic('image') }).image_url == image.image_url
	for unsupported in [
		painting.SVGPatternPaintStyle{...style, tile_rect: painting.Rect{0, 0, 0, 120}},
		painting.SVGPatternPaintStyle{...style, tile_rect: painting.Rect{0, 0, 8193, 120}},
		painting.SVGPatternPaintStyle{...style, pattern_transform: painting.Affine{a: 2}},
		painting.SVGPatternPaintStyle{...style, tile_display_list: none},
		painting.SVGPatternPaintStyle{...style, tile_display_list: &painting.SVGPatternDisplayList{}},
		painting.SVGPatternPaintStyle{...style, tile_display_list: &painting.SVGPatternDisplayList{
			operations: [painting.SVGMaskPaintOperation{kind: .begin_filter}, image]
		}},
		painting.SVGPatternPaintStyle{...style, tile_display_list: &painting.SVGPatternDisplayList{
			operations: [painting.SVGMaskPaintOperation{kind: .path}]
		}},
	] {
		assert single_svg_pattern_image(&unsupported) == none
	}
}
