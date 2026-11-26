module main

import html
import dom
import os

fn test_windowed_capture_grid_preserves_media_density_and_css_viewport() {
	previous := os.getenv_opt('VOX_CAPTURE_RENDER_DEVICE_PIXEL_RATIO')
	display := html.display_device_pixel_ratio()
	defer {
		html.set_display_device_pixel_ratio(display)
		if value := previous {
			os.setenv('VOX_CAPTURE_RENDER_DEVICE_PIXEL_RATIO', value, true)
		} else {
			os.unsetenv('VOX_CAPTURE_RENDER_DEVICE_PIXEL_RATIO')
		}
	}
	os.setenv('VOX_CAPTURE_RENDER_DEVICE_PIXEL_RATIO', '2', true)
	html.set_display_device_pixel_ratio(1)
	mut document := html.parse_document('<!doctype html><p>Capture grid</p>')
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{ x: 0, y: 0, width: 800, height: 600 })
	before := document.viewport_rect()
	mut app := BrowserApp{ document: document }
	app.sync_layout_coordinate_scale()
	assert document.display_device_pixel_ratio() == 1
	assert html.display_device_pixel_ratio() == 1
	assert document.rendering_device_pixel_ratio() == 2
	assert document.viewport_rect() == before
	$if macos {
		assert document.layout_coordinate_scale() == 2
	}
}
