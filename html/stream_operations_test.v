module html

import dom
import streams
import webidl

@[heap]
struct StreamOwnerObservations {
mut:
	reactions []string
}

fn stream_owner_window() &WindowModel {
	url := dom.URL{'https://streams.example.test/'}
	document := &dom.Document{ url: url, origin_: url.origin() }
	return WindowModel.create_top_level(document, none, 'stream-owner') or { panic(err) }
}

fn stream_owner_worker(window &WindowModel) &EnvironmentSettingsObject {
	mut realm := &ScriptingRealm{}
	scope := WorkerGlobalScope.create(dom.URL{'https://streams.example.test/worker.js'}, .classic, 'stream-owner', realm)
	return WorkerEnvironmentSettingsObject.setup(scope, mut realm, window.environment_settings_.settings.serialize(), 12).settings
}

fn test_stream_constructor_realms_queue_native_callback_promises_on_their_owning_window_worker_loops() {
	window := stream_owner_window()
	window_settings := window.environment_settings_.settings
	worker_settings := stream_owner_worker(window)
	mut window_loop := unsafe { &EventLoop(window_settings.responsible_event_loop()) }
	mut worker_loop := unsafe { &EventLoop(worker_settings.responsible_event_loop()) }
	assert voidptr(window_loop) != voidptr(worker_loop)
	mut worker_start := webidl.create_promise_for(worker_settings.stream_promise_context())
	mut readable := worker_settings.create_readable_stream(streams.UnderlyingSource{
		start_callback: webidl.CallbackType{
			callback: fn [worker_start] (_ webidl.Value, _ []webidl.Value) !webidl.Value {
				return webidl.promise_value(worker_start)
			}
		}
		pull_callback: webidl.CallbackType{
			callback: fn (_ webidl.Value, args []webidl.Value) !webidl.Value {
				mut controller := unsafe { &streams.ReadableStreamDefaultController(voidptr(args[0].opaque_id)) }
				controller.enqueue(streams.string_value('worker source'))!
				return webidl.undefined_value()
			}
		}
	}, streams.QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	mut reader := readable.get_default_reader() or { panic(err) }
	read := reader.read()
	mut window_start := webidl.create_promise_for(window_settings.stream_promise_context())
	mut sink_write := webidl.create_promise_for(window_settings.stream_promise_context())
	mut writable := window_settings.create_writable_stream(streams.UnderlyingSink{
		start_callback: webidl.CallbackType{
			callback: fn [window_start] (_ webidl.Value, _ []webidl.Value) !webidl.Value { return webidl.promise_value(window_start) }
		}
		write_callback: webidl.CallbackType{
			callback: fn [sink_write] (_ webidl.Value, args []webidl.Value) !webidl.Value {
				assert args[0].string_value == 'window sink'
				return webidl.promise_value(sink_write)
			}
		}
	}, streams.QueuingStrategy{}) or { panic(err) }
	mut writer := writable.get_writer() or { panic(err) }
	write := writer.write(streams.string_value('window sink'))
	assert readable.realm().id == u64(voidptr(worker_settings.realm()))
	assert writable.realm().id == u64(voidptr(window_settings.realm()))
	worker_start.resolve(webidl.undefined_value())
	window_loop.perform_a_microtask_checkpoint()
	assert read.state() == .pending
	assert !readable.default_controller() or { panic(err) }.started()
	worker_loop.perform_a_microtask_checkpoint()
	assert read.result().value.text == 'worker source'
	assert !writable.controller().started()
	assert write.state() == .pending
	window_start.resolve(webidl.undefined_value())
	window_loop.perform_a_microtask_checkpoint()
	assert writable.controller().started()
	assert write.state() == .pending
	sink_write.resolve(webidl.undefined_value())
	worker_loop.perform_a_microtask_checkpoint()
	assert write.state() == .pending
	window_loop.perform_a_microtask_checkpoint()
	assert write.state() == .fulfilled
}

fn test_stream_promise_job_captures_implied_script_document_and_prepares_actual_callback_realm() {
	window := stream_owner_window()
	settings := window.environment_settings_.settings
	mut event_loop := unsafe { &EventLoop(settings.responsible_event_loop()) }
	mut realm := unsafe { &ScriptingRealm(settings.realm()) }
	script := ClassicScript.create('stream-job.js', '', realm, window.associated_document().url, 1, .no)
	mut seen := &StreamOwnerObservations{}
	mut pending := webidl.create_promise_for(settings.stream_promise_context())
	_ := pending.upon_fulfillment(fn [settings, script, mut seen] (_ webidl.Value) !webidl.Value {
		assert settings.realm().script_execution_depth == 1
		assert settings.realm().callback_execution_depth == 1
		assert voidptr(current_principal_settings_object()) == voidptr(settings)
		assert voidptr(incumbent_settings_object()) == voidptr(settings)
		active := settings.realm().active_classic_script_ or { panic('missing captured source script') }
		assert voidptr(active) == voidptr(script)
		seen.reactions << 'source promise job'
		return webidl.undefined_value()
	})
	prepare_to_run_script(mut realm)
	realm.active_classic_script_ = script
	pending.resolve(webidl.undefined_value())
	realm.active_classic_script_ = none
	clean_up_after_running_script(mut realm)
	assert seen.reactions.len == 0
	assert event_loop.microtask_queue.len == 1
	job := event_loop.microtask_queue[0]
	assert job.source() == .microtask
	document := job.document() or { panic('missing script implied document') }
	assert voidptr(document) == voidptr(window.associated_document())
	event_loop.perform_a_microtask_checkpoint()
	assert seen.reactions == ['source promise job']
	assert realm.script_execution_depth == 0
	assert realm.callback_execution_depth == 0
	assert realm.active_classic_script_ == none
	assert event_loop.is_backup_incumbent_realm_stack_empty()
}

fn test_worker_transform_factory_adopts_shared_start_and_callback_promises_on_actual_owner() {
	window := stream_owner_window()
	settings := stream_owner_worker(window)
	mut event_loop := unsafe { &EventLoop(settings.responsible_event_loop()) }
	mut start := webidl.create_promise_for(settings.stream_promise_context())
	mut transformed := webidl.create_promise_for(settings.stream_promise_context())
	stream := settings.create_transform_stream(streams.Transformer{
		start_callback: webidl.CallbackType{
			callback: fn [start] (_ webidl.Value, _ []webidl.Value) !webidl.Value { return webidl.promise_value(start) }
		}
		transform_callback: webidl.CallbackType{
			callback: fn [transformed] (_ webidl.Value, args []webidl.Value) !webidl.Value {
				mut controller := unsafe { &streams.TransformStreamDefaultController(voidptr(args[1].opaque_id)) }
				controller.enqueue(streams.number_value(args[0].number_value + 1))!
				return webidl.promise_value(transformed)
			}
		}
	}, streams.QueuingStrategy{}, streams.QueuingStrategy{}) or { panic(err) }
	mut readable := stream.readable()
	mut writable := stream.writable()
	mut reader := readable.get_default_reader() or { panic(err) }
	mut writer := writable.get_writer() or { panic(err) }
	write := writer.write(streams.number_value(6))
	read := reader.read()
	event_loop.perform_a_microtask_checkpoint()
	assert !writable.controller().started()
	start.resolve(webidl.undefined_value())
	event_loop.perform_a_microtask_checkpoint()
	assert read.result().value.number == 7
	assert write.state() == .pending
	assert webidl.promise_realm(write.as_webidl_promise()) == u64(voidptr(settings.realm()))
	transformed.resolve(webidl.undefined_value())
	event_loop.perform_a_microtask_checkpoint()
	assert write.state() == .fulfilled
}
