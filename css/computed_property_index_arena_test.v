module css

import dom

fn test_computed_property_index_retires_without_retiring_published_pages() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	owner := document.native_storage()
	mut allocations := document.enter_native_storage()
	mut computer := StyleComputer.new(document)
	mut previous := []&ComputedProperties{}
	for batch in 0 .. 16 {
		computer.begin_computed_property_page_batch()
		computer.begin_computed_property_page_batch()
		mut style := computed_properties_with_initial_values()
		value := parse_css_value(ParsingParams{}, '${batch + 10}px', .width) or { panic('invalid width') }
		style.set_property(.width, value, .no, .no)
		computer.publish_computed_property_pages(style)
		index := computer.computed_property_page_interner_
		assert computer.computed_property_page_arena_.contains(voidptr(index))
		assert !owner.arena.contains(voidptr(index))
		for page in style.property_store_.pages {
			assert !computer.computed_property_page_arena_.contains(voidptr(page))
		}
		computer.end_computed_property_page_batch()
		assert voidptr(computer.computed_property_page_interner_) == voidptr(index)
		computer.end_computed_property_page_batch()
		assert computer.computed_property_page_interner_ == unsafe { nil }
		assert computer.computed_property_page_arena_.usage().used == 0
		previous << style
		for i, published in previous {
			assert (published.property(.width, .no) or { panic('lost width') }).css_text == '${i + 10}px'
		}
	}
	arena := computer.computed_property_page_arena_
	allocations.finish()
	document.finalize()
	document.release_native_storage()
	assert arena.usage().capacity == 0
}
