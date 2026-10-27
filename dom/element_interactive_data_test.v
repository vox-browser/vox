module dom

#include "element_interactive_data_test.h"

$if gcboehm ? {
	fn C.GC_size(voidptr) uint
	fn C.GC_get_total_bytes() uint
	fn C.vox_dom_rare_watch(index u32, owner voidptr)
	fn C.vox_dom_rare_collect(depth u32)
	fn C.vox_dom_rare_worker(work fn ())
	fn C.vox_dom_rare_alive() u32
}

fn dom_rare_html(document &Document, name string) &HTMLElement {
	element := document.create_element_ns(namespace_html_uri, name) or { panic(err) }
	return unsafe { &HTMLElement(element) }
}

fn test_dom_rare_default_reads_and_default_writes_allocate_no_payloads() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	for name in ['div', 'html', 'head', 'title', 'a', 'option', 'img'] {
		mut element := dom_rare_html(document, name)
		assert element.html_rare_data_ == unsafe { nil }
		assert element.interactive_data_ == unsafe { nil }
		mut before := uint(0)
		$if gcboehm ? { before = C.GC_get_total_bytes() }
		for _ in 0 .. 32 {
			assert element.popover_visibility_state() == .hidden
			assert !element.popover_showing_or_hiding() && !element.inert()
			assert !element.click_in_progress() && element.cryptographic_nonce() == ''
			assert element.popover_trigger() == none && element.opened_in_popover_mode() == none
			assert element.popover_close_watcher_handle() == unsafe { nil }
			assert element.attached_internals_handle() == unsafe { nil }
			assert element.popover_toggle_task_id() == 0 && element.popover_toggle_old_state() == ''
			assert element.labels_list() == none && element.cached_hyperlink_url() == none
			assert !element.hyperlink_url_is_initialized()
			assert element.el_scroll_offset() == CSSPixelPoint_{}
			assert element.snapped_scroll_areas_x().len == 0 && element.snapped_scroll_areas_y().len == 0
			element.set_popover_visibility_state(.hidden)
			element.set_popover_showing_or_hiding(false)
			element.set_inert(false)
			element.set_click_in_progress(false)
			element.set_cryptographic_nonce('')
			element.set_popover_trigger(none)
			element.set_opened_in_popover_mode(none)
			element.set_popover_close_watcher_handle(unsafe { nil })
			element.set_attached_internals_handle(unsafe { nil })
			element.set_popover_toggle_task_id(0)
			element.set_popover_toggle_old_state('')
			element.set_labels_list(none)
			element.set_popover_target_element(none)
			element.set_scroll_offset(none, CSSPixelPoint_{})
			element.set_snapped_scroll_areas([]ScrollSnapAreaReference_{}, []ScrollSnapAreaReference_{})
		}
		$if gcboehm ? { assert C.GC_get_total_bytes() == before }
		assert element.html_rare_data_ == unsafe { nil }
		assert element.interactive_data_ == unsafe { nil }
		assert element.rare_data_ == unsafe { nil }
	}
}

fn test_dom_rare_html_fields_preserve_values_and_clears() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := dom_rare_html(document, 'div')
	target := dom_rare_html(document, 'button')
	labels := &NodeList{ nodes: [target.as_node()] }
	element.set_popover_visibility_state(.showing)
	element.set_popover_showing_or_hiding(true)
	element.set_popover_trigger(target)
	element.set_opened_in_popover_mode('hint')
	element.set_popover_close_watcher_handle(voidptr(uint(0x1234)))
	element.set_popover_toggle_task_id(73)
	element.set_popover_toggle_old_state('closed')
	element.set_attached_internals_handle(voidptr(uint(0x5678)))
	element.set_click_in_progress(true)
	element.set_inert(true)
	element.set_cryptographic_nonce('secret')
	element.set_labels_list(labels)
	assert element.popover_visibility_state() == .showing && element.popover_showing_or_hiding()
	assert voidptr(element.popover_trigger() or { panic('missing trigger') }) == voidptr(target)
	assert (element.opened_in_popover_mode() or { '' }) == 'hint'
	assert element.popover_close_watcher_handle() == voidptr(uint(0x1234))
	assert element.popover_toggle_task_id() == 73 && element.popover_toggle_old_state() == 'closed'
	assert element.attached_internals_handle() == voidptr(uint(0x5678))
	assert element.click_in_progress() && element.inert() && element.cryptographic_nonce() == 'secret'
	assert voidptr(element.labels_list() or { panic('missing labels') }) == voidptr(labels)
	element.set_popover_visibility_state(.hidden)
	element.set_popover_showing_or_hiding(false)
	element.set_popover_trigger(none)
	element.set_opened_in_popover_mode(none)
	element.set_popover_close_watcher_handle(unsafe { nil })
	element.set_popover_toggle_task_id(0)
	element.set_popover_toggle_old_state('')
	element.set_attached_internals_handle(unsafe { nil })
	element.set_click_in_progress(false)
	element.set_inert(false)
	element.set_cryptographic_nonce('')
	element.set_labels_list(none)
	assert element.popover_visibility_state() == .hidden && !element.popover_showing_or_hiding()
	assert element.popover_trigger() == none && element.opened_in_popover_mode() == none
	assert element.popover_close_watcher_handle() == unsafe { nil }
	assert element.attached_internals_handle() == unsafe { nil }
	assert element.popover_toggle_task_id() == 0 && element.popover_toggle_old_state() == ''
	assert !element.click_in_progress() && !element.inert() && element.cryptographic_nonce() == ''
	assert element.labels_list() == none
}

fn test_dom_rare_html_value_copies_are_independent_and_heap_aliases_stay_live() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut original := dom_rare_html(document, 'a')
	original.set_cryptographic_nonce('old')
	original.set_hyperlink_url_cache(URL{value: 'https://old.example/path'})
	mut snapshot := *original
	mut alias := original
	alias.set_cryptographic_nonce('live')
	alias.set_hyperlink_url_cache(URL{value: 'https://live.example/'})
	assert original.cryptographic_nonce() == 'live' && snapshot.cryptographic_nonce() == 'old'
	assert (snapshot.cached_hyperlink_url() or { panic('lost old URL') }).serialize() == 'https://old.example/path'
	snapshot.set_cryptographic_nonce('copy')
	snapshot.initialize_null_hyperlink_url_cache()
	assert original.cryptographic_nonce() == 'live' && snapshot.cryptographic_nonce() == 'copy'
	assert (original.cached_hyperlink_url() or { panic('lost live URL') }).serialize() == 'https://live.example/'
	assert snapshot.cached_hyperlink_url() == none && snapshot.hyperlink_url_is_initialized()
	mut read_url := original.cached_hyperlink_url() or { panic('lost readable URL') }
	read_url.value = 'https://edited-copy.example/'
	assert (original.cached_hyperlink_url() or { panic('lost original URL') }).serialize() == 'https://live.example/'
	// An initialized-null cache differs from the initial uninitialized cache.
	mut fresh := dom_rare_html(document, 'a')
	assert !fresh.hyperlink_url_is_initialized()
	fresh.initialize_null_hyperlink_url_cache()
	assert fresh.hyperlink_url_is_initialized() && fresh.cached_hyperlink_url() == none
	$if gcboehm ? {
		before := C.GC_get_total_bytes()
		fresh.initialize_null_hyperlink_url_cache()
		assert C.GC_get_total_bytes() == before
	}
}

fn test_dom_rare_scroll_and_target_copies_keep_existing_map_identity_and_array_clones() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut original := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	target := document.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
	first_random := original.ensure_css_random_base_value('retained')
	mut input := [ScrollSnapAreaReference_{element_id: 41}]
	original.set_scroll_offset(none, CSSPixelPoint_{x_: 5, y_: 8})
	original.set_snapped_scroll_areas(input, [ScrollSnapAreaReference_{element_id: 42, pseudo_element: 3}])
	original.set_popover_target_element(target)
	mut snapshot := *original
	mut alias := original
	input[0] = ScrollSnapAreaReference_{element_id: 99}
	assert original.snapped_scroll_areas_x()[0].element_id == 41
	mut returned := original.snapped_scroll_areas_x()
	returned[0] = ScrollSnapAreaReference_{element_id: 100}
	assert original.snapped_scroll_areas_x()[0].element_id == 41
	alias.set_scroll_offset(none, CSSPixelPoint_{x_: 15, y_: 18})
	alias.set_snapped_scroll_areas([]ScrollSnapAreaReference_{}, []ScrollSnapAreaReference_{})
	alias.set_popover_target_element(none)
	assert original.el_scroll_offset() == CSSPixelPoint_{x_: 15, y_: 18}
	assert snapshot.el_scroll_offset() == CSSPixelPoint_{x_: 5, y_: 8}
	assert snapshot.snapped_scroll_areas_x()[0].element_id == 41
	assert snapshot.snapped_scroll_areas_y()[0].pseudo_element == 3
	assert voidptr(snapshot.popover_target_element() or { panic('missing old target') }) == voidptr(target)
	assert original.popover_target_element() == none
	snapshot.set_scroll_offset(none, CSSPixelPoint_{})
	assert original.el_scroll_offset().x_ == 15
	assert voidptr(snapshot.rare_data_) == voidptr(original.rare_data_)
	assert snapshot.ensure_css_random_base_value('retained') == first_random
	added := snapshot.ensure_css_random_base_value('added-through-shared-map')
	assert original.ensure_css_random_base_value('added-through-shared-map') == added
}

fn test_dom_rare_concrete_html_bases_and_allocation_classes() {
	assert sizeof(Element) == 1960
	assert sizeof(HTMLElement) == 1968
	assert sizeof(HTMLHtmlElement) == sizeof(HTMLElement)
	assert sizeof(HTMLHeadElement) == sizeof(HTMLElement)
	assert sizeof(HTMLTitleElement) == sizeof(HTMLElement)
	assert sizeof(HTMLAnchorElement) <= 2040
	assert sizeof(HTMLOptionElement) <= 2040
	assert sizeof(HTMLImageElement) <= 2040
	assert sizeof(ElementInteractiveData) == 120
	assert sizeof(HTMLElementRareData) == 624
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	for name in ['html', 'head', 'title', 'div', 'a', 'option', 'img'] {
		mut element := dom_rare_html(document, name)
		element.set_cryptographic_nonce('nonempty')
		element.set_inert(true)
		element.set_popover_toggle_task_id(123)
		assert element.local_name() == name && element.cryptographic_nonce() == 'nonempty'
		assert element.inert() && element.popover_toggle_task_id() == 123
		assert voidptr(element.document()) == voidptr(document)
		$if gcboehm ? {
			allocation := C.GC_size(voidptr(element))
			println('dom_rare_type=${name} object_bytes=${allocation}')
			assert allocation <= 2048 && allocation >= sizeof(HTMLElement)
		}
	}
	println('dom_rare_sizes element=${sizeof(Element)} html=${sizeof(HTMLElement)} anchor=${sizeof(HTMLAnchorElement)} option=${sizeof(HTMLOptionElement)} image=${sizeof(HTMLImageElement)} state=${sizeof(ElementInteractiveData)} htmlstate=${sizeof(HTMLElementRareData)}')
}

__global dom_rare_live_owner &HTMLElement
__global dom_rare_old_snapshot &HTMLElement

fn dom_rare_setup_owner_graph() {
	mut owner := &HTMLElement{}
	target := &HTMLElement{}
	owner.set_popover_trigger(target)
	owner.set_popover_target_element(unsafe { &Element(target) })
	owner.set_labels_list(&NodeList{nodes: [owner.as_node()]})
	dom_rare_live_owner = owner
	dom_rare_old_snapshot = &HTMLElement{...owner}
	$if gcboehm ? {
		C.vox_dom_rare_watch(0, target)
		C.vox_dom_rare_watch(1, owner.html_rare_data_)
		C.vox_dom_rare_watch(2, owner.interactive_data_)
	}
	owner.set_popover_trigger(none)
	owner.set_labels_list(none)
	owner.set_popover_target_element(none)
}

fn dom_rare_drop_snapshot() {
	assert dom_rare_old_snapshot.popover_trigger() != none
	assert dom_rare_live_owner.popover_trigger() == none
	assert dom_rare_live_owner.labels_list() == none
	assert dom_rare_live_owner.popover_target_element() == none
	dom_rare_old_snapshot = unsafe { nil }
}

fn test_dom_rare_cleared_snapshots_release_old_state_and_target_cycles() {
	$if gcboehm ? {
		C.vox_dom_rare_worker(dom_rare_setup_owner_graph)
		C.vox_dom_rare_collect(8)
		assert C.vox_dom_rare_alive() == 7
		C.vox_dom_rare_worker(dom_rare_drop_snapshot)
		C.vox_dom_rare_collect(8)
		C.vox_dom_rare_collect(8)
		mask := C.vox_dom_rare_alive()
		println('dom_rare_discarded_owner_mask=${mask}')
		assert mask == 0
	} $else {
		dom_rare_setup_owner_graph()
		dom_rare_drop_snapshot()
	}
	dom_rare_live_owner = unsafe { nil }
}
