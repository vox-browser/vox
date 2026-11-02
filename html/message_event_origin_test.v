module html

import dom

fn test_message_event_empty_origin_has_a_valid_sum_type_in_defaults_and_native_events() {
	init := MessageEventInit{}
	assert init.origin is EmptyMessageOrigin
	for event in [MessageEvent.create('message', init), &MessageEvent{}] {
		assert event.origin_ is EmptyMessageOrigin
		assert event.origin() == ''
		assert event.last_event_id() == ''
		assert event.source() == none
		assert event.ports().len == 0
	}
}

fn test_message_event_explicit_origins_and_initialization_preserve_the_selected_value() {
	origin := dom.URL{ value: 'https://message-origin.test/path' }.origin()
	mut event := MessageEvent.create('message', MessageEventInit{ origin: origin })
	assert event.origin_ is dom.Origin
	assert event.origin() == 'https://message-origin.test'
	event.init_message_event('next', false, false, dom.js_null(), 'verbatim origin', 'event id', none, [])
	assert event.origin_ is string
	assert event.origin() == 'verbatim origin'
	assert event.last_event_id() == 'event id'
}
