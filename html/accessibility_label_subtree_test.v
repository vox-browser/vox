module html

import dom

fn test_native_label_text_traverses_wrappers_and_skips_the_control_at_any_depth() {
	mut document := parse_document('<!doctype html><label role="none"><span>input <b>label</b></span><span><input id="target" role="none" value="excluded"></span></label><label for="explicit"><span>explicit label</span></label><input id="explicit">')
	defer { document.finalize() }
	for id, expected in {'target':'input label', 'explicit':'explicit label'} {
		element := document.get_element_by_id(id) or { panic('missing control') }
		assert element.as_node().accessible_name(document, .yes)!.fields().join(' ') == expected
	}
}

fn test_native_label_nested_embedded_control_uses_its_live_value() {
	mut document := parse_document('<!doctype html><label for="target"><span>Repeat <b><input id="count" value="7"></b> times</span><span><textarea id="target">excluded</textarea></span></label>')
	defer { document.finalize() }
	target := document.get_element_by_id('target') or { panic('missing control') }
	count := document.get_element_by_id('count') or { panic('missing count') }
	assert target.as_node().accessible_name(document, .yes)!.fields().join(' ') == 'Repeat 7 times'
	mut input := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(count) })
	input.set_value('9')!
	assert target.as_node().accessible_name(document, .yes)!.fields().join(' ') == 'Repeat 9 times'
}
