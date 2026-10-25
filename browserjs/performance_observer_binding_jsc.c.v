@[has_globals]
module browserjs

import html
import performancetimeline
import platform
import webidl

@[heap]
struct PerformanceObserverBinding {
	scope &html.WindowOrWorkerGlobalScopeMixin
mut:
	make      voidptr
	observers map[voidptr]&performancetimeline.PerformanceObserver
	wrappers  map[voidptr]voidptr
	lists     map[voidptr]performancetimeline.PerformanceObserverEntryList
	entries   map[voidptr]&performancetimeline.PerformanceEntry
	closed    bool
}

__global performance_observer_bindings_ = map[voidptr]&PerformanceObserverBinding{}

pub fn (mut runtime Runtime) install_performance_observer_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in performance_observer_bindings_ { return }
	settings := runtime.scripting_settings_ or { return error('PerformanceObserver requires an owning environment') }
	target := settings.global_object()
	if target.data.kind != .window { return error('PerformanceObserver requires an owning Window') }
	mut window := unsafe { &html.WindowModel(target) }
	mut binding := &PerformanceObserverBinding{ scope: window.window_or_worker_global_scope() }
	runtime.install_dom_exception_binding()!
	operation := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		settings := runtime.scripting_settings_ or { return error('PerformanceObserver requires settings') }
		document := settings.responsible_document() or { return error('PerformanceObserver requires a document') }
		mut storage := document.native_storage()
		mut allocation_scope := platform.RetainedArenaScope{}
		if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
		defer { allocation_scope.finish() }
		return runtime.performance_observer_operation(mut binding, args) or {
			if err is JavaScriptValueException { return err }
			if err.msg().starts_with('InvalidModificationError:') {
				return runtime.actual_javascript_exception(runtime.javascript_dom_exception(webidl.dom_exception_value(webidl.DOMException.create('InvalidModificationError', err.msg())))!)
			}
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(performance_observer_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	binding.make = runtime.retain_javascript_value(runtime.call_javascript_function(factory, global, [
		operation,
		global,
	])!)!
	performance_observer_bindings_[owner] = binding
	runtime.add_close_handler(fn [owner, mut binding] () {
		binding.closed = true
		for _, mut observer in binding.observers { observer.disconnect() }
		binding.observers = {}
		binding.wrappers = {}
		binding.lists = {}
		binding.entries = {}
		performance_observer_bindings_.delete(owner)
	})
}

fn (mut runtime Runtime) performance_observer_list(mut binding PerformanceObserverBinding, entries []&performancetimeline.PerformanceEntry) !voidptr {
	value := runtime.retain_javascript_value(runtime.call_javascript_function(binding.make, C.JSValueMakeUndefined(runtime.context), [C.JSValueMakeNumber(runtime.context, 1)])!)!
	binding.lists[value] = performancetimeline.PerformanceObserverEntryList.create(entries)
	return value
}

fn (mut runtime Runtime) performance_observer_entries(mut binding PerformanceObserverBinding, entries []&performancetimeline.PerformanceEntry) !voidptr {
	mut values := []voidptr{cap: entries.len}
	for entry in entries {
		if cached := binding.wrappers[voidptr(entry)] {
			values << cached
			continue
		}
		value := runtime.retain_javascript_value(runtime.call_javascript_function(binding.make, C.JSValueMakeUndefined(runtime.context), [C.JSValueMakeNumber(runtime.context, 2)])!)!
		binding.entries[value] = entry
		binding.wrappers[voidptr(entry)] = value
		values << value
	}
	mut exception := unsafe { nil }
	array := C.JSObjectMakeArray(runtime.context, usize(values.len), if values.len == 0 {
		unsafe { nil }
	} else {
		values.data
	}, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return array
}

fn (mut runtime Runtime) performance_observer_operation(mut binding PerformanceObserverBinding, args []voidptr) !voidptr {
	if args.len < 2 { return error('Missing PerformanceObserver operation') }
	method := runtime.binding_dom_string(args[0])!
	receiver := args[1]
	undefined := C.JSValueMakeUndefined(runtime.context)
	if method == 'string' { return runtime.binding_string(runtime.binding_dom_string(args[2])!) }
	if method == 'unsigned' {
		return C.JSValueMakeNumber(runtime.context, f64(webidl.convert_to_int(runtime.webidl_value(args[2])!, 32, false, .no, .no)!))
	}
	if method == 'supported' {
		values := performancetimeline.supported_entry_types.map(runtime.binding_string(it))
		return C.JSObjectMakeArray(runtime.context, usize(values.len), values.data, unsafe { nil })
	}
	if method == 'construct' {
		callback := runtime.retain_javascript_value(args[2])!
		runtime.retain_javascript_value(receiver)!
		owner := voidptr(&runtime)
		callback_settings := runtime.callback_settings()
		mut scope := binding.scope
		mut performance := scope.performance()
		observer := performancetimeline.PerformanceObserver.create(fn [owner, mut binding, receiver, callback, callback_settings] (list performancetimeline.PerformanceObserverEntryList, _ &performancetimeline.PerformanceObserver, options performancetimeline.PerformanceObserverCallbackOptions) {
			if binding.closed { return }
			mut runtime := unsafe { &Runtime(owner) }
			if settings := runtime.scripting_settings_ {
				if html.can_run_script_for_settings(settings) == .do_not_run { return }
			}
			runtime.prepare_html_callback(callback_settings)
			defer { runtime.clean_up_html_callback(callback_settings) }
			defer { runtime.mark_document_state_dirty() }
			records := runtime.performance_observer_list(mut binding, list.get_entries()) or {
				runtime.report_event_callback_exception(err)
				return
			}
			dropped := if count := options.dropped_entries_count {
				C.JSValueMakeNumber(runtime.context, f64(count))
			} else {
				C.JSValueMakeUndefined(runtime.context)
			}
			callback_options := runtime.call_javascript_function(binding.make, C.JSValueMakeUndefined(runtime.context), [
				C.JSValueMakeNumber(runtime.context, 3),
				dropped,
			]) or {
				runtime.report_event_callback_exception(err)
				return
			}
			runtime.call_javascript_function(callback, receiver, [records, receiver, callback_options]) or { runtime.report_event_callback_exception(err) }
		}, performance.timeline)
		binding.observers[receiver] = observer
		return undefined
	}
	if method in ['observerBrand', 'observe', 'disconnect', 'takeRecords'] {
		mut observer := binding.observers[receiver] or { return runtime.event_binding_type_error('Illegal PerformanceObserver receiver') }
		match method {
			'observe' {
				mut options := performancetimeline.PerformanceObserverInit{}
				if !C.JSValueIsUndefined(runtime.context, args[2]) {
					options.buffered = C.JSValueToBoolean(runtime.context, args[2])
				}
				if !C.JSValueIsUndefined(runtime.context, args[3]) {
					options.duration_threshold = u32(runtime.ui_event_long(args[3])!)
				}
				if !C.JSValueIsUndefined(runtime.context, args[4]) {
					length := int(runtime.ui_event_long(runtime.binding_property(args[4], 'length')!)!)
					mut types := []string{cap: length}
					for index in 0 .. length {
						mut exception := unsafe { nil }
						value := C.JSObjectGetPropertyAtIndex(runtime.context, args[4], u32(index), &exception)
						if exception != unsafe { nil } {
							return runtime.actual_javascript_exception(exception)
						}
						types << runtime.binding_dom_string(value)!
					}
					options.entry_types = types
				}
				if !C.JSValueIsUndefined(runtime.context, args[5]) {
					options.type_ = runtime.binding_dom_string(args[5])!
				}
				observer.observe(options)!
				mut scope := binding.scope
				scope.queue_the_performance_observer_task()
			}
			'disconnect' { observer.disconnect() }
			'takeRecords' {
				return runtime.performance_observer_entries(mut binding, observer.take_records())
			}
			else {}
		}
		return undefined
	}
	if method in ['listBrand', 'getEntries', 'getEntriesByType', 'getEntriesByName'] {
		list := binding.lists[receiver] or { return runtime.event_binding_type_error('Illegal PerformanceObserverEntryList receiver') }
		if method == 'listBrand' { return undefined }
		entries := match method {
			'getEntriesByType' { list.get_entries_by_type(runtime.binding_dom_string(args[2])!) }
			'getEntriesByName' {
				kind := if C.JSValueIsUndefined(runtime.context, args[3]) {
					?string(none)
				} else {
					?string(runtime.binding_dom_string(args[3])!)
				}
				list.get_entries_by_name(runtime.binding_dom_string(args[2])!, kind)
			}
			else { list.get_entries() }
		}
		return runtime.performance_observer_entries(mut binding, entries)
	}
	entry := binding.entries[receiver] or { return runtime.event_binding_type_error('Illegal PerformanceEntry receiver') }
	return match method {
		'name' { runtime.binding_string(entry.name()) }
		'entryType' { runtime.binding_string(entry.entry_type()) }
		'startTime' { C.JSValueMakeNumber(runtime.context, entry.start_time()) }
		'duration' { C.JSValueMakeNumber(runtime.context, entry.duration()) }
		else { return error('Unknown PerformanceObserver operation') }
	}
}
