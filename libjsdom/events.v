module libjsdom

import dom
import libjs
import platform

struct Listener {
	target    &dom.EventTarget
	type_     string
	callback  libjs.Value
	native    &dom.IDLEventListener
	capture   bool
	attribute bool
}

fn (mut host Host) install_events(mut node libjs.Object) ! {
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.event_prototype = prototype
	for name in ['target', 'currentTarget', 'type', 'defaultPrevented'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			event := host.event(mut vm)!
			mut owner := unsafe { &Host(host) }
			if name == 'type' {
				return libjs.Value.from_string(vm.create_string_from_str(event.type_))
			}
			if name == 'defaultPrevented' {
				return libjs.Value.from_bool(event.default_prevented())
			}
			mut event_target := event.target()
			if name == 'currentTarget' { event_target = event.current_target() }
			if target := event_target {
				return owner.wrap_target(target)
			}
			return libjs.js_null()
		}, unsafe { nil })
	}
	for name in ['preventDefault', 'stopPropagation', 'stopImmediatePropagation'] {
		host.method(mut prototype, name, 0, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut event := unsafe { &dom.Event(host.event(mut vm)!) }
			match name {
				'preventDefault' { event.prevent_default() }
				'stopPropagation' { event.set_stop_propagation(true) }
				else {
					event.set_stop_immediate_propagation(true)
					event.set_stop_propagation(true)
				}
			}
			return libjs.js_undefined()
		})
	}
	for name in ['addEventListener', 'removeEventListener'] {
		host.method(mut node, name, 2, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			actual := host.node(mut vm)!
			if vm.argument_count() < 2 {
				return vm.throw_error(.type_error, name + ' requires two arguments')
			}
			type_ := vm.argument(0).to_primitive_string(mut vm)!.str()
			callback := vm.argument(1)
			if callback.is_nullish() { return libjs.js_undefined() }
			if !callback.is_object() {
				return vm.throw_error(.type_error, 'Event listener must be an object')
			}
			options := vm.argument(2)
			mut capture := false
			mut once := false
			mut passive := ?bool(none)
			if options.is_object() {
				object := options.as_object()
				capture = object.get(mut vm, libjs.PropertyName.from_str('capture'))!.to_boolean()
				if name == 'addEventListener' {
					once = object.get(mut vm, libjs.PropertyName.from_str('once'))!.to_boolean()
					value := object.get(mut vm, libjs.PropertyName.from_str('passive'))!
					if !value.is_undefined() { passive = value.to_boolean() }
				}
			} else {
				capture = options.to_boolean()
			}
			mut owner := unsafe { &Host(host) }
			target := unsafe { &dom.EventTarget(actual) }
			if name == 'addEventListener' {
				owner.add_listener(target, type_, callback, dom.AddEventListenerOptions{ capture: capture, once: once, passive: passive }, false)
			} else {
				owner.remove_listener(target, type_, callback, capture)
			}
			return libjs.js_undefined()
		})
	}
	for type_ in ['click', 'input', 'change', 'load'] {
		host.accessor(mut node, 'on' + type_, fn [host, type_] (mut vm libjs.VM) !libjs.Value {
			target := unsafe { &dom.EventTarget(host.node(mut vm)!) }
			for listener in host.listeners {
				if listener.attribute && listener.type_ == type_ && voidptr(listener.target) == voidptr(target) {
					return listener.callback
				}
			}
			return libjs.js_null()
		}, fn [host, type_] (mut vm libjs.VM) !libjs.Value {
			target := unsafe { &dom.EventTarget(host.node(mut vm)!) }
			mut owner := unsafe { &Host(host) }
			for index := owner.listeners.len - 1; index >= 0; index-- {
				listener := owner.listeners[index]
				if listener.attribute && listener.type_ == type_ && voidptr(listener.target) == voidptr(target) {
					owner.listeners.delete(index)
				}
			}
			target.set_event_handler_attribute(type_, none)
			value := vm.argument(0)
			if value.is_function() {
				owner.add_listener(target, type_, value, dom.AddEventListenerOptions{}, true)
			}
			return libjs.js_undefined()
		})
	}
}

fn (mut host Host) wrap_target(target &dom.EventTarget) libjs.Value {
	if target.data.kind == .node { return host.wrap_node(unsafe { &dom.Node(target) }) }
	if target.data.kind == .window {
		return libjs.Value.from_object(host.realm.global_object_record())
	}
	return libjs.js_null()
}

fn (host &Host) event(mut vm libjs.VM) !&dom.Event {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if event := host.events[voidptr(vm.this_value().as_object())] { return event }
	}
	return vm.throw_error(.type_error, 'Event method called on incompatible receiver')
}

fn (mut host Host) wrap_event(event &dom.Event) libjs.Value {
	if object := host.event_wrappers[voidptr(event)] { return libjs.Value.from_object(object) }
	mut object := libjs.Object.create(host.realm, host.event_prototype)
	object.class_name = 'Event'
	host.events[voidptr(object)] = event
	host.event_wrappers[voidptr(event)] = object
	return libjs.Value.from_object(object)
}

fn (mut host Host) add_listener(target &dom.EventTarget, type_ string, callback libjs.Value, options dom.AddEventListenerOptions, attribute bool) {
	if !attribute {
		for listener in host.listeners {
			if !listener.attribute && voidptr(listener.target) == voidptr(target) && listener.type_ == type_
				&& listener.capture == options.capture && libjs.is_strictly_equal(listener.callback, callback) {
				return
			}
		}
	}
	invoke := fn [host, callback, target, type_, options, attribute] (event &dom.Event, current ?&dom.EventTarget) !dom.JSValue {
		if host.closed || host.document.has_been_destroyed() || !host.document.as_node().is_scripting_enabled() {
			return dom.js_undefined()
		}
		if permitted := host.hooks.can_run_callback {
			if !permitted() { return dom.js_undefined() }
		}
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		if before := host.hooks.before_callback { before() }
		defer { if after := host.hooks.after_callback { after() } }
		mut owner := unsafe { &Host(host) }
		if options.once && !attribute {
			owner.remove_listener(target, type_, callback, options.capture)
		}
		mut vm := host.vm
		mut function := callback
		mut receiver := if current_target := current {
			owner.wrap_target(current_target)
		} else {
			libjs.js_undefined()
		}
		if !callback.is_function() {
			function = callback.as_object().get(mut vm, libjs.PropertyName.from_str('handleEvent'))!
			receiver = callback
		}
		value := vm.call_with_limits(function, receiver, [owner.wrap_event(event)], libjs.ExecutionLimits{ max_instructions: 1000000 })!
		return if value.is_boolean() { dom.js_bool(value.as_bool()) } else { dom.js_undefined() }
	}
	report := fn [host] (err IError) {
		if callback := host.hooks.exception { callback(exception_message(err)) }
	}
	host.closures << voidptr(invoke)
	host.closures << voidptr(report)
	native := dom.IDLEventListener.create(&dom.CallbackType{ handle_event_with_exception: invoke, report_exception: report, callback_identity_: voidptr(callback.as_object()) })
	if attribute {
		target.set_event_handler_attribute(type_, native.callback())
	} else {
		target.add_event_listener(type_, native, options)
	}
	host.listeners << Listener{ target: target, type_: type_.clone(), callback: callback, native: native, capture: options.capture, attribute: attribute }
}

fn (mut host Host) remove_listener(target &dom.EventTarget, type_ string, callback libjs.Value, capture bool) {
	for index, listener in host.listeners {
		if !listener.attribute && listener.type_ == type_ && listener.capture == capture
			&& voidptr(listener.target) == voidptr(target) && libjs.is_strictly_equal(listener.callback, callback) {
			target.remove_event_listener(type_, listener.native, dom.EventListenerOptions{ capture: capture })
			host.listeners.delete(index)
			return
		}
	}
}
