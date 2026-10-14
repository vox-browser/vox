module main

import html

fn test_completed_background_svg_rebuilds_retained_layout_and_paint() {
	address := 'https://svg-cache.example.test/sprite.svg?version=1'
	mut document :=
		html.parse_document('<!doctype html><style>body{margin:0}#target{width:30px;height:20px;background-image:url("${address}")}</style><div id="target"></div>')
	mut app := BrowserApp{
		document:                    document
		background_resource_results: chan PreloadedResource{cap: 2}
		background_resource_pending: {
			address: true
		}
	}
	app.relayout(200, 232)
	before := document.layout_root
	assert !app.paint_commands.any(it.background_svg_document != none)
	app.background_resource_results <- PreloadedResource{
		url:  address
		body: '<svg xmlns="http://www.w3.org/2000/svg" width="30" height="20"><rect width="30" height="20" fill="red"/></svg>'
	}
	app.poll_background_resources()
	assert address !in app.background_resource_pending
	assert app.resource_cache[address].error == ''
	assert document.layout_root != before
	assert app.paint_commands.any(it.background_svg_document != none)
	first_svg := app.paint_commands.filter(it.background_svg_document != none)[0].background_svg_document or {
		panic('missing first SVG document')
	}

	first_rect := first_svg.document_element() or { panic('missing first SVG root') }
	assert first_rect.as_node().first_child()?.as_element()?.get_attribute_value('fill') == 'red'
	first_body := app.resource_cache[address].body
	app.background_resource_results <- PreloadedResource{
		url:  address
		body: first_body.replace('red', 'tan')
	}
	app.poll_background_resources()
	assert app.resource_cache[address].body.len == first_body.len
	second_svg := app.paint_commands.filter(it.background_svg_document != none)[0].background_svg_document or {
		panic('missing replacement SVG document')
	}

	assert second_svg != first_svg
	second_rect := second_svg.document_element() or { panic('missing replacement SVG root') }
	assert second_rect.as_node().first_child()?.as_element()?.get_attribute_value('fill') == 'tan'
	assert first_rect.as_node().first_child()?.as_element()?.get_attribute_value('fill') == 'red'
	app.background_resource_results <- PreloadedResource{
		url:   address
		error: 'replacement failed'
	}
	app.poll_background_resources()
	assert !app.paint_commands.any(it.background_svg_document != none)
	assert second_rect.as_node().first_child()?.as_element()?.get_attribute_value('fill') == 'tan'
	after := document.layout_root
	app.background_resource_results <- PreloadedResource{
		url:   'https://svg-cache.example.test/failed.svg'
		error: 'unavailable'
	}
	app.poll_background_resources()
	assert document.layout_root == after
	assert !publish_browser_svg_resource(PreloadedResource{
		url:  'https://svg-cache.example.test/picture.png'
		body: 'PNG'
	})
	assert !publish_browser_svg_resource(PreloadedResource{
		url:  'file:///sprite.svg'
		body: '<svg/>'
	})
	assert document.cached_display_list() != none
}
