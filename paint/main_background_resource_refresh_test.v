module main

import css
import dom
import html
import layout

fn test_polled_svg_background_completion_keeps_paint_projection_in_mixed_and_favicon_batches() {
	for batch in ['svg', 'mixed', 'favicon'] {
		address := 'https://polled-background.example.test/${batch}.svg'
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{width:40px;height:20px;background:url("${address}")}span{background:url("${address}")}</style><div id="target"></div><span>inline background</span><p>untouched text</p><img id="logo" src="https://polled-background.example.test/logo.svg" width="18" height="18">')
		defer { document.finalize() }
		_ = html.WindowModel.create_top_level(document, none, 'polled-svg-background')!
		logo := document.get_element_by_id('logo')?
		mut logo_model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(logo) })
		logo_model.set_fetch_hook(fn (url dom.URL) !html.DecodedImageData {
			return browser_decode_svg_image(url, '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18"><path d="M0 0H18V18H0Z" fill="orange"/></svg>'.bytes())
		})
		logo_model.update_the_image_data(false, false)
		assert logo_model.is_image_available()
		logo_request := logo_model.current_request()
		mut app := BrowserApp{
			document:                    document
			background_resource_results: chan PreloadedResource{cap: 2}
		}
		app.relayout(200, 232)
		before := layout.document_layout_result(document) or { panic('missing layout') }
		root := voidptr(before.root)
		state := voidptr(before.state)
		children := voidptr(before.paint_tree.children.data)
		target := document.get_element_by_id('target')?
		box := before.paint_tree.find_box(i64(target.as_node().unique_id()))?
		logo_box := before.paint_tree.find_box(i64(logo.as_node().unique_id()))?
		logo_document := logo_box.media().nested_viewport_document?
		assert app.paint_commands.any(it.kind == 'paint_nested_display_list')
		hit := document.element_from_point(2, 2)?
		assert before.hit_test_display_list_is_valid
		for fill in ['red', 'tan'] {
			revision := document.paint_content_revision()
			app.background_resource_results <- PreloadedResource{
				url:  address
				body: '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10"><rect width="20" height="10" fill="${fill}"/></svg>'
			}
			if batch == 'mixed' {
				app.background_resource_results <- PreloadedResource{
					url:  'https://polled-background.example.test/raster.png'
					body: 'completed raster bytes'
				}
			}
			if batch == 'favicon' {
				// A favicon fetch publishes new loader bytes without replacing the
				// HTML image request's independently decoded SVG document.
				app.background_resource_results <- PreloadedResource{
					url:  'https://polled-background.example.test/logo.svg'
					body: '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18"><path d="M0 0H18V18H0Z" fill="blue"/></svg>'
				}
			}
			app.poll_background_resources()
			after := layout.document_layout_result(document) or { panic('lost layout') }
			assert voidptr(after.root) == root
			assert voidptr(after.state) == state
			assert voidptr(after.paint_tree.children.data) == children
			retained_box := after.paint_tree.find_box(i64(target.as_node().unique_id()))?
			assert retained_box.layout_handle == box.layout_handle
			assert after.hit_test_display_list_is_valid
			assert voidptr(document.element_from_point(2, 2)?) == voidptr(hit)
			assert document.paint_content_revision() > revision
			assert document.cached_display_list() != none
			assert voidptr(logo_box.media().nested_viewport_document?) == voidptr(logo_document)
			assert voidptr(logo_model.current_request()) == voidptr(logo_request)
			assert app.paint_commands.any(it.kind == 'paint_nested_display_list')
			layers := app.paint_commands.filter(it.kind == 'draw_background_image'
				&& (it.image().background_svg_document != none
					|| it.image().background_static_svg_resource != none))
			assert layers.len >= 2
			for layer in layers {
				if svg_document := layer.image().background_svg_document {
					assert svg_document.document_element()?.as_node().first_child()?.as_element()?.get_attribute_value('fill') == fill
				} else {
					commands := svg_background_paint_commands(layer.image_data, 20, 10)?
					expected := if fill == 'red' {
						css.Color.rgb(255, 0, 0)
					} else {
						css.Color.rgb(210, 180, 140)
					}
					mut found_fill := false
					for command in commands {
						if color := command.retained_svg_fill_color() {
							if color == expected {
								found_fill = true
								break
							}
						}
					}
					assert found_fill
				}
			}
		}
	}
}

fn test_polled_svg_completion_patches_a_pending_repaint_without_replacing_owners() {
	address := 'https://polled-background.example.test/pending.svg'
	mut document := html.parse_document('<!doctype html><div id="target" style="width:40px;height:20px;background:url(${address})"></div>')
	defer { document.finalize() }
	mut app := BrowserApp{
		document:                    document
		background_resource_results: chan PreloadedResource{cap: 1}
	}
	app.relayout(200, 232)
	before := layout.document_layout_result(document) or { panic('missing layout') }
	children := voidptr(before.paint_tree.children.data)
	document.set_needs_repaint_with_invalidation(.paint_commands)
	app.background_resource_results <- PreloadedResource{
		url:  address
		body: '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10"><rect width="20" height="10" fill="red"/></svg>'
	}
	app.poll_background_resources()
	after := layout.document_layout_result(document) or { panic('lost layout') }
	assert voidptr(after.paint_tree.children.data) == children
	assert app.paint_commands.any(it.image().background_svg_document != none
		|| it.image().background_static_svg_resource != none)
	assert document.cached_display_list() != none
}
