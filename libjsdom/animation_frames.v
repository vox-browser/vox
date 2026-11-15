// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import libjs
import loader
import platform

@[heap]
struct AnimationFrameBinding {
	window &html.WindowModel
mut:
	handle u32
	callback libjs.Value
	native html.AnimationFrameCallback = unsafe { nil }
}

fn (mut host Host) frame_window(mut vm libjs.VM) !&html.WindowModel {
	host.require_open(mut vm)!
	if !loader.is_initialized() { loader.initialize() }
	if pointer := host.document.get_window() {
		for window in html.all_windows() {
			if voidptr(window) == voidptr(pointer) { return window }
		}
		return vm.throw_error(.type_error, 'AnimationFrameProvider requires its owning HTML Window')
	}
	return html.WindowModel.create_top_level(host.document, none, '') or { return host.dom_error(mut vm, err) }
}

fn (host &Host) window_receiver(mut vm libjs.VM) ! {
	host.require_open(mut vm)!
	receiver := vm.this_value()
	if !receiver.is_nullish() && (!receiver.is_object() || voidptr(receiver.as_object()) != voidptr(host.realm.global_object_record())) {
		return vm.throw_error(.type_error, 'Window member requires a Window receiver')
	}
}

// A completed native closure must return before its trampoline can be freed.
// Retire it at the next provider entry, frame delivery or host teardown. JS
// callback roots are cleared immediately, independently of trampoline storage.
fn (mut host Host) release_retired_frames() {
	for callback in host.retired_frame_closures { platform.release_closure(callback) }
	host.retired_frame_closures = []
}

fn (mut host Host) fire_animation_frame(mut record AnimationFrameBinding, now f64) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	host.release_retired_frames()
	host.animation_frames.delete(record.handle)
	callback := record.callback
	record.callback = libjs.js_undefined()
	defer { host.retired_frame_closures << voidptr(record.native) }
	if host.closed { return }
	host.callback_entry(fn [callback, now] (mut vm libjs.VM) !libjs.Value {
		return libjs.call(mut vm, callback, libjs.js_undefined(), [libjs.Value.from_f64(now)])
	}) or { if report := host.hooks.exception { report(exception_message(err)) } }
}

fn (mut host Host) install_animation_frames() {
	mut global := host.realm.global_object_record()
	attributes := libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable
	host.method_attributes(mut global, 'requestAnimationFrame', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.window_receiver(mut vm)!
		if vm.argument_count() == 0 || !vm.argument(0).is_function() { return vm.throw_error(.type_error, 'FrameRequestCallback must be callable') }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		owner.release_retired_frames()
		mut window := owner.frame_window(mut vm)!
		mut record := &AnimationFrameBinding{window: window, callback: vm.argument(0)}
		record.native = fn [host, record] (now f64) {
			mut owner := unsafe { &Host(host) }
			mut binding := unsafe { &AnimationFrameBinding(record) }
			owner.fire_animation_frame(mut binding, now)
		}
		record.handle = window.request_animation_frame(record.native)
		owner.animation_frames[record.handle] = record
		return libjs.Value.from_f64(f64(record.handle))
	}, attributes)
	host.method_attributes(mut global, 'cancelAnimationFrame', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.window_receiver(mut vm)!
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'cancelAnimationFrame requires 1 argument') }
		handle := vm.argument(0).to_u32(mut vm)!
		mut owner := unsafe { &Host(host) }
		owner.release_retired_frames()
		mut window := owner.frame_window(mut vm)!
		window.cancel_animation_frame(handle)
		if mut record := owner.animation_frames[handle] {
			owner.animation_frames.delete(handle)
			record.callback = libjs.js_undefined()
			platform.release_closure(voidptr(record.native))
		}
		return libjs.js_undefined()
	}, attributes)
}

fn (mut host Host) close_animation_frames() {
	for handle, mut record in host.animation_frames {
		mut window := unsafe { &html.WindowModel(record.window) }
		window.cancel_animation_frame(handle)
		record.callback = libjs.js_undefined()
		platform.release_closure(voidptr(record.native))
	}
	host.animation_frames.clear()
	host.release_retired_frames()
}
