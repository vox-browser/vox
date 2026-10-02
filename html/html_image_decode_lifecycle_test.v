module html

import dom

fn active_image_decode_fixture(path string) (&dom.Document, &EventLoop, &HTMLImageElementModel) {
	document := parse_document_with_url('<!doctype html><img id="image">', dom.URL{value: 'https://image-decode.example/${path}'})
	window := WindowModel.create_top_level(document, none, 'image-decode') or { panic(err) }
	mut settings := window.environment_settings_.settings
	owner := EventLoop.create(.window)
	settings.responsible_event_loop_ = owner
	element := document.get_element_by_id('image') or { panic('image missing') }
	model := html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	return document, owner, model
}

fn execute_image_decode_settlement(owner &EventLoop, document &dom.Document) {
	mut queue := owner.task_queue()
	task := queue.take_first_runnable() or { panic('decode task missing') }
	assert task.source() == .dom_manipulation
	assert task.document() or { panic('settlement document missing') } == document
	task.execute()
}

fn start_pending_image_decode(mut image HTMLImageElementModel, mut owner EventLoop) (&dom.Promise, &SharedResourceRequest) {
	mut request := image.current_request()
	request.set_current_url('${image.document_.url.serialize()}-image.png')
	request.set_state(.partially_available)
	image.add_callbacks_to_image_request(request, false, request.current_url(), '', 0)
	promise := image.decode()
	assert promise.state() == .pending
	owner.perform_a_microtask_checkpoint()
	assert promise.state() == .pending
	return promise, request.shared_resource_request() or { panic('shared request missing') }
}

fn lifecycle_decoded_image() DecodedImageData {
	bitmap := &dom.Bitmap_{width: 1, height: 1, pitch: 4, data: [u8(0), 0, 0, 255]}
	return BitmapDecodedImageData.create([BitmapDecodedImageFrame{frame: dom.DecodedImageFrame_.create(bitmap)}], 0, false)
}

fn test_already_available_decode_queues_a_microtask_before_the_owning_document_settlement_task() {
	document, mut owner, mut image := active_image_decode_fixture('available')
	mut request := image.current_request()
	request.set_state(.completely_available)
	promise := image.decode()
	assert promise.state() == .pending
	assert owner.microtask_queue.len == 1
	assert owner.task_queue().is_empty()
	owner.perform_a_microtask_checkpoint()
	assert promise.state() == .pending
	assert owner.microtask_queue.len == 0
	execute_image_decode_settlement(owner, document)
	assert promise.state() == .fulfilled
}

fn test_decode_checks_activity_and_request_state_in_the_microtask() {
	_, mut owner, mut image := active_image_decode_fixture('broken')
	promise := image.decode()
	mut request := image.current_request()
	request.set_state(.broken)
	assert promise.state() == .pending
	owner.perform_a_microtask_checkpoint()
	assert promise.state() == .rejected
	assert promise.result().to_string_value().contains('Current request state is broken')
	assert owner.task_queue().is_empty()
	mut inactive_document := dom.Document.create(dom.URL{value: 'https://image-decode.example/inactive'})
	mut inactive := HTMLImageElementModel.create(inactive_document, inactive_document.base_url())
	mut inactive_request := inactive.current_request()
	inactive_request.set_state(.completely_available)
	inactive_promise := inactive.decode()
	assert inactive_promise.state() == .pending
	mut main_owner := main_thread_event_loop()
	main_owner.perform_a_microtask_checkpoint()
	assert inactive_promise.state() == .rejected
	assert inactive_promise.result().to_string_value().contains('Node document not fully active')
}

fn test_decode_without_a_resource_queues_rejection_after_the_microtask() {
	document, mut owner, image := active_image_decode_fixture('no-resource')
	promise := image.decode()
	owner.perform_a_microtask_checkpoint()
	assert promise.state() == .pending
	execute_image_decode_settlement(owner, document)
	assert promise.state() == .rejected
	assert promise.result().to_string_value().contains('Current request changed or was mutated')
}

fn test_pending_decode_rechecks_request_identity_after_the_success_batch() {
	document, mut owner, mut image := active_image_decode_fixture('changed')
	promise, mut resource := start_pending_image_decode(mut image, mut owner)
	image.set_fetch_hook(fn (_ dom.URL) !DecodedImageData { return lifecycle_decoded_image() })
	mut element := image.to_html_element() or { panic('element missing') }
	element.set_attribute_value('src', '/replacement.png')
	image.update_the_image_data(false, false)
	resource.handle_successful_resource_load(lifecycle_decoded_image())
	mut dispatcher := batching_dispatcher()
	dispatcher.process()
	assert promise.state() == .pending
	execute_image_decode_settlement(owner, document)
	assert promise.state() == .rejected
	assert promise.result().to_string_value().contains('Current request changed or was mutated')
}

fn test_pending_decode_rechecks_the_adopted_document_before_success_and_failure_settlement() {
	for success in [true, false] {
		document, mut owner, mut image := active_image_decode_fixture('adopt-${success}')
		promise, mut resource := start_pending_image_decode(mut image, mut owner)
		mut inactive := dom.Document.create(dom.URL{value: 'https://image-decode.example/adopted-inactive'})
		element := image.to_html_element() or { panic('element missing') }
		inactive.adopt_node(element.as_node())
		assert image.document_ == inactive
		if success { resource.handle_successful_resource_load(lifecycle_decoded_image()) }
		else { resource.handle_failed_fetch() }
		mut dispatcher := batching_dispatcher()
		dispatcher.process()
		assert promise.state() == .pending
		execute_image_decode_settlement(owner, document)
		assert promise.state() == .rejected
		assert promise.result().to_string_value().contains('Node document not fully active')
	}
}
