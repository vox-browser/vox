module main

import dom
import html
import layout

fn test_favicon_svg_completion_keeps_the_html_image_request_and_geometry() {
	address := 'https://decoded-svg.example.test/logo.svg'
	for sizing in ['', 'width="18" height="18"'] {
		mut document := parse_loaded_browser_navigation_document(LoadedPage{
			url:    'https://decoded-svg.example.test/page'
			markup: '<!doctype html><style>body{margin:0}</style><link rel="icon" href="${address}"><img id="logo" src="${address}" ${sizing}><div id="after">after</div>'
		}, dom.URL{ value: 'https://decoded-svg.example.test/page' }, none, none, none, false)
		defer { document.finalize() }
		element := document.get_element_by_id('logo')?
		mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
		model.set_fetch_hook(fn (url dom.URL) !html.DecodedImageData {
			return browser_decode_svg_image(url, '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18"><rect width="18" height="18" fill="red"/></svg>'.bytes())
		})
		model.update_the_image_data(false, false)
		assert model.is_image_available()
		decoded := model.decoded_image_data()?
		assert decoded is html.SVGDecodedImageData
		request := model.current_request()
		load_events := model.event_count('load')
		mut app := BrowserApp{ document: document, background_resource_results: chan PreloadedResource{cap: 1} }
		app.relayout(200, 232)
		before := layout.document_layout_result(document) or { panic('missing image layout') }
		root := before.root
		state := before.state
		rect := document.get_element_by_id('after')?.bounding_client_rect_assuming_layout_clean()
		assert !browser_svg_resources_need_layout(document, {
			address: true
		})
		assert app.paint_commands.any(it.kind == 'paint_nested_display_list')
		// A separate request may return different bytes. The image keeps its
		// own completed response, while backgrounds consume the shell response.
		app.background_resource_results <- PreloadedResource{
			url:  address
			body: '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="32"><rect width="48" height="32" fill="tan"/></svg>'
		}
		app.poll_background_resources()
		after := layout.document_layout_result(document) or { panic('missing retained geometry') }
		assert voidptr(after.root) == voidptr(root)
		assert voidptr(after.state) == voidptr(state)
		assert voidptr(model.current_request()) == voidptr(request)
		assert model.event_count('load') == load_events
		assert model.natural_width() == 18
		assert model.natural_height() == 18
		assert document.get_element_by_id('after')?.bounding_client_rect_assuming_layout_clean() == rect
		assert app.paint_commands.any(it.kind == 'paint_nested_display_list')
	}
}

fn test_decoded_svg_does_not_hide_generated_content_dependency() {
	address := 'https://decoded-svg.example.test/generated.svg'
	mut document := html.parse_document_with_url('<!doctype html><img id="image" src="data:image/svg+xml,%3Csvg%20xmlns=%22http://www.w3.org/2000/svg%22%20width=%2218%22%20height=%2218%22/%3E" style="content:url(${address})">', dom.URL{ value: 'https://decoded-svg.example.test/page' })
	defer { document.finalize() }
	install_static_browser_image_fetch_hooks(document, map[string]bool{})
	mut app := BrowserApp{ document: document }
	app.relayout(200, 232)
	assert browser_svg_resources_need_layout(document, {
		address: true
	})
}
