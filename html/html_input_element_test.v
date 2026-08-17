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
	elements :=
		input_test_elements('<input type="number" min="2" max="10" step="2"><input type="range" min="0" max="20" step="5" value="12"><input type="color" value="#AABBCC">')
	mut number := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[0]) })
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
	elements :=
		input_test_elements('<input type="email" required multiple value="a@example.com"><input type="text" value="base" minlength="3">')
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
	elements :=
		input_test_elements('<input type="checkbox" required><input type="radio" name="g"><input type="radio" name="g"><input type="file" multiple accept="image/*,.txt,text/plain">')
	mut checkbox := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[0]) })
	assert checkbox.control.suffering_from_being_missing()
	checkbox.activate()
	assert checkbox.checked()
	assert !checkbox.control.suffering_from_being_missing()
	assert checkbox.event_count('change') == 1

	mut first_radio := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[1]) })
	mut second_radio := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[2]) })
	first_radio.set_checked(true)
	second_radio.set_checked(true)
	assert !first_radio.checked()
	assert second_radio.checked()

	mut file := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[3]) })
	file.did_select_files([SelectedFile.from_contents('a.txt', 'a'.bytes())], .replace)
	assert file.value() == 'C:\\fakepath\\a.txt'
	assert file.files()?.len == 1
	assert file.parse_accept_attribute().filters.len == 3
	file.set_value('not allowed') or { assert err.msg().starts_with('InvalidStateError:') }
	file.set_value('')!
	assert file.files()?.len == 0
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
