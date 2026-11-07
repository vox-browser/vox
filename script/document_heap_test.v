module main

import css
import os
import page

// 4chan's catalog parses with a few hundred elements and its scripts build
// the rest. A document that its scripts made large gets the heap capacity
// hint before its first layout; a scripted page that stays small does not.
// This file runs in its own process, so no other test has grown the heap.
fn test_document_made_large_by_its_scripts_gets_the_heap_hint_before_layout() {
	$if gcboehm ? {
		if os.getenv('GC_INITIAL_HEAP_SIZE') != '' || os.getenv('GC_MAXIMUM_HEAP_SIZE') != ''
			|| os.getenv('GC_FREE_SPACE_DIVISOR') != '' {
			return
		}
		// The capacity that platform.prepare_document_heap reserves.
		hinted_capacity := uint(160) * 1024 * 1024
		initial := gc_heap_usage()
		assert initial.heap_size + initial.unmapped_bytes < hinted_capacity
		mut owner := page.Page.create(1)!
		mut app := BrowserApp{page_model: owner, layout_tree_only: true, viewport_width: 320, viewport_height: 200}
		script := '<script>document.getElementById("threads").innerHTML = "<span></span>".repeat(COUNT)</script>'
		app.install_loaded_page(LoadedPage{url: 'https://script-heap.test/small', content_type: 'text/html',
			markup: '<!doctype html><div id="threads"></div>' + script.replace('COUNT', '10')}, false)
		assert app.js_runtime != unsafe { nil }
		assert css.query_selector_all(app.document.as_node(), 'span').len == 10
		small := gc_heap_usage()
		assert small.heap_size + small.unmapped_bytes < hinted_capacity
		app.install_loaded_page(LoadedPage{url: 'https://script-heap.test/large', content_type: 'text/html',
			markup: '<!doctype html><div id="threads"></div>' + script.replace('COUNT', '1200')}, false)
		assert css.query_selector_all(app.document.as_node(), 'span').len == 1200
		large := gc_heap_usage()
		assert large.heap_size + large.unmapped_bytes >= hinted_capacity
	}
}
