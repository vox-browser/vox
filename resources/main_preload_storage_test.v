module main

import css
import platform

fn test_preload_styles_follow_the_discovery_document_and_export_owned_urls() {
	loaded := LoadedPage{
		url: 'https://preload-storage.test/'
		markup: '<!doctype html><style id="sheet">.hidden{display:none}</style><img id="visible" src="visible.png"><div class="hidden"><img src="hidden.png"></div>'
		content_type: 'text/html'
	}
	mut document := parse_page_preload_document(loaded, false)
	assert document.font_rendering_policy() == .chromium
	assert document.font_size_keyword_policy() == .chromium
	owner := document.native_storage()
	base := document.base_url().serialize()
	urls := document_preload_resource_urls(document, base)
	foreground := foreground_preload_urls_in_document_storage(document, base,
		map[string]PreloadedResource{}, urls, 320, 200)
	assert foreground == ['https://preload-storage.test/visible.png']
	style_element := document.get_element_by_id('sheet') or { panic('missing stylesheet') }
	sheet := css.style_sheet_for_owner_node(document, style_element) or { panic('missing parsed stylesheet') }
	$if prealloc {
		assert owner.arena.contains(sheet)
		assert !owner.arena.contains(foreground.data)
		assert !owner.arena.contains(foreground[0].str)
	}
	retire_native_preload_document(document)
	$if prealloc { assert owner.arena.usage().used == 0 }
	mut scratch := platform.begin_thread_scratch('retired preload reuse')
	_ = 'overwrite retired parser blocks'.repeat(65536)
	scratch.finish()
	assert foreground == ['https://preload-storage.test/visible.png']
}
