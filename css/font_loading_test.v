module css

import fetch
import http
import os

fn font_loading_fixture(name string) []u8 {
	return os.read_bytes(os.join_path(os.dir(@FILE), '..', 'gfxfont', 'testdata', name)) or {
		panic(err)
	}
}

fn test_font_loading_uses_source_format_dispatch_and_legacy_woff_alias() {
	font := font_loading_fixture('HashSans.woff')
	for mime in ['font/woff', 'application/font-woff', 'font/x-woff'] {
		loaded := try_load_vector_font(font, mime, 'Source WOFF')!
		assert os.read_bytes(loaded.source_path)!.len > font.len
	}
	if _ := try_load_vector_font(font, 'font/woff2', 'Wrong declared format') { assert false
	 }
	if _ := try_load_vector_font(font, 'font/collection', 'Unsupported declared format') { assert false
	 }
	assert try_load_vector_font(font, none, 'Undeclared format')!.source_path != ''
}

fn test_font_preparation_uses_the_source_woff2_mime_or_signature_rule() {
	assert requires_off_thread_vector_font_preparation([], 'font/woff2')
	assert requires_off_thread_vector_font_preparation([], 'application/font-woff2')
	assert requires_off_thread_vector_font_preparation('wOF2'.bytes(), none)
	assert requires_off_thread_vector_font_preparation('wOF2'.bytes(), 'font/ttf')
	assert !requires_off_thread_vector_font_preparation('wOFF'.bytes(), 'font/woff')
	assert !requires_off_thread_vector_font_preparation('wOF'.bytes(), none)
}

fn test_font_loader_trusts_font_mime_and_sniffs_other_or_absent_mime() {
	loader := FontLoader.create(FontComputer.create(), 'Source sniff', [], [], none)
	font := font_loading_fixture('HashSans.woff')
	mut response := fetch.Response.create()
	assert loader.try_load_font_mime_type_essence(response, font)? == 'font/woff'
	assert loader.try_load_font_mime_type_essence(response, 'unknown'.bytes()) == none
	response.header_list.append(http.Header{ name: 'Content-Type', value: 'application/octet-stream' })
	assert loader.try_load_font_mime_type_essence(response, font)? == 'font/woff'
	response.header_list = http.HeaderList.create()
	response.header_list.append(http.Header{ name: 'Content-Type', value: 'font/woff2' })
	assert loader.try_load_font_mime_type_essence(response, font)? == 'font/woff2'
	if _ := loader.try_load_font(response, font) { assert false
	 }
}
