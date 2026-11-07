module main

import browserjs
import css
import dom
import html
import webidl

fn test_document_fonts_retains_the_actual_css_record_ready_promise_and_event_target() {
	mut document :=
		html.parse_document_with_url('<!doctype html><body>fonts</body>', dom.URL{value: 'https://document-fonts.example/'})
	_ = html.WindowModel.create_top_level(document, none, 'document-fonts') or { panic(err) }
	fonts := document.fonts()
	style := css.css_style_computer_for(document)
	assert fonts.font_face_set_record() == voidptr(style.font_face_set_)
	assert document.fonts().font_face_set_record() == fonts.font_face_set_record()
	assert voidptr(fonts.event_target()) == voidptr(style.font_face_set_)
	assert voidptr(fonts.ready()) == voidptr(style.font_face_set_.ready())
	assert webidl.promise_realm(fonts.ready()) != 0
	mut native := unsafe { &css.FontFaceSet(fonts.font_face_set_record()) }
	face := css.FontFaceObject.construct_impl_for_font_computer(style.font_computer(), 'Actual',
		css.FontFaceSource.from_string('url(actual.ttf)'), css.FontFaceDescriptors{})
	native.add(face) or { panic(err) }
	assert style.font_face_set_.set_entries().len == 1
	assert voidptr(style.font_face_set_.set_entries()[0]) == voidptr(face)
	// The DOM/CSS import-cycle boundary retains the implementation itself;
	// V's interface downcast reaches every concrete source FontFaceSet method.
	assert fonts is css.FontFaceSet
}

fn test_existing_css_state_and_style_reinitialization_keep_one_document_font_set() {
	mut document := dom.Document.create(dom.URL{value: 'https://document-fonts.example/'})
	first := css.StyleComputer.new(document)
	fonts := document.fonts()
	second := css.StyleComputer.new(document)
	assert fonts.font_face_set_record() == voidptr(first.font_face_set_)
	assert voidptr(second.font_face_set_) == voidptr(first.font_face_set_)
	assert voidptr(second.font_computer()) == voidptr(first.font_computer())
	assert fonts.font_face_set_record() == document.fonts().font_face_set_record()
}

fn test_compact_font_set_wrapper_binds_the_actual_document_fonts_platform_object() {
	$if !darwin { return }
	mut document :=
		html.parse_document_with_url('<!doctype html><body>fonts</body>', dom.URL{value: 'https://document-fonts.example/'})
	_ = html.WindowModel.create_top_level(document, none, 'document-fonts') or { panic(err) }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	runtime.evaluate_host('globalThis.document={}') or { panic(err) }
	mut host := browserjs.FontFaceHost.create(document)
	host.install(mut runtime) or { panic(err) }
	target := runtime.native_event_target(runtime.evaluate_host_value('document.fonts')!) or {
		panic(err)
	}
	assert voidptr(target) == document.fonts().font_face_set_record()
	assert runtime.evaluate_host('document.fonts instanceof FontFaceSet&&document.fonts instanceof EventTarget') or {
		panic(err)
	} == 'true'
}
