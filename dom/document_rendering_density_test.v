module dom

import math

fn test_rendering_density_override_preserves_media_density_and_layout_coordinates() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	document.set_display_device_pixel_ratio(1)
	document.set_layout_coordinate_scale(1)
	assert document.rendering_device_pixel_ratio() == 1
	document.set_rendering_device_pixel_ratio(2)
	document.set_needs_full_layout_tree_update(false)
	document.set_rendering_device_pixel_ratio(2)
	assert !document.needs_full_layout_tree_update()
	document.set_rendering_device_pixel_ratio(3)
	assert document.needs_full_layout_tree_update()
	document.set_rendering_device_pixel_ratio(2)
	assert document.rendering_device_pixel_ratio() == 2
	assert document.display_device_pixel_ratio() == 1
	assert document.layout_coordinate_scale() == 1
	document.set_display_device_pixel_ratio(1.5)
	assert document.rendering_device_pixel_ratio() == 2
	document.set_rendering_device_pixel_ratio(0)
	assert document.rendering_device_pixel_ratio() == 1.5
}

fn test_invalid_rendering_density_restores_the_presenting_display_default() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	document.set_display_device_pixel_ratio(2)
	for invalid in [f64(0), -1, math.nan(), math.inf(1)] {
		document.set_rendering_device_pixel_ratio(3)
		document.set_rendering_device_pixel_ratio(invalid)
		assert document.rendering_device_pixel_ratio() == 2
		assert document.display_device_pixel_ratio() == 2
	}
}
