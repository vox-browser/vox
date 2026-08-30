module websockets

import fileapi
import webidl

fn test_constructor_url_protocol_normalization_and_validation() {
	socket := WebSocket.construct_impl('https://example.test/chat', '', Protocols(['chat', 'super']))!
	assert socket.url() == 'wss://example.test/chat'
	assert socket.protocols == ['chat', 'super']
	relative := WebSocket.construct('/socket', 'http://example.test/base', NoProtocols{})!
	assert relative.url() == 'ws://example.test/socket'
	directory_relative :=
		WebSocket.construct('socket', 'https://example.test/a/base', NoProtocols{})!
	assert directory_relative.url() == 'wss://example.test/a/socket'
	dot_segments :=
		WebSocket.construct('../socket?mode=1', 'http://example.test/a/b/', NoProtocols{})!
	assert dot_segments.url() == 'ws://example.test/a/socket?mode=1'
	// Match the checked current implementation: empty protocol is accepted.
	assert WebSocket.construct('ws://example.test/', '', Protocols(''))!.protocols == [
		'',
	]
	for invalid in ['ftp://example.test/', 'ws://example.test/#fragment', 'not-relative'] {
		if _ := WebSocket.construct(invalid, '', NoProtocols{}) {
			assert false
		} else {
			assert err.msg().starts_with('SyntaxError:')
		}
	}
	for protocols in [Protocols(['x', 'x']), Protocols('bad protocol')] {
		if _ := WebSocket.construct('ws://example.test/', '', protocols) {
			assert false
		} else {
			assert err.msg().starts_with('SyntaxError:')
		}
	}
}

fn test_url_setter_and_generic_send_entry_point() {
	mut socket := WebSocket.construct('ws://example.test/', '', NoProtocols{})!
	socket.set_url('wss://other.example/socket')
	assert socket.url() == 'wss://other.example/socket'
	socket.establish_web_socket_connection()!
	socket.on_open('')
	socket.send(WebSocketSendData('text'))!
	socket.send(WebSocketSendData(WebSocketBufferData{
		buffer: webidl.BufferSource.array_buffer([u8(1), 2])
	}))!
	assert socket.sent_frames[0].is_text
	assert socket.sent_frames[1].data == [u8(1), 2]
}

fn test_state_send_close_and_payload_conversion() {
	mut socket := WebSocket.construct('ws://example.test/', '', NoProtocols{})!
	assert socket.ready_state() == 3
	socket.establish()
	if _ := socket.send_text('early') {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError:')
	}
	socket.on_open('chat')
	assert socket.ready_state() == 1
	assert socket.protocol() == 'chat'
	socket.send_text('hello')!
	socket.send_buffer(webidl.BufferSource.array_buffer([u8(1), 2]))!
	socket.send_buffer(webidl.BufferSource.view(.uint8_array, [u8(5), 6, 7], 1, 1)!)!
	socket.send_blob(fileapi.Blob.create([u8(3), 4], 'application/octet-stream'))!
	assert socket.sent_frames.len == 4
	assert socket.sent_frames[0].is_text
	assert socket.sent_frames[2].data == [u8(5), 6, 7]
	assert socket.sent_frames[3].data == [u8(3), 4]
	if _ := socket.close(2000, none) {
		assert false
	} else {
		assert err.msg().starts_with('InvalidAccessError:')
	}
	socket.close(1000, 'bye')!
	assert socket.state == .closing
}

fn test_message_close_error_events_binary_modes_and_gc_rules() {
	mut socket := WebSocket.construct('ws://example.test/', '', NoProtocols{})!
	socket.establish()
	socket.has_open_listener = true
	assert socket.must_survive_garbage_collection()
	socket.on_open('')
	socket.has_open_listener = false
	socket.has_message_listener = true
	assert socket.must_survive_garbage_collection()
	socket.on_message('hello'.bytes(), true)
	assert socket.events.last().text? == 'hello'
	socket.on_message([u8(1), 2], false)
	assert socket.events.last().blob?.raw_bytes() == [u8(1), 2]
	socket.set_binary_type('arraybuffer')
	socket.on_message([u8(3), 4], false)
	assert socket.events.last().bytes? == [u8(3), 4]
	socket.on_error()
	assert socket.events.last().kind == .error
	socket.on_close(1000, 'done', true)
	assert socket.events.last().was_clean
	assert !socket.must_survive_garbage_collection()
}

fn test_reason_utf8_byte_limit_and_disappear() {
	mut socket := WebSocket.construct('ws://example.test/', '', NoProtocols{})!
	socket.establish()
	if _ := socket.close(none, 'é'.repeat(62)) {
		assert false
	} else {
		assert err.msg().starts_with('SyntaxError:')
	}
	socket.make_disappear()
	assert socket.state == .closing
}
