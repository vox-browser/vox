// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import libjs
import math
import performancetimeline
import platform
import usertiming

@[heap]
struct LibJSPerformanceHost {
	runtime         &Runtime
	native          &html.GlobalScopePerformance
	object          &libjs.Object
	entry_prototype &libjs.Object
mut:
	entries  map[voidptr]&performancetimeline.PerformanceEntry
	wrappers map[voidptr]&libjs.Object
	closed   bool
}

// Script-visible entries use the actual Window/Worker Performance timeline.
// Structured-cloned detail, measures and observers remain separate bindings.
fn (mut runtime Runtime) install_libjs_performance() ! {
	if runtime.closed { return error('JavaScript runtime is closed') }
	if runtime.libjs_performance_host_ != none { return }
	settings := runtime.scripting_settings_ or { return error('Performance requires settings') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut scope := settings.window_or_worker_global_scope()!
	mut prototype := libjs.Object.create(runtime.realm, runtime.realm.object_prototype)
	mut entry_prototype := libjs.Object.create(runtime.realm, runtime.realm.object_prototype)
	mut object := libjs.Object.create(runtime.realm, prototype)
	object.class_name = 'Performance'
	mut host := &LibJSPerformanceHost{
		runtime:         &runtime
		native:          scope.performance()
		object:          object
		entry_prototype: entry_prototype
	}
	mut vm := runtime.agent_vm
	for name in ['name', 'entryType', 'startTime', 'duration', 'detail'] {
		getter := libjs.NativeFunction.create(mut vm, runtime.realm, runtime.realm.function_prototype,
			fn [host, name] (mut vm libjs.VM) !libjs.Value {
				entry := host.entry_receiver(mut vm)!
				return match name {
					'name' { libjs.Value.from_string(vm.create_string_from_str(entry.name)) }
					'entryType' {
						libjs.Value.from_string(vm.create_string_from_str(entry.entry_type))
					}
					'startTime' { libjs.Value.from_f64(entry.start_time) }
					'duration' { libjs.Value.from_f64(entry.duration) }
					else { libjs.js_null() }
				}
			}, 0, libjs.PropertyName.from_str(name), 'get')
		entry_prototype.define_direct_accessor(libjs.PropertyName.from_str(name), getter.object, none,
			libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	to_json := libjs.NativeFunction.create(mut vm, runtime.realm, runtime.realm.function_prototype,
		fn [host] (mut vm libjs.VM) !libjs.Value {
			entry := host.entry_receiver(mut vm)!
			mut result := libjs.Object.create(host.runtime.realm, host.runtime.realm.object_prototype)
			keys := ['name', 'entryType', 'startTime', 'duration', 'detail']
			values := [libjs.Value.from_string(vm.create_string_from_str(entry.name)),
				libjs.Value.from_string(vm.create_string_from_str(entry.entry_type)),
				libjs.Value.from_f64(entry.start_time), libjs.Value.from_f64(entry.duration),
				libjs.js_null()]
			for index, key in keys {
				result.create_data_property_or_throw(mut vm, libjs.PropertyName.from_str(key), values[index])!
			}
			return libjs.Value.from_object(result)
		}, 0, libjs.PropertyName.from_str('toJSON'), none)
	entry_prototype.define_direct_property(libjs.PropertyName.from_str('toJSON'), libjs.Value.from_object(to_json.object),
		libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	time_origin := libjs.NativeFunction.create(mut vm, runtime.realm, runtime.realm.function_prototype,
		fn [host] (mut vm libjs.VM) !libjs.Value {
			host.require_receiver(mut vm)!
			return libjs.Value.from_f64(host.native.time_origin())
		}, 0, libjs.PropertyName.from_str('timeOrigin'), 'get')
	prototype.define_direct_accessor(libjs.PropertyName.from_str('timeOrigin'), time_origin.object, none,
		libjs.attribute_enumerable | libjs.attribute_configurable)
	for name in ['now', 'mark', 'getEntries', 'getEntriesByType', 'getEntriesByName', 'clearMarks',
		'clearMeasures'] {
		length := if name in ['mark', 'getEntriesByType', 'getEntriesByName'] { 1 } else { 0 }
		method := libjs.NativeFunction.create(mut vm, runtime.realm, runtime.realm.function_prototype,
			fn [host, name] (mut vm libjs.VM) !libjs.Value {
				mut owner := unsafe { &LibJSPerformanceHost(host) }
				return owner.operation(mut vm, name)
			}, f64(length), libjs.PropertyName.from_str(name), none)
		prototype.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(method.object),
			libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	mut global := runtime.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('performance'), libjs.Value.from_object(object),
		libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	runtime.libjs_performance_host_ = host
	runtime.add_close_handler(fn [host] () {
		mut owner := unsafe { &LibJSPerformanceHost(host) }
		owner.closed = true
		owner.entries = {}
		owner.wrappers = {}
	})
}

fn (host &LibJSPerformanceHost) require_open(mut vm libjs.VM) ! {
	if host.closed || host.runtime.closed {
		return vm.throw_error(.type_error, 'Performance runtime is closed')
	}
}

fn (host &LibJSPerformanceHost) require_receiver(mut vm libjs.VM) ! {
	host.require_open(mut vm)!
	value := vm.this_value()
	if !value.is_object() || voidptr(value.as_object()) != voidptr(host.object) {
		return vm.throw_error(.type_error, 'Illegal Performance receiver')
	}
}

fn (host &LibJSPerformanceHost) entry_receiver(mut vm libjs.VM) !&performancetimeline.PerformanceEntry {
	host.require_open(mut vm)!
	value := vm.this_value()
	if value.is_object() {
		if entry := host.entries[voidptr(value.as_object())] { return entry }
	}
	return vm.throw_error(.type_error, 'Illegal PerformanceEntry receiver')
}

fn (mut host LibJSPerformanceHost) wrap_entry(entry &performancetimeline.PerformanceEntry) libjs.Value {
	if cached := host.wrappers[voidptr(entry)] { return libjs.Value.from_object(cached) }
	mut object := libjs.Object.create(host.runtime.realm, host.entry_prototype)
	object.class_name = if entry.entry_type == 'mark' {
		'PerformanceMark'
	} else {
		'PerformanceEntry'
	}
	host.wrappers[voidptr(entry)] = object
	host.entries[voidptr(object)] = entry
	return libjs.Value.from_object(object)
}

fn (mut host LibJSPerformanceHost) entry_array(mut vm libjs.VM, entries []&performancetimeline.PerformanceEntry) !libjs.Value {
	mut values := []libjs.Value{cap: entries.len}
	for entry in entries { values << host.wrap_entry(entry) }
	return libjs.Value.from_object(libjs.ArrayObject.create_from(mut vm, host.runtime.realm, values, host.runtime.realm.array_prototype_record())!.object)
}

// Native entries belong to the document arena. Allocate VM wrappers only after
// leaving it, so script-visible objects cannot retain recycled frame storage.
fn (host &LibJSPerformanceHost) native_mark(name string, options usertiming.PerformanceMarkOptions) !&usertiming.PerformanceMark {
	mut allocation := platform.RetainedArenaScope{}
	if settings := host.runtime.scripting_settings_ {
		if document := settings.responsible_document() {
			mut storage := document.native_storage()
			if storage != unsafe { nil } { allocation = storage.enter_nested() }
		}
	}
	defer { allocation.finish() }
	mut native := unsafe { &html.GlobalScopePerformance(host.native) }
	return native.mark(name.clone(), options)
}

fn (mut host LibJSPerformanceHost) operation(mut vm libjs.VM, name string) !libjs.Value {
	host.require_receiver(mut vm)!
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut native := host.native
	match name {
		'now' { return libjs.Value.from_f64(native.now()) }
		'mark' {
			if vm.argument_count() < 1 {
				return vm.throw_error(.type_error, 'Performance.mark requires a name')
			}
			mark_name := vm.argument(0).to_primitive_string(mut vm)!.str()
			options := vm.argument(1)
			mut start := ?f64(none)
			if !options.is_nullish() {
				if !options.is_object() {
					return vm.throw_error(.type_error, 'PerformanceMarkOptions must be an object')
				}
				detail := options.as_object().get(mut vm, libjs.PropertyName.from_str('detail'))!
				value := options.as_object().get(mut vm, libjs.PropertyName.from_str('startTime'))!
				if !value.is_undefined() {
					number := value.to_number(mut vm)!.number
					if math.is_nan(number) || math.is_inf(number, 0) {
						return vm.throw_error(.type_error, 'Performance startTime must be finite')
					}
					start = number
				}
				if !detail.is_nullish() {
					return vm.throw_error(.internal_error, 'LibJS PerformanceMark detail structured cloning is not translated yet')
				}
			}
			mark := host.native_mark(mark_name, usertiming.PerformanceMarkOptions{ start_time: start }) or {
				return vm.throw_error(if err.msg().starts_with('SyntaxError:') {
					.syntax_error
				} else {
					.type_error
				}, err.msg())
			}
			return host.wrap_entry(mark.entry)
		}
		'getEntries' { return host.entry_array(mut vm, native.get_entries()) }
		'getEntriesByType' {
			if vm.argument_count() < 1 {
				return vm.throw_error(.type_error, 'Performance.getEntriesByType requires a type')
			}
			return host.entry_array(mut vm, native.get_entries_by_type(vm.argument(0).to_primitive_string(mut vm)!.str()))
		}
		'getEntriesByName' {
			if vm.argument_count() < 1 {
				return vm.throw_error(.type_error, 'Performance.getEntriesByName requires a name')
			}
			entry_name := vm.argument(0).to_primitive_string(mut vm)!.str()
			kind := if vm.argument(1).is_undefined() {
				?string(none)
			} else {
				?string(vm.argument(1).to_primitive_string(mut vm)!.str())
			}
			return host.entry_array(mut vm, native.get_entries_by_name(entry_name, kind))
		}
		else {
			entry_name := if vm.argument(0).is_undefined() {
				?string(none)
			} else {
				?string(vm.argument(0).to_primitive_string(mut vm)!.str())
			}
			if name == 'clearMarks' {
				native.clear_marks(entry_name)
			} else {
				native.clear_measures(entry_name)
			}
			return libjs.js_undefined()
		}
	}
}
