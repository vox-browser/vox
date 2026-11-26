// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs

type TargetReceiver = fn (mut libjs.VM) !&dom.EventTarget

fn (mut host Host) install_target_event_handler(mut prototype libjs.Object, name string, type_ string, receiver TargetReceiver) {
	host.closures << voidptr(receiver)
	host.accessor(mut prototype, name, fn [host, type_, receiver] (mut vm libjs.VM) !libjs.Value {
		target := receiver(mut vm)!
		for listener in host.listeners {
			if listener.attribute && listener.type_ == type_ && voidptr(listener.target) == voidptr(target) { return listener.callback }
		}
		return libjs.js_null()
	}, fn [host, type_, receiver] (mut vm libjs.VM) !libjs.Value {
		target := receiver(mut vm)!
		mut owner := unsafe { &Host(host) }
		for index := owner.listeners.len - 1; index >= 0; index-- {
			listener := owner.listeners[index]
			if listener.attribute && listener.type_ == type_ && voidptr(listener.target) == voidptr(target) { owner.listeners.delete(index) }
		}
		target.set_event_handler_attribute(type_, none)
		if vm.argument(0).is_function() { owner.add_listener(target, type_, vm.argument(0), dom.AddEventListenerOptions{}, true) }
		return libjs.js_undefined()
	})
}
