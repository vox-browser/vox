@[has_globals]
module browserjs

import dom
import html
import platform

struct QueuedMicrotaskCallback {
	callback voidptr
	settings ?&html.EnvironmentSettingsObject
}

@[heap]
struct MicrotaskBinding {
	document &dom.Document
mut:
	enqueue    voidptr
	deactivate voidptr
	next_token int
	pending    map[int]QueuedMicrotaskCallback
	closed     bool
}

__global microtask_bindings_ = map[voidptr]&MicrotaskBinding{}

pub fn (mut runtime Runtime) install_microtask_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in microtask_bindings_ { return }
	settings := runtime.scripting_settings_ or { return error('queueMicrotask requires its owning environment') }
	if settings.global_object().data.kind != .window {
		return error('queueMicrotask currently requires a Window')
	}
	document := settings.responsible_document() or { return error('queueMicrotask requires a Document') }
	runtime.install_event_target_binding()!
	mut binding := &MicrotaskBinding{ document: document }
	deliver := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		undefined := C.JSValueMakeUndefined(runtime.context)
		if binding.closed || args.len != 1 { return undefined }
		mut storage := binding.document.native_storage()
		mut allocation_scope := platform.RetainedArenaScope{}
		if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
		defer { allocation_scope.finish() }
		// This private argument is an engine Number, not a WebIDL long.
		token := int(C.JSValueToNumber(runtime.context, args[0], unsafe { nil }))
		job := binding.pending[token] or { return undefined }
		binding.pending.delete(token)
		defer { runtime.release_javascript_value(job.callback) }
		if active_settings := runtime.scripting_settings_ {
			if html.can_run_script_for_settings(active_settings) == .do_not_run { return undefined }
		}
		runtime.prepare_html_callback(job.settings)
		defer { runtime.clean_up_html_callback(job.settings) }
		defer { runtime.mark_document_state_dirty() }
		// Ignore the callback's result, including thenables. Abrupt completion
		// reports an exception rather than rejecting the internal carrier job.
		runtime.call_javascript_function(job.callback, undefined, []) or {
			runtime.report_event_callback_exception(err)
		}
		return undefined
	})!
	queue := runtime.make_native_value_host_function('queueMicrotask', 1, fn [owner, mut binding] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		target := runtime.native_event_target(receiver)!
		if target.data.kind != .window {
			return runtime.event_binding_type_error('Illegal queueMicrotask receiver')
		}
		if args.len == 0 || !C.JSValueIsObject(runtime.context, args[0]) || !C.JSObjectIsFunction(runtime.context, args[0]) {
			return runtime.event_binding_type_error('queueMicrotask requires a callback function')
		}
		mut storage := binding.document.native_storage()
		mut allocation_scope := platform.RetainedArenaScope{}
		if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
		defer { allocation_scope.finish() }
		binding.next_token++
		token := binding.next_token
		callback := runtime.retain_javascript_value(args[0])!
		binding.pending[token] = QueuedMicrotaskCallback{callback, runtime.callback_settings()}
		runtime.call_javascript_function(binding.enqueue, C.JSValueMakeUndefined(runtime.context), [C.JSValueMakeNumber(runtime.context, f64(token))]) or {
			binding.pending.delete(token)
			runtime.release_javascript_value(callback)
			return err
		}
		return C.JSValueMakeUndefined(runtime.context)
	})!
	carrier := runtime.create_javascript_promise()!
	defer { runtime.release_javascript_promise(carrier) }
	runtime.resolve_javascript_promise(carrier, C.JSValueMakeUndefined(runtime.context))!
	factory := runtime.evaluate_host_value(microtask_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	functions := runtime.call_javascript_function(factory, global, [deliver, global, carrier.promise,
		queue])!
	mut exception := unsafe { nil }
	binding.enqueue = runtime.retain_javascript_value(C.JSObjectGetPropertyAtIndex(runtime.context, functions, 0, &exception))!
	binding.deactivate = runtime.retain_javascript_value(C.JSObjectGetPropertyAtIndex(runtime.context, functions, 1, &exception))!
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	microtask_bindings_[owner] = binding
	runtime.add_close_handler(fn [owner, mut binding] () {
		binding.closed = true
		mut runtime := unsafe { &Runtime(owner) }
		// close() has already disabled public Runtime operations; call the
		// engine directly while its context and host records still exist.
		runtime.call_engine_function(binding.deactivate, []) or {}
		binding.pending = {}
		microtask_bindings_.delete(owner)
	})
}
