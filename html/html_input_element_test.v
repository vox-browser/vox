module html

import dom
import math

fn collect_input_test_elements(node &dom.Node, mut result []&dom.Element) {
	if element := node.as_element() {
		if element.local_name() == 'input' {
			result << element
		}
	}
	for child in node.children_as_vector() {
		collect_input_test_elements(child, mut result)
	}
}

fn input_test_elements(markup string) []&dom.Element {
	document := parse_document(markup)
	mut result := []&dom.Element{}
	collect_input_test_elements(unsafe { &dom.Node(document) }, mut result)
	return result
}

fn test_input_type_sanitization_number_range_and_stepping() {
	elements := input_test_elements('<input type="number" min="2" max="10" step="2"><input type="range" min="0" max="20" step="5" value="12"><input type="color" value="#AABBCC">')
	mut number := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[0]) })
	assert number.min()? == 2
	assert number.max()? == 10
	number.set_value('3.5')!
	assert number.value() == '3.5'
	assert number.control.suffering_from_a_step_mismatch()
	number.step_up(1)!
	assert number.value_as_number() == 4
	number.step_down(1)!
	assert number.value_as_number() == 2
	number.set_value('invalid')!
	assert number.value() == ''
	assert math.is_nan(number.value_as_number())

	range := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[1]) })
	assert range.value() == '10.0'
	color := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[2]) })
	assert color.value() == '#aabbcc'
}

fn test_input_text_email_selection_required_and_reset() {
	elements := input_test_elements('<input type="email" required multiple value="a@example.com"><input type="text" value="base" minlength="3">')
	mut email := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[0]) })
	email.set_value('a@example.com, bad')!
	assert email.control.suffering_from_a_type_mismatch()
	email.set_value('a@example.com,b@example.org')!
	assert !email.control.suffering_from_a_type_mismatch()

	mut text := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[1]) })
	text.set_value('hello\nworld')!
	assert text.value() == 'helloworld'
	assert text.text_control.selection_end() == 10
	text.text_control.set_selection_range(0, 5, 'forward')!
	text.text_control.set_range_text('hi', 0, 5, .select)!
	assert text.value() == 'hiworld'
	text.reset()
	assert text.value() == 'base'
}

fn test_input_checkbox_radio_files_and_accept() {
	elements := input_test_elements('<input type="checkbox" required><input type="radio" name="g"><input type="radio" name="g"><input type="file" multiple accept="image/*,.txt,text/plain">')
	mut checkbox := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[0]) })
	assert checkbox.control.suffering_from_being_missing()
	checkbox.activate()
	assert checkbox.checked()
	assert elements[0].matches_checked_pseudo_class()
	assert unsafe { &dom.HTMLInputElement(elements[0]) }.checked()
	assert !checkbox.control.suffering_from_being_missing()
	assert checkbox.event_count('change') == 1

	mut first_radio := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[1]) })
	mut second_radio := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[2]) })
	first_radio.set_checked_binding(true)
	second_radio.set_checked_binding(true)
	assert !first_radio.checked()
	assert second_radio.checked()
	assert !elements[1].matches_checked_pseudo_class()
	assert elements[2].matches_checked_pseudo_class()

	mut file := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[3]) })
	file.did_select_files([SelectedFile.from_contents('a.txt', 'a'.bytes())], .replace)
	assert file.value() == 'C:\\fakepath\\a.txt'
	assert file.files()?.len == 1
	assert file.parse_accept_attribute().filters.len == 3
	file.set_value('not allowed') or { assert err.msg().starts_with('InvalidStateError:') }
	file.set_value('')!
	assert file.files()?.len == 0
}

fn test_input_radio_group_uses_live_tree_and_form_owner_boundaries() {
	elements := input_test_elements('<form><input type="radio" name="g"><input type="radio" name="g"></form><form><input type="radio" name="g" checked></form>')
	mut first := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[0]) })
	mut second := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[1]) })
	third := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[2]) })

	first.set_checked_binding(true)
	assert first.checked()
	assert !second.checked()
	assert third.checked()

	second.set_checked_binding(true)
	assert !first.checked()
	assert second.checked()
	assert third.checked()

	// This is the internal C++ primitive: group exclusivity is implemented by
	// set_checked_binding()/set_checked_within_group(), not set_checked().
	first.set_checked(true)
	assert first.checked()
	assert second.checked()
}

fn test_input_date_time_value_as_number() {
	elements := input_test_elements('<input type="date"><input type="time"><input type="month">')
	mut date := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[0]) })
	date.set_value('1970-01-02')!
	assert date.value_as_number() == 86400000
	date.set_value_as_number(0)!
	assert date.value() == '1970-01-01'
	mut time := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[1]) })
	time.set_value('01:30')!
	assert time.value_as_number() == 5400000
	mut month := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[2]) })
	month.set_value('1971-01')!
	assert month.value_as_number() == 12
}

fn input_test_image_fetch(_ dom.URL) !DecodedImageData {
	return BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{
			bitmap: &dom.ImmutableBitmap_{
				width: 40
				height: 30
			}
		},
	], 0, false)
}

fn test_input_value_modes_attributes_and_shadow_tree() {
	elements := input_test_elements('<input value="hello" placeholder="hint"><input type="submit"><input type="range" min="0" max="20" value="5">')
	mut text := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[0]) })
	assert html_input_element_value_attribute_mode_for_type_state(.text) == .value
	assert html_input_element_selection_or_range_applies_for_type_state(.text)
	assert !html_input_element_selection_or_range_applies_for_type_state(.email)
	assert text.text_node_?.data() == 'hello'
	text.set_type('button')
	assert text.value_attribute_mode() == .default_
	assert text.default_value() == 'hello'
	text.set_type('text')
	assert text.value() == 'hello'
	text.set_value('')!
	assert text.placeholder_value()? == 'hint'

	mut submit := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[1]) })
	assert submit.button_label() == 'Submit'
	mut submit_element := input_element(submit)
	submit_element.set_attribute_value('value', 'Send')
	submit.form_associated_element_attribute_changed('value', none, 'Send', none)
	assert submit.text_node_?.data() == 'Send'

	mut range := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[2]) })
	assert range.slider_progress_element_?.get_attribute_value('style').contains('25')
}

fn test_input_validation_picker_and_legacy_activation() {
	elements := input_test_elements('<input type="radio" name="g"><input type="radio" name="g" required><input pattern="[a-z]+"><input type="file">')
	mut first := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[0]) })
	mut second := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[1]) })
	first.update_validity()
	assert first.suffering_from_being_missing()
	assert second.suffering_from_being_missing()
	first.set_checked(true)
	second.update_validity()
	assert !second.suffering_from_being_missing()

	mut patterned := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[2]) })
	patterned.set_value('abc')!
	assert !patterned.suffering_from_a_pattern_mismatch()
	patterned.set_value('123')!
	assert patterned.suffering_from_a_pattern_mismatch()

	mut file := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[3]) })
	file.show_picker() or { assert err.msg().starts_with('NotAllowedError:') }
	file.set_picker_security_state(true, false)
	file.show_picker()!
	assert file.is_open()
	file.did_select_files([], .replace)
	assert !file.is_open()
	assert file.event_count('cancel') == 1

	mut checkbox := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(input_test_elements('<input type="checkbox">')[0]) })
	checkbox.set_indeterminate(true)
	checkbox.legacy_pre_activation_behavior()
	assert checkbox.checked()
	assert !checkbox.indeterminate()
	checkbox.legacy_cancelled_activation_behavior()
	assert !checkbox.checked()
	assert checkbox.indeterminate()
}

fn test_input_image_resource_dimensions_and_hints() {
	element := input_test_elements('<input type="image" src="https://example.test/image.png" border="2" hspace="3">')[0]
	mut image := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	image.set_image_fetch_hook(input_test_image_fetch)
	image.handle_src_attribute('https://example.test/image.png')!
	assert image.is_image_available()
	assert image.intrinsic_width()? == 40
	assert image.width() == 40
	assert image.height() == 30
	image.set_width(12)
	assert image.width() == 12
	assert image.event_count('load') == 1
	hints := image.apply_presentational_hints()
	assert hints.border_width? == 2
	assert hints.margin_left? == 3
	assert image.is_presentational_hint('width')
}
