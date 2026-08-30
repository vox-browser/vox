// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebSockets/WebSocket.{h,cpp}. Network I/O is represented by
// an explicit backend boundary; URL/protocol validation, state transitions,
// payload conversion, close validation and queued event data run in V.
module websockets

import fileapi
import net.urllib
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

@[heap]
pub struct WebSocket {
pub:
	protocols []string
pub mut:
	state                ReadyState = .closed
	selected_protocol    string
	events               []WebSocketEvent
	sent_frames          []SentFrame
	binary_type          string = 'blob'
	has_open_listener    bool
	has_message_listener bool
	has_error_listener   bool
	has_close_listener   bool
mut:
	url_               string
	connection_created bool
}

pub fn WebSocket.construct(input string, base_url string, protocols Protocols) !&WebSocket {
	return WebSocket.construct_impl(input, base_url, protocols)
}

// The V host supplies the relevant settings object's API base URL explicitly.
// https://websockets.spec.whatwg.org/#dom-websocket-websocket
pub fn WebSocket.construct_impl(input string, base_url string, protocols Protocols) !&WebSocket {
	url := normalize_websocket_url(input, base_url)!
	sequence := match protocols {
		NoProtocols { []string{} }
		string { [protocols] }
		[]string { protocols.clone() }
	}
	mut sorted := sequence.clone()
	sorted.sort()
	for index, protocol in sorted {
		if index + 1 < sorted.len && protocol == sorted[index + 1] {
			return error('SyntaxError: Found a duplicate protocol name in the specified list')
		}
		// Match current upstream behavior: it checks the visible ASCII range,
		// despite the adjacent RFC comment also mentioning separators/non-empty.
		for character in protocol.runes() {
			if character < 0x21 || character > 0x7e {
				return error('SyntaxError: Found invalid character in subprotocol name')
			}
		}
	}
	return &WebSocket{
		protocols: sequence
		url_:      url
	}
}

fn normalize_websocket_url(input string, base_url string) !string {
	reference := urllib.parse(input) or { return error('SyntaxError: Invalid URL') }
	mut parsed := if reference.is_abs() {
		// resolve_reference also removes dot segments from an absolute reference.
		empty_base := urllib.URL{}
		empty_base.resolve_reference(reference) or { return error('SyntaxError: Invalid URL') }
	} else {
		base := urllib.parse(base_url) or { return error('SyntaxError: Invalid URL') }
		if !base.is_abs() {
			return error('SyntaxError: Invalid URL')
		}
		base.resolve_reference(reference) or { return error('SyntaxError: Invalid URL') }
	}
	// urllib cannot distinguish a null fragment from an explicitly empty one,
	// so retain the source spelling check in addition to the parsed value.
	if input.contains('#') || parsed.fragment != '' {
		return error('SyntaxError: Presence of URL fragment is invalid')
	}
	if parsed.scheme == 'http' {
		parsed.scheme = 'ws'
	} else if parsed.scheme == 'https' {
		parsed.scheme = 'wss'
	}
	if parsed.scheme !in ['ws', 'wss'] {
		return error('SyntaxError: Invalid protocol')
	}
	if parsed.host == '' {
		return error('SyntaxError: Invalid URL')
	}
	return parsed.str()
}

// Models the deferred establish_web_socket_connection callback.
pub fn (mut socket WebSocket) establish() {
	socket.establish_web_socket_connection() or { return }
}

// Network creation is the explicit host boundary in the V translation. Once
// invoked, it has the same observable ready-state effect as installing the
// upstream Requests::WebSocket backend.
pub fn (mut socket WebSocket) establish_web_socket_connection() ! {
	if socket.connection_created {
		return
	}
	socket.connection_created = true
	socket.state = .connecting
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

pub fn (mut socket WebSocket) set_binary_type(value string) {
	// The current upstream setter stores the DOMString verbatim.
	socket.binary_type = value
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
				// Match current upstream: views send their viewed ArrayBuffer,
				// rather than only the view's byte range.
				if data.buffer.detached { []u8{}, false } else { data.buffer.bytes.clone(), false }
			}
			WebSocketBlobData { data.blob.raw_bytes(), false }
		}
		socket.sent_frames << SentFrame{
			data:    bytes
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
	socket.events << WebSocketEvent{
		kind:      .close
		code:      code
		reason:    reason
		was_clean: was_clean
	}
}

pub fn (mut socket WebSocket) on_message(message []u8, is_text bool) {
	if socket.state != .open {
		return
	}
	if is_text {
			socket.events << WebSocketEvent{
				kind:   .message
				text:   message.bytestr()
				origin: socket.url()
		}
		return
	}
	if socket.binary_type == 'blob' {
		socket.events << WebSocketEvent{
			kind:   .message
			blob:   fileapi.Blob.create(message.clone(), 'text/plain;charset=utf-8')
			origin: socket.url()
		}
	} else if socket.binary_type == 'arraybuffer' {
		socket.events << WebSocketEvent{
			kind:   .message
			bytes:  message.clone()
			origin: socket.url()
		}
	}
}

pub fn (mut socket WebSocket) make_disappear() {
	if socket.state !in [.closing, .closed] {
		socket.state = .closing
	}
}

pub fn (mut socket WebSocket) finalize() {
	if socket.state !in [.closing, .closed] {
		socket.state = .closing
	}
}

pub fn (socket &WebSocket) must_survive_garbage_collection() bool {
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
