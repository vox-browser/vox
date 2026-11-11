module html

import dom
import fetch
import mimesniff
import streams
import webidl

fn native_body_text_stream_owner() !(&dom.Document, &EnvironmentSettingsObject, &EventLoop) {
	url := dom.URL{value: 'https://native-body-text-stream.test/'}
	mut document := dom.Document.create(url)
	document.set_origin(url.origin())
	window := WindowModel.create_top_level(document, none, '')!
	mut settings := window.environment_settings_.settings
	owner := EventLoop.create(.window)
	settings.responsible_event_loop_ = owner
	return document, settings, owner
}

fn test_native_body_text_stream_null_bytes_and_unusable_bodies() {
	mut document, settings, mut owner := native_body_text_stream_owner()!
	defer { document.finalize() }
	realm := settings.stream_realm()
	empty := fetch.BodyMixin{}
	mut first := settings.body_text_stream_in_realm(empty, realm)!
	second := settings.body_text_stream_in_realm(empty, realm)!
	assert voidptr(first) != voidptr(second)
	assert first.realm().id == realm.id
	assert first.state() == .closed && second.state() == .closed
	assert !empty.body_used()
	if _ := first.get_byob_reader() { assert false } else { assert err.msg().starts_with('TypeError:') }
	mut empty_reader := first.get_default_reader()!
	assert empty_reader.read().result().done
	assert !empty.body_used()

	body := fetch.BodyMixin{
		body: fetch.Body.from_bytes([u8(`h`), 0, `i`, 0], .bytes)
		mime_type: mimesniff.MimeType.parse('text/plain;charset=utf-16le')
	}
	mut output := settings.body_text_stream_in_realm(body, realm)!
	assert body.body_used()
	if _ := settings.body_text_stream_in_realm(body, realm) { assert false } else { assert err.msg() == 'TypeError: Body is unusable' }
	mut reader := output.get_default_reader()!
	read := reader.read()
	owner.perform_a_microtask_checkpoint()
	assert read.state() == .fulfilled
	assert !read.result().done && read.result().value.kind == .string_
	assert read.result().value.text == 'h\0i\0'
	end := reader.read()
	owner.perform_a_microtask_checkpoint()
	assert end.state() == .fulfilled && end.result().done

	locked_body := fetch.Body.from_bytes('locked'.bytes(), .bytes)
	mut locked_source := locked_body.stream()
	mut held_reader := locked_source.get_default_reader()!
	if _ := settings.body_text_stream_in_realm(fetch.BodyMixin{body: locked_body}, realm) { assert false } else { assert err.msg() == 'TypeError: Body is unusable' }
	assert !locked_body.disturbed()
	held_reader.release_lock()!
}

fn test_native_body_text_stream_decodes_incrementally_before_source_close() {
	mut document, settings, mut owner := native_body_text_stream_owner()!
	defer { document.finalize() }
	realm := settings.stream_realm()
	mut source := streams.ReadableStream.create_for_constructor(realm,
		streams.UnderlyingSource{type_: .bytes}, streams.QueuingStrategy{})!
	body := fetch.BodyMixin{body: fetch.Body.create(source, .readable_stream, none)}
	mut output := settings.body_text_stream_in_realm(body, realm)!
	assert body.body_used()
	mut reader := output.get_default_reader()!
	first := reader.read()
	source.enqueue(streams.bytes_value([u8(0xef)]))!
	source.enqueue(streams.bytes_value([u8(0xbb), 0xbf, 0xe2, 0x82]))!
	owner.perform_a_microtask_checkpoint()
	assert first.state() == .pending
	source.enqueue(streams.bytes_value([u8(0xac)]))!
	owner.perform_a_microtask_checkpoint()
	assert first.state() == .fulfilled
	assert first.result().value.text == '€' && !first.result().done
	assert source.state() == .readable
	last := reader.read()
	source.enqueue(streams.bytes_value([u8(0xe2), 0x82]))!
	source.close()
	owner.perform_a_microtask_checkpoint()
	assert last.state() == .fulfilled
	assert last.result().value.text == '�' && !last.result().done
	end := reader.read()
	owner.perform_a_microtask_checkpoint()
	assert end.state() == .fulfilled && end.result().done
}

@[heap]
struct NativeBodyTextStreamCancellation {
mut:
	called bool
	reason streams.Value
}

fn test_native_body_text_stream_preserves_source_errors_and_cancel_reasons() {
	mut document, settings, mut owner := native_body_text_stream_owner()!
	defer { document.finalize() }
	realm := settings.stream_realm()
	marker := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('OperationError', 'body marker'))
	mut state := &NativeBodyTextStreamCancellation{}
	mut source := streams.ReadableStream.create_for_constructor(realm, streams.UnderlyingSource{
		cancel: fn [mut state] (reason streams.Value) ! {
			state.called = true
			state.reason = reason
		}
	}, streams.QueuingStrategy{})!
	mut output := settings.body_text_stream_in_realm(fetch.BodyMixin{
		body: fetch.Body.create(source, .readable_stream, none)
	}, realm)!
	cancel := output.cancel(streams.runtime_value(marker))
	owner.perform_a_microtask_checkpoint()
	assert cancel.state() == .fulfilled
	assert state.called && source.state() == .closed
	actual_reason := state.reason.runtime_value_ or { panic('missing cancellation value') }
	assert actual_reason.opaque_id == marker.opaque_id
	actual_record := actual_reason.dom_exception_ or { panic('missing cancellation record') }
	original_record := marker.dom_exception_ or { panic('missing marker record') }
	assert voidptr(actual_record) == voidptr(original_record)

	mut failed_source := streams.ReadableStream.create_for_constructor(realm,
		streams.UnderlyingSource{}, streams.QueuingStrategy{})!
	failed_source.error_value(marker)
	mut failed_output := settings.body_text_stream_in_realm(fetch.BodyMixin{
		body: fetch.Body.create(failed_source, .readable_stream, none)
	}, realm)!
	mut failed_reader := failed_output.get_default_reader()!
	failed_read := failed_reader.read()
	owner.perform_a_microtask_checkpoint()
	assert failed_read.state() == .rejected
	assert failed_read.as_webidl_promise().result.opaque_id == marker.opaque_id
}
