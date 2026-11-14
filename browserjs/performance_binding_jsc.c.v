@[has_globals]
module browserjs

import dom
import html
import platform
import webidl

__global performance_bindings_ = map[voidptr]bool{}

pub fn (mut runtime Runtime) install_performance_binding() ! {
	if runtime.engine == .libjs { runtime.install_libjs_performance()!; return }
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if performance_bindings_[owner] { return }
	runtime.install_performance_observer_binding()!
	runtime.install_event_target_binding()!
	mut binding := performance_observer_bindings_[owner] or { return error('Missing native performance timeline') }
	mut scope := binding.scope
	performance := scope.performance()
	operation := runtime.make_value_host_function(fn [owner, mut binding, performance] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		settings := runtime.scripting_settings_ or { return error('Performance requires settings') }
		persistent := platform.enter_persistent_if(settings.responsible_document() == none)
		defer { platform.leave_persistent(persistent) }
		mut allocation_scope := platform.RetainedArenaScope{}
		if document := settings.responsible_document() {
			mut storage := document.native_storage()
			if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
		}
		defer { allocation_scope.finish() }
		return runtime.performance_operation(mut binding, performance, args) or {
			if err is JavaScriptValueException { return err }
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(performance_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	wrapper := runtime.call_javascript_function(factory, global, [operation, global, binding.make])!
	runtime.bind_event_target(wrapper, unsafe { &dom.EventTarget(performance) })!
	register_runtime_binding(mut performance_bindings_, owner, true)
	runtime.add_close_handler(fn [owner] () { unregister_runtime_binding(mut performance_bindings_, owner) })
}

fn (mut runtime Runtime) performance_operation(mut binding PerformanceObserverBinding,
	performance &html.GlobalScopePerformance, args []voidptr) !voidptr {
	if args.len < 2 { return error('Missing Performance operation') }
	method := runtime.binding_dom_string(args[0])!
	target := runtime.native_event_target(args[1])!
	if voidptr(target) != voidptr(performance) {
		return runtime.event_binding_type_error('Illegal Performance receiver')
	}
	undefined := C.vox_jsc_JSValueMakeUndefined(runtime.context)
	mut current := unsafe { &html.GlobalScopePerformance(performance) }
	match method {
		'brand' { return undefined }
		'string' { return runtime.binding_string(runtime.binding_dom_string(args[2])!) }
		'now' { return C.vox_jsc_JSValueMakeNumber(runtime.context, current.now()) }
		'timeOrigin' { return C.vox_jsc_JSValueMakeNumber(runtime.context, current.time_origin()) }
		'getHandler' { return runtime.javascript_event_handler(target, 'resourcetimingbufferfull') }
		'setHandler' {
			runtime.set_javascript_event_handler(target, 'resourcetimingbufferfull', args[2])!
		}
		'getEntries' {
			return runtime.performance_observer_entries(mut binding, current.get_entries())
		}
		'getEntriesByType' {
			return runtime.performance_observer_entries(mut binding, current.get_entries_by_type(runtime.binding_dom_string(args[2])!))
		}
		'getEntriesByName' {
			kind := if C.JSValueIsUndefined(runtime.context, args[3]) {
				?string(none)
			} else {
				?string(runtime.binding_dom_string(args[3])!)
			}
			return runtime.performance_observer_entries(mut binding, current.get_entries_by_name(runtime.binding_dom_string(args[2])!, kind))
		}
		'clearMarks', 'clearMeasures' {
			name := if C.JSValueIsUndefined(runtime.context, args[2]) {
				?string(none)
			} else {
				?string(runtime.binding_dom_string(args[2])!)
			}
			if method == 'clearMarks' {
				current.clear_marks(name)
			} else {
				current.clear_measures(name)
			}
		}
		'clearResourceTimings' { current.clear_resource_timings() }
		'setResourceTimingBufferSize' {
			value := webidl.convert_to_int(runtime.webidl_value(args[2])!, 32, false, .no, .no)!
			current.set_resource_timing_buffer_size(u32(value))
		}
		else { return error('Unknown Performance operation') }
	}
	return undefined
}
