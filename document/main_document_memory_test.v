module main

import os
import page

fn test_medium_document_install_does_not_preallocate_gigabytes() {
	mut owner := page.Page.create(1)!
	mut app := BrowserApp{
		page_model: owner
		script_policy: .disabled
		viewport_width: 320
		viewport_height: 200
	}
	before := gc_heap_usage().heap_size
	// Cross the old 1,024-element threshold with inexpensive hidden content.
	// Document size alone must not cause a multi-gigabyte allocation.
	markup := '<!doctype html><div hidden>' + '<span></span>'.repeat(1100)
		+ '</div><p id="visible">Visible content</p>'
	app.install_loaded_page(LoadedPage{
		url: 'https://memory.example/'
		markup: markup
		content_type: 'text/html'
	}, false)
	mut document := app.document
	defer { document.finalize() }
	assert document.get_element_by_id('visible')?.as_node().text_content()? == 'Visible content'
	assert app.paint_commands.any(it.text.contains('Visible content'))
	$if gcboehm ? {
		if os.getenv('GC_INITIAL_HEAP_SIZE') == '' && os.getenv('GC_MAXIMUM_HEAP_SIZE') == '' {
			assert gc_is_enabled()
			// Leave ample space for font/filter startup and ordinary heap growth.
			assert gc_heap_usage().heap_size < before + uint(512) * 1024 * 1024
		}
	}
	gc_collect()
	assert document.get_element_by_id('visible')?.as_node().text_content()? == 'Visible content'
}
