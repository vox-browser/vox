@[has_globals]
module css

import fetch
import gfxfont
import http
import os
import platform
import time
import dom

@[heap]
struct PreparedFontObservation {
mut:
	done            bool
	callback_thread u64
	data            []u8
	error_message   ?string
}

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

fn test_font_typeface_retires_the_conversion_workspace_and_preserves_output() {
	$if prealloc {
		woff := font_loading_fixture('HashSans.woff')
		woff2 := font_loading_fixture('incorrect_sfnt_size.woff2')
		expected_woff := gfxfont.convert_woff_to_sfnt(woff) or { panic(err) }
		expected_woff2 := gfxfont.convert_woff2_to_sfnt(woff2) or { panic(err) }
		mut caller := platform.new_arena('font decode caller')
		entry := caller.enter()
		defer {
			caller.leave(entry)
			caller.release()
		}
		before := caller.usage().used
		mut loaded_woff := unsafe { &PlatformTypeface(nil) }
		mut loaded_woff2 := unsafe { &PlatformTypeface(nil) }
		for _ in 0 .. 8 {
			loaded_woff = try_load_vector_font(woff, 'font/woff', 'Owner WOFF') or { panic(err) }
			loaded_woff2 = try_load_vector_font(woff2, 'font/woff2', 'Owner WOFF2') or { panic(err) }
		}
		assert caller.usage().used - before < 64 * 1024
		assert loaded_woff.family_name == 'Owner WOFF'
		assert loaded_woff2.family_name == 'Owner WOFF2'
		assert os.read_bytes(loaded_woff.source_path) or { panic(err) } == expected_woff
		assert os.read_bytes(loaded_woff2.source_path) or { panic(err) } == expected_woff2
	}
}

fn test_font_worker_completion_preserves_bytes_and_errors_after_retirement() {
	woff2 := font_loading_fixture('incorrect_sfnt_size.woff2')
	expected := gfxfont.convert_woff2_to_sfnt(woff2) or { panic(err) }
	prepared := convert_woff2_for_font_completion(woff2)
	assert prepared.error_message == none
	assert prepared.data == expected
	invalid := convert_woff2_for_font_completion([]u8{})
	assert invalid.data.len == 0
	assert (invalid.error_message or { '' }).contains('WOFF2')
	if _ := try_load_vector_font([]u8{}, 'font/woff2', 'Invalid WOFF2') {
		assert false
	} else {
		assert err.msg().contains('WOFF2')
	}
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

fn test_font_preparation_retains_its_origin_callback_through_gc_until_native_delivery() {
	$if !darwin { return }
	state := &PreparedFontObservation{}
	origin_thread := platform.native_thread_identity()
	assert prepare_vector_font_data_off_thread(font_loading_fixture('incorrect_sfnt_size.woff2'), fn [state] (prepared PreparedVectorFontData) {
		mut observation := unsafe { &PreparedFontObservation(state) }
		observation.callback_thread = platform.native_thread_identity()
		observation.data = prepared.data.clone()
		observation.error_message = prepared.error_message
		observation.done = true
	})
	assert !state.done
	gc_collect()
	deadline := time.sys_mono_now() + 2 * time.second
	for !state.done && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.05)
	}
	assert state.done
	assert state.callback_thread == origin_thread
	assert state.error_message == none
	assert font_typeface_from_prepared_bytes(state.data, 'Source prepared font')!.source_path != ''
}

fn test_font_preparation_retains_the_receiving_document_outside_its_allocation_scope() {
	$if !darwin { return }
	mut document := dom.Document.create(dom.URL{value:'https://font-owner.test/'})
	document.enable_native_storage()
	storage := document.native_storage()
	state := &PreparedFontObservation{}
	mut scope := document.enter_native_storage()
	computer := FontComputer.create_for_document(document)
	name := 'Retired font family'.clone()
	bytes := font_loading_fixture('incorrect_sfnt_size.woff2')
	scope.finish()
	assert prepare_vector_font_data_for_computer(bytes, fn [state, name] (prepared PreparedVectorFontData) {
		assert prepared.error_message == none
		typeface := font_typeface_from_prepared_bytes(prepared.data, name) or { panic(err) }
		assert typeface.family_name == 'Retired font family'
		mut observation := unsafe { &PreparedFontObservation(state) }
		observation.done = true
	}, computer)
	document.release_native_storage()
	deadline := time.sys_mono_now() + 2 * time.second
	for !state.done && time.sys_mono_now() < deadline { platform.pump_native_events(0.05) }
	assert state.done
	$if prealloc {
		assert storage.arena.usage().used == 0
	} $else {
		assert storage == unsafe { nil }
	}
}
