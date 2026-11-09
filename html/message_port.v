// Copyright (c) 2021, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2023, Andrew Kaster <akaster@serenityos.org>
// Copyright (c) 2025, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MessagePort.{h,cpp}, MessageChannel.{h,cpp}, and
// StructuredSerializeOptions.h. The LibIPC transport is represented by the
// same spec-visible queued-message behavior in-process.
@[has_globals]
module html

import dom
import platform

pub struct MessagePortTransfer {
pub:
	value &MessagePort = unsafe { nil }
}

pub struct ImageBitmapTransfer {
pub:
	value &ImageBitmap = unsafe { nil }
}

pub type StructuredTransfer = ImageBitmapTransfer | MessagePortTransfer

pub struct StructuredSerializeOptions {
pub:
	transfer []StructuredTransfer
}

pub struct SerializedTransferItem {
pub:
	type_ TransferType
mut:
	port_endpoint ?&MessagePort
	data          []u8
	array_buffer_max_byte_length ?u64
}

pub struct SerializedTransferRecord {
pub:
	serialized SerializationRecord
	transfers  []SerializedTransferItem
	uses_transfer_memory bool
}

pub fn SerializedTransferItem.array_buffer(bytes []u8, maximum ?u64) SerializedTransferItem {
	return SerializedTransferItem{
		type_: if maximum != none { .resizable_array_buffer } else { .array_buffer }
		data: bytes.clone()
		array_buffer_max_byte_length: maximum
	}
}

pub struct DeserializedTransferRecord {
pub:
	deserialized       dom.JSValue
	transferred_ports  []&MessagePort
	transferred_images []&ImageBitmap
}

struct StructuredTransferredValue {
	port   ?&MessagePort
	bitmap ?&ImageBitmap
}

fn is_transferable_interface_exposed_on_target_realm(name TransferType, target_realm &ScriptingRealm) bool {
	_ = target_realm
	return name in [.message_port, .image_bitmap]
}

fn create_transferred_value(name TransferType, target_realm &ScriptingRealm, item SerializedTransferItem) !StructuredTransferredValue {
	return match name {
		.message_port {
			mut port := if settings := settings_object_of_realm(target_realm) {
				MessagePort.create_for_settings(settings)
			} else {
				MessagePort.create()
			}
			port.transfer_receiving_steps(item)!
			StructuredTransferredValue{ port: port }
		}
		.image_bitmap {
			StructuredTransferredValue{
				bitmap: image_bitmap_transfer_receiving_steps(item.data)!
			}
		}
		else {
			return error('DataCloneError: unsupported transfer type')
		}
	}
}

fn structured_deserialize_with_transfer_internal(item SerializedTransferItem, target_realm &ScriptingRealm) !StructuredTransferredValue {
	if !is_transferable_interface_exposed_on_target_realm(item.type_, target_realm) {
		return error('DataCloneError: unknown type transferred')
	}
	return create_transferred_value(item.type_, target_realm, item)
}

fn structured_transfer_identity(item StructuredTransfer) u64 {
	return match item {
		ImageBitmapTransfer { u64(voidptr((item as ImageBitmapTransfer).value)) }
		MessagePortTransfer { u64(voidptr((item as MessagePortTransfer).value)) }
	}
}

pub fn structured_serialize_with_transfer(message dom.JSValue, transfer []StructuredTransfer) !SerializedTransferRecord {
	mut seen := map[u64]bool{}
	for item in transfer {
		identity := structured_transfer_identity(item)
		if identity == 0 || seen[identity] {
			return error('DataCloneError: duplicate or null transferable')
		}
		seen[identity] = true
		match item {
			ImageBitmapTransfer {
				if (item as ImageBitmapTransfer).value.is_detached() {
					return error('DataCloneError: ImageBitmap is detached')
				}
			}
			MessagePortTransfer {
				if (item as MessagePortTransfer).value.is_detached() {
					return error('DataCloneError: MessagePort is detached')
				}
			}
		}
	}

	// Serialization must complete before any transfer steps mutate their source.
	serialized := structured_serialize(message)!
	mut transfers := []SerializedTransferItem{cap: transfer.len}
	for item in transfer {
		match item {
			ImageBitmapTransfer {
				mut bitmap := (item as ImageBitmapTransfer).value
				transfers << SerializedTransferItem{
					type_: .image_bitmap
					data:  bitmap.transfer_steps()
				}
			}
			MessagePortTransfer {
				mut port := (item as MessagePortTransfer).value
				transfers << port.transfer_steps()!
			}
		}
	}
	return SerializedTransferRecord{
		serialized: serialized
		transfers:  transfers
	}
}

pub fn structured_deserialize_with_transfer(record SerializedTransferRecord) !DeserializedTransferRecord {
	return structured_deserialize_with_transfer_in_realm(record, &ScriptingRealm{})
}

// Received ports belong to the receiving realm, including its worker loop.
pub fn structured_deserialize_with_transfer_in_realm(record SerializedTransferRecord, target_realm &ScriptingRealm) !DeserializedTransferRecord {
	return structured_deserialize_with_transfer_in_context(record, target_realm, StructuredDeserializationContext{})
}

pub fn structured_deserialize_with_transfer_in_context(record SerializedTransferRecord, target_realm &ScriptingRealm, context StructuredDeserializationContext) !DeserializedTransferRecord {
	mut memory := []&StructuredObject{}
	mut ports := []&MessagePort{}
	mut images := []&ImageBitmap{}
	for item in record.transfers {
		if record.uses_transfer_memory && item.type_ in [.array_buffer, .resizable_array_buffer] {
			memory << &StructuredObject{kind: .array_buffer, bytes: item.data.clone(), max_byte_length: item.array_buffer_max_byte_length}
			continue
		}
		transferred := structured_deserialize_with_transfer_internal(item, target_realm)!
		if port := transferred.port {
			mut received := unsafe { &MessagePort(port) }
			received.set_deserialization_context(context)
			ports << port
			if record.uses_transfer_memory { memory << &StructuredObject{kind: .message_port, message_port_: port} }
		}
		if bitmap := transferred.bitmap {
			images << bitmap
		}
	}
	data := if record.uses_transfer_memory {
		structured_deserialize_with_transfer_memory(record.serialized, memory, context)!
	} else { structured_deserialize_with_context(record.serialized, context)! }
	return DeserializedTransferRecord{
		deserialized:       data
		transferred_ports:  ports
		transferred_images: images
	}
}

__global (
	html_all_message_ports = []&MessagePort{}
)

@[heap]
pub struct MessagePort {
	dom.EventTarget
mut:
	remote_port_                    ?&MessagePort
	has_been_shipped_               bool
	detached_                       bool
	enabled_                        bool
	has_sent_message_               bool
	pending_messages_               []SerializedTransferRecord
	pending_outgoing_messages_      []SerializedTransferRecord
	message_task_generation_        u64
	scheduled_message_count_        int
	fail_next_transfer_for_testing_ bool
	worker_event_target_            ?&dom.EventTarget
	settings_                       ?&EnvironmentSettingsObject
	deserialization_context_        StructuredDeserializationContext
}

pub fn (mut port MessagePort) set_deserialization_context(context StructuredDeserializationContext) {
	port.deserialization_context_ = context
}

pub fn MessagePort.create() &MessagePort {
	return MessagePort.create_with_settings(none)
}

// Equivalent to upstream's relevant global event target ownership.
pub fn MessagePort.create_for_settings(settings &EnvironmentSettingsObject) &MessagePort {
	return MessagePort.create_with_settings(settings)
}

fn MessagePort.create_with_settings(settings ?&EnvironmentSettingsObject) &MessagePort {
	// The process registry retains ports beyond temporary caller allocations.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	port := &MessagePort{ settings_: settings }
	html_all_message_ports << port
	return port
}

pub fn for_each_message_port(callback fn (&MessagePort)) {
	MessagePort.for_each_message_port(callback)
}

pub fn MessagePort.for_each_message_port(callback fn (&MessagePort)) {
	for port in html_all_message_ports {
		callback(port)
	}
}

fn message_port_with_identity(identity u64) ?&MessagePort {
	for port in html_all_message_ports {
		if u64(voidptr(port)) == identity {
			return port
		}
	}
	return none
}

pub fn (port &MessagePort) is_entangled() bool {
	return port.remote_port_ != none
}

pub fn (port &MessagePort) is_detached() bool {
	return port.detached_
}

pub fn (port &MessagePort) has_been_shipped() bool {
	return port.has_been_shipped_
}

pub fn (port &MessagePort) entangled_port() ?&MessagePort {
	return port.remote_port_
}

pub fn (port &MessagePort) pending_outgoing_message_count() uint {
	return uint(port.pending_outgoing_messages_.len)
}

pub fn (port &MessagePort) pending_incoming_message_count() uint {
	return uint(port.pending_messages_.len)
}

// The worker IPC adapter currently exports only unused, disabled endpoints.
// Reject a port with queued or scheduled deliveries before moving its handle.
pub fn (port &MessagePort) require_idle_worker_transfer() ! {
	if port.detached_ { return error('DataCloneError: MessagePort is detached') }
	if port.enabled_ || port.has_sent_message_ || port.pending_messages_.len != 0
		|| port.pending_outgoing_messages_.len != 0 {
		return error('DataCloneError: Transferring active or queued worker MessagePorts is unavailable')
	}
}

// Backend-only endpoint draining. Script-visible endpoints keep using their
// ordinary posted-message tasks and must never be drained by the IPC router.
pub fn (mut port MessagePort) take_disabled_transport_messages() ![]SerializedTransferRecord {
	if port.enabled_ || port.detached_ { return error('MessagePort transport endpoint is not disabled') }
	result := port.pending_messages_
	port.pending_messages_ = []
	return result
}

pub fn (mut port MessagePort) fail_next_transfer_for_testing() {
	port.fail_next_transfer_for_testing_ = true
}

pub fn (mut port MessagePort) set_worker_event_target(target &dom.EventTarget) {
	port.worker_event_target_ = target
}

pub fn (mut port MessagePort) disentangle() {
	if remote := port.remote_port_ {
		mut mutable_remote := unsafe { &MessagePort(remote) }
		if other := mutable_remote.remote_port_ {
			if voidptr(other) == voidptr(port) {
				mutable_remote.remote_port_ = none
			}
		}
	}
	port.remote_port_ = none
	port.worker_event_target_ = none
}

pub fn (mut port MessagePort) entangle_with(remote_port &MessagePort) {
	if current := port.remote_port_ {
		if voidptr(current) == voidptr(remote_port) {
			return
		}
	}
	port.disentangle()
	mut mutable_remote := unsafe { &MessagePort(remote_port) }
	mutable_remote.disentangle()
	port.remote_port_ = remote_port
	mutable_remote.remote_port_ = &port
}

pub fn (mut port MessagePort) transfer_steps() !SerializedTransferItem {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if port.detached_ {
		return error('DataCloneError: MessagePort is detached')
	}
	// The native transport can fail while encoding its remote handle. V's
	// in-process transport has no fallible handle, so exercise that exact
	// pre-commit failure point when requested by Internals.
	if port.fail_next_transfer_for_testing_ {
		port.fail_next_transfer_for_testing_ = false
		return error('DataCloneError: Forced MessagePort transfer failure')
	}
	port.has_been_shipped_ = true
	port.detached_ = true
	// A disabled endpoint owns the channel while the transfer is in flight.
	// Its peer can continue sending, and transferring both ends still preserves
	// their connection. Scheduled deliveries move with the incoming queue.
	mut endpoint := MessagePort.create()
	endpoint.has_been_shipped_ = true
	endpoint.pending_messages_ = port.pending_messages_.clone()
	if remote := port.remote_port_ {
		mut peer := unsafe { &MessagePort(remote) }
		peer.has_been_shipped_ = true
		endpoint.entangle_with(peer)
	}
	port.discard_pending_messages()
	return SerializedTransferItem{
		type_:         .message_port
		port_endpoint: endpoint
	}
}

pub fn (mut port MessagePort) transfer_receiving_steps(item SerializedTransferItem) ! {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if item.type_ != .message_port {
		return error('DataCloneError: invalid MessagePort transfer data')
	}
	mut endpoint := item.port_endpoint or { return error('DataCloneError: missing MessagePort endpoint') }
	if endpoint.detached_ { return error('DataCloneError: MessagePort endpoint already received') }
	port.has_been_shipped_ = true
	port.pending_messages_ = endpoint.pending_messages_.clone()
	if remote := endpoint.remote_port_ {
		port.entangle_with(remote)
	}
	endpoint.close()
}

pub fn (port &MessagePort) post_message(message dom.JSValue, options StructuredSerializeOptions) ! {
	mut mutable_port := unsafe { &MessagePort(port) }
	mutable_port.message_port_post_message_steps(message, options)!
}

pub fn (port &MessagePort) post_message_without_transfer(message dom.JSValue) ! {
	port.post_message(message, StructuredSerializeOptions{})!
}

fn transfer_contains_port(transfer []StructuredTransfer, needle &MessagePort) bool {
	for item in transfer {
		if item is MessagePortTransfer && voidptr((item as MessagePortTransfer).value) == voidptr(needle) {
			return true
		}
	}
	return false
}

fn (mut port MessagePort) message_port_post_message_steps(message dom.JSValue, options StructuredSerializeOptions) ! {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if transfer_contains_port(options.transfer, &port) {
		return error('DataCloneError: cannot transfer a MessagePort to itself')
	}
	target := port.remote_port_ or {
		// The structured serialization still occurs even for a disentangled port.
		_ = structured_serialize_with_transfer(message, options.transfer)!
		return
	}

	doomed := transfer_contains_port(options.transfer, target)
	record := structured_serialize_with_transfer(message, options.transfer)!
	if doomed {
		return
	}
	port.post_port_message(record)
}

pub fn (mut port MessagePort) send_message_on_transport(record SerializedTransferRecord) ! {
	// Upstream's transport encodes an owning copy. A caller can release or
	// mutate its serialized buffers as soon as this nonblocking send returns.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	remote := port.remote_port_ or { return error('MessagePort transport is not open') }
	mut mutable_remote := unsafe { &MessagePort(remote) }
	mutable_remote.pending_messages_ << record.copy_for_transport()
	if mutable_remote.enabled_ {
		mutable_remote.read_from_transport()
	}
}

fn (record SerializedTransferRecord) copy_for_transport() SerializedTransferRecord {
	mut transfers := []SerializedTransferItem{cap: record.transfers.len}
	for item in record.transfers {
		transfers << SerializedTransferItem{
			type_:         item.type_
			port_endpoint: item.port_endpoint
			data:          item.data.clone()
			array_buffer_max_byte_length: item.array_buffer_max_byte_length
		}
	}
	return SerializedTransferRecord{
		serialized: SerializationRecord{
			data:                 record.serialized.data.clone()
			shared_array_buffers: record.serialized.shared_array_buffers.clone()
			type_:                record.serialized.type_
		}
		transfers:  transfers
		uses_transfer_memory: record.uses_transfer_memory
	}
}

pub fn (mut port MessagePort) post_port_message(record SerializedTransferRecord) {
	port.has_sent_message_ = true
	if !port.is_entangled() {
		return
	}
	port.send_message_on_transport(record) or {
		port.disentangle()
	}
}

pub fn (mut port MessagePort) read_from_transport() {
	if !port.enabled_ || !port.is_entangled() {
		return
	}
	port.schedule_pending_messages()
}

fn (mut port MessagePort) schedule_pending_messages() {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	loop := if settings := port.settings_ {
		settings.responsible_event_loop()
	} else {
		main_thread_event_loop()
	}
	document := if settings := port.settings_ { settings.responsible_document() } else { none }
	for port.enabled_ && port.scheduled_message_count_ < port.pending_messages_.len {
		port.scheduled_message_count_++
		port_identity := u64(voidptr(&port))
		message_task_generation := port.message_task_generation_
		queue_a_task(.posted_message, loop, document, fn [port_identity, message_task_generation] () {
			target_pointer := message_port_with_identity(port_identity) or { return }
			mut target := unsafe { &MessagePort(target_pointer) }
			if target.message_task_generation_ != message_task_generation {
				return
			}
			if target.pending_messages_.len == 0 { return }
			record := target.pending_messages_[0]
			target.pending_messages_.delete(0)
			target.scheduled_message_count_--
			target.post_message_task_steps(record)
		})
	}
}

fn (mut port MessagePort) post_message_task_steps(record SerializedTransferRecord) {
	// Event wrappers can keep the deserialized data after this task returns.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if !port.enabled_ || port.detached_ {
		return
	}
	target := port.worker_event_target_ or { unsafe { &dom.EventTarget(&port) } }
	target_realm := if settings := port.settings_ { settings.realm() } else { &ScriptingRealm{} }
	deserialized := structured_deserialize_with_transfer_in_context(record, target_realm, port.deserialization_context_) or {
		mut event := MessageEvent.create('messageerror', MessageEventInit{})
		event.set_is_trusted(true)
		target.dispatch_event(unsafe { &dom.Event(event) })
		return
	}
	mut event := MessageEvent.create('message', MessageEventInit{
		data:  deserialized.deserialized
		ports: deserialized.transferred_ports
	})
	event.set_is_trusted(true)
	target.dispatch_event(unsafe { &dom.Event(event) })
}

pub fn (mut port MessagePort) enable() {
	if port.enabled_ || port.detached_ {
		return
	}
	port.enabled_ = true
	port.read_from_transport()
}

pub fn (mut port MessagePort) start() {
	if port.is_entangled() {
		port.enable()
	}
}

pub fn (mut port MessagePort) close() {
	port.detached_ = true
	port.discard_pending_messages()
	port.disentangle()
}

pub fn (mut port MessagePort) discard_pending_messages() {
	port.pending_messages_.clear()
	port.scheduled_message_count_ = 0
	port.message_task_generation_++
}

pub fn (port &MessagePort) set_onmessageerror(handler ?&dom.CallbackType) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	unsafe { &dom.EventTarget(port) }
		.set_event_handler_attribute('messageerror', handler)
}

pub fn (port &MessagePort) onmessageerror() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(port) }.event_handler_attribute('messageerror')
}

pub fn (port &MessagePort) set_onmessage(handler ?&dom.CallbackType) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	unsafe { &dom.EventTarget(port) }
		.set_event_handler_attribute('message', handler)
	mut mutable_port := unsafe { &MessagePort(port) }
	mutable_port.start()
}

pub fn (port &MessagePort) onmessage() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(port) }.event_handler_attribute('message')
}

pub fn (_ &MessagePort) primary_interface() TransferType {
	return .message_port
}

@[heap]
pub struct MessageChannel {
mut:
	port1_ &MessagePort
	port2_ &MessagePort
}

pub fn MessageChannel.construct_impl() !&MessageChannel {
	return MessageChannel.create_with_settings(none)
}

pub fn MessageChannel.create_for_settings(settings &EnvironmentSettingsObject) &MessageChannel {
	return MessageChannel.create_with_settings(settings)
}

fn MessageChannel.create_with_settings(settings ?&EnvironmentSettingsObject) &MessageChannel {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut port1 := MessagePort.create_with_settings(settings)
	port2 := MessagePort.create_with_settings(settings)
	port1.entangle_with(port2)
	return &MessageChannel{
		port1_: port1
		port2_: port2
	}
}

pub fn (channel &MessageChannel) port1() &MessagePort {
	return channel.port1_
}

pub fn (channel &MessageChannel) port2() &MessagePort {
	return channel.port2_
}
