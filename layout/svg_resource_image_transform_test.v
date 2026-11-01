module layout

import html
import math
import painting

fn test_scaled_svg_viewport_keeps_pattern_image_coordinates_in_target_user_space() {
	source := 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAD0lEQVR4nGNgaGBAIOI4ANA0CAF5jtVRAAAAAElFTkSuQmCC'
	mut document := html.parse_document('<!doctype html><svg width="152" height="91.2" viewBox="0 0 200 120"><defs><image id="image" width="600" height="360" href="${source}"/><pattern id="tile" width="1" height="1" patternContentUnits="objectBoundingBox"><use href="#image" transform="scale(.001666666666666667 .002777777777777778)"/></pattern></defs><rect width="200" height="120" fill="url(#tile)"/></svg>')
	defer { document.finalize() }
	root := layout_document_typed_in_viewport(document, 240, 160)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	pattern := paths[0].svg().fill_pattern or { panic('pattern') }
	operations := (pattern.tile_display_list or { panic('tile') }).operations.filter(it.kind == .image)
	bounds := operations[0].transform.map_rect(operations[0].image_rect)
	assert math.abs(bounds.x) < 0.001
	assert math.abs(bounds.y) < 0.001
	assert math.abs(bounds.width - 200) < 0.001
	assert math.abs(bounds.height - 120) < 0.001
}

fn test_pattern_images_share_the_resource_and_use_transforms_of_vector_paths() {
	raster := 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAD0lEQVR4nGNgaGBAIOI4ANA0CAF5jtVRAAAAAElFTkSuQmCC'
	vector := "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 600 360'%3E%3Crect width='600' height='360' fill='green'/%3E%3C/svg%3E"
	for source in [raster, vector] {
		mut document := html.parse_document('<!doctype html><svg width="200" height="120" viewBox="0 0 200 120"><defs><image id="image" width="600" height="360" href="${source}"/><pattern id="tile" width="1" height="1" patternContentUnits="objectBoundingBox"><use href="#image" transform="scale(.001666666666666667 .002777777777777778)"/></pattern></defs><rect x="20" y="10" width="160" height="96" fill="url(#tile)"/></svg>')
		defer { document.finalize() }
		root := layout_document_typed_in_viewport(document, 240, 160)
		paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
		assert paths.len == 1
		pattern := paths[0].svg().fill_pattern or { panic('pattern') }
		operations := (pattern.tile_display_list or { panic('tile') }).operations
		images := operations.filter(it.kind in [.image, .path])
		assert images.len == 1
		operation := images[0]
		bounds := if operation.kind == .image {
			operation.transform.map_rect(operation.image_rect)
		} else {
			operation.transform.map_rect(painting_clip_path_bounds(operation.path) or { panic('path bounds') })
		}
		assert math.abs(bounds.x) < 0.001
		assert math.abs(bounds.y) < 0.001
		assert math.abs(bounds.width - 160) < 0.001
		assert math.abs(bounds.height - 96) < 0.001
	}
}

fn test_pattern_raster_coordinates_are_normalized_once_after_the_image_transform() {
	source := 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAD0lEQVR4nGNgaGBAIOI4ANA0CAF5jtVRAAAAAElFTkSuQmCC'
	mut document := html.parse_document('<!doctype html><svg width="200" height="120"><defs><pattern id="tile" width="100" height="80" patternUnits="userSpaceOnUse"><g transform="translate(7 9)"><image x="10" y="20" width="30" height="20" transform="scale(2)" href="${source}"/></g></pattern></defs><rect width="200" height="120" fill="url(#tile)"/></svg>')
	defer { document.finalize() }
	root := layout_document_typed_in_viewport(document, 240, 160)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	pattern := paths[0].svg().fill_pattern or { panic('pattern') }
	operations := (pattern.tile_display_list or { panic('tile') }).operations.filter(it.kind == .image)
	assert operations.len == 1
	assert operations[0].transform.map_rect(operations[0].image_rect) == painting.Rect{27, 49, 60, 40}
}
