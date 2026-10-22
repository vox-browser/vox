module css

import dom
import platform

fn test_immutable_abstract_element_handles_update_their_referenced_style_state() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	main_handle := dom.AbstractElement.new(element, none)
	before_handle := dom.AbstractElement.new(element, .before)
	after_handle := dom.AbstractElement.new(element, .after)
	main_style := &dom.CSSComputedProperties_{opacity_: 0.25}
	pseudo_style := &dom.CSSComputedProperties_{opacity_: 0.75}
	main_data := &dom.CSSCustomPropertyData_{}
	pseudo_data := &dom.CSSCustomPropertyData_{}
	main_handle.set_computed_properties(main_style)
	main_handle.set_custom_property_data(main_data)
	before_handle.set_computed_properties(pseudo_style)
	before_handle.set_custom_property_data(pseudo_data)
	copy := before_handle
	assert voidptr(copy.computed_properties() or { panic('missing pseudo style') }) == voidptr(pseudo_style)
	assert voidptr(copy.custom_property_data() or { panic('missing pseudo data') }) == voidptr(pseudo_data)
	assert after_handle.computed_properties() == none
	copy.set_computed_properties(none)
	copy.set_custom_property_data(none)
	assert before_handle.computed_properties() == none
	assert before_handle.custom_property_data() == none
	assert voidptr(main_handle.computed_properties() or { panic('missing main style') }) == voidptr(main_style)
	assert voidptr(main_handle.custom_property_data() or { panic('missing main data') }) == voidptr(main_data)
}

fn test_temporary_pseudo_handles_do_not_allocate_when_clearing_absent_styles() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	start := platform.thread_arena_usage().used
	for index in 0 .. 1024 {
		handle := dom.AbstractElement.new(element, if index % 2 == 0 { .before } else { .after })
		handle.set_computed_properties(none)
		handle.set_custom_property_data(none)
	}
	end := platform.thread_arena_usage().used
	$if prealloc {
		assert end - start < 2048
	}
	assert dom.AbstractElement.new(element, .before).computed_properties() == none
	assert dom.AbstractElement.new(element, .after).custom_property_data() == none
}
