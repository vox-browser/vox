module layout

import css
import dom

fn test_directory_growth_preserves_pages_and_initializes_every_gap() {
	mut store := UsedValuesPagedStore{}
	mut first := store.allocate(31)
	first.set_content_width(CSSPixels.new(73))
	address := voidptr(first)
	for count in [u32(0), 1, 16, 32, 33, 511, 512, 513, 1024, 2331, 4097] {
		old_length := store.pages.len
		store.ensure_capacity(count)
		assert store.pages.len == if int((count + 15) >> 4) > old_length {
			int((count + 15) >> 4)
		} else {
			old_length
		}
		for index, page in store.pages {
			if index == 1 {
				assert page != unsafe { nil }
			} else {
				assert page == unsafe { nil }
			}
		}
		value := store.get(31) or { panic('lost existing value') }
		assert voidptr(value) == address
		assert value.content_width() == CSSPixels.new(73)
	}
	mut last := store.allocate(4096)
	last.set_content_height(CSSPixels.new(29))
	assert store.get(4095) == none
	assert store.get(4097) == none
	assert store.get(4096) or { panic('missing last value') }.content_height() == CSSPixels.new(29)
}

fn test_directory_growth_clears_uninitialized_capacity_without_touching_live_slots() {
	mut store := UsedValuesPagedStore{}
	mut value := store.allocate(16)
	value.set_content_width(CSSPixels.new(91))
	store.ensure_capacity(48)
	assert store.pages.len == 3
	assert store.pages.cap > store.pages.len
	old_data := store.pages.data
	old_capacity := store.pages.cap
	// Unused capacity has no initialization contract. Give it a real pointer
	// to detect accidental publication of the previous contents without UB.
	unsafe {
		mut slots := &voidptr(store.pages.data)
		for index in store.pages.len .. store.pages.cap {
			slots[index] = voidptr(store.pages[1])
		}
	}
	store.ensure_capacity(u32(old_capacity * 16))
	assert store.pages.data == old_data
	assert store.pages.cap == old_capacity
	for index in 2 .. store.pages.len {
		assert store.pages[index] == unsafe { nil }
		assert store.get(u32(index * 16)) == none
	}
	assert store.get(16) or { panic('lost live slot') }.content_width() == CSSPixels.new(91)
}

fn test_public_state_capacity_growth_keeps_independent_measurement_owners() {
	document := dom.Document.create(dom.url_about_blank())
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut source := LayoutState.new()
	mut original := source.get_mutable(node)
	original.set_content_width(CSSPixels.new(97))
	for _ in 0 .. 3 {
		mut probe := LayoutState.new_for_subtree(node)
		probe.ensure_capacity(2331)
		mut copied := probe.populate_node_from(mut source, node)
		assert copied.content_width() == CSSPixels.new(97)
		assert voidptr(copied) != voidptr(original)
		probe.ensure_capacity(4097)
		assert voidptr(probe.get(node)) == voidptr(copied)
		copied.set_content_width(CSSPixels.new(12))
		assert original.content_width() == CSSPixels.new(97)
		probe.release_measurement()
	}
	assert source.get(node).content_width() == CSSPixels.new(97)
}
