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
	target   &dom.EventTarget
	document ?&dom.Document
mut:
	enqueue    voidptr
	deactivate voidptr
	next_token int
	pending    map[int]QueuedMicrotaskCallback
	closed     bool
}

__global microtask_bindings_ = map[voidptr]&MicrotaskBinding{}

// Platform algorithms use the same protected Promise carrier as public
// queueMicrotask, without consulting an author-replaceable global function.
pub fn (mut runtime Runtime) enqueue_javascript_microtask(callback voidptr) ! {
	runtime.install_microtask_binding()!
	mut binding := microtask_bindings_[voidptr(&runtime)] or { return error('Microtask binding is missing') }
	if binding.closed { return error('Microtask binding is closed') }
	if !C.JSValueIsObject(runtime.context, callback) || !C.JSObjectIsFunction(runtime.context, callback) {
		return runtime.event_binding_type_error('Microtask callback must be callable')
	}
	entry := platform.enter_persistent()
	defer { platform.leave_persistent(entry) }
	binding.next_token++
	token := binding.next_token
	binding.pending[token] = QueuedMicrotaskCallback{runtime.retain_javascript_value(callback)!, runtime.callback_settings()}
	if settings := runtime.scripting_settings_ {
		if settings.realm().script_execution_depth == 0 {
			// Native DOM steps must finish before entering JSC can service its
			// Promise queue. Deliver through the owning HTML checkpoint when no
			// JavaScript entry is already keeping that checkpoint deferred.
			owner := voidptr(&runtime)
			html.queue_a_task(.microtask, settings.responsible_event_loop(), none, fn [owner, mut binding, token] () {
				if binding.closed { return }
				mut runtime := unsafe { &Runtime(owner) }
				runtime.call_javascript_function(binding.enqueue, C.vox_jsc_JSValueMakeUndefined(runtime.context), [C.vox_jsc_JSValueMakeNumber(runtime.context, f64(token))]) or {
					runtime.report_event_callback_exception(err)
				}
			})
			return
		}
	}
	runtime.call_javascript_function(binding.enqueue, C.vox_jsc_JSValueMakeUndefined(runtime.context), [C.vox_jsc_JSValueMakeNumber(runtime.context, f64(token))]) or {
		binding.pending.delete(token)
		runtime.release_javascript_value(callback)
		return err
	}
}

pub fn (mut runtime Runtime) install_microtask_binding() ! {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in microtask_bindings_ { return }
	settings := runtime.scripting_settings_ or { return error('queueMicrotask requires its owning environment') }
	_ = settings.window_or_worker_global_scope()!
	runtime.install_event_target_binding()!
	mut binding := &MicrotaskBinding{
		target: settings.global_object()
		document: settings.responsible_document()
	}
	deliver := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		undefined := C.vox_jsc_JSValueMakeUndefined(runtime.context)
		if binding.closed || args.len != 1 { return undefined }
		mut allocation_scope := platform.RetainedArenaScope{}
		if document := binding.document {
			mut storage := document.native_storage()
			if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
		}
		defer { allocation_scope.finish() }
		// This private argument is an engine Number, not a WebIDL long.
		token := int(C.vox_jsc_JSValueToNumber(runtime.context, args[0], unsafe { nil }))
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
		if voidptr(target) != voidptr(binding.target) {
			return runtime.event_binding_type_error('Illegal queueMicrotask receiver')
		}
		if args.len == 0 || !C.JSValueIsObject(runtime.context, args[0]) || !C.JSObjectIsFunction(runtime.context, args[0]) {
			return runtime.event_binding_type_error('queueMicrotask requires a callback function')
		}
		mut allocation_scope := platform.RetainedArenaScope{}
		if document := binding.document {
			mut storage := document.native_storage()
			if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
		}
		defer { allocation_scope.finish() }
		binding.next_token++
		token := binding.next_token
		callback := runtime.retain_javascript_value(args[0])!
		binding.pending[token] = QueuedMicrotaskCallback{callback, runtime.callback_settings()}
		runtime.call_javascript_function(binding.enqueue, C.vox_jsc_JSValueMakeUndefined(runtime.context), [C.vox_jsc_JSValueMakeNumber(runtime.context, f64(token))]) or {
			binding.pending.delete(token)
			runtime.release_javascript_value(callback)
			return err
		}
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	carrier := runtime.create_javascript_promise()!
	defer { runtime.release_javascript_promise(carrier) }
	runtime.resolve_javascript_promise(carrier, C.vox_jsc_JSValueMakeUndefined(runtime.context))!
	factory := runtime.evaluate_host_value(microtask_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	functions := runtime.call_javascript_function(factory, global, [deliver, global, carrier.promise,
		queue])!
	mut exception := unsafe { nil }
	binding.enqueue = runtime.retain_javascript_value(C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, functions, 0, &exception))!
	binding.deactivate = runtime.retain_javascript_value(C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, functions, 1, &exception))!
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	register_runtime_binding(mut microtask_bindings_, owner, binding)
	runtime.add_close_handler(fn [owner, mut binding] () {
		binding.closed = true
		mut runtime := unsafe { &Runtime(owner) }
		// close() has already disabled public Runtime operations; call the
		// engine directly while its context and host records still exist.
		runtime.call_engine_function(binding.deactivate, []) or {}
		binding.pending = {}
		unregister_runtime_binding(mut microtask_bindings_, owner)
	})
}
