module dom

fn test_pseudo_element_lookup_distinguishes_missing_entries_and_live_identity() {
	document := Document.create(url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	assert element.get_pseudo_element(1) == none
	first := element.ensure_pseudo_element(1)
	assert voidptr(element.get_pseudo_element(1) or { panic('missing entry') }) == voidptr(first)
	assert element.get_pseudo_element(2) == none
	assert element.get_pseudo_element_node(1) == none
	element.remove_pseudo_element_record(1)
	assert element.get_pseudo_element(1) == none
	replacement := element.ensure_pseudo_element(1)
	assert voidptr(element.get_pseudo_element(1) or { panic('missing replacement') }) == voidptr(replacement)
	assert voidptr(replacement) != voidptr(first)
}
