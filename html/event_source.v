// Copyright (c) 2024, Tim Flynn <trflynn89@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of EventSource.{h,cpp}.
module html

import dom

pub struct EventSourceInit {
pub:
	with_credentials bool
}

pub enum EventSourceReadyState {
	connecting
	open
	closed
}

pub enum EventSourceCacheMode {
	no_store
}

pub enum EventSourceInitiatorType {
	other
}

pub struct EventSourceRequest {
pub mut:
	url              dom.URL
	mode             PotentialCORSRequestMode
	credentials_mode CredentialsMode
	headers          map[string]string
	cache_mode       EventSourceCacheMode     = .no_store
	initiator_type   EventSourceInitiatorType = .other
}

pub struct EventSourceResponse {
pub:
	status                u16
	content_type          string
	body                  string
	network_error         bool
	aborted_network_error bool
}

pub type EventSourceFetchHook = fn (&EventSourceRequest) !EventSourceResponse

@[heap]
pub struct EventSource {
	dom.EventTarget
mut:
	url_                  dom.URL
	request_              EventSourceRequest
	reconnection_time_ms_ i64 = 3000
	last_event_id_        string
	event_type_           string
	data_                 string
	pending_input_        string
	stream_bom_processed_ bool
	with_credentials_     bool
	ready_state_          EventSourceReadyState = .connecting
	fetch_hook_           ?EventSourceFetchHook
	last_message_event_   ?&MessageEvent
	reconnect_pending_    bool
	fetch_aborted_        bool
}

pub fn EventSource.construct_impl(url string, base_url dom.URL, init EventSourceInit) !&EventSource {
	url_record := dom.dom_url_parse(url, base_url, 'UTF-8') or {
		return error('SyntaxError: invalid EventSource URL')
	}
	cors_state := if init.with_credentials {
		CORSSettingAttribute.use_credentials
	} else {
		CORSSettingAttribute.anonymous
	}
	potential_request := create_potential_cors_request(url_record, none, cors_state, .no)
	return &EventSource{
		url_:              url_record
		request_:          EventSourceRequest{
			url:              url_record
			mode:             potential_request.mode
			credentials_mode: potential_request.credentials_mode
			headers:          {
				'Accept': 'text/event-stream'
			}
		}
		with_credentials_: init.with_credentials
	}
}

pub fn (source &EventSource) url() string {
	return source.url_.serialize()
}

pub fn (source &EventSource) with_credentials() bool {
	return source.with_credentials_
}

pub fn (source &EventSource) ready_state() EventSourceReadyState {
	return source.ready_state_
}

pub fn (source &EventSource) request() EventSourceRequest {
	return source.request_
}

pub fn (source &EventSource) reconnection_time_ms() i64 {
	return source.reconnection_time_ms_
}

pub fn (source &EventSource) last_event_id() string {
	return source.last_event_id_
}

pub fn (source &EventSource) reconnect_pending() bool {
	return source.reconnect_pending_
}

pub fn (source &EventSource) last_message_event() ?&MessageEvent {
	return source.last_message_event_
}

pub fn (mut source EventSource) set_fetch_hook(hook ?EventSourceFetchHook) {
	source.fetch_hook_ = hook
}

pub fn (mut source EventSource) start_fetch() ! {
	if source.ready_state_ == .closed {
		return error('InvalidStateError: EventSource is closed')
	}
	hook := source.fetch_hook_ or { return error('EventSource has no fetch hook') }

	response := hook(&source.request_)!
	source.receive_response(response)
}

fn event_source_mime_essence(content_type string) string {
	return content_type.all_before(';').trim_space().to_lower()
}

pub fn (mut source EventSource) receive_response(response EventSourceResponse) {
	if source.ready_state_ == .closed {
		return
	}
	if response.aborted_network_error {
		source.fail_the_connection()
		return
	}
	if response.network_error {
		source.reestablish_the_connection()
		return
	}
	if response.status != 200
		|| event_source_mime_essence(response.content_type) != 'text/event-stream' {
		source.fail_the_connection()
		return
	}
	// Reconnection starts a new event stream, whose first UTF-8 BOM is ignored.
	source.pending_input_ = ''
	source.stream_bom_processed_ = false
	source.announce_the_connection()
	source.feed(response.body)
	source.end_of_body(false)
}

pub fn (mut source EventSource) close() {
	source.fetch_aborted_ = true
	source.reconnect_pending_ = false
	source.ready_state_ = .closed
}

pub fn (mut source EventSource) forcibly_close() {
	source.close()
}

pub fn (mut source EventSource) announce_the_connection() {
	if source.ready_state_ == .closed {
		return
	}
	source.ready_state_ = .open
	open_event := dom.Event.create('open', dom.EventInit{})
	unsafe { &dom.EventTarget(source) }.dispatch_event(open_event)
}

pub fn (mut source EventSource) reestablish_the_connection() {
	if source.ready_state_ == .closed {
		return
	}
	source.ready_state_ = .connecting
	source.reconnect_pending_ = true
	if source.last_event_id_ != '' {
		source.request_.headers['Last-Event-ID'] = source.last_event_id_
	}
	error_event := dom.Event.create('error', dom.EventInit{})
	unsafe { &dom.EventTarget(source) }.dispatch_event(error_event)
}

pub fn (mut source EventSource) retry_connection() ! {
	if source.ready_state_ != .connecting || !source.reconnect_pending_ {
		return error('InvalidStateError: no EventSource reconnection is pending')
	}
	source.reconnect_pending_ = false
	source.start_fetch()!
}

pub fn (mut source EventSource) fail_the_connection() {
	if source.ready_state_ == .closed {
		return
	}
	source.ready_state_ = .closed
	source.reconnect_pending_ = false
	error_event := dom.Event.create('error', dom.EventInit{})
	unsafe { &dom.EventTarget(source) }.dispatch_event(error_event)
}

fn (mut source EventSource) process_line(line string) {
	if line == '' {
		source.dispatch_the_event()
		return
	}
	if line.starts_with(':') {
		return
	}
	colon := line.index_u8(`:`)
	if colon < 0 {
		source.process_field(line, '')
		return
	}
	field := line[..colon]
	mut value := line[colon + 1..]
	if value.starts_with(' ') {
		value = value[1..]
	}
	source.process_field(field, value)
}

// Incrementally interpret UTF-8 event-stream text, preserving partial lines
// and treating CR, LF, and CRLF as line endings.
pub fn (mut source EventSource) feed(chunk string) {
	source.pending_input_ += chunk
	if !source.stream_bom_processed_ {
		// UTF-8 decoding ignores just the initial BOM. Retain incomplete BOM
		// prefixes between chunks rather than interpreting them as field bytes.
		bom := '\xef\xbb\xbf'
		if source.pending_input_.len < bom.len && bom.starts_with(source.pending_input_) {
			return
		}
		if source.pending_input_.starts_with(bom) {
			source.pending_input_ = source.pending_input_[bom.len..]
		}
		source.stream_bom_processed_ = true
	}
	for source.pending_input_.len > 0 {
		mut break_index := -1
		for index, byte in source.pending_input_.bytes() {
			if byte == `\r` || byte == `\n` {
				break_index = index
				break
			}
		}
		if break_index < 0 {
			return
		}
		if source.pending_input_[break_index] == `\r`
			&& break_index + 1 == source.pending_input_.len {
			return
		}
		line := source.pending_input_[..break_index]
		mut consumed := break_index + 1
		if source.pending_input_[break_index] == `\r` && consumed < source.pending_input_.len
			&& source.pending_input_[consumed] == `\n` {
			consumed++
		}
		source.pending_input_ = source.pending_input_[consumed..]
		source.process_line(line)
	}
}

pub fn (mut source EventSource) interpret_response(response string) {
	source.feed(response)
}

pub fn (mut source EventSource) end_of_body(network_error bool) {
	if source.pending_input_ != '' {
		mut line := source.pending_input_
		if line.ends_with('\r') {
			line = line[..line.len - 1]
		}
		source.pending_input_ = ''
		source.process_line(line)
	}
	if !network_error && source.ready_state_ != .closed {
		source.reestablish_the_connection()
	}
}

fn event_source_ascii_digits(value string) bool {
	if value == '' {
		return false
	}
	for byte in value.bytes() {
		if byte < `0` || byte > `9` {
			return false
		}
	}
	return true
}

pub fn (mut source EventSource) process_field(field string, value string) {
	match field {
		'event' {
			source.event_type_ = value
		}
		'data' {
			source.data_ += value + '\n'
		}
		'id' {
			if !value.contains_u8(0) {
				source.last_event_id_ = value
			}
		}
		'retry' {
			if event_source_ascii_digits(value) {
				retry := value.i64()
				if retry >= 0 {
					source.reconnection_time_ms_ = retry
				}
			}
		}
		else {}
	}
}

pub fn (mut source EventSource) dispatch_the_event() {
	if source.data_ == '' {
		source.event_type_ = ''
		return
	}
	data := if source.data_.ends_with('\n') {
		source.data_[..source.data_.len - 1]
	} else {
		source.data_
	}
	type_ := if source.event_type_ == '' { 'message' } else { source.event_type_ }
	event := MessageEvent.create(type_, MessageEventInit{
		data:          dom.js_string(data)
		origin:        source.url_.origin()
		last_event_id: source.last_event_id_
	})
	source.event_type_ = ''
	source.data_ = ''
	source.last_message_event_ = event
	if source.ready_state_ != .closed {
		target := unsafe { &dom.EventTarget(source) }
		base_event := unsafe { &dom.Event(event) }
		target.dispatch_event(base_event)
	}
}

pub fn (source &EventSource) set_onopen(handler ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(source) }.set_event_handler_attribute('open', handler)
}

pub fn (source &EventSource) onopen() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(source) }.event_handler_attribute('open')
}

pub fn (source &EventSource) set_onmessage(handler ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(source) }.set_event_handler_attribute('message', handler)
}

pub fn (source &EventSource) onmessage() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(source) }.event_handler_attribute('message')
}

pub fn (source &EventSource) set_onerror(handler ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(source) }.set_event_handler_attribute('error', handler)
}

pub fn (source &EventSource) onerror() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(source) }.event_handler_attribute('error')
}
