// SPDX-License-Identifier: BSD-2-Clause
// Hidden HTML endpoints relay MessagePort traffic over the owning worker pipe.
// Each endpoint and every JS wrapper remains in its own process and realm.
module browserjs

import dom
import html
import platform

struct WorkerPortDelivery {
	token u64
	record NativeArrayBufferTransferRecord
	bytes int
}

@[heap]
struct WorkerPortRouter {
	runtime &Runtime
	settings &html.EnvironmentSettingsObject
mut:
	next_token u64
	proxies map[u64]&html.MessagePort
	pending []WorkerPortDelivery
	pending_bytes int
	closed bool
}

fn WorkerPortRouter.create(runtime &Runtime, parent bool) !&WorkerPortRouter {
	settings := runtime.scripting_settings_ or { return error('Worker ports require their owning settings') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return &WorkerPortRouter{runtime: runtime, settings: settings, next_token: if parent { u64(1) } else { u64(2) }}
}

fn (runtime &Runtime) native_message_port(value voidptr) ?&html.MessagePort {
	binding := message_channel_bindings_[voidptr(runtime)] or { return none }
	return binding.ports[value] or { return none }
}

fn (mut runtime Runtime) javascript_message_port(port &html.MessagePort) !voidptr {
	mut binding := message_channel_bindings_[voidptr(runtime)] or { return error('Missing MessagePort binding') }
	return runtime.message_channel_port_wrapper(mut binding, port)
}

fn (mut router WorkerPortRouter) export_port(port &html.MessagePort) !u64 {
	port.require_idle_worker_transfer() or { return native_clone_unsupported(err.msg()) }
	if router.next_token > ~u64(0) - 2 { return error('Worker MessagePort identifiers exhausted') }
	mut source := unsafe { &html.MessagePort(port) }
	item := source.transfer_steps() or { return native_clone_unsupported(err.msg()) }
	mut proxy := html.MessagePort.create_for_settings(router.settings)
	proxy.transfer_receiving_steps(item)!
	token := router.next_token
	router.next_token += 2
	// postMessage still serializes/transfers when its Worker has terminated,
	// including termination by an author getter during graph serialization.
	if router.closed { proxy.close() } else { router.proxies[token] = proxy }
	return token
}

fn (mut router WorkerPortRouter) import_port(token u64) !&html.MessagePort {
	if router.closed { return error('Worker MessagePort router is closed') }
	if token == 0 || token % 2 == router.next_token % 2 || token in router.proxies {
		return native_clone_unsupported('Invalid or repeated received MessagePort token')
	}
	channel := html.MessageChannel.create_for_settings(router.settings)
	router.proxies[token] = channel.port2()
	router.deliver_pending()!
	return channel.port1()
}

fn (mut router WorkerPortRouter) deliver_pending() ! {
	mut waiting := []WorkerPortDelivery{}
	for delivery in router.pending {
		if mut proxy := router.proxies[delivery.token] {
			if delivery.record.ports.len != 0 { return error('Nested MessagePort transfer is unavailable') }
			value := router.runtime.worker_message_graph(delivery.record)!
			proxy.post_message_without_transfer(value)!
			router.pending_bytes -= delivery.bytes
		} else {
			waiting << delivery
		}
	}
	router.pending = waiting
	if waiting.len == 0 { router.pending_bytes = 0 }
}

// A port frame can arrive in the same read turn as its Worker message, before
// that message's posted task has created the receiving endpoints. Bound and
// retain those frames until the corresponding transfer is deserialized.
fn (mut router WorkerPortRouter) queue_incoming(bytes []u8) ! {
	if router.closed { return }
	if bytes.len > worker_message_max_bytes || bytes.len < 12 { return error('Invalid worker MessagePort frame size') }
	mut reader := WorkerMessageReader{bytes: bytes}
	if reader.take(4)! != 'VXP1'.bytes() { return error('Invalid worker MessagePort frame version') }
	token := reader.read_u64()!
	if token == 0 { return error('Invalid worker MessagePort token') }
	if token % 2 == router.next_token % 2 && token !in router.proxies { return error('Unknown exported worker MessagePort token') }
	record := decode_worker_message(reader.take(bytes.len - reader.offset)!)!
	if record.ports.len != 0 { return error('Nested MessagePort transfer is unavailable') }
	if bytes.len > 64 * 1024 * 1024 - router.pending_bytes { return error('Worker MessagePort incoming queue is full') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	router.pending << WorkerPortDelivery{token: token, record: record, bytes: bytes.len}
	router.pending_bytes += bytes.len
	router.deliver_pending()!
}

fn (mut router WorkerPortRouter) take_outgoing() ![][]u8 {
	if router.closed { return [][]u8{} }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut frames := [][]u8{}
	mut total := 0
	for token, mut proxy in router.proxies {
		for record in proxy.take_disabled_transport_messages()! {
			if record.transfers.len != 0 { return error('Nested MessagePort transfer is unavailable') }
			payload := encode_worker_message(NativeArrayBufferTransferRecord{serialized: record.serialized})!
			if payload.len > worker_message_max_bytes - 12 { return error('Worker MessagePort frame exceeds the limit') }
			mut bytes := 'VXP1'.bytes()
			worker_message_write_u64(mut bytes, token)
			bytes << payload
			if bytes.len > 64 * 1024 * 1024 - total { return error('Worker MessagePort outgoing queue is full') }
			total += bytes.len
			frames << bytes
		}
	}
	return frames
}

fn (mut router WorkerPortRouter) close() {
	if router.closed { return }
	router.closed = true
	for _, mut proxy in router.proxies { proxy.close() }
	router.proxies = {}
	router.pending = []
	router.pending_bytes = 0
}

// Convert a buffer-transfer graph to an ordinary self-contained HTML value for
// the local MessagePort transport. The JS sender has already been detached.
fn (runtime &Runtime) worker_message_graph(record NativeArrayBufferTransferRecord) !dom.JSValue {
	if record.ports.len != 0 { return native_clone_unsupported('Nested MessagePort transfer is unavailable') }
	mut memory := []&html.StructuredObject{}
	for data in record.buffers {
		mut buffer := html.StructuredObject.create(.array_buffer)
		buffer.bytes = data.bytes
		buffer.max_byte_length = data.max_byte_length
		memory << buffer
	}
	return html.structured_deserialize_with_transfer_memory(record.serialized, memory, runtime.native_clone_deserialization_context())
}
