// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform
import resizeobserver

@[heap]
struct ResizeEntryBinding {
	native &resizeobserver.ResizeObserverEntry
	arrays []&libjs.Object
}

fn (host &Host) resize_receiver(mut vm libjs.VM) !&resizeobserver.ResizeObserver {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if observer := host.resize_observers[voidptr(vm.this_value().as_object())] { return observer }
	}
	return vm.throw_error(.type_error, 'ResizeObserver member called on incompatible receiver')
}

fn (mut host Host) resize_element(mut vm libjs.VM, value libjs.Value) !&dom.Element {
	if value.is_object() {
		if node := host.nodes[voidptr(value.as_object())] {
			if element := node.as_element() { return element }
		}
	}
	return vm.throw_error(.type_error, 'ResizeObserver requires an Element')
}

fn resize_options(mut vm libjs.VM, value libjs.Value) !resizeobserver.ResizeObserverOptions {
	if value.is_nullish() { return resizeobserver.ResizeObserverOptions{} }
	if !value.is_object() { return vm.throw_error(.type_error, 'ResizeObserverOptions must be a dictionary') }
	box := value.as_object().get(mut vm, libjs.PropertyName.from_str('box'))!
	if box.is_undefined() { return resizeobserver.ResizeObserverOptions{} }
	name := box.to_primitive_string(mut vm)!.str()
	option := resizeobserver.resize_observer_box_options_from_string(name) or { return vm.throw_error(.type_error, 'Invalid ResizeObserver box option') }
	return resizeobserver.ResizeObserverOptions{box: option}
}

fn (mut host Host) resize_entry(mut vm libjs.VM, entry &resizeobserver.ResizeObserverEntry) !libjs.Value {
	if object := host.resize_entry_wrappers[voidptr(entry)] { return libjs.Value.from_object(object) }
	mut object := libjs.Object.create(host.realm, host.resize_entry_prototype)
	object.class_name = 'ResizeObserverEntry'
	mut arrays := []&libjs.Object{}
	for sizes in [entry.border_box_size(), entry.content_box_size(), entry.device_pixel_content_box_size()] {
		mut values := []libjs.Value{}
		for size in sizes {
			vm.consume_execution_budget()!
			mut item := libjs.Object.create(host.realm, host.resize_size_prototype)
			item.class_name = 'ResizeObserverSize'
			host.resize_sizes[voidptr(item)] = size
			values << libjs.Value.from_object(item)
		}
		mut array := libjs.ArrayObject.create_from(mut vm, host.realm, values, host.realm.array_prototype_record())!.object
		if !array.set_integrity_level(mut vm, .frozen)! { return vm.throw_error(.type_error, 'Unable to freeze ResizeObserver sizes') }
		arrays << array
	}
	host.resize_entries[voidptr(object)] = &ResizeEntryBinding{native: entry, arrays: arrays}
	host.resize_entry_wrappers[voidptr(entry)] = object
	return libjs.Value.from_object(object)
}

fn (mut host Host) resize_entry_array(mut vm libjs.VM, entries []&resizeobserver.ResizeObserverEntry) !libjs.Value {
	mut values := []libjs.Value{cap: entries.len}
	for entry in entries {
		vm.consume_execution_budget()!
		values << host.resize_entry(mut vm, entry)!
	}
	return libjs.Value.from_object(libjs.ArrayObject.create_from(mut vm, host.realm, values, host.realm.array_prototype_record())!.object)
}

// ResizeObserver/*.idl. Observations read the native layout adapter at gather
// time; each delivered entry retains its native geometry and frozen size arrays.
fn (mut host Host) install_resize_observers() {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.resize_observer_prototype = prototype
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		callback := vm.argument(0)
		if !callback.is_function() { return vm.throw_error(.type_error, 'ResizeObserver requires a callable callback') }
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut object := libjs.Object.create(host.realm, if parent.is_object() { parent.as_object() } else { host.resize_observer_prototype })
		object.class_name = 'ResizeObserver'
		delivery := fn [host, callback, object] (entries []&resizeobserver.ResizeObserverEntry, _ &resizeobserver.ResizeObserver) {
			mut owner := unsafe { &Host(host) }
			if owner.closed { return }
			owner.callback_entry(fn [host, callback, object, entries] (mut vm libjs.VM) !libjs.Value {
				mut owner := unsafe { &Host(host) }
				values := owner.resize_entry_array(mut vm, entries)!
				return libjs.call(mut vm, callback, libjs.Value.from_object(object), [values, libjs.Value.from_object(object)])
			}) or { if report := host.hooks.exception { report(exception_message(err)) }; return }
		}
		mut owner := unsafe { &Host(host) }
		owner.closures << voidptr(delivery)
		owner.resize_observers[voidptr(object)] = resizeobserver.ResizeObserver.create_for_constructor(host.document, delivery)
		return object
	}
	host.closures << voidptr(construct)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'ResizeObserver constructor requires new') }, construct, 1, libjs.PropertyName.from_str('ResizeObserver')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('ResizeObserver')), libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('ResizeObserver'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	for name in ['observe', 'unobserve', 'disconnect'] {
		host.method_attributes(mut prototype, name, if name == 'disconnect' { 0 } else { 1 }, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut native := host.resize_receiver(mut vm)!
			if name == 'disconnect' { native.disconnect(); return libjs.js_undefined() }
			mut owner := unsafe { &Host(host) }
			element := owner.resize_element(mut vm, vm.argument(0))!
			options := if name == 'observe' { resize_options(mut vm, vm.argument(1))! } else { resizeobserver.ResizeObserverOptions{} }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			id := element.as_node().unique_id()
			target := owner.resize_targets[id] or {
				value := resizeobserver.ResizeTarget.for_element(element)
				owner.resize_targets[id] = value
				value
			}
			if name == 'observe' { native.observe(target, options); owner.changed() } else { native.unobserve(target) }
			return libjs.js_undefined()
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	host.install_resize_records()
}

fn (mut host Host) install_resize_records() {
	mut vm := host.vm
	for name in ['ResizeObserverEntry', 'ResizeObserverSize'] {
		mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
		if name == 'ResizeObserverEntry' { host.resize_entry_prototype = prototype } else { host.resize_size_prototype = prototype }
		mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
			fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal ResizeObserver record constructor') },
			fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal ResizeObserver record constructor') }, 0, libjs.PropertyName.from_str(name)).object
		constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
		prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
		prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str(name)), libjs.attribute_configurable)
		mut global := host.realm.global_object_record()
		global.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	}
	mut size := host.resize_size_prototype
	for name in ['inlineSize', 'blockSize'] {
		host.accessor(mut size, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			host.require_open(mut vm)!
			if vm.this_value().is_object() {
				if native := host.resize_sizes[voidptr(vm.this_value().as_object())] { return libjs.Value.from_f64(if name == 'inlineSize' { native.inline_size() } else { native.block_size() }) }
			}
			return vm.throw_error(.type_error, 'ResizeObserverSize member called on incompatible receiver')
		}, unsafe { nil })
	}
	mut entry := host.resize_entry_prototype
	for name in ['target', 'contentRect', 'borderBoxSize', 'contentBoxSize', 'devicePixelContentBoxSize'] {
		host.accessor(mut entry, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			host.require_open(mut vm)!
			if vm.this_value().is_object() {
				if record := host.resize_entries[voidptr(vm.this_value().as_object())] {
					mut owner := unsafe { &Host(host) }
					if name == 'target' { return owner.wrap_node(record.native.target().element.as_node()) }
					if name == 'contentRect' { return owner.wrap_read_only_rect(record.native.content_rect(), host.read_only_rect_prototype) }
					index := if name == 'borderBoxSize' { 0 } else if name == 'contentBoxSize' { 1 } else { 2 }
					return libjs.Value.from_object(record.arrays[index])
				}
			}
			return vm.throw_error(.type_error, 'ResizeObserverEntry member called on incompatible receiver')
		}, unsafe { nil })
	}
}

fn (mut host Host) close_resize_observers() {
	for _, mut native in host.resize_observers {
		native.disconnect()
		native.finalize()
	}
	host.resize_observers.clear()
	host.resize_targets.clear()
	host.resize_entries.clear()
	host.resize_entry_wrappers.clear()
	host.resize_sizes.clear()
}
