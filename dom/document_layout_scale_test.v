module dom

import math

fn test_layout_scale_preserves_the_css_viewport_and_invalidates_only_on_change() {
	mut document := Document.create(url_about_blank())
	viewport := Rect{5, 7, 800, 600}
	document.set_viewport_rect(viewport)
	assert document.layout_coordinate_scale() == 1
	assert document.layout_viewport_rect() == viewport
	document.set_needs_full_layout_tree_update(false)
	document.set_layout_coordinate_scale(1)
	assert !document.needs_full_layout_tree_update()
	document.set_layout_coordinate_scale(2)
	assert document.needs_full_layout_tree_update()
	assert document.viewport_rect() == viewport
	assert document.layout_viewport_rect() == Rect{10, 14, 1600, 1200}
	document.set_needs_full_layout_tree_update(false)
	document.set_layout_coordinate_scale(2)
	assert !document.needs_full_layout_tree_update()
	document.set_layout_coordinate_scale(1.5)
	assert document.needs_full_layout_tree_update()
	assert document.layout_viewport_rect() == Rect{7.5, 10.5, 1200, 900}
}

fn test_invalid_layout_scales_return_to_css_coordinates() {
	mut document := Document.create(url_about_blank())
	document.set_viewport_rect(Rect{1, 2, 3, 4})
	for value in [f64(0), -1, math.nan(), math.inf(1)] {
		document.set_layout_coordinate_scale(2)
		document.set_layout_coordinate_scale(value)
		assert document.layout_coordinate_scale() == 1
		assert document.layout_viewport_rect() == document.viewport_rect()
	}
}
