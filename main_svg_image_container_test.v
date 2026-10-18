module main

import dom
import encoding.base64

fn test_svg_image_chromium_layout_keeps_the_unsnapped_container_size() {
	source := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 139 150"><path d="M0 0L139 150"/></svg>'
	for chromium in [false, true] {
		markup := '<!doctype html>' +
			if chromium { '<base href="https://asgardpvp.com/">' } else { '' } +
			'<style>body{margin:0}img{display:block;width:80px;height:auto}</style><img src="data:image/svg+xml;base64,${base64.encode(source.bytes())}">'
		mut document := parse_loaded_browser_navigation_document(LoadedPage{
			url:    'about:blank'
			markup: markup
		}, dom.url_about_blank(), none, none, none, false)
		defer { document.finalize() }
		install_static_browser_image_fetch_hooks(document, map[string]bool{})
		mut app := BrowserApp{
			document: document
		}
		app.relayout(800, 680)
		images := app.paint_commands.filter(it.kind == 'paint_nested_display_list')
		assert images.len == 1
		paintable := images[0].nested_viewport_paintable?
		assert paintable.nested_rect?.height == 86
		if chromium {
			container := paintable.nested_layout_size?
			assert container.width == 80
			assert container.height == 86.328125
		} else {
			assert paintable.nested_layout_size == none
		}
	}
}
