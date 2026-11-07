module main

import browserjs
import css
import html
import webidl

fn test_compact_browser_uses_native_font_records_and_real_engine_promises() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><body>fonts</body>')
	defer { document.finalize() }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
 globalThis.face=new FontFace("Native Compact","url(unused.ttf)",{weight:"700"});
 document.fonts.add(face);
 globalThis.original=face.loaded;
 console.log("font record installed");
 '], runtime, mut messages)
	assert messages == ['font record installed']
	style := css.css_style_computer_for(document)
	assert webidl.promise_realm(style.font_face_set_.ready()) != 0
	assert style.font_face_set_.set_entries().len == 1
	face := style.font_face_set_.set_entries()[0]
	assert face.status() == .unloaded
	assert face.weight() == '700'
	assert runtime.evaluate_host('document.fonts.has(face)&&[...document.fonts][0]===face&&face.loaded===original&&original instanceof Promise')! == 'true'
}
