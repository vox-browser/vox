@[has_globals]
module browserjs

import dom
import html
import intersectionobserver
import math
import platform
import webidl

@[heap]
struct IntersectionObserverBinding {
	document       &dom.Document
	before_observe ?IntersectionObserverBeforeObserveHook
mut:
	make       voidptr
	observers  map[voidptr]&intersectionobserver.IntersectionObserver
	roots      map[voidptr]voidptr
	thresholds map[voidptr]voidptr
	entries    map[voidptr]&intersectionobserver.IntersectionObserverEntry
	wrappers   map[voidptr]voidptr
	closed     bool
}

__global intersection_observer_bindings_ = map[voidptr]&IntersectionObserverBinding{}

pub fn (mut runtime Runtime) install_intersection_observer_binding(before_observe ?IntersectionObserverBeforeObserveHook) ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in intersection_observer_bindings_ { return }
	settings := runtime.scripting_settings_ or { return error('IntersectionObserver requires an owning environment') }
	if settings.global_object().data.kind != .window {
		return error('IntersectionObserver requires a Window')
	}
	document := settings.responsible_document() or { return error('IntersectionObserver requires a Document') }
	runtime.install_event_target_binding()!
	runtime.install_dom_exception_binding()!
	runtime.install_dom_rect_read_only_binding()!
	mut binding := &IntersectionObserverBinding{ document: document, before_observe: before_observe }
	operation := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		mut storage := binding.document.native_storage()
		mut allocation_scope := platform.RetainedArenaScope{}
		if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
		defer { allocation_scope.finish() }
		return runtime.intersection_observer_operation(mut binding, args) or {
			if err is JavaScriptValueException { return err }
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(intersection_observer_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	binding.make = runtime.retain_javascript_value(runtime.call_javascript_function(factory, global, [
		operation,
		global,
	])!)!
	intersection_observer_bindings_[owner] = binding
	runtime.add_close_handler(fn [owner, mut binding] () {
		binding.closed = true
		for _, mut observer in binding.observers {
			observer.disconnect()
			observer.finalize()
		}
		binding.observers = {}
		binding.roots = {}
		binding.thresholds = {}
		binding.entries = {}
		binding.wrappers = {}
		intersection_observer_bindings_.delete(owner)
	})
}

fn (runtime &Runtime) intersection_observer_node(value voidptr) !&dom.Node {
	target := runtime.native_event_target(value)!
	if target.data.kind != .node {
		return runtime.event_binding_type_error('IntersectionObserver requires a native Node')
	}
	return unsafe { &dom.Node(target) }
}

fn (runtime &Runtime) intersection_observer_element(value voidptr) !&dom.Element {
	node := runtime.intersection_observer_node(value)!
	return node.as_element() or { return runtime.event_binding_type_error('IntersectionObserver requires an Element') }
}

fn (mut runtime Runtime) intersection_observer_entries(mut binding IntersectionObserverBinding, entries []&intersectionobserver.IntersectionObserverEntry) !voidptr {
	mut values := []voidptr{cap: entries.len}
	for entry in entries {
		if wrapper := binding.wrappers[voidptr(entry)] {
			values << wrapper
			continue
		}
		wrapper := runtime.retain_javascript_value(runtime.call_javascript_function(binding.make, C.JSValueMakeUndefined(runtime.context), [C.JSValueMakeNumber(runtime.context, 0)])!)!
		binding.entries[wrapper] = entry
		binding.wrappers[voidptr(entry)] = wrapper
		values << wrapper
	}
	mut exception := unsafe { nil }
	array := C.JSObjectMakeArray(runtime.context, uint(values.len), values.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return array
}

fn (mut runtime Runtime) intersection_observer_operation(mut binding IntersectionObserverBinding, args []voidptr) !voidptr {
	if args.len < 2 {
		return runtime.event_binding_type_error('Missing IntersectionObserver operation')
	}
	method := runtime.binding_dom_string(args[0])!
	receiver := args[1]
	undefined := C.JSValueMakeUndefined(runtime.context)
	if method == 'string' { return runtime.binding_string(runtime.binding_dom_string(args[2])!) }
	if method == 'long' {
		return C.JSValueMakeNumber(runtime.context, webidl.convert_to_int(runtime.webidl_value(args[2])!, 32, true, .no, .no)!)
	}
	if method == 'double' {
		number := webidl.value_to_number(runtime.webidl_value(args[2])!)!
		if math.is_nan(number) || math.is_inf(number, 0) {
			return runtime.event_binding_type_error('IntersectionObserver threshold must be finite')
		}
		return C.JSValueMakeNumber(runtime.context, number)
	}
	if method == 'rootArgument' {
		node := runtime.intersection_observer_node(args[2])!
		if !node.is_element() && !node.is_document() {
			return runtime.event_binding_type_error('IntersectionObserver root must be an Element or Document')
		}
		return args[2]
	}
	if method == 'construct' {
		mut root := intersectionobserver.ObserverRoot{}
		if !C.JSValueIsNull(runtime.context, args[3]) {
			node := runtime.intersection_observer_node(args[3])!
			if element := node.as_element() {
				root = intersectionobserver.ObserverRoot{ kind: .element, element: element }
			} else if document := node.as_document() {
				root = intersectionobserver.ObserverRoot{ kind: .document, document: document }
			}
		}
		margin := runtime.binding_dom_string(args[4])!
		scroll := runtime.binding_dom_string(args[5])!
		// Match the source's validation order and its actual exception types.
		if intersectionobserver.parse_a_margin(margin) == none || intersectionobserver.parse_a_margin(scroll) == none {
			return runtime.actual_javascript_exception(runtime.javascript_dom_exception(webidl.dom_exception_value(webidl.DOMException.create('SyntaxError', 'IntersectionObserver margin must contain pixel or percentage lengths')))!)
		}
		length := int(runtime.ui_event_long(runtime.binding_property(args[6], 'length')!)!)
		mut thresholds := []f64{cap: length}
		for index in 0 .. length {
			mut exception := unsafe { nil }
			value := C.JSObjectGetPropertyAtIndex(runtime.context, args[6], u32(index), &exception)
			if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
			threshold := webidl.value_to_number(runtime.webidl_value(value)!)!
			if threshold < 0 || threshold > 1 {
				return runtime.actual_javascript_exception(runtime.binding_exception_value(error('RangeError: Threshold must be between zero and one')))
			}
			thresholds << threshold
		}
		if synchronize := binding.before_observe { synchronize(runtime)! }
		callback := runtime.retain_javascript_value(args[2])!
		runtime.retain_javascript_value(receiver)!
		owner := voidptr(&runtime)
		callback_settings := runtime.callback_settings()
		delivery := fn [owner, mut binding, receiver, callback, callback_settings] (entries []&intersectionobserver.IntersectionObserverEntry, _ &intersectionobserver.IntersectionObserver) {
			if binding.closed { return }
			mut runtime := unsafe { &Runtime(owner) }
			if settings := runtime.scripting_settings_ {
				if html.can_run_script_for_settings(settings) == .do_not_run { return }
			}
			runtime.prepare_html_callback(callback_settings)
			defer { runtime.clean_up_html_callback(callback_settings) }
			defer { runtime.mark_document_state_dirty() }
			records := runtime.intersection_observer_entries(mut binding, entries) or {
				runtime.report_event_callback_exception(err)
				return
			}
			runtime.call_javascript_function(callback, receiver, [records, receiver]) or { runtime.report_event_callback_exception(err) }
		}
		runtime.own_closure(voidptr(delivery))
		observer := intersectionobserver.IntersectionObserver.construct_impl(delivery, intersectionobserver.IntersectionObserverInit{
			root:              root
			relevant_document: binding.document
			root_margin:       margin
			scroll_margin:     scroll
			thresholds:        thresholds
			delay:             runtime.ui_event_long(args[7])!
			track_visibility:  C.JSValueToBoolean(runtime.context, args[8])
		})!
		binding.observers[receiver] = observer
		binding.roots[receiver] = runtime.retain_javascript_value(args[3])!
		values := observer.thresholds().map(C.JSValueMakeNumber(runtime.context, it))
		array := C.JSObjectMakeArray(runtime.context, uint(values.len), values.data, unsafe { nil })
		binding.thresholds[receiver] = runtime.retain_javascript_value(runtime.call_javascript_function(binding.make, undefined, [
			C.JSValueMakeNumber(runtime.context, 1),
			array,
		])!)!
		return undefined
	}
	if method.starts_with('entry ') {
		entry := binding.entries[receiver] or { return runtime.event_binding_type_error('Illegal IntersectionObserverEntry receiver') }
		return match method {
			'entry time' { C.JSValueMakeNumber(runtime.context, entry.time()) }
			'entry isIntersecting' {
				C.JSValueMakeBoolean(runtime.context, entry.is_intersecting())
			}
			'entry intersectionRatio' {
				C.JSValueMakeNumber(runtime.context, entry.intersection_ratio())
			}
			'entry target' {
				runtime.javascript_event_target(unsafe { &dom.EventTarget(entry.target()) }, none)!
			}
			'entry rootBounds' {
				if bounds := entry.root_bounds() {
					runtime.javascript_read_only_rect(bounds)!
				} else {
					C.JSValueMakeNull(runtime.context)
				}
			}
			'entry boundingClientRect' {
				runtime.javascript_read_only_rect(entry.bounding_client_rect())!
			}
			'entry intersectionRect' {
				runtime.javascript_read_only_rect(entry.intersection_rect())!
			}
			else { return error('Unknown IntersectionObserverEntry operation') }
		}
	}
	mut observer := binding.observers[receiver] or { return runtime.event_binding_type_error('Illegal IntersectionObserver receiver') }
	match method {
		'observe', 'unobserve' {
			target := runtime.intersection_observer_element(args[2])!
			if synchronize := binding.before_observe { synchronize(runtime)! }
			if method == 'observe' {
				observer.observe(target)
				runtime.mark_document_state_dirty()
			} else {
				observer.unobserve(target)
			}
		}
		'disconnect' { observer.disconnect() }
		'takeRecords' {
			return runtime.intersection_observer_entries(mut binding, observer.take_records())
		}
		'root' { return binding.roots[receiver] or { return error('Missing IntersectionObserver roots') } }
		'rootMargin' { return runtime.binding_string(observer.root_margin()) }
		'scrollMargin' { return runtime.binding_string(observer.scroll_margin()) }
		'thresholds' { return binding.thresholds[receiver] or { return error('Missing IntersectionObserver thresholds') } }
		'delay' { return C.JSValueMakeNumber(runtime.context, f64(observer.delay())) }
		'trackVisibility' {
			return C.JSValueMakeBoolean(runtime.context, observer.track_visibility())
		}
		'observerBrand' {}
		else { return error('Unknown IntersectionObserver operation') }
	}
	return undefined
}
