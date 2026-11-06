module main

import dom
import encoding.base64
import html
import math

fn test_svg_image_chromium_layout_keeps_the_unsnapped_container_size() {
	source := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 139 150"><path d="M0 0L139 150"/></svg>'
	encoded_source := base64.encode(source.bytes())
	for chromium in [false, true] {
		markup := '<!doctype html>' +
			if chromium { '<base href="https://asgardpvp.com/">' } else { '' } +
			'<style>body{margin:0}img{display:block;width:80px;height:auto}</style><img id="picture" src="data:image/svg+xml;base64,' + encoded_source + '">'
		mut document := parse_loaded_browser_navigation_document(LoadedPage{
			url:    'about:blank'
			markup: markup
		}, dom.url_about_blank(), none, none, none, false)
		defer { document.finalize() }
		document.set_font_rendering_policy(if chromium { .chromium } else { .libweb })
		install_static_browser_image_fetch_hooks(document, map[string]bool{})
		image := unsafe { &dom.HTMLImageElement(document.get_element_by_id('picture')?) }
		model := html.html_image_element_model_for_dom_element(image)
		assert model.is_image_available()
		assert model.event_count('load') == 1
		assert model.event_count('error') == 0
		mut app := BrowserApp{
			document: document
		}
		app.relayout(800, 680)
		images := app.paint_commands.filter(it.kind == 'paint_nested_display_list')
		assert images.len == 1
		paintable := images[0].nested_viewport_paintable?
		scale := document.layout_coordinate_scale()
		rect := paintable.nested_rect?
		assert rect.width == 80 * scale
		assert rect.height == math.round(86.328125 * scale)
		if chromium {
			container := paintable.nested_layout_size?
			assert container.width == 80 * scale
			assert container.height == 86.328125 * scale
		} else {
			assert paintable.nested_layout_size == none
		}
	}
}
