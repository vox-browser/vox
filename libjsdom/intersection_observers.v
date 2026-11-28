// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import intersectionobserver
import libjs
import math
import platform

@[heap]
struct IntersectionBinding {
	native &intersectionobserver.IntersectionObserver
	thresholds &libjs.Object
}

fn intersection_threshold(mut vm libjs.VM, value libjs.Value) !f64 {
	number := value.to_number(mut vm)!.number
	if math.is_nan(number) || math.is_inf(number, 0) { return vm.throw_error(.type_error, 'IntersectionObserver threshold must be finite') }
	return number
}

fn intersection_thresholds(mut vm libjs.VM, value libjs.Value) ![]f64 {
	if value.is_undefined() { return [0.0] }
	if value.is_object() {
		method := value.as_object().get(mut vm, libjs.PropertyName.from_symbol(vm.well_known_symbol_iterator()))!
		if !method.is_nullish() {
			if !method.is_function() { return vm.throw_error(.type_error, 'Threshold iterator must be callable') }
			mut iterator := libjs.get_iterator_from_method(mut vm, value, method)!
			mut values := []f64{}
			for {
				vm.consume_execution_budget()!
				step := libjs.iterator_step_value(mut vm, mut iterator)!
				if step.done { return values }
				threshold := intersection_threshold(mut vm, step.value) or {
					return libjs.iterator_close(mut vm, iterator, libjs.completion_from_error(err)).release_error()
				}
				values << threshold
			}
		}
	}
	return [intersection_threshold(mut vm, value)!]
}

fn (host &Host) intersection_root(mut vm libjs.VM, value libjs.Value) !intersectionobserver.ObserverRoot {
	if value.is_nullish() { return intersectionobserver.ObserverRoot{} }
	if value.is_object() {
		if node := host.nodes[voidptr(value.as_object())] {
			if element := node.as_element() { return intersectionobserver.ObserverRoot{kind: .element, element: element} }
			if document := node.as_document() { return intersectionobserver.ObserverRoot{kind: .document, document: document} }
		}
	}
	return vm.throw_error(.type_error, 'IntersectionObserver root must be an Element or Document')
}

fn (host &Host) intersection_options(mut vm libjs.VM, value libjs.Value) !intersectionobserver.IntersectionObserverInit {
	if !value.is_nullish() && !value.is_object() { return vm.throw_error(.type_error, 'IntersectionObserverInit must be a dictionary') }
	if !value.is_object() { return intersectionobserver.IntersectionObserverInit{relevant_document: host.document} }
	object := value.as_object()
	// WebIDL conversion completes in dictionary order before constructor
	// validation checks margins, then the finite threshold range.
	delay := object.get(mut vm, libjs.PropertyName.from_str('delay'))!.to_i32(mut vm)!
	root := host.intersection_root(mut vm, object.get(mut vm, libjs.PropertyName.from_str('root'))!)!
	raw_margin := object.get(mut vm, libjs.PropertyName.from_str('rootMargin'))!
	margin := if raw_margin.is_undefined() { '0px' } else { raw_margin.to_primitive_string(mut vm)!.str() }
	raw_scroll := object.get(mut vm, libjs.PropertyName.from_str('scrollMargin'))!
	scroll := if raw_scroll.is_undefined() { '0px' } else { raw_scroll.to_primitive_string(mut vm)!.str() }
	thresholds := intersection_thresholds(mut vm, object.get(mut vm, libjs.PropertyName.from_str('threshold'))!)!
	visibility := object.get(mut vm, libjs.PropertyName.from_str('trackVisibility'))!.to_boolean()
	return intersectionobserver.IntersectionObserverInit{root: root, relevant_document: host.document,
		root_margin: margin, scroll_margin: scroll, thresholds: thresholds, delay: i64(delay), track_visibility: visibility}
}

fn (host &Host) intersection_receiver(mut vm libjs.VM) !&IntersectionBinding {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if binding := host.intersection_observers[voidptr(vm.this_value().as_object())] { return binding }
	}
	return vm.throw_error(.type_error, 'IntersectionObserver member called on incompatible receiver')
}

fn (mut host Host) intersection_entry(native &intersectionobserver.IntersectionObserverEntry) libjs.Value {
	if object := host.intersection_entry_wrappers[voidptr(native)] { return libjs.Value.from_object(object) }
	mut object := libjs.Object.create(host.realm, host.intersection_entry_prototype)
	object.class_name = 'IntersectionObserverEntry'
	host.intersection_entries[voidptr(object)] = native
	host.intersection_entry_wrappers[voidptr(native)] = object
	return libjs.Value.from_object(object)
}

fn (mut host Host) intersection_entry_array(mut vm libjs.VM, entries []&intersectionobserver.IntersectionObserverEntry) !libjs.Value {
	mut values := []libjs.Value{cap: entries.len}
	for entry in entries {
		vm.consume_execution_budget()!
		values << host.intersection_entry(entry)
	}
	return libjs.Value.from_object(libjs.ArrayObject.create_from(mut vm, host.realm, values, host.realm.array_prototype_record())!.object)
}

fn (mut host Host) install_intersection_observers() {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.intersection_observer_prototype = prototype
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		callback := vm.argument(0)
		if !callback.is_function() { return vm.throw_error(.type_error, 'IntersectionObserver requires a callable callback') }
		options := host.intersection_options(mut vm, vm.argument(1))!
		mut owner := unsafe { &Host(host) }
		if intersectionobserver.parse_a_margin(options.root_margin) == none || intersectionobserver.parse_a_margin(options.scroll_margin) == none {
			return owner.dom_error(mut vm, error('SyntaxError: IntersectionObserver margin must contain absolute or percentage lengths'))
		}
		for threshold in options.thresholds {
			if threshold < 0 || threshold > 1 { return vm.throw_error(.range_error, 'IntersectionObserver thresholds must be between zero and one') }
		}
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut object := libjs.Object.create(host.realm, if parent.is_object() { parent.as_object() } else { host.intersection_observer_prototype })
		object.class_name = 'IntersectionObserver'
		delivery := fn [host, callback, object] (entries []&intersectionobserver.IntersectionObserverEntry, _ &intersectionobserver.IntersectionObserver) {
			mut owner := unsafe { &Host(host) }
			if owner.closed { return }
			owner.callback_entry(fn [host, callback, object, entries] (mut vm libjs.VM) !libjs.Value {
				mut owner := unsafe { &Host(host) }
				values := owner.intersection_entry_array(mut vm, entries)!
				return libjs.call(mut vm, callback, libjs.Value.from_object(object), [values, libjs.Value.from_object(object)])
			}) or { if report := host.hooks.exception { report(exception_message(err)) }; return }
		}
		owner.closures << voidptr(delivery)
		native := intersectionobserver.IntersectionObserver.construct_impl(delivery, options) or { return owner.dom_error(mut vm, err) }
		mut values := []libjs.Value{}
		for threshold in native.thresholds() { values << libjs.Value.from_f64(threshold) }
		mut thresholds := libjs.ArrayObject.create_from(mut vm, host.realm, values, host.realm.array_prototype_record())!.object
		if !thresholds.set_integrity_level(mut vm, .frozen)! { return vm.throw_error(.type_error, 'Unable to freeze observer thresholds') }
		owner.intersection_observers[voidptr(object)] = &IntersectionBinding{native: native, thresholds: thresholds}
		return object
	}
	host.closures << voidptr(construct)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'IntersectionObserver constructor requires new') }, construct, 1, libjs.PropertyName.from_str('IntersectionObserver')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('IntersectionObserver')), libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('IntersectionObserver'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	for name in ['observe', 'unobserve', 'disconnect', 'takeRecords'] {
		host.method_attributes(mut prototype, name, if name in ['observe', 'unobserve'] { 1 } else { 0 }, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			binding := host.intersection_receiver(mut vm)!
			mut native := binding.native
			mut owner := unsafe { &Host(host) }
			if name == 'takeRecords' { return owner.intersection_entry_array(mut vm, native.take_records()) }
			if name == 'disconnect' { native.disconnect(); return libjs.js_undefined() }
			value := vm.argument(0)
			if value.is_object() {
				if node := host.nodes[voidptr(value.as_object())] {
					if element := node.as_element() {
						if name == 'observe' { native.observe(element) } else { native.unobserve(element) }
						return libjs.js_undefined()
					}
				}
			}
			return vm.throw_error(.type_error, name + ' requires an Element')
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	for name in ['root', 'rootMargin', 'scrollMargin', 'thresholds', 'delay', 'trackVisibility'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			binding := host.intersection_receiver(mut vm)!
			native := binding.native
			mut owner := unsafe { &Host(host) }
			match name {
				'thresholds' { return libjs.Value.from_object(binding.thresholds) }
				'delay' { return libjs.Value.from_f64(f64(native.delay())) }
				'trackVisibility' { return libjs.Value.from_bool(native.track_visibility()) }
				'rootMargin', 'scrollMargin' { return libjs.Value.from_string(vm.create_string_from_str(if name == 'rootMargin' { native.root_margin() } else { native.scroll_margin() })) }
				else {
					root := native.root()
					if element := root.element { return owner.wrap_node(element.as_node()) }
					if document := root.document { return owner.wrap_node(document.as_node()) }
					return libjs.js_null()
				}
			}
		}, unsafe { nil })
	}
	host.install_intersection_entries()
}

fn (mut host Host) install_intersection_entries() {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.intersection_entry_prototype = prototype
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal IntersectionObserverEntry constructor') },
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal IntersectionObserverEntry constructor') }, 0, libjs.PropertyName.from_str('IntersectionObserverEntry')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('IntersectionObserverEntry')), libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('IntersectionObserverEntry'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	for name in ['time', 'rootBounds', 'boundingClientRect', 'intersectionRect', 'isIntersecting', 'intersectionRatio', 'target'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			host.require_open(mut vm)!
			if vm.this_value().is_object() {
				if entry := host.intersection_entries[voidptr(vm.this_value().as_object())] {
					mut owner := unsafe { &Host(host) }
					return match name {
						'time' { libjs.Value.from_f64(entry.time()) }
						'isIntersecting' { libjs.Value.from_bool(entry.is_intersecting()) }
						'intersectionRatio' { libjs.Value.from_f64(entry.intersection_ratio()) }
						'target' { owner.wrap_node(entry.target().as_node()) }
						'rootBounds' { if rect := entry.root_bounds() { owner.wrap_read_only_rect(rect, host.read_only_rect_prototype) } else { libjs.js_null() } }
						'boundingClientRect' { owner.wrap_read_only_rect(entry.bounding_client_rect(), host.read_only_rect_prototype) }
						else { owner.wrap_read_only_rect(entry.intersection_rect(), host.read_only_rect_prototype) }
					}
				}
			}
			return vm.throw_error(.type_error, 'IntersectionObserverEntry member called on incompatible receiver')
		}, unsafe { nil })
	}
}

fn (mut host Host) close_intersection_observers() {
	for _, binding in host.intersection_observers {
		mut native := binding.native
		native.disconnect()
		native.finalize()
	}
	host.intersection_observers.clear()
	host.intersection_entries.clear()
	host.intersection_entry_wrappers.clear()
}
