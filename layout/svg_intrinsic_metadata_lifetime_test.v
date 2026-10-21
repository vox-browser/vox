module layout

import dom
import html
import http
import loader
import platform

fn test_svg_intrinsic_scan_does_not_copy_the_document_tail() {
	source := '<!--prefix--><svg width="32" height="16" viewBox="0 0 32 16">' + ' '.repeat(1024 * 1024) + '</svg>'
	before := platform.thread_arena_usage().used
	size := svg_image_natural_size(source)?
	assert size.width?.to_double() == 32
	assert size.height?.to_double() == 16
	assert size.aspect_ratio?.to_double() == 2
	$if prealloc {
		assert platform.thread_arena_usage().used - before < 4096
	}
	assert svg_image_natural_size('<svg width="32"') == none
}

fn test_background_intrinsic_dimensions_use_the_retained_svg_resource() {
	mut embedder := html.parse_document('<!doctype html>')
	defer { embedder.finalize() }
	address := 'https://retained-svg-metadata.test/image.svg'
	source := '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="16"/>'
	mut isolated := parse_svg_image_document(SVGImageSource{ source: source, url: dom.URL{ value: address } }, 'light', embedder)?
	defer { isolated.finalize() }
	mut resource_loader := if loader.is_initialized() {
		loader.ResourceLoader.the()
	} else {
		loader.initialize()
	}
	// A later response must not supply metadata for an earlier decoded image.
	resource_loader.register_network_response(address, loader.NetworkResponse{
		data:    '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="48"/>'.bytes()
		headers: [http.Header{ name: 'Content-Type', value: 'image/svg+xml' }]
	})
	before := platform.thread_arena_usage().used
	for _ in 0 .. 8 {
		width, height := background_svg_intrinsic_dimensions(isolated)
		assert width == 32 && height == 16
	}
	$if prealloc {
		assert platform.thread_arena_usage().used - before < 8192
	}
	width, height := background_svg_intrinsic_dimensions(none)
	assert width == 0 && height == 0
}

fn test_background_intrinsic_optional_dimensions_preserve_ratio_transfer() {
	mut embedder := html.parse_document('<!doctype html>')
	defer { embedder.finalize() }
	attributes := ['viewBox="0 0 200 100"', 'width="100" viewBox="0 0 200 100"',
		'height="40" viewBox="0 0 200 100"', 'width="100"', '',
		'width="100%" height="100%" viewBox="0 0 200 100"',
		'width="100" height="40" viewBox="0 0 200 100"']
	widths := [f64(200), 100, 80, 100, 0, 200, 100]
	heights := [f64(100), 50, 40, 0, 0, 100, 40]
	for i, attrs in attributes {
		mut isolated := parse_svg_image_document(SVGImageSource{
			source: '<svg xmlns="http://www.w3.org/2000/svg" ' + attrs + '/>'
			url:    dom.URL{ value: 'https://optional-svg-metadata.test/image.svg' }
		}, 'light', embedder)?
		width, height := background_svg_intrinsic_dimensions(isolated)
		assert width == widths[i], attrs
		assert height == heights[i], attrs
		isolated.finalize()
	}
}
