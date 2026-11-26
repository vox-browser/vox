module css

import dom

// Publication canonicalizes the pages a computation wrote. Pages it shares
// with the initial store or an earlier published style are left as they are
// and do not enter the interner again.
fn test_publication_interns_only_pages_written_by_the_computation() {
	mut computer := StyleComputer.new(dom.Document.create(dom.url_about_blank()))
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	value := parse_css_value(ParsingParams{}, '41px', .width) or { panic('width') }
	mut first := computed_properties_with_initial_values()
	mut second := computed_properties_with_initial_values()
	first.set_property(.width, value, .no, .no)
	second.set_property(.width, value, .no, .no)
	index := int(PropertyID.width) - int(first_longhand_property_id())
	untouched := (index >> 4 + 1) % computed_property_page_count
	shared_page := second.property_store_.pages[untouched]
	computer.publish_computed_property_pages(first)
	interned := computer.computed_property_page_interner_.pages.len
	if !disable_written_page_publication { assert interned == 1 }
	computer.publish_computed_property_pages(second)
	// The written page is replaced by the first style's equal page.
	assert voidptr(first.property_store_.pages[index >> 4]) == voidptr(second.property_store_.pages[index >> 4])
	// The untouched page keeps its identity, and the second publication adds
	// nothing to the interner.
	assert voidptr(second.property_store_.pages[untouched]) == voidptr(shared_page)
	assert computer.computed_property_page_interner_.pages.len == interned
	assert (second.property(.width, .no) or { panic('width') }) == value
	assert second.property_store_.writable == 0
}
