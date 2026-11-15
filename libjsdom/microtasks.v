// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform

@[heap]
struct QueuedMicrotaskBinding {
	event_loop &html.EventLoop
mut:
	task ?&html.Task
	callback libjs.Value
}

fn (mut host Host) fire_microtask(mut record QueuedMicrotaskBinding) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if task := record.task { host.microtasks.delete(task.id) }
	record.task = none
	callback := record.callback
	record.callback = libjs.js_undefined()
	if host.closed || host.document.has_been_destroyed() { return }
	previous := host.document.current_script()
	mut document := unsafe { &dom.Document(host.document) }
	document.set_current_script(none)
	defer { document.set_current_script(previous) }
	host.callback_entry(fn [callback] (mut vm libjs.VM) !libjs.Value {
		return libjs.call(mut vm, callback, libjs.js_undefined(), [])
	}) or { if report := host.hooks.exception { report(exception_message(err)) } }
	// The callback's result is ignored, including returned thenables.
}

fn (mut host Host) install_microtasks() {
	mut global := host.realm.global_object_record()
	host.method_attributes(mut global, 'queueMicrotask', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.window_receiver(mut vm)!
		if vm.argument_count() == 0 || !vm.argument(0).is_function() { return vm.throw_error(.type_error, 'queueMicrotask requires a callable callback') }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		owner.frame_window(mut vm)!
		settings := unsafe { &html.EnvironmentSettingsObject(owner.document.relevant_settings_object()) }
		mut loop := settings.responsible_event_loop()
		mut record := &QueuedMicrotaskBinding{event_loop: loop, callback: vm.argument(0)}
		task := html.Task.create_owned(.microtask, owner.document, fn [host, record] () {
			mut owner := unsafe { &Host(host) }
			mut binding := unsafe { &QueuedMicrotaskBinding(record) }
			owner.fire_microtask(mut binding)
		})
		record.task = task
		owner.microtasks[task.id] = record
		loop.enqueue_microtask(task)
		return libjs.js_undefined()
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
}

fn (mut host Host) close_microtasks() {
	for _, mut record in host.microtasks {
		record.callback = libjs.js_undefined()
		if task := record.task {
			mut loop := unsafe { &html.EventLoop(record.event_loop) }
			loop.discard_microtask(task)
		}
		record.task = none
	}
	host.microtasks.clear()
}
