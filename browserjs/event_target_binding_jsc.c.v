// DOM native records and WebIDL callback objects stay in their owning JSC realm.
@[has_globals]
module browserjs

import platform
import dom
import html
import highresolutiontime
import libjs
import webidl


fn C.JSValueIsBoolean(context voidptr, value voidptr) bool
fn C.JSValueIsNumber(context voidptr, value voidptr) bool
fn C.vox_jsc_JSValueToNumber(context voidptr, value voidptr, exception &voidptr) f64

pub struct EventWrapperProvider {
pub:
	owner  voidptr
	@[required]
	create fn (&dom.Event) !voidptr
}

// Resolve compact DOM facades before allocating a bare EventTarget wrapper.
// The owner installs this hook without changing EventTarget's DOM algorithms.
pub struct EventTargetWrapperProvider {
pub:
	owner  voidptr
	@[required]
	create fn (&dom.EventTarget) !voidptr
}

@[heap]
struct EventTargetBinding {
mut:
	targets            map[voidptr]&dom.EventTarget
	target_wrappers    map[voidptr]voidptr
	events             map[voidptr]&dom.Event
	event_wrappers     map[voidptr]voidptr
	callbacks          map[voidptr]voidptr
	providers          []EventWrapperProvider
	target_providers   []EventTargetWrapperProvider
	factory            voidptr
	define_trusted     voidptr
	event_constructor  voidptr
	ui_event_constructor voidptr
	ui_event_prototype voidptr
	keyboard_event_prototype voidptr
	mouse_event_prototype voidptr
	mouse_event_constructor voidptr
	pointer_event_prototype voidptr
	pointer_event_sequence_converter voidptr
	wheel_event_prototype voidptr
	drag_event_prototype voidptr
	track_event_prototype voidptr
	form_data_event_prototype voidptr
	data_transfer_factory voidptr
	data_transfer_prototype voidptr
	data_transfer_constructor voidptr
	data_transfer_freeze_array voidptr
	data_transfer_types_arrays map[voidptr]DataTransferTypesArray
	data_transfers map[voidptr]&html.DataTransfer
	data_transfer_wrappers map[voidptr]voidptr
	data_transfer_item_binding &DataTransferItemsBinding = unsafe { nil }
	file_system_entry_binding &FileSystemEntryBinding = unsafe { nil }
	closed             bool
}

__global event_target_bindings_ = map[voidptr]&EventTargetBinding{}

fn (runtime &Runtime) event_binding() !&EventTargetBinding {
	return event_target_bindings_[voidptr(runtime)] or {
		return error('Native EventTarget binding is not installed')
	}
}

fn (runtime &Runtime) event_binding_type_error(message string) IError {
	return runtime.actual_javascript_exception(runtime.binding_exception_value(error(
		'TypeError: ' + message)))
}

pub fn (mut runtime Runtime) install_event_target_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if binding := event_target_bindings_[owner] {
		if binding.ui_event_prototype == unsafe { nil } {
			if settings := runtime.scripting_settings_ {
				if settings.global_object().data.kind == .window {
					runtime.install_ui_event_binding()!
				}
			}
		}
		if binding.mouse_event_prototype == unsafe { nil } && binding.ui_event_prototype != unsafe { nil } {
			runtime.install_mouse_event_binding()!
		}
		if binding.keyboard_event_prototype == unsafe { nil } && binding.ui_event_prototype != unsafe { nil } {
			runtime.install_keyboard_event_binding()!
		}
		if binding.pointer_event_prototype == unsafe { nil } && binding.mouse_event_prototype != unsafe { nil } {
			runtime.install_pointer_event_binding()!
		}
		if binding.wheel_event_prototype == unsafe { nil } && binding.mouse_event_prototype != unsafe { nil } {
			runtime.install_wheel_event_binding()!
		}
		if binding.drag_event_prototype == unsafe { nil } && binding.mouse_event_prototype != unsafe { nil } {
			runtime.install_drag_event_binding()!
		}
		if binding.track_event_prototype == unsafe { nil } && binding.ui_event_prototype != unsafe { nil } {
			runtime.install_track_event_binding()!
		}
		if binding.data_transfer_constructor == unsafe { nil } && binding.ui_event_prototype != unsafe { nil } {
			runtime.install_data_transfer_binding()!
		}
		return
	}
	runtime.install_dom_exception_binding()!
	mut binding := &EventTargetBinding{}
	event_target_bindings_[owner] = binding
	runtime.define_value_host_function('__ladybirdEvent', fn [owner] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len < 2 {
			return runtime.event_binding_type_error('Missing internal Event binding arguments')
		}
		method := runtime.binding_dom_string(args[0])!
		return runtime.event_binding_call(method, args[1], args[2..])
	})!
	runtime.evaluate_host(event_target_bootstrap())!
	binding.factory = runtime.evaluate_host_value('__ladybirdEventFactory')!
	binding.define_trusted = runtime.evaluate_host_value('__ladybirdEventDefineTrusted')!
	binding.event_constructor = runtime.evaluate_host_value('Event')!
	runtime.retain_javascript_value(binding.factory)!
	runtime.retain_javascript_value(binding.define_trusted)!
	if settings := runtime.scripting_settings_ {
		if settings.global_object().data.kind == .window {
			runtime.install_ui_event_binding()!
			runtime.install_keyboard_event_binding()!
			runtime.install_mouse_event_binding()!
			runtime.install_pointer_event_binding()!
			runtime.install_wheel_event_binding()!
			runtime.install_drag_event_binding()!
			runtime.install_track_event_binding()!
			runtime.install_data_transfer_binding()!
		}
	}
	runtime.add_close_handler(fn [owner, mut binding] () {
		binding.closed = true
		// Closed callbacks return before reaching these records. Dropping them
		// keeps a callback that outlives the runtime from retaining its targets.
		for provider in binding.providers { platform.release_closure(voidptr(provider.create)) }
		for provider in binding.target_providers { platform.release_closure(voidptr(provider.create)) }
		// Clearing in place would leave the old entries in the buffers that
		// the collector still scans.
		binding.providers = []EventWrapperProvider{}
		binding.target_providers = []EventTargetWrapperProvider{}
		binding.targets = map[voidptr]&dom.EventTarget{}
		binding.target_wrappers = map[voidptr]voidptr{}
		binding.events = map[voidptr]&dom.Event{}
		binding.event_wrappers = map[voidptr]voidptr{}
		binding.callbacks = map[voidptr]voidptr{}
		binding.data_transfers = {}
		binding.data_transfer_wrappers = {}
		binding.data_transfer_types_arrays = {}
		if binding.file_system_entry_binding != unsafe { nil } {
			mut entries := binding.file_system_entry_binding
			entries.entries = {}
			entries.wrappers = {}
		}
		if binding.data_transfer_item_binding != unsafe { nil } {
			mut items := binding.data_transfer_item_binding
			items.items = {}
			items.item_wrappers = {}
			items.lists = {}
			items.list_wrappers = {}
			// Runtime.close unprotects the pending callback values before it
			// releases the engine context; already queued tasks observe closed.
			items.string_callbacks = {}
		}
		event_target_bindings_.delete(owner)
	})
	if settings := runtime.scripting_settings_ {
		if document := settings.responsible_document() {
			mut mutable_document := unsafe { &dom.Document(document) }
			mutable_document.set_event_callback_exception_reporter(fn [owner, binding] (exception IError) {
				if binding.closed { return }
				mut runtime := unsafe { &Runtime(owner) }
				runtime.report_event_callback_exception(exception)
			})
			runtime.install_window_event_handler_compiler(document)!
		}
	}
}

pub fn (mut runtime Runtime) bind_event_target(wrapper voidptr, target &dom.EventTarget) ! {
	mut binding := runtime.event_binding()!
	if !C.JSValueIsObject(runtime.context, wrapper) {
		return runtime.event_binding_type_error('EventTarget wrapper is not an object')
	}
	if existing := binding.target_wrappers[voidptr(target)] {
		if existing != wrapper {
			return runtime.event_binding_type_error('EventTarget already has an owning wrapper')
		}
	}
	binding.targets[wrapper] = target
	binding.target_wrappers[voidptr(target)] = wrapper
	runtime.retain_javascript_value(wrapper)!
}

pub fn (mut runtime Runtime) javascript_event_target(target &dom.EventTarget, prototype ?voidptr) !voidptr {
	binding := runtime.event_binding()!
	if wrapper := binding.target_wrappers[voidptr(target)] { return wrapper }
	for provider in binding.target_providers {
		wrapper := provider.create(target)!
		if wrapper == unsafe { nil } { continue }
		if existing := binding.targets[wrapper] {
			if voidptr(existing) != voidptr(target) {
				return runtime.event_binding_type_error('EventTarget provider returned another owner')
			}
		} else {
			runtime.bind_event_target(wrapper, target)!
		}
		return wrapper
	}
	wrapper := runtime.call_javascript_function(binding.factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		runtime.binding_string('target'),
		prototype or { C.vox_jsc_JSValueMakeNull(runtime.context) },
	])!
	runtime.bind_event_target(wrapper, target)!
	return wrapper
}

pub fn (mut runtime Runtime) install_event_target_wrapper_provider(provider EventTargetWrapperProvider) ! {
	mut binding := runtime.event_binding()!
	binding.target_providers = binding.target_providers.filter(it.owner != provider.owner)
	binding.target_providers << provider
}

pub fn (runtime &Runtime) native_event_target(wrapper voidptr) !&dom.EventTarget {
	binding := runtime.event_binding()!
	return binding.targets[wrapper] or {
		return runtime.event_binding_type_error('Illegal EventTarget receiver')
	}
}

pub fn (mut runtime Runtime) bind_event(wrapper voidptr, event &dom.Event) ! {
	mut binding := runtime.event_binding()!
	if !C.JSValueIsObject(runtime.context, wrapper) {
		return runtime.event_binding_type_error('Event wrapper is not an object')
	}
	if existing := binding.event_wrappers[voidptr(event)] {
		if existing != wrapper {
			return runtime.event_binding_type_error('Event already has an owning wrapper')
		}
		return
	}
	runtime.retain_javascript_value(wrapper)!
	runtime.call_javascript_function(binding.define_trusted, C.vox_jsc_JSValueMakeUndefined(runtime.context), [wrapper])!
	binding.events[wrapper] = event
	binding.event_wrappers[voidptr(event)] = wrapper
}

pub fn (mut runtime Runtime) install_event_wrapper_provider(provider EventWrapperProvider) ! {
	mut binding := runtime.event_binding()!
	binding.providers = binding.providers.filter(it.owner != provider.owner)
	binding.providers << provider
}

pub fn (mut runtime Runtime) javascript_event(event &dom.Event) !voidptr {
	binding := runtime.event_binding()!
	if wrapper := binding.event_wrappers[voidptr(event)] { return wrapper }
	for provider in binding.providers {
		wrapper := provider.create(event)!
		if wrapper != unsafe { nil } {
			runtime.bind_event(wrapper, event)!
			return wrapper
		}
	}
	mut prototype := C.vox_jsc_JSValueMakeNull(runtime.context)
	if binding.pointer_event_prototype != unsafe { nil } && event.interface_ == .pointer_event {
		prototype = binding.pointer_event_prototype
	} else if binding.wheel_event_prototype != unsafe { nil } && event.interface_ == .wheel_event {
		prototype = binding.wheel_event_prototype
	} else if binding.drag_event_prototype != unsafe { nil } && event.interface_ == .drag_event {
		prototype = binding.drag_event_prototype
	} else if binding.track_event_prototype != unsafe { nil } && event.interface_ == .track_event {
		prototype = binding.track_event_prototype
	} else if binding.form_data_event_prototype != unsafe { nil } && event.interface_ == .form_data_event {
		prototype = binding.form_data_event_prototype
	} else if binding.mouse_event_prototype != unsafe { nil } && native_event_is_mouse_event(event) {
		prototype = binding.mouse_event_prototype
	} else if binding.keyboard_event_prototype != unsafe { nil } && event.interface_ == .keyboard_event {
		prototype = binding.keyboard_event_prototype
	} else if binding.ui_event_prototype != unsafe { nil } && native_event_is_ui_event(event) {
		prototype = binding.ui_event_prototype
	}
	wrapper := runtime.call_javascript_function(binding.factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		runtime.binding_string(if event.interface_ == .before_unload_event {
			'beforeunload'
		} else {
			'event'
		}),
		prototype,
	])!
	runtime.bind_event(wrapper, event)!
	return wrapper
}

pub fn (runtime &Runtime) native_event(wrapper voidptr) !&dom.Event {
	binding := runtime.event_binding()!
	return binding.events[wrapper] or {
		return runtime.event_binding_type_error('Illegal Event receiver')
	}
}

fn (runtime &Runtime) event_binding_bool_property(value voidptr, property string, fallback bool) !bool {
	if C.JSValueIsUndefined(runtime.context, value) || C.JSValueIsNull(runtime.context, value) {
		return fallback
	}
	if !C.JSValueIsObject(runtime.context, value) {
		return runtime.event_binding_type_error('Event options must be a dictionary')
	}
	member := runtime.binding_property(value, property)!
	return if C.JSValueIsUndefined(runtime.context, member) {
		fallback
	} else {
		C.JSValueToBoolean(runtime.context, member)
	}
}

fn (runtime &Runtime) event_binding_options(value voidptr, add bool) !dom.AddEventListenerOptions {
	if !C.JSValueIsObject(runtime.context, value) && !C.JSValueIsUndefined(runtime.context, value)
		&& !C.JSValueIsNull(runtime.context, value) {
		return dom.AddEventListenerOptions{
			capture: C.JSValueToBoolean(runtime.context, value)
		}
	}
	mut options := dom.AddEventListenerOptions{}
	// Dictionary members are converted in lexicographic order by WebIDL.
	options.capture = runtime.event_binding_bool_property(value, 'capture', false)!
	if !add { return options }
	options.once = runtime.event_binding_bool_property(value, 'once', false)!
	if C.JSValueIsObject(runtime.context, value) {
		passive := runtime.binding_property(value, 'passive')!
		if !C.JSValueIsUndefined(runtime.context, passive) {
			options.passive = C.JSValueToBoolean(runtime.context, passive)
		}
		signal := runtime.binding_property(value, 'signal')!
		if !C.JSValueIsUndefined(runtime.context, signal) {
			if !C.JSValueIsObject(runtime.context, signal) {
				return runtime.event_binding_type_error('signal must be an AbortSignal')
			}
			target := runtime.native_event_target(signal)!
			if target.data.kind != .abort_signal {
				return runtime.event_binding_type_error('signal must be an AbortSignal')
			}
			options.signal = unsafe { &dom.AbortSignal(target) }
		}
	}
	return options
}

fn (mut runtime Runtime) event_callback_result(value voidptr) !dom.JSValue {
	if C.JSValueIsUndefined(runtime.context, value) { return dom.js_undefined() }
	if C.JSValueIsNull(runtime.context, value) { return dom.js_null() }
	if C.JSValueIsBoolean(runtime.context, value) {
		return dom.js_bool(C.JSValueToBoolean(runtime.context, value))
	}
	return dom.js_webidl_value(runtime.webidl_value(value)!)
}

fn (mut runtime Runtime) report_event_callback_exception(exception IError) {
	if settings := runtime.scripting_settings_ {
		mut actual := unsafe { nil }
		if exception is JavaScriptValueException {
			actual = exception.value
		} else {
			actual = runtime.binding_exception_value(exception)
		}
		value := runtime.webidl_value(actual) or { return }
		settings.report_an_exception(dom.js_webidl_value(value), false)
	}
}

fn (mut runtime Runtime) event_callback(value voidptr, handler bool) !&dom.CallbackType {
	return runtime.event_callback_with_settings(value, handler, runtime.callback_settings())
}

fn (mut runtime Runtime) event_callback_with_settings(value voidptr, handler bool, stored_settings ?&html.EnvironmentSettingsObject) !&dom.CallbackType {
	if C.JSValueIsUndefined(runtime.context, value) || C.JSValueIsNull(runtime.context, value) {
		return unsafe { nil }
	}
	if !C.JSValueIsObject(runtime.context, value) {
		if handler { return unsafe { nil } }
		return runtime.event_binding_type_error('EventListener must be an object')
	}
	// LegacyTreatNonObjectAsNull retains any object without an IsCallable check.
	runtime.retain_javascript_value(value)!
	owner := voidptr(&runtime)
	binding := runtime.event_binding()!
	mut window := ?&dom.Window(none)
	if settings := runtime.scripting_settings_ {
		if document := settings.responsible_document() { window = document.get_window() }
	}
	callback := &dom.CallbackType{
		callback_identity_:          value
		associated_window:           window
		report_exception: fn [owner, binding] (exception IError) {
			if binding.closed { return }
			mut runtime := unsafe { &Runtime(owner) }
			runtime.report_event_callback_exception(exception)
		}
		handle_event_with_exception: fn [owner, value, handler, stored_settings, binding] (event &dom.Event, current_target ?&dom.EventTarget) !dom.JSValue {
			if binding.closed { return dom.js_undefined() }
			mut runtime := unsafe { &Runtime(owner) }
			// WebIDL callback invocation returns undefined for non-callable legacy
			// handlers before entering script/callback contexts or reading handleEvent.
			if handler && !C.JSObjectIsFunction(runtime.context, value) {
				return dom.js_undefined()
			}
			if settings := runtime.scripting_settings_ {
				if html.can_run_script_for_settings(settings) == .do_not_run {
					return dom.js_undefined()
				}
			}
			runtime.prepare_html_callback(stored_settings)
			defer { runtime.clean_up_html_callback(stored_settings) }
			defer { runtime.mark_document_state_dirty() }
			return runtime.invoke_event_callback(value, handler, event, current_target)
		}
	}
	mut mutable_binding := unsafe { &EventTargetBinding(binding) }
	mutable_binding.callbacks[voidptr(callback)] = value
	return callback
}

fn (mut runtime Runtime) invoke_event_callback(value voidptr, handler bool, event &dom.Event, current_target ?&dom.EventTarget) !dom.JSValue {
	mut function := unsafe { value }
	mut receiver := C.vox_jsc_JSValueMakeUndefined(runtime.context)
	if C.JSObjectIsFunction(runtime.context, value) {
		if target := current_target { receiver = runtime.javascript_event_target(target, none)! }
	} else {
		function = runtime.binding_property(value, 'handleEvent')!
		if !C.JSValueIsObject(runtime.context, function)
			|| !C.JSObjectIsFunction(runtime.context, function) {
			return runtime.event_binding_type_error('EventListener.handleEvent is not callable')
		}
		receiver = value
	}
	mut call_arguments := []voidptr{}
	if handler && dom.event_uses_special_error_event_handling(event) {
		error_event := unsafe { &dom.ErrorEvent(event) }
		call_arguments = [
			runtime.binding_string(error_event.message()),
			runtime.binding_string(error_event.filename()),
			C.vox_jsc_JSValueMakeNumber(runtime.context, error_event.lineno()),
			C.vox_jsc_JSValueMakeNumber(runtime.context, error_event.colno()),
			runtime.event_callback_argument(error_event.error())!,
		]
	} else {
		call_arguments = [runtime.javascript_event(event)!]
	}
	result := runtime.call_javascript_function(function, receiver, call_arguments)!
	return runtime.event_callback_result(result)
}

fn (mut runtime Runtime) event_callback_argument(value dom.JSValue) !voidptr {
	native := value.as_webidl_value()!
	if native.dom_exception_ != none { return runtime.javascript_dom_exception(native) }
	return match native.kind {
		.undefined { C.vox_jsc_JSValueMakeUndefined(runtime.context) }
		.null_ { C.vox_jsc_JSValueMakeNull(runtime.context) }
		.boolean { C.vox_jsc_JSValueMakeBoolean(runtime.context, native.boolean_value) }
		.number { C.vox_jsc_JSValueMakeNumber(runtime.context, native.number_value) }
		.string_ { runtime.binding_string(native.string_value) }
		.runtime_value { runtime.actual_webidl_value(native)! }
		else { return error('Event value has no owning JavaScript object') }
	}
}

pub fn (runtime &Runtime) javascript_event_handler(target &dom.EventTarget, name string) !voidptr {
	binding := runtime.event_binding()!
	callback := target.event_handler_attribute(name) or {
		return C.vox_jsc_JSValueMakeNull(runtime.context)
	}
	return binding.callbacks[voidptr(callback)] or {
		return runtime.event_binding_type_error('Event handler has no owning JavaScript callback')
	}
}

pub fn (mut runtime Runtime) set_javascript_event_handler(target &dom.EventTarget, name string, value voidptr) ! {
	callback := runtime.event_callback(value, true)!
	target.set_event_handler_attribute(name, if callback != unsafe { nil } {
		?&dom.CallbackType(callback)
	} else {
		none
	})
}

fn (mut runtime Runtime) event_binding_call(method string, receiver voidptr, args []voidptr) !voidptr {
	context := runtime.context
	if method == 'constructTarget' {
		target := dom.EventTarget.construct_impl()!
		runtime.bind_event_target(receiver, target)!
		return C.vox_jsc_JSValueMakeUndefined(context)
	}
	if method == 'constructEvent' {
		type_ := runtime.binding_dom_string(args[0])!
		init := dom.EventInit{
			bubbles:    runtime.event_binding_bool_property(args[1], 'bubbles', false)!
			cancelable: runtime.event_binding_bool_property(args[1], 'cancelable', false)!
			composed:   runtime.event_binding_bool_property(args[1], 'composed', false)!
		}
		mut event := dom.Event.construct_impl(type_, init)!
		if settings := runtime.scripting_settings_ {
			event.set_time_stamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
				time_origin:                      settings.time_origin()
				cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
			}))
		}
		runtime.bind_event(receiver, event)!
		return C.vox_jsc_JSValueMakeUndefined(context)
	}
	if method in ['add', 'remove', 'dispatch'] {
		target := runtime.native_event_target(receiver)!
		if method == 'dispatch' {
			event := runtime.native_event(args[0])!
			result := target.dispatch_event_binding(event) or {
				if err.msg().starts_with('InvalidStateError:') {
					actual := runtime.javascript_dom_exception(webidl.dom_exception_value(webidl.DOMException.create('InvalidStateError',
						err.msg().all_after('InvalidStateError: '))))!
					return runtime.actual_javascript_exception(actual)
				}
				return err
			}
			return C.vox_jsc_JSValueMakeBoolean(context, result)
		}
		type_ := runtime.binding_dom_string(args[0])!
		callback := runtime.event_callback(args[1], false)!
		mut listener := ?&dom.IDLEventListener(none)
		if callback != unsafe { nil } { listener = dom.IDLEventListener.create(callback) }
		options := runtime.event_binding_options(args[2], method == 'add')!
		if method == 'add' {
			target.add_event_listener(type_, listener, options)
		} else {
			target.remove_event_listener(type_, listener, dom.EventListenerOptions{
				capture: options.capture
			})
		}
		return C.vox_jsc_JSValueMakeUndefined(context)
	}
	mut event := runtime.native_event(receiver)!
	if method in ['getBeforeUnloadReturnValue', 'setBeforeUnloadReturnValue'] {
		if event.interface_ != .before_unload_event {
			return runtime.event_binding_type_error('Illegal BeforeUnloadEvent receiver')
		}
		mut before_unload := unsafe { &dom.BeforeUnloadEvent(event) }
		if method == 'getBeforeUnloadReturnValue' {
			return runtime.binding_string(before_unload.return_value())
		}
		before_unload.set_return_value(runtime.binding_dom_string(args[0])!)
		return C.vox_jsc_JSValueMakeUndefined(context)
	}
	if method == 'getEvent' {
		property := runtime.binding_dom_string(args[0])!
		return match property {
			'type' {
				if event.interface_ == .track_event {
					runtime.binding_utf16_string(libjs.utf16_string_from_utf8_without_validation(event.type_name()))!
				} else {
					runtime.binding_string(event.type_name())
				}
			}
			'target', 'srcElement', 'currentTarget' {
				target := if property == 'currentTarget' {
					event.current_target_for_bindings()
				} else {
					event.target()
				}
				if native := target {
					runtime.javascript_event_target(native, none)!
				} else {
					C.vox_jsc_JSValueMakeNull(context)
				}
			}
			'eventPhase' {
				C.vox_jsc_JSValueMakeNumber(context, event.event_phase())
			}
			'timeStamp' {
				C.vox_jsc_JSValueMakeNumber(context, event.time_stamp())
			}
			'bubbles' {
				C.vox_jsc_JSValueMakeBoolean(context, event.bubbles())
			}
			'cancelable' {
				C.vox_jsc_JSValueMakeBoolean(context, event.cancelable())
			}
			'composed' {
				C.vox_jsc_JSValueMakeBoolean(context, event.composed())
			}
			'isTrusted' {
				C.vox_jsc_JSValueMakeBoolean(context, event.is_trusted())
			}
			'defaultPrevented' {
				C.vox_jsc_JSValueMakeBoolean(context, event.default_prevented())
			}
			'cancelBubble' {
				C.vox_jsc_JSValueMakeBoolean(context, event.cancel_bubble())
			}
			'returnValue' {
				C.vox_jsc_JSValueMakeBoolean(context, event.return_value())
			}
			else {
				return runtime.event_binding_type_error('Unknown Event attribute')
			}
		}
	}
	match method {
		'setEvent' {
			property := runtime.binding_dom_string(args[0])!
			value := C.JSValueToBoolean(context, args[1])
			if property == 'cancelBubble' {
				event.set_cancel_bubble(value)
			} else if property == 'returnValue' {
				event.set_return_value(value)
			} else {
				return runtime.event_binding_type_error('Unknown Event setter')
			}
		}
		'stopPropagation' {
			event.stop_propagation()
		}
		'stopImmediatePropagation' {
			event.stop_immediate_propagation()
		}
		'preventDefault' {
			event.prevent_default()
		}
		'initEvent' {
			event.init_event(runtime.binding_dom_string(args[0])!, C.JSValueToBoolean(context,
				args[1]), C.JSValueToBoolean(context, args[2]))
		}
		'composedPath' {
			mut values := []voidptr{}
			for target in event.composed_path() {
				values << runtime.javascript_event_target(target, none)!
			}
			mut exception := unsafe { nil }
			array := C.vox_jsc_JSObjectMakeArray(context, uint(values.len), values.data, &exception)
			if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
			return array
		}
		else {
			return runtime.event_binding_type_error('Unknown Event operation')
		}
	}

	return C.vox_jsc_JSValueMakeUndefined(context)
}
