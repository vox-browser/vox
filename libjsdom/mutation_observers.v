// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform

@[heap]
struct ObserverBinding {
	native &dom.MutationObserver
}

@[heap]
struct MutationRecordBinding {
	native &dom.MutationRecord
	added &dom.NodeList
	removed &dom.NodeList
}

fn (mut host Host) mutation_record(native &dom.MutationRecord) libjs.Value {
	if object := host.mutation_record_wrappers[voidptr(native)] { return libjs.Value.from_object(object) }
	object := libjs.Object.create(host.realm, host.mutation_record_prototype)
	host.mutation_records[voidptr(object)] = &MutationRecordBinding{native: native, added: dom.StaticNodeList.create(native.added_nodes_()), removed: dom.StaticNodeList.create(native.removed_nodes_())}
	host.mutation_record_wrappers[voidptr(native)] = object
	return libjs.Value.from_object(object)
}

fn (mut host Host) mutation_record_array(mut vm libjs.VM, records []&dom.MutationRecord) !libjs.Value {
	mut values := []libjs.Value{cap: records.len}
	for record in records {
		vm.consume_execution_budget()!
		values << host.mutation_record(record)
	}
	return libjs.Value.from_object(libjs.ArrayObject.create_from(mut vm, host.realm, values, host.realm.array_prototype_record())!.object)
}

fn (host &Host) observer_receiver(mut vm libjs.VM) !&dom.MutationObserver {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if binding := host.mutation_observers[voidptr(vm.this_value().as_object())] { return binding.native }
	}
	return vm.throw_error(.type_error, 'MutationObserver method called on incompatible receiver')
}

fn mutation_options(mut vm libjs.VM, value libjs.Value) !dom.MutationObserverOptions {
	mut options := dom.MutationObserverOptions{}
	if value.is_nullish() { return options }
	if !value.is_object() { return vm.throw_error(.type_error, 'MutationObserverInit must be a dictionary') }
	object := value.as_object()
	// WebIDL dictionaries read members in lexicographic order, preserving
	// presence separately from false for the native observe() validation.
	filter := object.get(mut vm, libjs.PropertyName.from_str('attributeFilter'))!
	if !filter.is_undefined() { options.attribute_filter = custom_element_strings(mut vm, filter)! }
	for name in ['attributeOldValue', 'attributes', 'characterData', 'characterDataOldValue', 'childList', 'subtree'] {
		member := object.get(mut vm, libjs.PropertyName.from_str(name))!
		if member.is_undefined() { continue }
		match name {
			'attributeOldValue' { options.attribute_old_value = member.to_boolean() }
			'attributes' { options.attributes = member.to_boolean() }
			'characterData' { options.character_data = member.to_boolean() }
			'characterDataOldValue' { options.character_data_old_value = member.to_boolean() }
			'childList' { options.child_list = member.to_boolean() }
			else { options.subtree = member.to_boolean() }
		}
	}
	return options
}

fn (mut host Host) install_mutation_observers() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.mutation_observer_prototype = prototype
	host.install_mutation_record_interface()!
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('MutationObserver')), libjs.attribute_configurable)
	host.mutation_queue = dom.MutationObserverDeliveryQueue.create(fn [host] () {
		mut owner := unsafe { &Host(host) }
		if owner.closed { return }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut vm := host.vm
		// DOM notification jobs and Promise reactions share one FIFO. The
		// native event-loop bridge also checkpoints jobs for outside-JS writes.
		vm.enqueue_promise_job(fn [host] () !libjs.Value {
			mut owner := unsafe { &Host(host) }
			if !owner.closed { owner.mutation_queue.notify() }
			return libjs.js_undefined()
		}, host.realm)
		html.queue_a_microtask(none, fn [host] () {
			mut owner := unsafe { &Host(host) }
			if owner.closed { return }
			owner.callback_entry(fn (mut vm libjs.VM) !libjs.Value { return libjs.js_undefined() }) or {
				if report := host.hooks.exception { report(exception_message_with_stack(err)) }
				return
			}
		})
	})
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		callback := vm.argument(0)
		if !callback.is_function() { return vm.throw_error(.type_error, 'MutationObserver requires a callable callback') }
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		object := libjs.Object.create(host.realm, if parent.is_object() { parent.as_object() } else { host.mutation_observer_prototype })
		native := dom.MutationObserver.construct_impl(&dom.CallbackType{mutation_callback: fn [host, callback, object] (records []&dom.MutationRecord, _ &dom.MutationObserver) {
			mut owner := unsafe { &Host(host) }
			if owner.closed { return }
			owner.callback_entry(fn [host, callback, object, records] (mut vm libjs.VM) !libjs.Value {
				mut owner := unsafe { &Host(host) }
				values := owner.mutation_record_array(mut vm, records)!
				return libjs.call(mut vm, callback, libjs.Value.from_object(object), [values, libjs.Value.from_object(object)])
			}) or { if report := host.hooks.exception { report(exception_message_with_stack(err)) }; return }
		}})!
		mut observer := unsafe { &dom.MutationObserver(native) }
		observer.delivery_queue_ = host.mutation_queue
		mut owner := unsafe { &Host(host) }
		owner.mutation_observers[voidptr(object)] = &ObserverBinding{native: native}
		return object
	}
	host.closures << voidptr(construct)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'MutationObserver constructor requires new') }, construct, 1, libjs.PropertyName.from_str('MutationObserver')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('MutationObserver'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	for name in ['observe', 'disconnect', 'takeRecords'] {
		host.method_attributes(mut prototype, name, if name == 'observe' { 1 } else { 0 }, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut observer := host.observer_receiver(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			if name == 'disconnect' { observer.disconnect(); return libjs.js_undefined() }
			if name == 'takeRecords' { return owner.mutation_record_array(mut vm, observer.take_records()) }
			if vm.argument_count() < 1 || !vm.argument(0).is_object() { return vm.throw_error(.type_error, 'observe requires a Node target') }
			target := host.nodes[voidptr(vm.argument(0).as_object())] or { return vm.throw_error(.type_error, 'observe requires a Node target') }
			mut options := mutation_options(mut vm, vm.argument(1))!
			observer.observe(target, mut options) or { return owner.dom_error(mut vm, err) }
			return libjs.js_undefined()
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
}

fn (mut host Host) install_mutation_record_interface() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.mutation_record_prototype = prototype
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('MutationRecord')), libjs.attribute_configurable)
	for name in ['type', 'target', 'addedNodes', 'removedNodes', 'previousSibling', 'nextSibling', 'attributeName', 'attributeNamespace', 'oldValue'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			host.require_open(mut vm)!
			if !vm.this_value().is_object() { return vm.throw_error(.type_error, 'MutationRecord receiver required') }
			binding := host.mutation_records[voidptr(vm.this_value().as_object())] or { return vm.throw_error(.type_error, 'MutationRecord receiver required') }
			native := binding.native
			mut owner := unsafe { &Host(host) }
			match name {
				'type' { return libjs.Value.from_string(vm.create_string_from_str(native.type_())) }
				'target' { return owner.wrap_node(native.target_()) }
				'addedNodes' { return owner.wrap_node_list(binding.added) }
				'removedNodes' { return owner.wrap_node_list(binding.removed) }
				'previousSibling', 'nextSibling' {
					value := if name == 'previousSibling' { native.previous_sibling_() } else { native.next_sibling_() }
					return if node := value { owner.wrap_node(node) } else { libjs.js_null() }
				}
				else {
					value := match name { 'attributeName' { native.attribute_name_() } 'attributeNamespace' { native.attribute_namespace_() } else { native.old_value_() } }
					return if text := value { libjs.Value.from_string(vm.create_string_from_str(text)) } else { libjs.js_null() }
				}
			}
		}, unsafe { nil })
	}
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal MutationRecord constructor') },
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal MutationRecord constructor') }, 0, libjs.PropertyName.from_str('MutationRecord')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('MutationRecord'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
}

fn (mut host Host) close_mutation_observers() {
	if host.mutation_queue != unsafe { nil } { host.mutation_queue.retire() }
	for _, binding in host.mutation_observers {
		mut observer := unsafe { &dom.MutationObserver(binding.native) }
		observer.disconnect()
		if record := observer.callback_ {
			if callback := record.mutation_callback { platform.release_closure(voidptr(callback)) }
		}
		observer.callback_ = none
	}
	host.mutation_observers.clear()
	host.mutation_records.clear()
	host.mutation_record_wrappers.clear()
}
