@[has_globals]
module html

import dom

__global (
	svg_script_fetch_count     int
	svg_script_executed_source string
)

fn svg_script_test_fetch(url dom.URL, kind ScriptElementType) !string {
	assert url.serialize() in ['https://example.test/assets/app.js',
		'https://example.test/assets/fail.js']
	assert kind == .classic
	svg_script_fetch_count++
	if url.serialize().ends_with('/fail.js') {
		return error('network error')
	}
	return 'svgExternal()'
}

fn test_failed_external_svg_script_still_releases_the_parser_and_load_delayer() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/page.html' })
	_ = WindowModel.create_top_level(document, none, 'failed-svg-script')!
	document.set_ready_to_run_scripts()
	mut parser := HTMLParser.create(document, '<svg><script href="/assets/fail.js"/></svg><p>after</p>')
	parser.set_script_hooks(svg_script_test_fetch, svg_script_test_execute)
	svg_script_fetch_count = 0
	svg_script_executed_source = ''
	parser.run()
	assert parser.paused()

	mut event_loop := main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
	}

	assert svg_script_fetch_count == 1
	assert svg_script_executed_source == ''
	assert !parser.paused()
	assert !document.has_pending_parsing_blocking_script()
	assert !document.anything_is_delaying_the_load_event()
	assert document.get_elements_by_tag_name('p').length() == 1
}

fn svg_script_test_execute(kind ScriptElementType, source string, base_url dom.URL) ! {
	assert kind == .classic
	assert base_url.serialize() == 'https://example.test/page.html'
	svg_script_executed_source = source
}

fn test_external_svg_script_fetch_pauses_and_resumes_the_html_parser() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/page.html' })
	_ = WindowModel.create_top_level(document, none, 'svg-script')!
	document.set_ready_to_run_scripts()
	mut parser := HTMLParser.create(document, '<svg><script href="/assets/app.js"></script></svg><p>after</p>')
	parser.set_script_hooks(svg_script_test_fetch, svg_script_test_execute)
	svg_script_fetch_count = 0
	svg_script_executed_source = ''

	parser.run()

	assert parser.paused()
	assert document.pending_parsing_blocking_svg_script() != none
	assert document.anything_is_delaying_the_load_event()
	assert svg_script_fetch_count == 0
	assert svg_script_executed_source == ''

	mut event_loop := main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
	}

	assert svg_script_fetch_count == 1
	assert svg_script_executed_source == 'svgExternal()'
	assert !parser.paused()
	assert !document.has_pending_parsing_blocking_script()
	assert !document.anything_is_delaying_the_load_event()
	assert document.get_elements_by_tag_name('p').length() == 1
}

fn test_svg_script_adoption_transfers_an_in_flight_load_event_delay() {
	mut old_document := dom.Document.create(dom.URL{ value: 'https://old.example/page.svg' })
	mut new_document := dom.Document.create(dom.URL{ value: 'https://new.example/adopted.svg' })
	_ = WindowModel.create_top_level(old_document, none, 'old-svg-script')!
	_ = WindowModel.create_top_level(new_document, none, 'new-svg-script')!
	mut script_element := old_document.create_element_ns(dom.namespace_svg_uri, 'script')!
	script_element.set_attribute_value('href', '/pending.js')
	old_document.append_child(script_element)
	script := unsafe { &dom.SVGScriptElement(script_element) }
	mut model := unsafe {
		&SVGScriptElementModel(svg_script_element_model_for_dom_element(script))
	}
	model.process_the_script_element()

	assert old_document.anything_is_delaying_the_load_event()
	assert !new_document.anything_is_delaying_the_load_event()

	new_document.adopt_node(script_element.as_node())
	assert voidptr(model.document_) == voidptr(new_document)
	assert model.base_url_.serialize() == 'https://new.example/adopted.svg'
	assert !old_document.anything_is_delaying_the_load_event()
	assert new_document.anything_is_delaying_the_load_event()

	mut event_loop := main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
	}
	assert !new_document.anything_is_delaying_the_load_event()
}
