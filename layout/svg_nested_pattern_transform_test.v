module layout

import html
import painting

fn test_nested_pattern_paints_keep_their_coordinates_when_the_outer_target_is_translated() {
	source := $embed_file('@VMODROOT/Tests/Browser/Native/svg-pattern-tile-nested-strokes.html').to_string()
	for scale in [f64(1), 2] {
		mut document := html.parse_document(source)
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		document.set_display_device_pixel_ratio(scale)
		document.set_layout_coordinate_scale(scale)
		root := layout_document_typed_in_viewport(document, 320, 160)
		paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
		assert paths.len == 2
		mut keys := []u64{cap: 2}
		for path in paths {
			outer := path.svg().fill_pattern or { panic('outer pattern') }
			operations := (outer.tile_display_list or { panic('outer tile') }).operations
			assert operations.len == 3
			stroke := operations[0].stroke_pattern or { panic('nested stroke pattern') }
			fill := operations[2].fill_pattern or { panic('nested fill pattern') }
			for pattern in [stroke, fill] {
				stripes := (pattern.tile_display_list or { panic('inner tile') }).operations
				assert stripes.len == 2
				for i, stripe in stripes {
					bounds := painting_clip_path_bounds(stripe.path) or { panic('stripe path') }
					assert stripe.transform.map_rect(bounds) == painting.Rect{f64(i * 8), 0, 8, 10}
				}
			}
			keys << outer.cache_key
		}
		assert keys[0] != 0 && keys[0] == keys[1]
	}
}
