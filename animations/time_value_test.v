module animations

import dom

fn test_time_value_units_and_arithmetic() {
	time := TimeValue.milliseconds(250)
	assert time.str() == '250.0ms'
	assert time.add(TimeValue.milliseconds(50))!.value == 300
	assert time.multiply(2).value == 500
	assert time.ratio(TimeValue.milliseconds(125))! == 2
	if _ := time.add(TimeValue.percentage(10)) {
		assert false
	} else {
		assert err.msg().contains('different units')
	}
}

fn test_document_and_scroll_timeline_time_values() {
	mut document_timeline := new_document_timeline(none, 25, 100)
	document_timeline.set_document_active(true)
	assert document_timeline.current_time()!.value == 75
	document_timeline.update_current_time(125)
	assert document_timeline.current_time()!.value == 100
	origin_time := document_timeline.convert_to_origin_relative_time(TimeValue.milliseconds(10)) or {
		assert false
		return
	}
	assert origin_time == 35

	mut scroll := new_scroll_timeline(.y)
	scroll.update_from_scroll_metrics(.y, ScrollMetrics{
		is_scroll_container: true
		has_overflow:        true
		scroll_y:            250
		overflow_height:     1000
		container_height:    500
	})
	assert scroll.current_time()!.type_ == .percentage
	assert scroll.current_time()!.value == 50
}

fn test_document_updates_every_associated_timeline_and_honors_disassociation() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	mut first := new_document_timeline(document, 10, 100)
	mut second := new_document_timeline(document, 20, 100)

	document.update_animations_and_send_events(150)
	assert first.current_time()!.value == 140
	assert second.current_time()!.value == 130

	second.set_associated_document(none)
	document.update_animations_and_send_events(200)
	assert first.current_time()!.value == 190
	assert second.current_time()!.value == 130
}
