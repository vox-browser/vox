module browserjs

import dom

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
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
	owner := voidptr(&elements)
	invalidate_element_key_index(owner)
	assert native_canvas_element_identity_keys(owner, elements, first) == ['shared', 'alias']
	assert native_canvas_element_identity_keys(owner, elements, second) == ['equal-copy']
	// Writes that keep the map's size invalidate its index.
	elements['shared'] = second
	invalidate_element_key_index(owner)
	assert native_canvas_element_identity_keys(owner, elements, first) == ['alias']
	assert native_canvas_element_identity_keys(owner, elements, second) == ['shared', 'equal-copy']
	elements.delete('alias')
	assert native_canvas_element_identity_keys(owner, elements, first).len == 0
}

// The reverse index answers from the keys it owns and checks each against the
// map: a stale candidate is dropped and a resized map is indexed again.
fn test_native_canvas_identity_index_checks_candidates_and_resizes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	first := document.create_element('canvas')!
	second := document.create_element('canvas')!
	mut elements := map[string]&dom.Element{}
	for index in 0 .. 64 { elements['key-${index}'] = second }
	elements['first'] = first
	owner := voidptr(&elements)
	invalidate_element_key_index(owner)
	assert native_canvas_element_identity_keys(owner, elements, first) == ['first']
	elements['first'] = second
	assert native_canvas_element_identity_keys(owner, elements, first).len == 0
	elements['added'] = first
	assert native_canvas_element_identity_keys(owner, elements, first) == ['added']
	assert native_canvas_element_identity_keys(owner, elements, second).len == 65
}

fn test_native_canvas_identity_misses_do_not_copy_element_records_or_maps() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	first := document.create_element('canvas')!
	mut missing := &dom.Element{}
	unsafe { *missing = *first }
	mut elements := map[string]&dom.Element{}
	for index in 0 .. 128 { elements['key-${index}'] = first }
	// The first lookup builds the map's reverse index; misses after it
	// allocate nothing.
	assert native_canvas_element_identity_keys(voidptr(&elements), elements, missing).len == 0
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	for _ in 0 .. 1000 {
		assert native_canvas_element_identity_keys(voidptr(&elements), elements, missing).len == 0
	}
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert allocated == 0
}
