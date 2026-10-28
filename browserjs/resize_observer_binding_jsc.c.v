@[has_globals]
module browserjs

import dom
import html
import platform
import resizeobserver

@[heap]
struct ResizeObserverBinding {
	document       &dom.Document
	before_observe ?ResizeObserverBeforeObserveHook
mut:
	make         voidptr
	observers    map[voidptr]&resizeobserver.ResizeObserver
	targets      map[voidptr]&resizeobserver.ResizeTarget
	entries      map[voidptr]&resizeobserver.ResizeObserverEntry
	entry_arrays map[voidptr][]voidptr
	sizes        map[voidptr]resizeobserver.ResizeObserverSize
	closed       bool
}

__global resize_observer_bindings_ = map[voidptr]&ResizeObserverBinding{}

pub fn (mut runtime Runtime) install_resize_observer_binding(before_observe ?ResizeObserverBeforeObserveHook) ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in resize_observer_bindings_ { return }
	settings := runtime.scripting_settings_ or { return error('ResizeObserver requires an owning environment') }
	if settings.global_object().data.kind != .window {
		return error('ResizeObserver requires a Window')
	}
	document := settings.responsible_document() or { return error('ResizeObserver requires a Document') }
	runtime.install_event_target_binding()!
	runtime.install_dom_rect_read_only_binding()!
	mut binding := &ResizeObserverBinding{ document: document, before_observe: before_observe }
	operation := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		mut storage := binding.document.native_storage()
		mut allocation_scope := platform.RetainedArenaScope{}
		if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
		defer { allocation_scope.finish() }
		return runtime.resize_observer_operation(mut binding, args) or {
			if err is JavaScriptValueException { return err }
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(resize_observer_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	binding.make = runtime.retain_javascript_value(runtime.call_javascript_function(factory, global, [
		operation,
		global,
	])!)!
	resize_observer_bindings_[owner] = binding
	runtime.add_close_handler(fn [owner, mut binding] () {
		binding.closed = true
		for _, mut observer in binding.observers {
			observer.disconnect()
			observer.finalize()
		}
		binding.observers = {}
		binding.targets = {}
		binding.entries = {}
		binding.entry_arrays = {}
		binding.sizes = {}
		resize_observer_bindings_.delete(owner)
	})
}

fn (runtime &Runtime) resize_observer_element(value voidptr) !&dom.Element {
	target := runtime.native_event_target(value)!
	if target.data.kind != .node {
		return runtime.event_binding_type_error('ResizeObserver requires an Element')
	}
	node := unsafe { &dom.Node(target) }
	return node.as_element() or { return runtime.event_binding_type_error('ResizeObserver requires an Element') }
}

fn (mut runtime Runtime) resize_observer_make(binding &ResizeObserverBinding, kind int) !voidptr {
	return runtime.retain_javascript_value(runtime.call_javascript_function(binding.make,
		C.JSValueMakeUndefined(runtime.context), [C.JSValueMakeNumber(runtime.context, kind)])!)!
}

fn (mut runtime Runtime) resize_observer_array(binding &ResizeObserverBinding, values []voidptr, frozen bool) !voidptr {
	mut exception := unsafe { nil }
	array := C.JSObjectMakeArray(runtime.context, uint(values.len), values.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	if !frozen { return array }
	return runtime.retain_javascript_value(runtime.call_javascript_function(binding.make,
		C.JSValueMakeUndefined(runtime.context), [
			C.JSValueMakeNumber(runtime.context, 3),
			array,
		])!)!
}

fn (mut runtime Runtime) resize_observer_entries(mut binding ResizeObserverBinding, entries []&resizeobserver.ResizeObserverEntry) !voidptr {
	mut values := []voidptr{cap: entries.len}
	for entry in entries {
		wrapper := runtime.resize_observer_make(binding, 1)!
		binding.entries[wrapper] = entry
		mut arrays := []voidptr{cap: 3}
		for sizes in [entry.border_box_size(), entry.content_box_size(),
			entry.device_pixel_content_box_size()] {
			mut items := []voidptr{cap: sizes.len}
			for size in sizes {
				item := runtime.resize_observer_make(binding, 2)!
				binding.sizes[item] = size
				items << item
			}
			arrays << runtime.resize_observer_array(binding, items, true)!
		}
		binding.entry_arrays[wrapper] = arrays
		values << wrapper
	}
	return runtime.resize_observer_array(binding, values, false)
}

fn (mut runtime Runtime) resize_observer_operation(mut binding ResizeObserverBinding, args []voidptr) !voidptr {
	if args.len < 2 { return runtime.event_binding_type_error('Missing ResizeObserver operation') }
	method := runtime.binding_dom_string(args[0])!
	receiver := args[1]
	undefined := C.JSValueMakeUndefined(runtime.context)
	if method == 'string' { return runtime.binding_string(runtime.binding_dom_string(args[2])!) }
	if method == 'element' {
		runtime.resize_observer_element(args[2])!
		return args[2]
	}
	if method == 'construct' {
		callback := runtime.retain_javascript_value(args[2])!
		runtime.retain_javascript_value(receiver)!
		owner := voidptr(&runtime)
		callback_settings := runtime.callback_settings()
		delivery := fn [owner, mut binding, receiver, callback, callback_settings] (entries []&resizeobserver.ResizeObserverEntry, _ &resizeobserver.ResizeObserver) {
			if binding.closed { return }
			mut runtime := unsafe { &Runtime(owner) }
			mut storage := binding.document.native_storage()
			mut allocation_scope := platform.RetainedArenaScope{}
			if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
			defer { allocation_scope.finish() }
			if settings := runtime.scripting_settings_ {
				if html.can_run_script_for_settings(settings) == .do_not_run { return }
			}
			runtime.prepare_html_callback(callback_settings)
			defer { runtime.clean_up_html_callback(callback_settings) }
			defer { runtime.mark_document_state_dirty() }
			records := runtime.resize_observer_entries(mut binding, entries) or {
				runtime.report_event_callback_exception(err)
				return
			}
			runtime.call_javascript_function(callback, receiver, [records, receiver]) or { runtime.report_event_callback_exception(err) }
		}
		runtime.own_closure(voidptr(delivery))
		binding.observers[receiver] = resizeobserver.ResizeObserver.create_for_constructor(binding.document, delivery)
		return undefined
	}
	if method.starts_with('size ') {
		size := binding.sizes[receiver] or { return runtime.event_binding_type_error('Illegal ResizeObserverSize receiver') }
		return match method {
			'size inlineSize' { C.JSValueMakeNumber(runtime.context, size.inline_size()) }
			'size blockSize' { C.JSValueMakeNumber(runtime.context, size.block_size()) }
			else { error('Unknown ResizeObserverSize operation') }
		}
	}
	if method.starts_with('entry ') {
		entry := binding.entries[receiver] or { return runtime.event_binding_type_error('Illegal ResizeObserverEntry receiver') }
		entry_arrays := binding.entry_arrays[receiver] or { return error('Missing ResizeObserverEntry size arrays') }
		return match method {
			'entry target' {
				runtime.javascript_event_target(unsafe { &dom.EventTarget(entry.target().element) }, none)!
			}
			'entry contentRect' { runtime.javascript_read_only_rect(entry.content_rect())! }
			'entry borderBoxSize' { entry_arrays[0] }
			'entry contentBoxSize' { entry_arrays[1] }
			'entry devicePixelContentBoxSize' { entry_arrays[2] }
			else { error('Unknown ResizeObserverEntry operation') }
		}
	}
	mut observer := binding.observers[receiver] or { return runtime.event_binding_type_error('Illegal ResizeObserver receiver') }
	match method {
		'observe', 'unobserve' {
			element := runtime.resize_observer_element(args[2])!
			if synchronize := binding.before_observe { synchronize(runtime)! }
			key := voidptr(element)
			target := binding.targets[key] or {
				value := resizeobserver.ResizeTarget.for_element(element)
				binding.targets[key] = value
				value
			}
			if method == 'observe' {
				box := resizeobserver.resize_observer_box_options_from_string(runtime.binding_dom_string(args[3])!)!
				observer.observe(target, resizeobserver.ResizeObserverOptions{ box: box })
				runtime.mark_document_state_dirty()
			} else {
				observer.unobserve(target)
			}
		}
		'disconnect' { observer.disconnect() }
		'brand' {}
		else { return error('Unknown ResizeObserver operation') }
	}
	return undefined
}
