// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform

fn scroll_options(mut vm libjs.VM) !html.ScrollToOptions {
	if vm.argument_count() >= 2 {
		x := vm.argument(0).to_number(mut vm)!.number
		y := vm.argument(1).to_number(mut vm)!.number
		return html.ScrollToOptions{ left: x, top: y }
	}
	value := vm.argument(0)
	if value.is_nullish() { return html.ScrollToOptions{} }
	if !value.is_object() {
		return vm.throw_error(.type_error, 'ScrollToOptions must be a dictionary')
	}
	object := value.as_object()
	behavior_value := object.get(mut vm, libjs.PropertyName.from_str('behavior'))!
	mut behavior := html.WindowScrollBehavior.auto_
	if !behavior_value.is_undefined() {
		text := behavior_value.to_primitive_string(mut vm)!.str()
		behavior = match text {
			'auto' { .auto_ }
			'instant' { .instant }
			'smooth' { .smooth }
			else { return vm.throw_error(.type_error, 'Invalid ScrollBehavior') }
		}
	}
	left := object.get(mut vm, libjs.PropertyName.from_str('left'))!
	x := if left.is_undefined() { ?f64(none) } else { ?f64(left.to_number(mut vm)!.number) }
	top := object.get(mut vm, libjs.PropertyName.from_str('top'))!
	y := if top.is_undefined() { ?f64(none) } else { ?f64(top.to_number(mut vm)!.number) }
	return html.ScrollToOptions{ behavior: behavior, left: x, top: y }
}

fn (mut host Host) window_scroll(mut vm libjs.VM, name string) !libjs.Value {
	host.window_receiver(mut vm)!
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	options := scroll_options(mut vm)!
	mut window := host.frame_window(mut vm)!
	native := if name == 'scrollBy' { window.scroll_by(options) } else { window.scroll(options) }
	host.changed()
	return host.wrap_scroll_promise(mut vm, native)
}

fn (mut host Host) wrap_scroll_promise(mut vm libjs.VM, native &dom.Promise) !libjs.Value {
	if promise := native.webidl_promise() { return host.wrap_stream_promise(mut vm, promise) }
	capability := libjs.new_promise_capability(mut vm, libjs.Value.from_object(host.realm.promise_constructor_record()))!
	if native.state() == .pending {
		return vm.throw_error(.internal_error, 'Native scroll promise has no owning realm')
	}
	result := if native.state() == .rejected {
		host.abort_reason_value(mut vm, native.result().as_webidl_value()!)!
	} else {
		libjs.js_undefined()
	}
	libjs.call(mut vm, if native.state() == .rejected {
		capability.reject
	} else {
		capability.resolve
	}, libjs.js_undefined(), [result])!
	return capability.promise
}

fn (host &Host) reject_scroll_promise(mut vm libjs.VM, err IError) !libjs.Value {
	if !libjs.is_throw_completion(err) { return err }
	capability := libjs.new_promise_capability(mut vm, libjs.Value.from_object(host.realm.promise_constructor_record()))!
	libjs.call(mut vm, capability.reject, libjs.js_undefined(), [libjs.thrown_value(err)])!
	return capability.promise
}

fn (mut host Host) install_scroll_methods(mut receiver libjs.Object, viewport bool) {
	for name in ['scroll', 'scrollTo', 'scrollBy'] {
		host.method_attributes(mut receiver, name, 0, fn [host, name, viewport] (mut vm libjs.VM) !libjs.Value {
			mut owner := unsafe { &Host(host) }
			if viewport {
				return owner.window_scroll(mut vm, name) or { return owner.reject_scroll_promise(mut vm, err) }
			}
			return owner.element_scroll(mut vm, name) or { return owner.reject_scroll_promise(mut vm, err) }
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
}

fn (mut host Host) install_window_scrolling() {
	mut global := host.realm.global_object_record()
	for name in ['scrollX', 'scrollY', 'pageXOffset', 'pageYOffset'] {
		host.accessor(mut global, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			host.window_receiver(mut vm)!
			mut owner := unsafe { &Host(host) }
			window := owner.frame_window(mut vm)!
			return libjs.Value.from_f64(if name in ['scrollX', 'pageXOffset'] {
				window.scroll_x()
			} else {
				window.scroll_y()
			})
		}, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			host.window_receiver(mut vm)!
			mut receiver := host.realm.global_object_record()
			receiver.define_direct_property(libjs.PropertyName.from_str(name), vm.argument(0), libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
			return libjs.js_undefined()
		})
	}
	host.install_scroll_methods(mut global, true)
}
