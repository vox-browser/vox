@[has_globals]
module css

import dom

__global font_loader_completion_tasks []fn ()

fn font_loader_defer_completion(_ &dom.Document, _ bool, steps fn ()) bool {
	unsafe { font_loader_completion_tasks << steps }
	return true
}

@[heap]
struct FontLoaderCompletionOrder {
mut:
	events []string
	delay_during_callback bool
}

fn font_loader_record_parser_check(target voidptr) {
	mut order := unsafe { &FontLoaderCompletionOrder(target) }
	order.events << 'parser-check'
}

fn test_font_completion_subscribers_queue_before_releasing_the_document_load_delay() {
	mut document := dom.Document.create(dom.URL{value:'https://font-order.test/'})
	order := &FontLoaderCompletionOrder{}
	defer { document.clear_html_parser_end_state(voidptr(order)); document.finalize() }
	document.set_html_parser_end_state(voidptr(order), font_loader_record_parser_check)
	computer := FontComputer.create_for_document(document)
	mut loader := FontLoader.create(computer, 'Completion order', [], [], fn [order, document] (_ &PlatformTypeface) {
		mut observed := unsafe { &FontLoaderCompletionOrder(order) }
		observed.events << 'font-completion'
		observed.delay_during_callback = document.anything_is_delaying_the_load_event()
	})
	loader.document_load_event_delayer_ = dom.DocumentLoadEventDelayer.new(mut document)
	loader.font_did_load_or_fail(unsafe { nil })
	assert loader.has_completed
	assert order.delay_during_callback
	assert order.events == ['font-completion','parser-check']
	assert !document.anything_is_delaying_the_load_event()
}

fn test_shared_font_loader_keeps_load_delayed_until_all_completion_tasks_execute() {
	previous_provider := unsafe { font_loading_task_provider_ }
	install_font_loading_task_provider(font_loader_defer_completion)
	defer {
		unsafe { font_loading_task_provider_ = previous_provider }
		unsafe { font_loader_completion_tasks.clear() }
	}
	mut document := dom.Document.create(dom.URL{value:'https://font-order.test/'})
	order := &FontLoaderCompletionOrder{}
	defer { document.clear_html_parser_end_state(voidptr(order)); document.finalize() }
	document.set_html_parser_end_state(voidptr(order), font_loader_record_parser_check)
	computer := FontComputer.create_for_document(document)
	mut loader := FontLoader.create(computer, 'Shared completion', [], [], none)
	for index in 0 .. 2 {
		loader.subscribe(fn [computer, order, index, document] (_ &PlatformTypeface) {
			queue_font_loading_task(computer, true, fn [order, index, document] () {
				mut observed := unsafe { &FontLoaderCompletionOrder(order) }
				observed.events << 'face-${index}'
				assert document.anything_is_delaying_the_load_event()
			})
		})
	}
	loader.document_load_event_delayer_ = dom.DocumentLoadEventDelayer.new(mut document)
	loader.font_did_load_or_fail(unsafe { nil })
	assert document.anything_is_delaying_the_load_event()
	assert order.events.len == 0
	unsafe {
		assert font_loader_completion_tasks.len == 3
		for task in font_loader_completion_tasks { task() }
	}
	assert order.events == ['face-0','face-1','parser-check']
	assert !document.anything_is_delaying_the_load_event()
}

fn test_shared_completed_font_loader_keeps_its_remaining_sources_and_typeface() {
	$if macos {
		computer := FontComputer.create()
		mut loader := FontLoader.create(computer, 'Settled source', [], [
			URL.from_url('file:///System/Library/Fonts/Supplemental/Arial.ttf'),
			URL.from_url('file:///System/Library/Fonts/Supplemental/Times New Roman.ttf'),
		], none)
		loader.start_loading_next_url()
		assert loader.has_completed
		assert loader.typeface != unsafe { nil }
		assert loader.urls.len == 1
		first_typeface := loader.typeface
		loader.start_loading_next_url()
		assert loader.urls.len == 1
		assert loader.typeface == first_typeface
	}
}
