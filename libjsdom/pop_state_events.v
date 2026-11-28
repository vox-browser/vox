// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (host &Host) pop_state_event_receiver(mut vm libjs.VM) !&dom.PopStateEvent {
	event := host.event(mut vm)!
	if event.interface_ != .pop_state_event {
		return vm.throw_error(.type_error, 'Expected PopStateEvent')
	}
	return unsafe { &dom.PopStateEvent(event) }
}

fn (mut host Host) install_pop_state_events() ! {
	mut prototype := libjs.Object.create(host.realm, host.event_prototype)
	host.pop_state_event_prototype = prototype
	host.register_event_interface(mut prototype, 'PopStateEvent', 'Event', fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'PopStateEvent requires a type') }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		type_ := vm.argument(0).to_primitive_string(mut vm)!.str()
		options := vm.argument(1)
		if !options.is_nullish() && !options.is_object() {
			return vm.throw_error(.type_error, 'PopStateEventInit must be a dictionary')
		}
		bubbles := text_encoding_member(mut vm, options, 'bubbles')!.to_boolean()
		cancelable := text_encoding_member(mut vm, options, 'cancelable')!.to_boolean()
		composed := text_encoding_member(mut vm, options, 'composed')!.to_boolean()
		transition := text_encoding_member(mut vm, options, 'hasUAVisualTransition')!.to_boolean()
		state := text_encoding_member(mut vm, options, 'state')!
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		mut owner := unsafe { &Host(host) }
		native := dom.PopStateEvent.create(type_, dom.PopStateEventInit{
			EventInit: dom.EventInit{bubbles: bubbles, cancelable: cancelable, composed: composed}
			has_ua_visual_transition: transition
			state: owner.native_abort_reason(if state.is_undefined() { libjs.js_null() } else { state })
		})
		mut object := libjs.Object.create(host.realm, if parent.is_object() { parent.as_object() } else { host.pop_state_event_prototype })
		return owner.register_event_wrapper(mut object, unsafe { &dom.Event(native) }).as_object()
	})!

	host.accessor(mut prototype, 'state', fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.pop_state_event_receiver(mut vm)!
		state := native.state()
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		if raw := state.native_value_ {
			if raw.runtime_value_ != none { return owner.abort_reason_value(mut vm, raw) }
		}
		if saved := owner.pop_state_values[voidptr(native)] { return saved }
		current := owner.document.history().state
		value := if state.is_structured_object() && current.object_data == state.object_data {
			mut binding := owner.native_history(mut vm)!
			owner.history_state_value(mut vm, mut binding, state)!
		} else {
			mut clone := HistoryClone{host: owner}
			clone.reconstruct(mut vm, state, 0) or { return owner.dom_error(mut vm, err) }
		}
		owner.pop_state_values[voidptr(native)] = value
		return value
	}, unsafe { nil })
	host.accessor(mut prototype, 'hasUAVisualTransition', fn [host] (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_bool(host.pop_state_event_receiver(mut vm)!.has_ua_visual_transition)
	}, unsafe { nil })
}
