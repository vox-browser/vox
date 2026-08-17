module html

fn test_html_all_collection_index_names_and_duplicates() {
	mut document :=
		parse_document('<div id="first"></div><form id="form-id" name="shared"></form><img name="shared"><span name="ignored"></span>')
	all := document.all()
	assert all.length() >= 6
	first := all.named_item('first') or { panic('missing id') }
	assert first.element != none
	shared_result := all.named_item('shared') or { panic('missing named elements') }
	assert shared_result.collection != none
	assert shared_result.collection?.length() == 2
	assert all.named_item('ignored') == none
	assert all.item('0') != none
	assert all.item(none) == none
	assert all.supported_property_names().contains('form-id')
	assert all.supported_property_names().contains('shared')
}
