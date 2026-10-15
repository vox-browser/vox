module main

import dom
import os
import time

fn navigation_cp1251_title() string {
	// "Горячее Пикабу" as supplied by a windows-1251 HTTP response.
	return [u8(0xc3), 0xee, 0xf0, 0xff, 0xf7, 0xe5, 0xe5, 0x20, 0xcf, 0xe8, 0xea, 0xe0, 0xe1, 0xf3].bytestr()
}

fn test_native_http_navigation_decodes_transport_charset_before_the_tokenizer() {
	address := dom.URL{
		value: 'https://pikabu.ru/'
	}
	loaded := LoadedPage{
		url:          address.serialize()
		markup:       '<!doctype html><meta charset=utf-8><p id=title>${navigation_cp1251_title()}</p>'
		content_type: 'Text/HTML; Charset="windows-1251"'
	}
	mut document :=
		parse_loaded_browser_navigation_document(loaded, address, none, none, none, true)
	defer { document.finalize() }
	assert document.get_element_by_id('title')?.text_content()? == 'Горячее Пикабу'
	assert document.character_set() == 'windows-1251'
	assert document.url.serialize() == loaded.url
}

fn test_native_http_navigation_bom_overrides_transport_and_meta_charset() {
	address := dom.URL{
		value: 'https://pikabu.ru/'
	}
	loaded := LoadedPage{
		url:          address.serialize()
		markup:       '\xef\xbb\xbf<!doctype html><meta charset=windows-1251><p id=title>Пикабу ✓</p>'
		content_type: 'text/html;charset=windows-1251'
	}
	mut document := parse_loaded_browser_navigation_document(loaded, address, none, none, none,
		false)
	defer { document.finalize() }
	assert document.get_element_by_id('title')?.text_content()? == 'Пикабу ✓'
	assert document.character_set() == 'UTF-8'
	assert !document.is_scripting_enabled_by_embedder()
}

fn test_native_http_navigation_sniffs_meta_without_a_valid_transport_charset() {
	for content_type in ['text/html', 'text/html;charset=not-an-encoding'] {
		address := dom.URL{
			value: 'https://pikabu.ru/'
		}
		loaded := LoadedPage{
			url:          address.serialize()
			markup:       '<!doctype html><meta charset=windows-1251><p id=title>${navigation_cp1251_title()}</p>'
			content_type: content_type
		}
		mut document :=
			parse_loaded_browser_navigation_document(loaded, address, none, none, none, true)
		assert document.get_element_by_id('title')?.text_content()? == 'Горячее Пикабу'
		assert document.character_set() == 'windows-1251'
		document.finalize()
	}
}

fn test_native_unicode_local_and_literal_navigation_are_not_redecoded() {
	for address in ['file:///tmp/pikabu.html', 'about:blank'] {
		loaded := LoadedPage{
			url:          address
			markup:       '<!doctype html><meta charset=windows-1251><p id=title>Пикабу ✓</p>'
			content_type: 'text/html;charset=windows-1251'
		}
		mut document := parse_loaded_browser_navigation_document(loaded, dom.URL{ value: address },
			none, none, none, true)
		assert document.get_element_by_id('title')?.text_content()? == 'Пикабу ✓'
		document.finalize()
	}
}

fn test_native_preload_discovery_decodes_non_ascii_resource_attributes() {
	image_path := [u8(0xf4), 0xee, 0xf2, 0xee].bytestr() + '.png'
	loaded := LoadedPage{
		url:          'https://pikabu.ru/'
		markup:       '<!doctype html><meta charset=utf-8><img id=image src="${image_path}">'
		content_type: 'text/html;charset=windows-1251'
	}
	mut document := parse_page_preload_document(loaded, true)
	defer { document.finalize() }
	assert document.get_element_by_id('image')?.get_attribute_value('src') == 'фото.png'
	assert document.character_set() == 'windows-1251'
	assert document.get_window() == none
}

fn test_native_page_cache_and_history_keep_transport_charset_with_raw_response_bytes() {
	previous_cache := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(),
		'vox-navigation-encoding-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if prior := previous_cache {
			os.setenv('LADYBIRD_CACHE_DIR', prior, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache) or {}
	}
	address := dom.URL{
		value: 'https://pikabu.ru/'
	}
	loaded := LoadedPage{
		url:          address.serialize()
		markup:       '<!doctype html><p id=title>${navigation_cp1251_title()}</p>'
		content_type: 'text/html;charset=windows-1251'
	}
	cache_loaded_page(loaded)
	cached := read_cached_page(loaded.url) or { panic('missing cached response') }
	assert cached.markup == loaded.markup
	assert cached.content_type == loaded.content_type
	mut document :=
		parse_loaded_browser_navigation_document(cached, address, none, none, none, true)
	defer { document.finalize() }
	assert document.get_element_by_id('title')?.text_content()? == 'Горячее Пикабу'
	mut app := BrowserApp{
		history:       [HistoryEntry{ url: loaded.url }]
		history_index: 0
	}
	app.update_current_history_entry(loaded)
	assert app.history[0].markup == loaded.markup
	assert app.history[0].content_type == loaded.content_type
}
