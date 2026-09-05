module dom

fn test_request_pointer_lock_returns_rejected_not_supported_error_promise() {
	document := Document.create(url_about_blank())
	element := document.create_element('div')!
	promise := element.request_pointer_lock(none)

	assert promise.state == .rejected
	assert promise.result.kind == .platform_object
	assert promise.result.object_value['name'].string_value == 'NotSupportedError'
	assert promise.result.object_value['message'].string_value == 'request_pointer_lock() is not implemented'
	assert promise.result.object_value['code'].number_value == 9
	assert !promise.is_handled
}
