module layout

import dom
import html
import http
import loader

const remote_svg_source = '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="16" viewBox="0 0 32 16"><image href="images/piece.png" width="4" height="4"/><path d="M0 0H32V16H0Z" fill="green"/></svg>'

fn remote_svg_test_loader() &loader.ResourceLoader {
	if !loader.is_initialized() { return loader.initialize() }
	return loader.ResourceLoader.the()
}

fn test_remote_svg_uses_response_type_natural_dimensions_and_fetched_document_url() {
	mut resource_loader := remote_svg_test_loader()
	resource_loader.register_network_response('https://svg-source.test/assets/sprite?revision=2', loader.NetworkResponse{
		data:    remote_svg_source.bytes()
		headers: [http.Header{ name: 'Content-Type', value: 'IMAGE/SVG+XML; charset=utf-8' }]
	})
	mut document :=
		dom.Document.create(dom.URL{ value: 'https://svg-source.test/pages/index.html' })
	defer { document.finalize() }
	source := '../assets/sprite?revision=2#symbol'
	mut isolated := svg_image_document_for_source(document, source) or {
		panic('remote SVG was not decoded')
	}
	defer { isolated.finalize() }
	assert isolated.url.serialize() == 'https://svg-source.test/assets/sprite?revision=2#symbol'
	assert isolated.encoding_parse_url('images/piece.png')?.serialize() == 'https://svg-source.test/assets/images/piece.png'
	assert isolated.is_svg_image_document()
	size := image_intrinsic_size_for_source(document, source) or {
		panic('remote SVG natural size missing')
	}
	assert size.width?.to_double() == 32
	assert size.height?.to_double() == 16
	assert size.aspect_ratio?.to_double() == 2
}

fn test_remote_svg_background_retains_typed_document_and_intrinsic_geometry() {
	mut resource_loader := remote_svg_test_loader()
	resource_loader.register_network_response('https://svg-background.test/asset', loader.NetworkResponse{
		data:    remote_svg_source.bytes()
		headers: [http.Header{ name: 'content-type', value: 'image/svg+xml' }]
	})
	mut document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:10px;height:10px;background:url("https://svg-background.test/asset") no-repeat}</style><div id="target"></div>')
	defer { document.finalize() }
	root := layout_document_typed_in_viewport(document, 80, 60)
	backgrounds := root.paint_commands().filter(it.kind == 'draw_background_image')
	assert backgrounds.len == 1
	assert backgrounds[0].image().background_svg_document != none
	assert backgrounds[0].image().image_intrinsic_width == 32
	assert backgrounds[0].image().image_intrinsic_height == 16
}

fn test_remote_svg_rejects_declared_wrong_type_failed_responses_and_non_svg_documents() {
	mut resource_loader := remote_svg_test_loader()
	mut document := dom.Document.create(dom.URL{ value: 'https://svg-response.test/' })
	defer { document.finalize() }
	responses := {
		'wrong-type.svg': loader.NetworkResponse{
			data:    remote_svg_source.bytes()
			headers: [http.Header{ name: 'Content-Type', value: 'text/html' }]
		}
		'empty-type.svg': loader.NetworkResponse{
			data:    remote_svg_source.bytes()
			headers: [http.Header{ name: 'Content-Type', value: '' }]
		}
		'missing.svg':    loader.NetworkResponse{
			data:        remote_svg_source.bytes()
			status_code: 404
		}
		'failed.svg':     loader.NetworkResponse{
			data:          remote_svg_source.bytes()
			error_message: 'connection failed'
		}
		'empty.svg':      loader.NetworkResponse{}
		'wrong-root.svg': loader.NetworkResponse{
			data:    '<html xmlns="http://www.w3.org/1999/xhtml"/>'.bytes()
			headers: [http.Header{ name: 'Content-Type', value: 'image/svg+xml' }]
		}
	}
	for name, response in responses {
		address := 'https://svg-response.test/${name}'
		resource_loader.register_network_response(address, response)
		assert svg_image_document_for_source(document, address) == none
	}
	resource_loader.register_network_response('https://svg-response.test/legacy.svg', loader.NetworkResponse{
		data: remote_svg_source.bytes()
	})
	assert svg_image_document_for_source(document, 'https://svg-response.test/legacy.svg') != none
	resource_loader.register_network_response('https://svg-response.test/extensionless', loader.NetworkResponse{
		data: remote_svg_source.bytes()
	})
	assert svg_image_document_for_source(document, 'https://svg-response.test/extensionless') == none
	resource_loader.register_network_response('https://svg-response.test:22/blocked.svg', loader.NetworkResponse{
		data: remote_svg_source.bytes()
	})
	assert svg_image_document_for_source(document, 'https://svg-response.test:22/blocked.svg') == none
}
