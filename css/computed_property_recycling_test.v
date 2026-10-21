module css

import dom
import platform

fn recycling_style(computer &StyleComputer, value &dom.StyleValue) &ComputedProperties {
	mut style := computed_properties_with_initial_values()
	computer.prepare_computed_property_page_recycling(style)
	style.set_property(.color, value, .no, .yes)
	return style
}

fn test_property_publication_recycles_only_unpublished_exclusive_pages_across_batches() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	owner := document.native_storage()
	mut allocations := document.enter_native_storage()
	mut computer := StyleComputer.new(document)
	value := &dom.StyleValue{css_text: 'red'}
	other := &dom.StyleValue{css_text: 'blue'}
	index := (int(PropertyID.color) - int(first_longhand_property_id())) >> 4
	computer.begin_computed_property_page_batch()
	first := recycling_style(computer, value)
	computer.publish_computed_property_pages(first)
	canonical := first.property_store_.pages[index]
	mut reusable := unsafe { &ComputedPropertyPage(nil) }
	for _ in 0 .. 256 {
		current := recycling_style(computer, value)
		page := current.property_store_.pages[index]
		if reusable != unsafe { nil } { assert voidptr(page) == voidptr(reusable) }
		alias := *current
		computer.publish_computed_property_pages(current)
		assert voidptr(alias.property_store_.pages[index]) == voidptr(canonical)
		assert current.property_store_.recycling.pages.len == 1
		reusable = page
		for slot in page.values { assert slot == unsafe { nil } }
	}
	// An independent raw-store clone freezes the source's writable pages. Its
	// page must survive later publication, even when the source deduplicates.
	mut source := recycling_style(computer, value)
	clone := &ComputedProperties{
		...source
		property_store_: source.clone_raw_property_store()
		computed_property_graph_token_: unsafe { nil }
	}
	shared := source.property_store_.pages[index]
	computer.publish_computed_property_pages(source)
	assert computer.computed_property_page_recycling_.pages.len == 0
	assert (clone.property(.color, .no) or { panic('lost snapshot color') }).css_text == 'red'
	assert voidptr(shared.values[(int(PropertyID.color) - int(first_longhand_property_id())) & 15]) == voidptr(value)
	late := recycling_style(computer, value)
	computer.publish_computed_property_pages(late)
	pool := computer.computed_property_page_recycling_
	epoch := pool.epoch
	assert pool.pages.len == 1
	computer.end_computed_property_page_batch()
	assert !pool.active && pool.pages.len == 1
	assert !pool.can_reuse(epoch)
	computer.begin_computed_property_page_batch()
	next := recycling_style(computer, other)
	assert pool.epoch != epoch && pool.pages.len == 0
	// Old styles cannot acquire a page during the new batch.
	assert !pool.can_reuse(epoch)
	mut scratch := platform.new_arena('property recycling eligibility')
	entry := scratch.enter()
	assert !pool.can_reuse(pool.epoch)
	scratch.leave(entry)
	scratch.release()
	assert pool.can_reuse(pool.epoch)
	computer.publish_computed_property_pages(next)
	computer.end_computed_property_page_batch()
	assert (first.property(.color, .no) or { panic('lost published color') }).css_text == 'red'
	assert (clone.property(.color, .no) or { panic('lost shared color') }).css_text == 'red'
	allocations.finish()
	document.finalize()
	document.release_native_storage()
	for _ in 0 .. 100 {
		if owner.arena.usage().capacity == 0 { break }
		platform.pump_native_events(0.01)
	}
	assert owner.arena.usage().capacity == 0
	assert !pool.active && pool.owner == unsafe { nil } && pool.pages.len == 0
}
