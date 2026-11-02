module main

import platform
import css

fn test_preload_document_metadata_and_payload_outlive_the_callers_allocation_owner() {
	loaded := LoadedPage{ url: 'https://preload-lifetime.test/path/page', content_type: 'text/html;charset=utf-8', markup: '<!doctype html><title>Discovery</title><p id="retained">日本語😀</p>' }
	mut caller := platform.new_arena('temporary native caller')
	entry := caller.enter()
	mut document := parse_page_preload_document(loaded, true)
	$if prealloc {
		assert !caller.contains(voidptr(document)), 'discovery document metadata belongs to the temporary caller'
		node := document.get_element_by_id('retained') or { panic('missing child') }
		assert document.native_storage().arena.contains(voidptr(node)), 'discovery DOM payload does not belong to its document'
	}
	caller.leave(entry)
	caller.release()
	defer { retire_native_preload_document(document) }
	assert document.url.serialize() == loaded.url
	assert document.get_element_by_id('retained')?.as_node().text_content()? == '日本語😀'
	assert document.get_window() == none
}

fn test_preload_styles_and_exported_urls_escape_an_unrelated_caller_arena() {
	loaded := LoadedPage{ url: 'https://preload-lifetime.test/', content_type: 'text/html', markup: '<!doctype html><style id="sheet">.hidden{display:none}</style><img src="visible.png"><div class="hidden"><img src="hidden.png"></div>' }
	mut document := parse_page_preload_document(loaded, false)
	defer { retire_native_preload_document(document) }
	urls := document_preload_resource_urls(document, loaded.url)
	mut caller := platform.new_arena('temporary style caller')
	entry := caller.enter()
	foreground := foreground_preload_urls_in_document_storage(document, loaded.url, map[string]PreloadedResource{}, urls, 320, 200)
	element := document.get_element_by_id('sheet') or { panic('missing style') }
	sheet := css.style_sheet_for_owner_node(document, element) or { panic('missing parsed stylesheet') }
	$if prealloc {
		assert document.native_storage().arena.contains(sheet), 'preload stylesheet belongs to the caller instead of the discovery document'
		assert !caller.contains(foreground.data), 'exported URL vector belongs to the temporary caller'
		assert !caller.contains(foreground[0].str), 'exported URL text belongs to the temporary caller'
	}
	caller.leave(entry)
	caller.release()
	assert foreground == ['https://preload-lifetime.test/visible.png']
}
