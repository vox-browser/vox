module browsernet

import browsercookies
import crypto.sha1
import encoding.base64
import encoding.utf8
import net
import net.http
import net.ssl
import platform
import rand
import strings
import sync
import time
import url

#include "@DIR/websocket_wake.h"

fn C.vox_websocket_wake_create() voidptr
fn C.vox_websocket_wake_signal(wake voidptr)
fn C.vox_websocket_wake_wait(wake voidptr, socket i64, timeout_ms i32) i32
fn C.vox_websocket_wake_close(wake voidptr)
fn C.mbedtls_ssl_get_bytes_avail(ssl voidptr) uint

const websocket_guid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
const websocket_max_message = 64 * 1024 * 1024
const websocket_max_handshake = 64 * 1024
const websocket_close_wait_ms = 5000

pub enum WebSocketEventKind {
	open
	message
	error
	close
}

// One RFC 6455 connection event, delivered to the owning thread in order.
pub struct WebSocketEvent {
pub:
	kind       WebSocketEventKind
	text       bool
	data       []u8
	protocol   string
	extensions string
	code       u16
	reason     string
	was_clean  bool
}

struct WebSocketOutgoing {
	opcode  u8
	payload []u8
}

// A client WebSocket connection. Its own thread owns the socket: the owning
// thread only queues frames and takes events, so TLS state is never shared.
@[heap]
pub struct WebSocketConnection {
	address    string
	origin     string
	source_url string
	protocols  []string
	ca_bundle  string
	notify     fn () = unsafe { nil }
mut:
	mu         &sync.Mutex = sync.new_mutex()
	outgoing   []WebSocketOutgoing
	events     []WebSocketEvent
	wake       voidptr
	finished   bool
	close_requested bool
	close_code u16
	close_reason string
}

// Starts connecting to a ws: or wss: URL. `notify` runs on the connection
// thread whenever new events can be taken; it must only wake the owner.
pub fn WebSocketConnection.open(address string, origin string, source_url string, protocols []string,
	ca_bundle string, notify fn ()) &WebSocketConnection {
	mut connection := &WebSocketConnection{
		address:    address.clone()
		origin:     origin.clone()
		source_url: source_url.clone()
		protocols:  protocols.clone()
		ca_bundle:  ca_bundle.clone()
		notify:     notify
		wake:       C.vox_websocket_wake_create()
	}
	spawn connection.run()
	return connection
}

pub fn (mut connection WebSocketConnection) send_text(text string) {
	connection.queue(1, text.bytes())
}

pub fn (mut connection WebSocketConnection) send_binary(data []u8) {
	connection.queue(2, data.clone())
}

// Starts the closing handshake; a connection that has not opened is dropped.
pub fn (mut connection WebSocketConnection) close(code u16, reason string) {
	connection.mu.lock()
	if !connection.finished && !connection.close_requested {
		connection.close_requested = true
		connection.close_code = code
		connection.close_reason = reason.clone()
		C.vox_websocket_wake_signal(connection.wake)
	}
	connection.mu.unlock()
}

pub fn (mut connection WebSocketConnection) take_events() []WebSocketEvent {
	connection.mu.lock()
	defer { connection.mu.unlock() }
	if connection.events.len == 0 { return [] }
	events := connection.events
	connection.events = []WebSocketEvent{}
	return events
}

pub fn (mut connection WebSocketConnection) is_finished() bool {
	connection.mu.lock()
	defer { connection.mu.unlock() }
	return connection.finished && connection.events.len == 0
}

fn (mut connection WebSocketConnection) queue(opcode u8, payload []u8) {
	connection.mu.lock()
	if !connection.finished && !connection.close_requested {
		connection.outgoing << WebSocketOutgoing{ opcode: opcode, payload: payload }
		C.vox_websocket_wake_signal(connection.wake)
	}
	connection.mu.unlock()
}

fn (mut connection WebSocketConnection) emit(event WebSocketEvent) {
	connection.mu.lock()
	connection.events << event
	connection.mu.unlock()
	if connection.notify != unsafe { nil } { connection.notify() }
}

// Fail the WebSocket connection: an error event followed by an unclean close.
fn (mut connection WebSocketConnection) fail() {
	connection.emit(WebSocketEvent{ kind: .error })
	connection.emit(WebSocketEvent{ kind: .close, code: 1006 })
}

struct WebSocketStream {
mut:
	tcp &net.TcpConn = unsafe { nil }
	tls &ssl.SSLConn = unsafe { nil }
}

fn (mut stream WebSocketStream) read(mut buffer []u8) !int {
	if stream.tls != unsafe { nil } { return stream.tls.read(mut buffer) }
	return stream.tcp.read(mut buffer)
}

fn (mut stream WebSocketStream) write_all(data []u8) ! {
	mut sent := 0
	for sent < data.len {
		n := if stream.tls != unsafe { nil } {
			stream.tls.write(data[sent..])!
		} else {
			stream.tcp.write(data[sent..])!
		}
		if n <= 0 { return error('WebSocket write made no progress') }
		sent += n
	}
}

fn (stream &WebSocketStream) handle() int {
	if stream.tls != unsafe { nil } { return stream.tls.handle }
	return stream.tcp.sock.handle
}

// TLS can hold decrypted application data after the socket drains.
fn (stream &WebSocketStream) buffered() bool {
	$if !use_openssl ? {
		if stream.tls != unsafe { nil } {
			return C.mbedtls_ssl_get_bytes_avail(voidptr(&stream.tls.ssl)) > 0
		}
	}
	return false
}

fn (mut stream WebSocketStream) close() {
	if stream.tls != unsafe { nil } {
		stream.tls.shutdown() or {}
	} else if stream.tcp != unsafe { nil } {
		stream.tcp.close() or {}
	}
}

struct WebSocketTarget {
	secure    bool
	host      string
	port      int
	resource  string
	host_line string
	http_url  string
}

fn websocket_target(address string) !WebSocketTarget {
	parsed := url.parse(address) or { return error('Invalid WebSocket URL') }
	secure := match parsed.scheme {
		'wss' { true }
		'ws' { false }
		else { return error('Unsupported WebSocket URL scheme') }
	}
	host_record := parsed.host or { return error('WebSocket URL has no host') }
	host := host_record.serialize().trim('[]')
	default_port := if secure { 443 } else { 80 }
	port := if explicit := parsed.port { int(explicit) } else { default_port }
	mut resource := parsed.serialize_path()
	if resource == '' { resource = '/' }
	if query := parsed.query { resource += '?' + query }
	bracketed := if host.contains(':') { '[${host}]' } else { host }
	host_line := if port == default_port { bracketed } else { '${bracketed}:${port}' }
	scheme := if secure { 'https' } else { 'http' }
	return WebSocketTarget{
		secure:    secure
		host:      host
		port:      port
		resource:  resource
		host_line: host_line
		http_url:  '${scheme}://${host_line}${resource}'
	}
}

fn websocket_accept_value(key string) string {
	return base64.encode(sha1.sum((key + websocket_guid).bytes()))
}

fn (connection &WebSocketConnection) dial(target WebSocketTarget) !WebSocketStream {
	proxy := request_proxy(target.http_url)!
	address := if target.host.contains(':') { '[${target.host}]:${target.port}' } else { '${target.host}:${target.port}' }
	mut tcp := if proxy != '' { http.dial_tcp_via_proxy(proxy, address)! } else { net.dial_tcp(address)! }
	tcp.set_read_timeout(30 * time.second)
	tcp.set_write_timeout(30 * time.second)
	if !target.secure { return WebSocketStream{ tcp: tcp } }
	mut tls := ssl.new_ssl_conn(verify: connection.ca_bundle, validate: true) or {
		tcp.close() or {}
		return err
	}
	tls.connect(mut tcp, target.host) or {
		tcp.close() or {}
		return err
	}
	tls.owns_socket = true
	tls.set_read_timeout(30 * time.second)
	return WebSocketStream{ tcp: tcp, tls: tls }
}

// Opening handshake (RFC 6455 section 4). Returns the selected subprotocol and
// any bytes the server sent after its response headers.
fn (connection &WebSocketConnection) handshake(mut stream WebSocketStream, target WebSocketTarget) !(string, []u8) {
	key := base64.encode(rand.bytes(16)!)
	mut request := strings.new_builder(512)
	request.write_string('GET ${target.resource} HTTP/1.1\r\nHost: ${target.host_line}\r\n')
	request.write_string('Upgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: ${key}\r\n')
	request.write_string('Sec-WebSocket-Version: 13\r\nPragma: no-cache\r\nCache-Control: no-cache\r\n')
	if connection.origin != '' { request.write_string('Origin: ${connection.origin}\r\n') }
	request.write_string('User-Agent: ${request_user_agent(target.http_url)}\r\n')
	if connection.protocols.len > 0 {
		request.write_string('Sec-WebSocket-Protocol: ${connection.protocols.join(', ')}\r\n')
	}
	cookies := browsercookies.request_header(target.http_url, connection.source_url, false, 'GET')
	if cookies != '' { request.write_string('Cookie: ${cookies}\r\n') }
	request.write_string('\r\n')
	stream.write_all(request.str().bytes())!
	mut received := []u8{}
	mut chunk := []u8{len: 4096}
	mut end := -1
	for end < 0 {
		n := stream.read(mut chunk)!
		if n <= 0 { return error('WebSocket server closed the connection during the handshake') }
		received << chunk[..n]
		end = received.bytestr().index('\r\n\r\n') or { -1 }
		if end < 0 && received.len > websocket_max_handshake {
			return error('WebSocket handshake response is too large')
		}
	}
	head := received[..end].bytestr()
	rest := received[end + 4..].clone()
	lines := head.split('\r\n')
	status := lines[0].fields()
	if status.len < 2 || status[1] != '101' {
		return error('WebSocket handshake failed: ${lines[0]}')
	}
	mut headers := map[string]string{}
	mut set_cookies := []string{}
	for line in lines[1..] {
		colon := line.index(':') or { continue }
		name := line[..colon].trim_space().to_lower()
		value := line[colon + 1..].trim_space()
		if name == 'set-cookie' {
			set_cookies << value
			continue
		}
		headers[name] = if name in headers { headers[name] + ', ' + value } else { value }
	}
	if (headers['upgrade'] or { '' }).to_lower() != 'websocket'
		|| !(headers['connection'] or { '' }).to_lower().split(',').any(it.trim_space() == 'upgrade') {
		return error('WebSocket handshake response is not an upgrade')
	}
	if (headers['sec-websocket-accept'] or { '' }) != websocket_accept_value(key) {
		return error('WebSocket handshake has an invalid Sec-WebSocket-Accept')
	}
	if (headers['sec-websocket-extensions'] or { '' }) != '' {
		return error('WebSocket server selected an extension that was not requested')
	}
	protocol := headers['sec-websocket-protocol'] or { '' }
	if protocol != '' && protocol !in connection.protocols {
		return error('WebSocket server selected an unrequested subprotocol')
	}
	if protocol == '' && connection.protocols.len > 0 && 'sec-websocket-protocol' in headers {
		return error('WebSocket server selected an empty subprotocol')
	}
	if set_cookies.len > 0 {
		browsercookies.store_response_cookies(target.http_url, connection.source_url, false, 'GET', set_cookies)
	}
	return protocol, rest
}

// Client frames are always final and masked.
fn websocket_frame(opcode u8, payload []u8) []u8 {
	mut frame := []u8{cap: payload.len + 14}
	frame << (0x80 | opcode)
	if payload.len < 126 {
		frame << u8(0x80 | payload.len)
	} else if payload.len <= 0xffff {
		frame << u8(0x80 | 126)
		frame << u8(payload.len >> 8)
		frame << u8(payload.len)
	} else {
		frame << u8(0x80 | 127)
		for shift := 56; shift >= 0; shift -= 8 {
			frame << u8(u64(payload.len) >> u64(shift))
		}
	}
	mask := rand.bytes(4) or { [u8(0x5a), 0xa5, 0x3c, 0xc3] }
	frame << mask
	for index, value in payload {
		frame << (value ^ mask[index & 3])
	}
	return frame
}

struct WebSocketFrame {
	fin     bool
	opcode  u8
	payload []u8
}

// Parses one server frame from the start of `buffer`. Returns none when the
// frame is incomplete, or an error for a protocol violation.
fn websocket_parse_frame(buffer []u8) !(WebSocketFrame, int) {
	return websocket_parse_frame_with_message_size(buffer, 0)
}

// Check the whole message's declared size before copying a fragment's payload.
fn websocket_parse_frame_with_message_size(buffer []u8, message_size int) !(WebSocketFrame, int) {
	if buffer.len < 2 { return error('incomplete') }
	fin := buffer[0] & 0x80 != 0
	if buffer[0] & 0x70 != 0 { return error('protocol: reserved bits set') }
	opcode := buffer[0] & 0x0f
	if (opcode >= 3 && opcode <= 7) || opcode >= 11 {
		return error('protocol: reserved opcode')
	}
	if buffer[1] & 0x80 != 0 { return error('protocol: masked server frame') }
	length_bits := buffer[1] & 0x7f
	mut length := u64(length_bits)
	mut offset := 2
	if length == 126 {
		if buffer.len < 4 { return error('incomplete') }
		length = u64(buffer[2]) << 8 | u64(buffer[3])
		offset = 4
	} else if length == 127 {
		if buffer.len < 10 { return error('incomplete') }
		if buffer[2] & 0x80 != 0 { return error('protocol: invalid frame length') }
		length = 0
		for index in 2 .. 10 { length = length << 8 | u64(buffer[index]) }
		offset = 10
	}
	if (length_bits == 126 && length < 126) || (length_bits == 127 && length < 65536) {
		return error('protocol: non-minimal frame length')
	}
	if opcode >= 8 && (!fin || length > 125) { return error('protocol: invalid control frame') }
	if length > u64(websocket_max_message) {
		return error_with_code('protocol: message too large', 1009)
	}
	// Control frames may arrive between fragments and do not add to the message.
	if opcode < 8 && u64(message_size) + length > u64(websocket_max_message) {
		return error_with_code('protocol: message too large', 1009)
	}
	end := offset + int(length)
	if buffer.len < end { return error('incomplete') }
	return WebSocketFrame{ fin: fin, opcode: opcode, payload: buffer[offset..end].clone() }, end
}

fn websocket_close_payload(code u16, reason string) []u8 {
	if code == 0 { return []u8{} }
	mut payload := [u8(code >> 8), u8(code)]
	payload << reason.bytes()
	return payload
}

fn (mut connection WebSocketConnection) run() {
	platform.retain_thread_allocations()
	defer {
		connection.mu.lock()
		connection.finished = true
		C.vox_websocket_wake_close(connection.wake)
		connection.wake = unsafe { nil }
		connection.outgoing = []WebSocketOutgoing{}
		connection.mu.unlock()
		if connection.notify != unsafe { nil } { connection.notify() }
	}
	target := websocket_target(connection.address) or {
		connection.fail()
		return
	}
	mut stream := connection.dial(target) or {
		connection.fail()
		return
	}
	defer { stream.close() }
	protocol, rest := connection.handshake(mut stream, target) or {
		connection.fail()
		return
	}
	connection.mu.lock()
	aborted := connection.close_requested
	connection.mu.unlock()
	if aborted {
		// close() before open: the connection is failed without a close frame.
		connection.fail()
		return
	}
	connection.emit(WebSocketEvent{ kind: .open, protocol: protocol })
	connection.exchange(mut stream, rest)
}

// Reads frames and writes queued frames until the connection closes.
fn (mut connection WebSocketConnection) exchange(mut stream WebSocketStream, initial []u8) {
	mut buffer := initial.clone()
	mut chunk := []u8{len: 16 * 1024}
	mut message := []u8{}
	mut message_opcode := u8(0)
	mut close_sent := false
	mut close_deadline := i64(0)
	for {
		// Parse everything already received before waiting again.
		for {
			frame, used := websocket_parse_frame_with_message_size(buffer, message.len) or {
				if err.msg() == 'incomplete' { break }
				code := if err.code() == 1009 { u16(1009) } else { u16(1002) }
				stream.write_all(websocket_frame(8, websocket_close_payload(code, ''))) or {}
				connection.fail()
				return
			}
			buffer.delete_many(0, used)
			match frame.opcode {
				0, 1, 2 {
					if frame.opcode != 0 {
						if message_opcode != 0 {
							connection.fail()
							return
						}
						message_opcode = frame.opcode
						message = frame.payload.clone()
					} else {
						if message_opcode == 0 {
							connection.fail()
							return
						}
						message << frame.payload
					}
					if frame.fin {
						if !close_sent {
							connection.emit(WebSocketEvent{ kind: .message, text: message_opcode == 1, data: message })
						}
						message = []u8{}
						message_opcode = 0
					}
				}
				8 {
					mut code := u16(1005)
					mut reason := ''
					if frame.payload.len == 1 {
						connection.fail()
						return
					}
					if frame.payload.len >= 2 {
						code = u16(frame.payload[0]) << 8 | u16(frame.payload[1])
						reason = frame.payload[2..].bytestr()
						// RFC 6455 requires UTF-8, which excludes surrogate code points.
						if !utf8.validate_str(reason) {
							if !close_sent {
								stream.write_all(websocket_frame(8, websocket_close_payload(1007, ''))) or {}
							}
							connection.fail()
							return
						}
					}
					if !close_sent {
						echo := if frame.payload.len >= 2 { frame.payload[..2].clone() } else { []u8{} }
						stream.write_all(websocket_frame(8, echo)) or {}
					}
					connection.emit(WebSocketEvent{ kind: .close, code: code, reason: reason, was_clean: true })
					return
				}
				9 {
					// Stop answering pings once our closing handshake has started.
					if !close_sent {
						stream.write_all(websocket_frame(10, frame.payload)) or {
							connection.fail()
							return
						}
					}
				}
				10 {}
				else {
					connection.fail()
					return
				}
			}
		}
		// Send queued frames, then start a requested closing handshake.
		connection.mu.lock()
		outgoing := connection.outgoing
		connection.outgoing = []WebSocketOutgoing{}
		close_requested := connection.close_requested
		close_code := connection.close_code
		close_reason := connection.close_reason
		connection.mu.unlock()
		for item in outgoing {
			if close_sent { break }
			stream.write_all(websocket_frame(item.opcode, item.payload)) or {
				connection.fail()
				return
			}
		}
		if close_requested && !close_sent {
			close_sent = true
			close_deadline = time.sys_mono_now() + i64(websocket_close_wait_ms) * 1_000_000
			stream.write_all(websocket_frame(8, websocket_close_payload(close_code, close_reason))) or {
				connection.emit(WebSocketEvent{ kind: .close, code: 1006 })
				return
			}
		}
		if !stream.buffered() {
			mut timeout := -1
			if close_sent {
				remaining := (close_deadline - time.sys_mono_now()) / 1_000_000
				if remaining <= 0 {
					connection.emit(WebSocketEvent{ kind: .close, code: 1006 })
					return
				}
				timeout = int(remaining)
			}
			ready := C.vox_websocket_wake_wait(connection.wake, i64(stream.handle()), i32(timeout))
			if ready == 2 || ready == 0 { continue }
			if ready < 0 {
				connection.fail()
				return
			}
		}
		n := stream.read(mut chunk) or {
			if err.code() == net.err_timed_out_code || err.msg().contains('timeout')
				|| err.msg().contains('did not receive any data') {
				continue
			}
			if close_sent {
				connection.emit(WebSocketEvent{ kind: .close, code: 1006 })
			} else {
				connection.fail()
			}
			return
		}
		if n <= 0 {
			if close_sent {
				connection.emit(WebSocketEvent{ kind: .close, code: 1006 })
			} else {
				connection.fail()
			}
			return
		}
		buffer << chunk[..n]
	}
}
