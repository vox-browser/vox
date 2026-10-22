module main

import dom
import platform

fn navigation_input_parent_growth(loaded LoadedPage, discovery bool) int {
	before := platform.thread_arena_usage().used
	mut document := if discovery {
		parse_page_preload_document(loaded, false)
	} else {
		parse_loaded_browser_navigation_document(loaded, dom.URL{ value: loaded.url }, none,
			none, none, false)
	}
	mut growth := platform.thread_arena_usage().used - before
	$if prealloc {
		if discovery {
			growth = document.native_storage().arena.usage().used
		}
	}
	defer {
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		document.release_native_storage()
	}
	for _ in 0 .. 8 {
		reuse := platform.begin_thread_scratch('reuse navigation decoded input')
		_ = []u8{len: 262144, init: 0xa5}
		reuse.finish()
	}
	title := document.get_element_by_id('title') or { panic('missing retained title element') }
	title_text := title.text_content() or { panic('missing retained title text') }
	assert title_text == '日本語😀'
	assert document.character_set() == 'UTF-8'
	assert document.url.serialize() == loaded.url
	assert !document.is_scripting_enabled_by_embedder()
	if discovery {
		assert document.get_window() == none
	}
	return growth
}

fn navigation_input_storage_sample(padding int) LoadedPage {
	return LoadedPage{
		url:          'https://navigation.example/decoded'
		content_type: 'text/html;charset=utf-8'
		markup:       ' '.repeat(padding) + '<!doctype html><p id=title>日本語😀</p>'
	}
}

fn test_loaded_navigation_does_not_retain_a_second_decoded_source_in_parent_storage() {
	small := navigation_input_storage_sample(0)
	large := navigation_input_storage_sample(131072)
	_ = navigation_input_parent_growth(small, false)
	small_growth := navigation_input_parent_growth(small, false)
	large_growth := navigation_input_parent_growth(large, false)
	$if prealloc {
		assert large_growth < small_growth + 8192, '${small_growth}, ${large_growth}'
	}
}

fn test_preload_navigation_owns_source_and_encoding_after_decoded_input_retires() {
	small := navigation_input_storage_sample(0)
	large := navigation_input_storage_sample(131072)
	_ = navigation_input_parent_growth(small, true)
	small_growth := navigation_input_parent_growth(small, true)
	large_growth := navigation_input_parent_growth(large, true)
	$if prealloc {
		// Discovery storage retains the parser's original source once. Leading
		// whitespace creates no DOM nodes or other source-sized retained data.
		assert large_growth < small_growth + large.markup.len - small.markup.len + 8192, '${small_growth}, ${large_growth}'
	}
}
