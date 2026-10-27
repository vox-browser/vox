module html

import css
import dom

fn canvas_svg_test_context(filters string) (&dom.Document, &CanvasRenderingContext2D) {
	mut document := parse_document_with_url('<!doctype html><svg xmlns="http://www.w3.org/2000/svg"><defs>${filters}</defs></svg><canvas id="canvas" width="32" height="24"></canvas>',
		dom.URL{ value: 'https://canvas.test/page' })
	css.install_document_style_hook(document)
	canvas := unsafe { &dom.HTMLCanvasElement(document.get_element_by_id('canvas') or { panic('canvas') }) }
	context := html_canvas_element_get_context(canvas, '2d', none) or { panic(err) }
	return document, context
}

fn canvas_svg_test_pixel(mut context CanvasRenderingContext2D, x int, y int) []u8 {
	return (context.get_image_data(x, y, 1, 1, none) or { panic(err) }).data()
}

fn test_canvas_svg_filter_resolves_urls_and_preserves_css_chain_order() {
	document, mut context := canvas_svg_test_context('<filter id="shift"><feOffset dx="4"/></filter>')
	context.set_filter('invert(1) url("#shift") opacity(.5)')
	assert context.drawing_state.filter_functions.len == 3
	assert context.drawing_state.filter_functions[1].reference == 'https://canvas.test/page#shift'
	context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{ r: 255, a: 255 })
	context.fill_rect(2, 4, 4, 4)
	assert canvas_svg_test_pixel(mut context, 3, 5)[3] == 0
	assert canvas_svg_test_pixel(mut context, 7, 5) == [u8(0), 255, 255, 128]
	// A same-origin external document is still a different resource.
	assert canvas_svg_filter_graph(document, 'https://canvas.test/other#shift', 32, 24) == none
	assert canvas_svg_filter_graph(document, 'https://canvas.test/page#missing', 32, 24) == none
	mut detached := OffscreenCanvas.create(8, 8) or { panic(err) }
	mut detached_context := detached.get_context(.canvas_2d, none) or { panic(err) }
	detached_context.set_filter('url("#shift") opacity(.5)')
	assert detached_context.drawing_state.filter_functions.len == 1
}

fn test_canvas_svg_filter_uses_live_resource_and_style_changes_after_save() {
	document, mut context := canvas_svg_test_context('<filter id="live" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="0"/><feOffset id="offset" dx="2"/></filter>')
	context.set_filter('url("#live")')
	context.save()
	context.set_filter('none')
	context.restore()
	context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{ r: 255, a: 255 })
	context.fill_rect(0, 2, 2, 2)
	assert canvas_svg_test_pixel(mut context, 2, 2) == [u8(255), 0, 0, 255]
	mut offset := document.get_element_by_id('offset') or { panic('offset') }
	offset.set_attribute_value('dx', '8')
	context.fill_rect(0, 8, 2, 2)
	assert canvas_svg_test_pixel(mut context, 2, 8)[3] == 0
	assert canvas_svg_test_pixel(mut context, 8, 8) == [u8(255), 0, 0, 255]
	mut filter := document.get_element_by_id('live') or { panic('filter') }
	filter.set_attribute_value('style', 'color-interpolation-filters:linearRGB')
	graph := canvas_svg_filter_graph(document, 'https://canvas.test/page#live', 32, 24) or { panic('graph') }
	assert graph.nodes.first().kind == .to_linear_rgb
	assert graph.nodes.last().kind == .to_srgb
}

fn test_canvas_svg_filter_merge_keeps_repeated_and_named_inputs() {
	_, mut context := canvas_svg_test_context('<filter id="merge" x="0" y="0" width="1" height="1" color-interpolation-filters="sRGB"><feOffset dx="4" result="moved"/><feMerge><feMergeNode in="SourceGraphic"/><feMergeNode in="moved"/><feMergeNode in="moved"/></feMerge></filter>')
	context.set_filter('url("#merge")')
	context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{ r: 255, a: 128 })
	context.fill_rect(2, 4, 2, 2)
	assert canvas_svg_test_pixel(mut context, 2, 4) == [u8(255), 0, 0, 128]
	assert canvas_svg_test_pixel(mut context, 6, 4) == [u8(255), 0, 0, 192]
	assert canvas_svg_test_pixel(mut context, 10, 4)[3] == 0
}

fn test_canvas_svg_filter_blur_morphology_and_empty_merge_rasterize() {
	_, mut context := canvas_svg_test_context('<filter id="backdrop" x="0" y="0" width="1" height="1"><feGaussianBlur stdDeviation="2" result="blur"/><feMorphology operator="dilate" radius="0"/><feMerge><feMergeNode/><feMergeNode in="blur"/></feMerge></filter><filter id="empty"><feMerge/></filter><filter id="grow" color-interpolation-filters="sRGB"><feMorphology operator="dilate" radius="2"/></filter>')
	context.set_filter('url("#backdrop")')
	context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{ r: 255, a: 255 })
	context.fill_rect(12, 8, 4, 4)
	blurred := canvas_svg_test_pixel(mut context, 10, 9)
	assert blurred[0] == 255 && blurred[3] > 0 && blurred[3] < 255
	context.clear_rect(0, 0, 32, 24)
	context.set_filter('url("#empty")')
	context.fill_rect(0, 0, 32, 24)
	assert canvas_svg_test_pixel(mut context, 16, 12)[3] == 0
	context.set_filter('url("#grow")')
	context.fill_rect(12, 8, 4, 4)
	assert canvas_svg_test_pixel(mut context, 10, 9) == [u8(255), 0, 0, 255]
	assert canvas_svg_test_pixel(mut context, 9, 9)[3] == 0
}

fn test_canvas_svg_filter_coordinates_and_object_bounds_use_canvas_bitmap() {
	_, mut context := canvas_svg_test_context('<filter id="shift" x="0" y="0" width="1" height="1"><feOffset dx="4"/></filter><filter id="clip" x="50%" y="0" width="50%" height="100%"><feOffset/></filter><filter id="relative" primitiveUnits="objectBoundingBox"><feOffset dx=".25"/></filter>')
	context.set_filter('url("#shift")')
	context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{ r: 255, a: 255 })
	context.drawing_state.transform = CanvasAffineTransform{ a: 2, d: 2 }
	context.fill_rect(1, 2, 2, 2)
	assert canvas_svg_test_pixel(mut context, 6, 4) == [u8(255), 0, 0, 255]
	assert canvas_svg_test_pixel(mut context, 10, 4)[3] == 0
	context.drawing_state.transform = CanvasAffineTransform{}
	context.clear_rect(0, 0, 32, 24)
	context.set_filter('url("#clip")')
	context.fill_rect(8, 0, 16, 8)
	assert canvas_svg_test_pixel(mut context, 12, 4)[3] == 0
	assert canvas_svg_test_pixel(mut context, 16, 4)[3] == 255
	context.clear_rect(0, 0, 32, 24)
	context.set_filter('url("#relative")')
	context.fill_rect(1, 2, 2, 2)
	assert canvas_svg_test_pixel(mut context, 9, 2) == [u8(255), 0, 0, 255]
}

fn test_canvas_svg_filter_draw_image_and_unresolved_resource_fallback() {
	_, mut context := canvas_svg_test_context('<filter id="alpha" color-interpolation-filters="sRGB"><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 1 0"/></filter><filter id="unsupported"><feFlood flood-color="blue"/></filter><filter id="subregion"><feOffset width="2"/></filter>')
	mut image := ImageBitmap.create()
	image.set_bitmap(&dom.Bitmap_{ width: 1, height: 1, pitch: 4, alpha_type: 1, data: [
		u8(255),
		0,
		0,
		255,
	] })
	for i, filter in ['url("#alpha")', 'url("#unsupported") opacity(.5)',
		'url("#subregion") opacity(.5)'] {
		context.set_filter(filter)
		context.draw_image_internal(CanvasDrawImageRequest{
			image:              ImageBitmapCanvasSource{ value: image }
			source_width:       1
			source_height:      1
			destination_x:      f64(i * 4)
			destination_width:  4
			destination_height: 4
		}) or { panic(err) }
	}
	assert canvas_svg_test_pixel(mut context, 1, 1) == [u8(0), 255, 0, 255]
	assert canvas_svg_test_pixel(mut context, 5, 1) == [u8(255), 0, 0, 128]
	assert canvas_svg_test_pixel(mut context, 9, 1) == [u8(255), 0, 0, 128]
}
