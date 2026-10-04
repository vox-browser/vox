module html

import css
import dom
import highresolutiontime

fn form_state_test_element(document &dom.Document, local_name string) &dom.Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', local_name) or {
		panic(err)
	}
}

fn test_indeterminate_selector_tracks_live_checkbox_state() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := form_state_test_element(document, 'input')
	element.set_attribute_value('type', 'checkbox')
	mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })

	assert !css.element_matches_selector(element, ':indeterminate')
	model.set_indeterminate(true)
	assert css.element_matches_selector(element, ':indeterminate')
	element.set_attribute_value('switch', '')
	assert !css.element_matches_selector(element, ':indeterminate')
	model.set_indeterminate(false)
	assert !css.element_matches_selector(element, ':indeterminate')

	progress := form_state_test_element(document, 'progress')
	assert css.element_matches_selector(progress, ':indeterminate')
}

fn test_open_selector_tracks_input_and_select_pickers() {
	document := dom.Document.create(dom.url_about_blank())
	_ = WindowModel.create_top_level(document, none, 'open-selector-picker')!
	mut native := document.get_window()?
	mut input_element := form_state_test_element(document, 'input')
	input_element.set_attribute_value('type', 'color')
	mut input := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(input_element) })
	assert !css.element_matches_selector(input_element, ':open')
	assert css.element_matches_selector(input_element, ':closed')
	native.set_last_activation_timestamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
		time_origin: document.load_timing_info.navigation_start_time
	}))
	input.show_picker() or { panic(err) }
	assert css.element_matches_selector(input_element, ':open')
	assert !css.element_matches_selector(input_element, ':closed')
	input.did_pick_color(none, true)
	assert !css.element_matches_selector(input_element, ':open')

	select_element := form_state_test_element(document, 'select')
	mut select_control := HTMLSelectElementModel.create(unsafe { &dom.HTMLSelectElement(select_element) })
	assert !css.element_matches_selector(select_element, ':open')
	assert css.element_matches_selector(select_element, ':closed')
	native.set_last_activation_timestamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
		time_origin: document.load_timing_info.navigation_start_time
	}))
	select_control.show_picker() or { panic(err) }
	assert select_control.is_open()
	assert css.element_matches_selector(select_element, ':open')
	assert !css.element_matches_selector(select_element, ':closed')
	select_control.did_select_item(none)
	assert !select_control.is_open()
	assert !css.element_matches_selector(select_element, ':open')
}
