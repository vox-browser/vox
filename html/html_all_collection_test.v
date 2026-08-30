module html

fn test_html_all_collection_index_names_and_duplicates() {
	mut document := parse_document('<div id="first"></div><form id="form-id" name="shared"></form><img name="shared"><span name="ignored"></span>')
	all := document.all()
	assert all.length() >= 6
	first := all.named_item('first') or { panic('missing id') }
	assert first.element != none
	shared_result := all.named_item('shared') or { panic('missing named elements') }
	assert shared_result.collection != none
	assert shared_result.collection?.length() == 2
	assert all.named_item('ignored') == none
	assert all.get_the_all_named_elements('first')?.element != none
	assert all.get_the_all_indexed_element(0) != none
	assert all.get_the_all_indexed_or_named_elements('shared')?.collection != none
	assert all.item_value(0) != none
	assert all.named_item_value('shared')?.collection != none
	assert all.item('0') != none
	assert all.item(none) == none
	assert all.supported_property_names().contains('form-id')
	assert all.supported_property_names().contains('shared')
}
