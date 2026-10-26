module html

import dom
import platform

fn message_port_owner_fixture(name string) &EnvironmentSettingsObject {
	url := dom.URL{ value: 'https://port-owner.test/${name}.js' }
	mut realm := &ScriptingRealm{}
	scope := DedicatedWorkerGlobalScope.create(url, WorkerOptions{}, realm)
	return WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope, mut realm,
		SerializedEnvironmentSettingsObject{
			creation_url: url
			api_base_url: url
			origin:       url.origin()
			global:       SerializedWorkerGlobalScope{ relevant_settings_object_is_secure_context: true }
		}, 1).settings
}

struct PortOwnerRecorder {
mut:
	values  []string
	ports   []&MessagePort
	trusted bool = true
}

fn port_owner_callback(mut recorder PortOwnerRecorder) &dom.CallbackType {
	return &dom.CallbackType{
		handle_event: fn [mut recorder] (base &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			event := unsafe { &MessageEvent(base) }
			recorder.values << if base.type_name() == 'messageerror' {
				'messageerror'
			} else {
				event.data().to_string_value()
			}
			recorder.ports << event.ports()
			recorder.trusted = recorder.trusted && base.is_trusted()
			return dom.js_undefined()
		}
	}
}

fn drain_port_owner_loop(loop &EventLoop) {
	mut queue := loop.task_queue()
	for {
		task := queue.take_first_runnable_matching(fn (task &Task) bool {
			return task.source() == .posted_message
		}) or { break }
		task.execute()
	}
}

fn test_message_channel_delivers_fifo_on_its_worker_loop_after_start() {
	settings := message_port_owner_fixture('fifo')
	channel := MessageChannel.create_for_settings(settings)
	mut recorder := &PortOwnerRecorder{}
	channel.port2().add_event_listener_without_options('message', dom.IDLEventListener.create(port_owner_callback(mut recorder)))
	channel.port1().post_message_without_transfer(dom.js_string('first'))!
	channel.port1().post_message_without_transfer(dom.js_string('second'))!
	assert channel.port2().pending_incoming_message_count() == 2
	drain_port_owner_loop(settings.responsible_event_loop())
	assert recorder.values.len == 0
	mut target := channel.port2()
	target.start()
	target.start()
	drain_port_owner_loop(main_thread_event_loop())
	assert recorder.values.len == 0
	drain_port_owner_loop(settings.responsible_event_loop())
	assert recorder.values == ['first', 'second']
	assert recorder.trusted
}

fn test_received_port_and_its_pending_messages_belong_to_the_receiving_worker_realm() {
	sender := message_port_owner_fixture('sender')
	receiver := message_port_owner_fixture('receiver')
	channel := MessageChannel.create_for_settings(sender)
	carrier := MessageChannel.create_for_settings(receiver)
	mut carrier_recorder := &PortOwnerRecorder{}
	mut received_recorder := &PortOwnerRecorder{}
	mut reply_recorder := &PortOwnerRecorder{}
	carrier.port2().set_onmessage(port_owner_callback(mut carrier_recorder))
	channel.port2().set_onmessage(port_owner_callback(mut reply_recorder))
	channel.port2().post_message_without_transfer(dom.js_string('before transfer'))!
	carrier.port1().post_message(dom.js_string('port'), StructuredSerializeOptions{
		transfer: [StructuredTransfer(MessagePortTransfer{ value: channel.port1() })]
	})!
	assert channel.port1().is_detached()
	drain_port_owner_loop(sender.responsible_event_loop())
	drain_port_owner_loop(main_thread_event_loop())
	assert carrier_recorder.ports.len == 0
	drain_port_owner_loop(receiver.responsible_event_loop())
	assert carrier_recorder.ports.len == 1
	received := carrier_recorder.ports[0]
	assert voidptr(received.settings_?) == voidptr(receiver)
	received.set_onmessage(port_owner_callback(mut received_recorder))
	channel.port2().post_message_without_transfer(dom.js_string('after transfer'))!
	drain_port_owner_loop(sender.responsible_event_loop())
	drain_port_owner_loop(main_thread_event_loop())
	assert received_recorder.values.len == 0
	drain_port_owner_loop(receiver.responsible_event_loop())
	assert received_recorder.values == ['before transfer', 'after transfer']
	received.post_message_without_transfer(dom.js_string('reply'))!
	drain_port_owner_loop(receiver.responsible_event_loop())
	assert reply_recorder.values.len == 0
	drain_port_owner_loop(sender.responsible_event_loop())
	assert reply_recorder.values == ['reply']
}

fn test_worker_port_cancellation_and_clone_error_survive_scratch_resets() {
	settings := message_port_owner_fixture('lifetime')
	mut recorder := &PortOwnerRecorder{}
	// The host owns its callback; the port owns registrations and queued bytes.
	callback := port_owner_callback(mut recorder)
	mut caller := platform.begin_thread_scratch('worker port caller')
	mut malformed := [u8(255)]
	invalid := SerializedTransferRecord{ serialized: SerializationRecord{ data: malformed } }
	channel := MessageChannel.create_for_settings(settings)
	channel.port2().set_onmessage(callback)
	channel.port2().set_onmessageerror(callback)
	channel.port1().post_message_without_transfer(dom.js_string('discard'))!
	mut target := channel.port2()
	target.discard_pending_messages()
	channel.port1().post_message_without_transfer(dom.js_string('retained Санкт-Петербург 😀'))!
	mut source := channel.port1()
	source.send_message_on_transport(invalid)!
	malformed[0] = u8(StructuredSerializeValueTag.undefined_primitive)
	caller.finish()
	mut delivery := platform.begin_thread_scratch('worker port delivery')
	drain_port_owner_loop(main_thread_event_loop())
	assert recorder.values.len == 0
	drain_port_owner_loop(settings.responsible_event_loop())
	delivery.finish()
	assert recorder.values == ['retained Санкт-Петербург 😀', 'messageerror']
	assert recorder.trusted
	source.post_message_without_transfer(dom.js_string('closed'))!
	target.close()
	drain_port_owner_loop(settings.responsible_event_loop())
	assert recorder.values.len == 2
}
