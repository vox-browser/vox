// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebSockets/WebSocket.{h,cpp}. Network I/O is represented by
// an explicit backend boundary; URL/protocol validation, state transitions,
// payload conversion, close validation and queued event data run in V.
module websockets

import fileapi
import url as liburl
import webidl

pub enum ReadyState {
	connecting
	open
	closing
	closed
}

pub enum BinaryType {
	blob
	arraybuffer
}

pub enum EventKind {
	open
	error
	close
	message
}

pub struct WebSocketEvent {
pub:
	kind      EventKind
	text      ?string
	bytes     ?[]u8
	blob      ?&fileapi.Blob
	origin    string
	code      u16
	reason    string
	was_clean bool
}

pub struct SentFrame {
pub:
	data    []u8
	is_text bool
}

pub struct WebSocketBufferData {
pub:
	buffer webidl.BufferSource
}

pub struct WebSocketBlobData {
pub:
	blob &fileapi.Blob
}

pub type WebSocketSendData = WebSocketBlobData | WebSocketBufferData | string

pub struct NoProtocols {}

pub type Protocols = NoProtocols | []string | string

pub type WebSocketEstablishConnectionHook = fn (string, []string) !

@[heap]
pub struct WebSocketGlobalScope {
pub:
	api_base_url string
	origin       string
mut:
	establish_connection_hook ?WebSocketEstablishConnectionHook
}

pub fn (mut scope WebSocketGlobalScope) set_establish_connection_hook(hook WebSocketEstablishConnectionHook) {
	scope.establish_connection_hook = hook
}

pub fn WebSocketGlobalScope.create(api_base_url string, origin string) &WebSocketGlobalScope {
	return &WebSocketGlobalScope{
		api_base_url: api_base_url
		origin: origin
	}
}

@[heap]
pub struct WebSocket {
pub:
	protocols []string
pub mut:
	state                ReadyState = .closed
	selected_protocol    string
	events               []WebSocketEvent
	sent_frames          []SentFrame
	binary_type          BinaryType = .blob
	has_open_listener    bool
	has_message_listener bool
	has_error_listener   bool
	has_close_listener   bool
mut:
	url_               string
	connection_created bool
	relevant_global_   &WebSocketGlobalScope = unsafe { nil }
	has_activity_root_ bool
	has_disappeared_   bool
	is_registered_     bool
}

pub fn WebSocket.construct(input string, base_url string, protocols Protocols) !&WebSocket {
	return WebSocket.construct_impl(input, base_url, protocols)
}

// The V host supplies the relevant settings object's API base URL explicitly.
// https://websockets.spec.whatwg.org/#dom-websocket-websocket
pub fn WebSocket.construct_impl(input string, base_url string, protocols Protocols) !&WebSocket {
	global_scope := WebSocketGlobalScope.create(base_url, '')
	return WebSocket.create(global_scope, input, protocols)
}

pub fn WebSocket.create(global_scope &WebSocketGlobalScope, input string, protocols Protocols) !&WebSocket {
	url := normalize_websocket_url(input, global_scope.api_base_url)!
	sequence := match protocols {
		NoProtocols { []string{} }
		string { [protocols] }
		[]string { protocols.clone() }
	}
	mut sorted := sequence.clone()
	sorted.sort()
	for index, protocol in sorted {
		if protocol == '' {
			return error('SyntaxError: Found empty protocol name')
		}
		if index + 1 < sorted.len && protocol == sorted[index + 1] {
			return error('SyntaxError: Found a duplicate protocol name in the specified list')
		}
		// Match current upstream behavior: empty names and characters outside the
		// visible ASCII range are rejected; separators are not checked separately.
		for character in protocol.runes() {
			if character < 0x21 || character > 0x7e {
				return error('SyntaxError: Found invalid character in subprotocol name')
			}
		}
	}
	return &WebSocket{
		protocols: sequence
		url_: url
		relevant_global_: global_scope
		is_registered_: true
	}
}

pub fn WebSocket.create_for_constructor(global_scope &WebSocketGlobalScope, input string, protocols Protocols) !&WebSocket {
	return WebSocket.create(global_scope, input, protocols)
}

fn normalize_websocket_url(input string, base_url string) !string {
	mut parsed := liburl.parse(input) or {
		base := liburl.parse(base_url) or { return error('SyntaxError: Invalid URL') }
		liburl.parse_with_base(input, &base) or { return error('SyntaxError: Invalid URL') }
	}
	if parsed.scheme == 'http' {
		parsed = parsed.with_scheme('ws')
	} else if parsed.scheme == 'https' {
		parsed = parsed.with_scheme('wss')
	}
	if parsed.scheme !in ['ws', 'wss'] {
		return error('SyntaxError: Invalid protocol')
	}
	if parsed.fragment != none {
		return error('SyntaxError: Presence of URL fragment is invalid')
	}
	return parsed.serialize(false)
}

// Models the deferred establish_web_socket_connection callback.
pub fn (mut socket WebSocket) establish() {
	socket.establish_web_socket_connection() or {
		// The translated backend can fail before producing a live connection.
		// Surface that startup failure through the events required by the JS API.
		socket.on_error()
		socket.on_close(1006, '', false)
		return
	}
}

// Network creation is the explicit host boundary in the V translation. Once
// invoked, it has the same observable ready-state effect as installing the
// upstream Requests::WebSocket backend.
pub fn (mut socket WebSocket) establish_web_socket_connection() ! {
	if socket.connection_created {
		return
	}
	if hook := socket.relevant_global_scope().establish_connection_hook {
		hook(socket.url_, socket.protocols)!
	}
	socket.connection_created = true
	socket.state = .connecting
	socket.update_activity_root()
}

pub fn (socket &WebSocket) relevant_global_object() &WebSocketGlobalScope {
	return socket.relevant_global_scope()
}

pub fn (socket &WebSocket) relevant_global_scope() &WebSocketGlobalScope {
	if socket.relevant_global_ == unsafe { nil } {
		panic('WebSocket has no relevant global scope')
	}
	return socket.relevant_global_
}

pub fn (socket &WebSocket) url() string {
	return socket.url_
}

pub fn (mut socket WebSocket) set_url(value string) {
	socket.url_ = value
}

pub fn (socket &WebSocket) ready_state() u16 {
	return u16(socket.state)
}

pub fn (socket &WebSocket) extensions() string {
	return ''
}

pub fn (socket &WebSocket) protocol() string {
	return socket.selected_protocol
}

pub fn (mut socket WebSocket) set_binary_type(value BinaryType) {
	socket.binary_type = value
}

pub fn (socket &WebSocket) binary_type() BinaryType {
	return socket.binary_type
}

pub fn (mut socket WebSocket) close(code ?u16, reason ?string) ! {
	if close_code := code {
		if close_code != 1000 && (close_code < 3000 || close_code > 4999) {
			return error('InvalidAccessError: The close error code is invalid')
		}
	}
	if close_reason := reason {
		if close_reason.bytes().len > 123 {
			return error('SyntaxError: The close reason is longer than 123 bytes')
		}
	}
	if socket.state in [.closing, .closed] {
		return
	}
	socket.state = .closing
	socket.update_activity_root()
}

pub fn (mut socket WebSocket) send_text(data string) ! {
	socket.send(WebSocketSendData(data))!
}

pub fn (mut socket WebSocket) send_buffer(source webidl.BufferSource) ! {
	socket.send(WebSocketSendData(WebSocketBufferData{source}))!
}

pub fn (mut socket WebSocket) send_blob(blob &fileapi.Blob) ! {
	socket.send(WebSocketSendData(WebSocketBlobData{blob}))!
}

// https://websockets.spec.whatwg.org/#dom-websocket-send
pub fn (mut socket WebSocket) send(data WebSocketSendData) ! {
	if socket.state == .connecting {
		return error('InvalidStateError: Websocket is still CONNECTING')
	}
	if socket.state == .open {
		bytes, is_text := match data {
			string { data.bytes(), true }
			WebSocketBufferData {
				webidl.get_buffer_source_copy(data.buffer), false
			}
			WebSocketBlobData { data.blob.raw_bytes(), false }
		}
		socket.sent_frames << SentFrame{
			data: bytes
			is_text: is_text
		}
	}
}

pub fn (mut socket WebSocket) on_open(selected_protocol string) {
	if socket.state != .connecting {
		return
	}
	socket.state = .open
	socket.selected_protocol = selected_protocol
	socket.update_activity_root()
	socket.events << WebSocketEvent{
		kind: .open
	}
}

pub fn (mut socket WebSocket) on_error() {
	socket.events << WebSocketEvent{
		kind: .error
	}
}

pub fn (mut socket WebSocket) on_close(code u16, reason string, was_clean bool) {
	socket.state = .closed
	socket.update_activity_root()
	socket.events << WebSocketEvent{
		kind: .close
		code: code
		reason: reason
		was_clean: was_clean
	}
}

pub fn (mut socket WebSocket) on_message(message []u8, is_text bool) {
	if socket.state != .open {
		return
	}
	if is_text {
		socket.events << WebSocketEvent{
			kind: .message
			text: message.bytestr()
			origin: socket.message_origin()
		}
		return
	}
	if socket.binary_type == .blob {
		socket.events << WebSocketEvent{
			kind: .message
			blob: fileapi.Blob.create(message.clone(), '')
			origin: socket.message_origin()
		}
	} else if socket.binary_type == .arraybuffer {
		socket.events << WebSocketEvent{
			kind: .message
			bytes: message.clone()
			origin: socket.message_origin()
		}
	}
}

fn (socket &WebSocket) message_origin() string {
	parsed := liburl.parse(socket.url_) or { return 'null' }
	return parsed.origin().serialize()
}

pub fn (mut socket WebSocket) make_disappear() {
	socket.has_disappeared_ = true
	if socket.state !in [.closing, .closed] {
		socket.state = .closing
	}
	socket.update_activity_root()
}

pub fn (mut socket WebSocket) finalize() {
	if socket.state !in [.closing, .closed] {
		socket.state = .closing
	}
	socket.has_activity_root_ = false
	socket.is_registered_ = false
}

pub fn (socket &WebSocket) should_be_kept_alive() bool {
	if socket.has_disappeared_ {
		return false
	}
	return match socket.state {
		.connecting {
			socket.has_open_listener || socket.has_message_listener || socket.has_error_listener
				|| socket.has_close_listener
		}
		.open {
			socket.has_message_listener || socket.has_error_listener || socket.has_close_listener
		}
		.closing {
			socket.has_error_listener || socket.has_close_listener
		}
		.closed {
			false
		}
	}
}

pub fn (socket &WebSocket) must_survive_garbage_collection() bool {
	return socket.should_be_kept_alive()
}

pub fn (mut socket WebSocket) update_activity_root() {
	socket.has_activity_root_ = socket.should_be_kept_alive()
}

pub fn (mut socket WebSocket) event_listener_list_changed() {
	socket.update_activity_root()
}

pub fn (socket &WebSocket) has_activity_root() bool {
	return socket.has_activity_root_
}

pub fn (socket &WebSocket) is_registered_with_global() bool {
	return socket.is_registered_
}
