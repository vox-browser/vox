module main

import browserjs
import html

fn test_computed_font_shorthand_expresses_keyword_widths() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><p id="plain" style="font: 9px serif">a</p><p id="styled" style="font: italic bold condensed 20px/30px monospace">b</p><p id="odd" style="font: 20px serif; font-stretch: 90%">c</p>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'console.log(getComputedStyle(plain).font);console.log(getComputedStyle(styled).font);console.log(JSON.stringify(getComputedStyle(odd).font));',
	], runtime, mut messages)
	assert messages == ['9px serif', 'italic 700 condensed 20px / 30px monospace', '""']
}
