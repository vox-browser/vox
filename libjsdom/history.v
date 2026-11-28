// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform

@[heap]
struct HistoryBinding {
	native &html.History
mut:
	state libjs.Value
	state_cached bool
	state_revision u64
	state_entry voidptr
}

fn (mut host Host) native_history(mut vm libjs.VM) !&HistoryBinding {
	host.require_open(mut vm)!
	if binding := host.history_binding { return binding }
	window := host.frame_window(mut vm)!
	model := window.navigable_model()
	if entry := model.active_session_history_entry() {
		mut navigation := unsafe { &html.Navigation(window.navigation()) }
		navigation.initialize_the_navigation_api_entries_for_a_new_document(model.get_session_history_entries(), entry)
	}
	binding := &HistoryBinding{native: window.history()}
	host.history_binding = binding
	return binding
}

fn (host &Host) history_receiver(mut vm libjs.VM) ! {
	host.require_open(mut vm)!
	if !vm.this_value().is_object() || voidptr(vm.this_value().as_object()) != voidptr(host.history_object) {
		return vm.throw_error(.type_error, 'History member called on incompatible receiver')
	}
}

fn (mut host Host) history_state_value(mut vm libjs.VM, mut binding HistoryBinding, state dom.JSValue) !libjs.Value {
	entry := host.document.get_latest_entry() or { unsafe { nil } }
	if !binding.state_cached || binding.state_revision != binding.native.state_revision() || binding.state_entry != voidptr(entry) {
		mut clone := HistoryClone{host: &host}
		binding.state = clone.reconstruct(mut vm, state, 0) or { return host.dom_error(mut vm, err) }
		binding.state_revision = binding.native.state_revision()
		binding.state_entry = voidptr(entry)
		binding.state_cached = true
	}
	return binding.state
}

// The synchronous History.idl surface delegates to the owning Window. Native
// session entries, URL security and navigation cancellation retain ownership.
// Traversal scheduling and the other structured-clone families are separate.
fn (mut host Host) install_history() {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.history_object = libjs.Object.create(host.realm, prototype)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('History')), libjs.attribute_configurable)
	construct := fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal History constructor') }
	host.closures << voidptr(construct)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal History constructor') }, construct, 0, libjs.PropertyName.from_str('History')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	for name in ['length', 'state', 'scrollRestoration'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			host.history_receiver(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			mut binding := owner.native_history(mut vm)!
			native := binding.native
			if name == 'length' { return libjs.Value.from_f64(f64(native.length() or { return owner.dom_error(mut vm, err) })) }
			if name == 'scrollRestoration' { return libjs.Value.from_string(vm.create_string_from_str((native.scroll_restoration() or { return owner.dom_error(mut vm, err) }).str())) }
			state := native.state() or { return owner.dom_error(mut vm, err) }
			return owner.history_state_value(mut vm, mut binding, state)
		}, if name == 'scrollRestoration' { fn [host] (mut vm libjs.VM) !libjs.Value {
			host.history_receiver(mut vm)!
			text := vm.argument(0).to_primitive_string(mut vm)!.str()
			if text !in ['auto','manual'] { return vm.throw_error(.type_error, 'Invalid ScrollRestoration') }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			binding := owner.native_history(mut vm)!
			mut native := binding.native
			native.set_scroll_restoration(if text == 'manual' { .manual } else { .auto }) or { return owner.dom_error(mut vm, err) }
			return libjs.js_undefined()
		} } else { unsafe { nil } })
	}
	for name in ['pushState','replaceState'] {
		host.method_attributes(mut prototype, name, 2, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			host.history_receiver(mut vm)!
			if vm.argument_count() < 2 { return vm.throw_error(.type_error, name + ' requires two arguments') }
			unused := vm.argument(1).to_primitive_string(mut vm)!.str()
			url := if vm.argument(2).is_nullish() { ?string(none) } else { ?string(query_usv(mut vm, vm.argument(2))!) }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			binding := owner.native_history(mut vm)!
			mut native := binding.native
			_ = native.length() or { return owner.dom_error(mut vm, err) }
			mut clone := HistoryClone{host: owner}
			projected := clone.project(mut vm, vm.argument(0), 0) or { return owner.dom_error(mut vm, err) }
			// Prevalidate before the native API, whose legacy host adapter can
			// otherwise replace an uncloneable input with null.
			record := html.structured_serialize_for_storage(projected) or { return owner.dom_error(mut vm, err) }
			data := html.structured_deserialize(record) or { return owner.dom_error(mut vm, err) }
			if name == 'pushState' { native.push_state(data, unused, url) or { return owner.dom_error(mut vm, err) } }
			else { native.replace_state(data, unused, url) or { return owner.dom_error(mut vm, err) } }
			owner.refresh_location() or { return owner.dom_error(mut vm, err) }
			owner.changed()
			return libjs.js_undefined()
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('History'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	host.accessor(mut global, 'history', fn [host] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		if !vm.this_value().is_object() || voidptr(vm.this_value().as_object()) != voidptr(host.realm.global_object_record()) { return vm.throw_error(.type_error, 'History requires a Window receiver') }
		return libjs.Value.from_object(host.history_object)
	}, unsafe { nil })
}
