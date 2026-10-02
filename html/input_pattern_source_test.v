// SPDX-License-Identifier: BSD-2-Clause
module html

import dom

fn collect_pattern_source_inputs(node &dom.Node, mut result []&dom.Element) {
	if element := node.as_element() {
		if element.local_name() == 'input' { result << element }
	}
	for child in node.children_as_vector() { collect_pattern_source_inputs(child, mut result) }
}

fn pattern_source_inputs(markup string) []&dom.Element {
	document := parse_document(markup)
	mut result := []&dom.Element{}
	collect_pattern_source_inputs(unsafe { &dom.Node(document) }, mut result)
	return result
}

fn test_input_pattern_unicode_sets_and_non_capturing_backreference_anchors() {
	elements := pattern_source_inputs('<input pattern="[\\p{Letter}&amp;&amp;\\p{ASCII}]+"><input pattern="(a)\\1"><input pattern="[\\p{ASCII}--[0-9]]+">')
	mut letters := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[0]) })
	for value in ['A', 'hello'] {
		letters.set_value(value)!
		assert !letters.suffering_from_a_pattern_mismatch()
		assert !letters.control.suffering_from_a_pattern_mismatch()
	}
	for value in ['é', '123', 'aé'] {
		letters.set_value(value)!
		assert letters.suffering_from_a_pattern_mismatch()
	}
	mut repeated := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[1]) })
	repeated.set_value('aa')!
	assert !repeated.suffering_from_a_pattern_mismatch()
	for value in ['a', 'aaa', 'baa', 'aab'] {
		repeated.set_value(value)!
		assert repeated.suffering_from_a_pattern_mismatch()
	}
	mut subtraction := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[2]) })
	subtraction.set_value('Hello')!
	assert !subtraction.suffering_from_a_pattern_mismatch()
	subtraction.set_value('Hello1')!
	assert subtraction.suffering_from_a_pattern_mismatch()
}

fn test_input_pattern_original_compile_gate_missing_empty_invalid_and_inapplicable_patterns() {
	elements := pattern_source_inputs('<input><input pattern=""><input pattern=")|("><input pattern="[a-z-]"><input type="number" pattern="[">')
	mut missing := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[0]) })
	missing.set_value('a')!
	assert missing.compiled_pattern_regular_expression() == none
	assert !missing.suffering_from_a_pattern_mismatch()
	mut empty := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[1]) })
	empty.set_value('')!
	assert !empty.suffering_from_a_pattern_mismatch()
	empty.set_value('a')!
	assert empty.suffering_from_a_pattern_mismatch()
	// Wrapping this invalid pattern alone could make it valid. The source
	// explicitly compiles the original pattern first and ignores any failure.
	mut invalid := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[2]) })
	invalid.set_value('a')!
	assert invalid.compiled_pattern_regular_expression() == none
	assert !invalid.suffering_from_a_pattern_mismatch()
	mut invalid_set := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[3]) })
	invalid_set.set_value('a')!
	assert invalid_set.compiled_pattern_regular_expression() == none
	assert !invalid_set.suffering_from_a_pattern_mismatch()
	mut number := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[4]) })
	number.set_value('42')!
	assert !number.suffering_from_a_pattern_mismatch()
}

fn test_input_pattern_multiple_email_list_uses_source_nonempty_split_views() {
	elements := pattern_source_inputs('<input type="email" multiple pattern="a@example\\.com">')
	mut email := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[0]) })
	for value in ['a@example.com', 'a@example.com,a@example.com', ',a@example.com,,'] {
		email.set_value(value)!
		assert !email.suffering_from_a_pattern_mismatch(), email.value()
	}
	email.set_value('a@example.com,b@example.com')!
	assert email.suffering_from_a_pattern_mismatch()
	assert email.control.suffering_from_a_pattern_mismatch()
}
