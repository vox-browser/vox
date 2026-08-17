module html

import dom

fn test_event_source_construction_and_request() {
	source := EventSource.construct_impl('/events', dom.URL{ value: 'https://example.test/page' }, EventSourceInit{
		with_credentials: true
	})!
	assert source.url() == 'https://example.test/events'
	assert source.with_credentials()
	assert source.ready_state() == .connecting
	request := source.request()
	assert request.headers['Accept'] == 'text/event-stream'
	assert request.mode == .cors
	assert request.credentials_mode == .include
}

fn test_event_source_stream_parser_and_reconnect_state() {
	mut source :=
		EventSource.construct_impl('/events', dom.URL{ value: 'https://example.test/' }, EventSourceInit{})!
	source.announce_the_connection()
	source.feed('id: 7\r\nevent: update\ndata: first')
	assert source.last_message_event() == none
	source.feed(' line\ndata: second\nretry: 1250\n\n')
	event := source.last_message_event() or { panic('message was not dispatched') }
	assert event.type_name() == 'update'
	assert event.data().to_string_value() == 'first line\nsecond'
	assert event.origin() == 'https://example.test'
	assert event.last_event_id() == '7'
	assert source.last_event_id() == '7'
	assert source.reconnection_time_ms() == 1250

	source.end_of_body(false)
	assert source.ready_state() == .connecting
	assert source.reconnect_pending()
	assert source.request().headers['Last-Event-ID'] == '7'
}

fn test_event_source_ignores_comments_bad_fields_and_empty_events() {
	mut source :=
		EventSource.construct_impl('https://example.test/events', dom.url_about_blank(), EventSourceInit{})!
	source.announce_the_connection()
	source.interpret_response(':comment\ndata\nretry: 1s\nid: bad\x00id\n\n')
	event := source.last_message_event() or { panic('empty data field must dispatch') }
	assert event.data().to_string_value() == ''
	assert source.reconnection_time_ms() == 3000
	assert source.last_event_id() == ''
}

fn test_event_source_failure_and_close_are_terminal() {
	mut source :=
		EventSource.construct_impl('https://example.test/events', dom.url_about_blank(), EventSourceInit{})!
	source.receive_response(EventSourceResponse{
		status:       200
		content_type: 'text/plain'
	})
	assert source.ready_state() == .closed
	source.announce_the_connection()
	assert source.ready_state() == .closed

	mut open_source := EventSource.construct_impl('https://example.test/events',
		dom.url_about_blank(), EventSourceInit{})!
	open_source.announce_the_connection()
	open_source.close()
	open_source.feed('data: ignored\n\n')
	assert open_source.ready_state() == .closed
	assert open_source.last_message_event() != none
}
