module html

fn test_accessible_labelledby_retains_referenced_text_and_idref_order() {
	mut document := parse_document('<!doctype html><div id="group" role="group" aria-labelledby="heading"><h2 id="heading">first heading</h2></div><button id="button" aria-labelledby="second missing first">x</button><span id="first">first</span><span id="second">second</span>')
	defer { document.finalize() }
	group := document.get_element_by_id('group') or { panic('missing group') }
	button := document.get_element_by_id('button') or { panic('missing button') }
	assert group.as_node().accessible_name(document, .yes)!.fields().join(' ') == 'first heading'
	assert button.as_node().accessible_name(document, .yes)!.fields().join(' ') == 'second first'
}

fn test_accessible_labelledby_retains_self_labels_and_empty_reference_fallbacks() {
	mut document := parse_document('<!doctype html><div id="self" role="group" aria-label="Self" aria-labelledby="self other"><span id="other">other label</span></div><button id="fallback" aria-label="Fallback" aria-labelledby="empty">unrelated content</button><span id="empty"></span>')
	defer { document.finalize() }
	self := document.get_element_by_id('self') or { panic('missing self') }
	fallback := document.get_element_by_id('fallback') or { panic('missing fallback') }
	assert self.as_node().accessible_name(document, .yes)!.fields().join(' ') == 'Self other label'
	assert fallback.as_node().accessible_name(document, .yes)!.fields().join(' ') == 'Fallback'
}
