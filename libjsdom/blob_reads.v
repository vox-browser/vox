// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import encoding
import fileapi
import html
import libjs
import platform

@[heap]
struct BlobReadBinding {
	event_loop &html.EventLoop
	method string
mut:
	task ?&html.Task
	blob ?&fileapi.Blob
	capability ?&libjs.JSPromiseCapability
}

fn (mut host Host) queue_blob_read(mut vm libjs.VM, blob &fileapi.Blob, method string, capability &libjs.JSPromiseCapability) ! {
	host.frame_window(mut vm)!
	settings := unsafe { &html.EnvironmentSettingsObject(host.document.relevant_settings_object()) }
	mut loop := settings.responsible_event_loop()
	mut record := &BlobReadBinding{event_loop: loop, method: method, blob: blob, capability: capability}
	task := html.Task.create_owned(.file_reading, host.document, fn [host, record] () {
		mut owner := unsafe { &Host(host) }
		mut binding := unsafe { &BlobReadBinding(record) }
		owner.fire_blob_read(mut binding)
	})
	record.task = task
	host.blob_reads[task.id] = record
	mut queue := loop.task_queue()
	queue.enqueue(task)
}

fn (mut host Host) fire_blob_read(mut record BlobReadBinding) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if task := record.task { host.blob_reads.delete(task.id) }
	record.task = none
	blob := record.blob or { return }
	capability := record.capability or { return }
	record.blob, record.capability = none, none
	if host.closed || host.document.has_been_destroyed() { return }
	method := record.method
	host.callback_entry(fn [host, blob, capability, method] (mut vm libjs.VM) !libjs.Value {
		value := host.blob_read_result(mut vm, blob, method) or {
			return libjs.call(mut vm, capability.reject, libjs.js_undefined(), [host.fetch_error_value(mut vm, err)])
		}
		return libjs.call(mut vm, capability.resolve, libjs.js_undefined(), [value])
	}) or { if report := host.hooks.exception { report(exception_message(err)) } }
}

fn (host &Host) blob_read_result(mut vm libjs.VM, blob &fileapi.Blob, method string) !libjs.Value {
	charge_buffer_source_work(mut vm, blob.size())!
	// This Blob owns one immutable in-memory byte sequence. The file-reading
	// task supplies the asynchronous boundary; no standalone stream is needed
	// to aggregate that same sequence into another temporary buffer.
	bytes := blob.raw_bytes()
	if method == 'bytes' { return host.uint8_array_from_bytes(bytes) }
	if method == 'arrayBuffer' {
		prototype := host.realm.array_buffer_prototype or { return error('Missing ArrayBuffer prototype') }
		return libjs.Value.from_object(libjs.ArrayBufferObject.create_from_bytes(host.realm, bytes, false, prototype).object)
	}
	text := encoding.TextDecoder.create().decode(bytes, encoding.TextDecodeOptions{})!
	return libjs.Value.from_string(vm.create_string_from_str(text))
}

fn (mut host Host) close_blob_reads() {
	for _, mut record in host.blob_reads {
		record.blob, record.capability = none, none
		if task := record.task {
			mut queue := record.event_loop.task_queue()
			matches := fn [task] (candidate &html.Task) bool { return voidptr(task) == voidptr(candidate) }
			queue.remove_tasks_matching(matches)
			platform.release_closure(voidptr(matches))
		}
		record.task = none
	}
	host.blob_reads.clear()
}
