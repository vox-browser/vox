module html

import dom
import os

__global forwarded_broadcast_messages = []BroadcastChannelMessage{}

fn record_forwarded_broadcast_message(message BroadcastChannelMessage) {
	forwarded_broadcast_messages << message
}

struct MessageRecorder {
mut:
	data    []string
	origins []string
	ports   []&MessagePort
	types   []string
}

fn message_recorder_callback(mut recorder MessageRecorder) &dom.CallbackType {
	return &dom.CallbackType{
		handle_event: fn [mut recorder] (base_event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			event := unsafe { &MessageEvent(base_event) }
			recorder.types << event.type_name()
			recorder.data << event.data().to_string_value()
			recorder.origins << event.origin()
			recorder.ports << event.ports()
			return dom.js_undefined()
		}
	}
}

fn drain_messaging_tasks() {
	mut event_loop := main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
	}
}

fn test_message_event_accessors_and_legacy_initializer() {
	channel := MessageChannel.construct_impl() or { panic(err) }
	mut event := MessageEvent.create('message', MessageEventInit{
		data:          dom.js_string('first')
		origin:        dom.Origin{
			value: 'https://example.com'
		}
		last_event_id: '7'
		ports:         [channel.port1()]
	})
	assert event.data().string_data == 'first'
	assert event.origin() == 'https://example.com'
	assert event.last_event_id() == '7'
	assert event.ports().len == 1
	assert event.extract_an_origin() or { panic('missing origin') } == dom.Origin{
		value: 'https://example.com'
	}
	assert message_event_to_message_event_source_internal(none) == none

	event.init_message_event('messageerror', true, false, dom.js_number(4), 'custom-origin', '8',
		none, [])
	assert event.type_name() == 'messageerror'
	assert event.bubbles()
	assert event.data().number_data == 4
	assert event.origin() == 'custom-origin'
	assert event.extract_an_origin() == none
}

fn test_message_channel_queues_until_started_and_clones_data() {
	channel := MessageChannel.construct_impl() or { panic(err) }
	mut source_object := StructuredObject.create(.object)
	mut source_text := &dom.JSValue{
		kind:        .string
		string_data: 'before'
	}
	source_object.properties << StructuredProperty{
		key:   'value'
		value: source_text
	}
	channel.port1().post_message_without_transfer(structured_object_value(source_object)) or {
		panic(err)
	}
	// postMessage serializes synchronously.
	source_text.string_data = 'after'

	mut recorder := &MessageRecorder{}
	channel.port2().set_onmessage(message_recorder_callback(mut recorder))
	assert recorder.data.len == 0
	drain_messaging_tasks()
	assert recorder.types == ['message']
	assert recorder.data == ['[object Object]']
}

fn test_discard_pending_messages_clears_queue_and_invalidates_scheduled_delivery() {
	queued_channel := MessageChannel.construct_impl()!
	queued_channel.port1().post_message_without_transfer(dom.js_string('queued'))!
	mut queued_target := queued_channel.port2()
	assert queued_target.pending_incoming_message_count() == 1
	queued_target.discard_pending_messages()
	assert queued_target.pending_incoming_message_count() == 0

	scheduled_channel := MessageChannel.construct_impl()!
	mut recorder := &MessageRecorder{}
	scheduled_channel.port2().set_onmessage(message_recorder_callback(mut recorder))
	scheduled_channel.port1().post_message_without_transfer(dom.js_string('scheduled'))!
	mut scheduled_target := scheduled_channel.port2()
	scheduled_target.discard_pending_messages()
	drain_messaging_tasks()
	assert recorder.data.len == 0
}

fn test_message_port_exact_registry_and_transport_helpers() {
	mut seen := 0
	MessagePort.for_each_message_port(fn [mut seen] (_ &MessagePort) {
		seen++
	})
	assert seen >= 0
	channel := MessageChannel.construct_impl()!
	mut source := channel.port1()
	mut target := channel.port2()
	target.enable()
	record := structured_serialize_with_transfer(dom.js_string('direct'), [])!
	source.send_message_on_transport(record)!
	assert target.pending_incoming_message_count() == 1
	drain_messaging_tasks()
	assert target.pending_incoming_message_count() == 0
	source.post_port_message(structured_serialize_with_transfer(dom.js_string('queued'), [])!)
	target.read_from_transport()
}

fn test_message_port_close_and_self_transfer_errors() {
	channel := MessageChannel.construct_impl() or { panic(err) }
	channel.port1().post_message(dom.js_null(), StructuredSerializeOptions{
		transfer: [
			StructuredTransfer(MessagePortTransfer{
				value: channel.port1()
			}),
		]
	}) or {
		assert err.msg().contains('itself')
		mut port1 := channel.port1()
		port1.close()
		assert port1.is_detached()
		assert !port1.is_entangled()
		assert !channel.port2().is_entangled()
		return
	}
	assert false
}

fn test_message_port_transfer_reentangles_the_received_port() {
	carrier := MessageChannel.construct_impl() or { panic(err) }
	transferred_channel := MessageChannel.construct_impl() or { panic(err) }
	mut carrier_recorder := &MessageRecorder{}
	mut remote_recorder := &MessageRecorder{}
	carrier.port2().set_onmessage(message_recorder_callback(mut carrier_recorder))
	transferred_channel.port2().set_onmessage(message_recorder_callback(mut remote_recorder))

	carrier.port1().post_message(dom.js_string('port'), StructuredSerializeOptions{
		transfer: [
			StructuredTransfer(MessagePortTransfer{
				value: transferred_channel.port1()
			}),
		]
	}) or { panic(err) }
	assert transferred_channel.port1().is_detached()
	drain_messaging_tasks()
	assert carrier_recorder.ports.len == 1
	received_port := carrier_recorder.ports[0]
	assert received_port.is_entangled()
	received_port.post_message_without_transfer(dom.js_string('through transferred port')) or {
		panic(err)
	}
	drain_messaging_tasks()
	assert remote_recorder.data == ['through transferred port']
}

fn test_image_bitmap_transfer_detaches_source_and_reconstructs_pixels() {
	mut source := ImageBitmap.create()
	source.set_bitmap(&dom.Bitmap_{
		width:      2
		height:     1
		pitch:      8
		format:     3
		alpha_type: 1
		data:       [u8(1), 2, 3, 4]
	})
	record := structured_serialize_with_transfer(dom.js_string('image'), [
		StructuredTransfer(ImageBitmapTransfer{
			value: source
		}),
	]) or { panic(err) }
	assert source.is_detached()
	decoded := structured_deserialize_with_transfer(record) or { panic(err) }
	assert decoded.transferred_images.len == 1
	assert decoded.transferred_images[0].width() == 2
	bitmap := decoded.transferred_images[0].bitmap() or { panic('missing bitmap') }
	assert bitmap.data == [u8(1), 2, 3, 4]
}

fn test_broadcast_channel_filters_by_name_and_storage_key() {
	source := BroadcastChannel.construct_impl('updates')
	target := BroadcastChannel.construct_impl('updates')
	wrong_name := BroadcastChannel.construct_impl('other')
	wrong_partition := BroadcastChannel.construct_impl('updates')
	mut mutable_source := source
	mut mutable_target := target
	mut mutable_wrong_name := wrong_name
	mut mutable_wrong_partition := wrong_partition
	origin := dom.Origin{
		value: 'https://example.com'
	}
	mutable_source.set_messaging_environment(origin, 'partition-a', true)
	mutable_target.set_messaging_environment(origin, 'partition-a', true)
	mutable_wrong_name.set_messaging_environment(origin, 'partition-a', true)
	mutable_wrong_partition.set_messaging_environment(origin, 'partition-b', true)

	mut target_recorder := &MessageRecorder{}
	mut wrong_name_recorder := &MessageRecorder{}
	mut wrong_partition_recorder := &MessageRecorder{}
	target.set_onmessage(message_recorder_callback(mut target_recorder))
	wrong_name.set_onmessage(message_recorder_callback(mut wrong_name_recorder))
	wrong_partition.set_onmessage(message_recorder_callback(mut wrong_partition_recorder))
	source.post_message(dom.js_string('hello')) or { panic(err) }
	drain_messaging_tasks()
	assert target_recorder.data == ['hello']
	assert target_recorder.origins == ['https://example.com']
	assert wrong_name_recorder.data.len == 0
	assert wrong_partition_recorder.data.len == 0

	mutable_target.close()
	source.post_message(dom.js_string('ignored')) or { panic(err) }
	drain_messaging_tasks()
	assert target_recorder.data == ['hello']
	mutable_source.close()
	source.post_message(dom.js_null()) or {
		assert err.msg().contains('InvalidStateError')
		mutable_wrong_name.close()
		mutable_wrong_partition.close()
		return
	}
	assert false
}

fn test_broadcast_channel_repository_exact_registration_api() {
	mut repository := BroadcastChannelRepository.create()
	channel := BroadcastChannel.construct_impl('repository-test')
	mut mutable_channel := channel
	mutable_channel.set_messaging_environment(dom.Origin{ value: 'https://example.test' },
		'repository-key', true)
	repository.register_channel(channel)
	assert repository.registered_channels_for_key('repository-key') == [channel]
	repository.unregister_channel(channel)
	assert repository.registered_channels_for_key('repository-key').len == 0
	mutable_channel.close()
}

fn test_broadcast_channel_message_ipc_round_trip() {
	origin := dom.origin_create_opaque()
	message := BroadcastChannelMessage{
		storage_key: 'partition-a'
		channel_name: 'updates'
		source_origin: origin
		serialized_message: structured_serialize(dom.js_string('hello')) or { panic(err) }
		source_process_id: -1
		source_channel_id: 42
	}
	encoded := encode_broadcast_channel_message(message)
	decoded := decode_broadcast_channel_message(encoded) or { panic(err) }
	assert decoded.storage_key == message.storage_key
	assert decoded.channel_name == message.channel_name
	assert decoded.source_origin.is_same_origin(origin)
	assert decoded.serialized_message.data == message.serialized_message.data
	assert decoded.source_process_id == -1
	assert decoded.source_channel_id == 42
	if _ := decode_broadcast_channel_message(encoded[..encoded.len - 1]) {
		assert false
	}
}

fn test_broadcast_channel_forwards_messages_and_accepts_remote_channel_id_collisions() {
	forwarded_broadcast_messages.clear()
	set_broadcast_channel_message_forwarder(record_forwarded_broadcast_message)
	source := BroadcastChannel.construct_impl('cross-process')
	target := BroadcastChannel.construct_impl('cross-process')
	mut mutable_source := source
	mut mutable_target := target
	origin := dom.Origin{ value: 'https://example.test' }
	mutable_source.set_messaging_environment(origin, 'shared-partition', true)
	mutable_target.set_messaging_environment(origin, 'shared-partition', true)
	mut recorder := &MessageRecorder{}
	target.set_onmessage(message_recorder_callback(mut recorder))
	source.post_message(dom.js_string('local')) or { panic(err) }
	drain_messaging_tasks()
	assert recorder.data == ['local']
	assert forwarded_broadcast_messages.len == 1
	assert forwarded_broadcast_messages[0].source_channel_id == source.channel_id()

	remote_message := BroadcastChannelMessage{
		storage_key: 'shared-partition'
		channel_name: 'cross-process'
		source_origin: origin
		serialized_message: structured_serialize(dom.js_string('remote')) or { panic(err) }
		source_process_id: os.getpid() + 1
		source_channel_id: target.channel_id()
	}
	BroadcastChannel.deliver_message_locally(remote_message)
	drain_messaging_tasks()
	assert recorder.data == ['local', 'remote']

	set_broadcast_channel_message_forwarder(none)
	mutable_source.close()
	mutable_target.close()
}
