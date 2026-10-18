module browserjs

import dom

$if gcboehm ? {
	fn C.GC_get_total_bytes() usize
}

fn test_native_canvas_identity_distinguishes_equal_records_and_keeps_live_aliases() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	first := document.create_element('canvas')!
	// A separate native object with identical field values still has its own
	// identity. Do not attach or finalize this shallow fixture copy.
	mut second := &dom.Element{}
	unsafe { *second = *first }
	mut elements := {'shared': first, 'equal-copy': second, 'alias': first}
	assert native_canvas_element_identity_keys(elements, first) == ['shared', 'alias']
	assert native_canvas_element_identity_keys(elements, second) == ['equal-copy']
	elements['shared'] = second
	assert native_canvas_element_identity_keys(elements, first) == ['alias']
	assert native_canvas_element_identity_keys(elements, second) == ['shared', 'equal-copy']
	elements.delete('alias')
	assert native_canvas_element_identity_keys(elements, first).len == 0
}

fn test_native_canvas_identity_misses_do_not_copy_element_records_or_maps() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	first := document.create_element('canvas')!
	mut missing := &dom.Element{}
	unsafe { *missing = *first }
	mut elements := map[string]&dom.Element{}
	for index in 0 .. 128 { elements['key-${index}'] = first }
	mut before := usize(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	for _ in 0 .. 1000 {
		assert native_canvas_element_identity_keys(elements, missing).len == 0
	}
	mut allocated := usize(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert allocated == 0
}
