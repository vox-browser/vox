module html

import dom

fn meter_test_first_element_with_local_name(node &dom.Node, local_name string) ?&dom.Element {
	if element := node.as_element() {
		if element.local_name() == local_name {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := meter_test_first_element_with_local_name(child, local_name) {
			return element
		}
	}
	return none
}

fn test_progress_element_value_max_and_position() {
	document :=
		parse_document('<progress id="p" value="12" max="10"></progress><progress id="i"></progress>')
	document_node := unsafe { &dom.Node(document) }
	progress_element := meter_test_first_element_with_local_name(document_node, 'progress') or {
		panic('missing progress')
	}
	progress := unsafe { &dom.HTMLProgressElement(progress_element) }
	assert html_progress_element_value(progress) == 10
	assert html_progress_element_max(progress) == 10
	assert html_progress_element_position(progress) == 1
	set_html_progress_element_value(progress, -4)
	assert html_progress_element_value(progress) == 0
	set_html_progress_element_max(progress, -1)
	assert html_progress_element_max(progress) == 10

	second := meter_test_first_element_with_local_name(progress_element.as_node().next_sibling() or {
		panic('missing indeterminate progress')
	}, 'progress') or { panic('missing second progress') }
	indeterminate := unsafe { &dom.HTMLProgressElement(second) }
	assert html_progress_element_position(indeterminate) == -1
}

fn test_meter_element_numeric_algorithms() {
	document :=
		parse_document('<meter min="10" max="20" low="12" high="18" optimum="15" value="30"></meter>')
	meter_element := meter_test_first_element_with_local_name(unsafe { &dom.Node(document) },
		'meter') or { panic('missing meter') }
	meter := unsafe { &dom.HTMLMeterElement(meter_element) }
	assert html_meter_element_min(meter) == 10
	assert html_meter_element_max(meter) == 20
	assert html_meter_element_low(meter) == 12
	assert html_meter_element_high(meter) == 18
	assert html_meter_element_optimum(meter) == 15
	assert html_meter_element_value(meter) == 20
	assert html_meter_element_value_state(meter) == .suboptimal

	set_html_meter_element_value(meter, 15)
	assert html_meter_element_value_state(meter) == .optimal
	set_html_meter_element_optimum(meter, 30)
	set_html_meter_element_value(meter, 10)
	assert html_meter_element_value_state(meter) == .even_less_good
}
