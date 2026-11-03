@[has_globals]
module browserjs

import html
import math
import performancetimeline
import platform
import usertiming
import webidl

@[heap]
struct PerformanceObserverBinding {
	scope &html.WindowOrWorkerGlobalScopeMixin
	clone &StructuredCloneBridge
mut:
	make      voidptr
	observers map[voidptr]&performancetimeline.PerformanceObserver
	wrappers  map[voidptr]voidptr
	lists     map[voidptr]performancetimeline.PerformanceObserverEntryList
	entries   map[voidptr]&performancetimeline.PerformanceEntry
	mark_details map[voidptr]voidptr
	closed    bool
}

__global performance_observer_bindings_ = map[voidptr]&PerformanceObserverBinding{}

pub fn (mut runtime Runtime) install_performance_observer_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in performance_observer_bindings_ { return }
	settings := runtime.scripting_settings_ or { return error('PerformanceObserver requires an owning environment') }
	runtime.install_dom_exception_binding()!
	mut binding := &PerformanceObserverBinding{
		scope: settings.window_or_worker_global_scope()!
		clone: StructuredCloneBridge.create(&runtime)!
	}
	operation := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		settings := runtime.scripting_settings_ or { return error('PerformanceObserver requires settings') }
		persistent := platform.enter_persistent_if(settings.responsible_document() == none)
		defer { platform.leave_persistent(persistent) }
		mut allocation_scope := platform.RetainedArenaScope{}
		if document := settings.responsible_document() {
			mut storage := document.native_storage()
			if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
		}
		defer { allocation_scope.finish() }
		return runtime.performance_observer_operation(mut binding, args) or {
			if err is JavaScriptValueException { return err }
			value := webidl.exception_value(err)
			if value.dom_exception_ != none {
				return runtime.actual_javascript_exception(runtime.javascript_dom_exception(value)!)
			}
			if err.msg().starts_with('SyntaxError:') {
				return runtime.actual_javascript_exception(runtime.javascript_dom_exception(webidl.dom_exception_value(webidl.DOMException.create('SyntaxError', err.msg())))!)
			}
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
		binding.mark_details = {}
		performance_observer_bindings_.delete(owner)
	})
}

fn (mut runtime Runtime) performance_observer_list(mut binding PerformanceObserverBinding, entries []&performancetimeline.PerformanceEntry) !voidptr {
	value := runtime.retain_javascript_value(runtime.call_javascript_function(binding.make, C.vox_jsc_JSValueMakeUndefined(runtime.context), [C.vox_jsc_JSValueMakeNumber(runtime.context, 1)])!)!
	binding.lists[value] = performancetimeline.PerformanceObserverEntryList.create(entries)
	return value
}

fn (mut runtime Runtime) performance_observer_entries(mut binding PerformanceObserverBinding, entries []&performancetimeline.PerformanceEntry) !voidptr {
	mut values := []voidptr{cap: entries.len}
	for entry in entries {
		values << runtime.performance_observer_entry(mut binding, entry)!
	}
	mut exception := unsafe { nil }
	array := C.vox_jsc_JSObjectMakeArray(runtime.context, uint(values.len), values.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return array
}

fn (mut runtime Runtime) performance_observer_entry(mut binding PerformanceObserverBinding, entry &performancetimeline.PerformanceEntry) !voidptr {
	if cached := binding.wrappers[voidptr(entry)] { return cached }
	index := if entry.entry_type() == 'mark' { 4 } else { 2 }
	value := runtime.retain_javascript_value(runtime.call_javascript_function(binding.make, C.vox_jsc_JSValueMakeUndefined(runtime.context), [C.vox_jsc_JSValueMakeNumber(runtime.context, f64(index))])!)!
	binding.entries[value] = entry
	binding.wrappers[voidptr(entry)] = value
	return value
}

fn (mut runtime Runtime) performance_mark_operation(mut binding PerformanceObserverBinding, method string, args []voidptr) !voidptr {
	mut scope := binding.scope
	mut performance := scope.performance()
	if method != 'constructMark' {
		target := runtime.native_event_target(args[1])!
		if voidptr(target) != voidptr(performance) {
			return runtime.event_binding_type_error('Illegal Performance receiver')
		}
	}
	if method == 'performanceMarkBrand' { return C.vox_jsc_JSValueMakeUndefined(runtime.context) }
	name := runtime.binding_dom_string(args[2])!
	start := if C.JSValueIsUndefined(runtime.context, args[3]) { ?f64(none) }
		else { ?f64(webidl.value_to_number(runtime.webidl_value(args[3])!)!) }
	// Native constructor checks precede detail serialization. Publish only after
	// the actual engine value has been cloned into its owning context.
	options := usertiming.PerformanceMarkOptions{ start_time: start }
	now := performance.now()
	usertiming.validate_mark_options(name, options, now, performance.host.window_context)!
	detail := if C.JSValueIsUndefined(runtime.context, args[4]) || C.JSValueIsNull(runtime.context, args[4]) {
		C.vox_jsc_JSValueMakeNull(runtime.context)
	} else {
		binding.clone.clone(args[4])!
	}
	mark := usertiming.PerformanceMark.create_for_constructor(name, options, now, performance.host.window_context)!
	value := if method == 'constructMark' {
		runtime.retain_javascript_value(args[1])!
	} else {
		runtime.performance_observer_entry(mut binding, mark.entry)!
	}
	binding.entries[value] = mark.entry
	binding.wrappers[voidptr(mark.entry)] = value
	// The typed model's legacy string detail is not the JavaScript value ABI.
	// Keep the real cloned value rooted beside its native entry wrapper.
	binding.mark_details[voidptr(mark.entry)] = detail
	if method == 'mark' { performance.record_entry(mark.entry) }
	return value
}

fn (mut runtime Runtime) performance_observer_operation(mut binding PerformanceObserverBinding, args []voidptr) !voidptr {
	if args.len < 2 { return error('Missing PerformanceObserver operation') }
	method := runtime.binding_dom_string(args[0])!
	receiver := args[1]
	undefined := C.vox_jsc_JSValueMakeUndefined(runtime.context)
	if method == 'string' { return runtime.binding_string(runtime.binding_dom_string(args[2])!) }
	if method in ['performanceMarkBrand', 'mark', 'constructMark'] {
		return runtime.performance_mark_operation(mut binding, method, args)
	}
	if method == 'markDouble' {
		number := webidl.value_to_number(runtime.webidl_value(args[2])!)!
		if math.is_nan(number) || math.is_inf(number, 0) {
			return runtime.event_binding_type_error('PerformanceMark startTime must be finite')
		}
		return C.vox_jsc_JSValueMakeNumber(runtime.context, number)
	}
	if method == 'unsigned' {
		return C.vox_jsc_JSValueMakeNumber(runtime.context, f64(webidl.convert_to_int(runtime.webidl_value(args[2])!, 32, false, .no, .no)!))
	}
	if method == 'supported' {
		values := performancetimeline.supported_entry_types.map(runtime.binding_string(it))
		return C.vox_jsc_JSObjectMakeArray(runtime.context, uint(values.len), values.data, unsafe { nil })
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
				C.vox_jsc_JSValueMakeNumber(runtime.context, f64(count))
			} else {
				C.vox_jsc_JSValueMakeUndefined(runtime.context)
			}
			callback_options := runtime.call_javascript_function(binding.make, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
				C.vox_jsc_JSValueMakeNumber(runtime.context, 3),
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
						value := C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, args[4], u32(index), &exception)
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
	if method == 'markDetail' {
		if entry.entry_type() != 'mark' { return runtime.event_binding_type_error('Illegal PerformanceMark receiver') }
		detail := binding.mark_details[voidptr(entry)] or { return C.vox_jsc_JSValueMakeNull(runtime.context) }
		copy := binding.clone.clone(detail)!
		// The result transfers to the engine caller. Only the stored original
		// needs a permanent root; repeated reads must not accumulate roots.
		runtime.release_javascript_value(copy)
		return copy
	}
	return match method {
		'name' { runtime.binding_string(entry.name()) }
		'entryType' { runtime.binding_string(entry.entry_type()) }
		'startTime' { C.vox_jsc_JSValueMakeNumber(runtime.context, entry.start_time()) }
		'duration' { C.vox_jsc_JSValueMakeNumber(runtime.context, entry.duration()) }
		else { return error('Unknown PerformanceObserver operation') }
	}
}
