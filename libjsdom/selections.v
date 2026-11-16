// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (host &Host) selection_receiver(mut vm libjs.VM) !&dom.Selection {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if native := host.selections[voidptr(vm.this_value().as_object())] { return native }
	}
	return vm.throw_error(.type_error, 'Expected Selection')
}

fn (mut host Host) wrap_selection(document &dom.Document) libjs.Value {
	native := document.get_selection() or { return libjs.js_null() }
	if object := host.selection_wrappers[voidptr(native)] { return libjs.Value.from_object(object) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := libjs.Object.create(host.realm, host.selection_prototype)
	object.class_name = 'Selection'
	host.selections[voidptr(object)] = native
	host.selection_wrappers[voidptr(native)] = object
	return libjs.Value.from_object(object)
}

// Selection owns the document's actual native range; no script-side copy.
// Range object wrappers and getComposedRanges remain a separate binding slice.
fn (mut host Host) install_selections() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.selection_prototype = prototype
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value {
			return vm.throw_error(.type_error, 'Illegal Selection constructor')
		},
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object {
			return vm.throw_error(.type_error, 'Illegal Selection constructor')
		}, 0, libjs.PropertyName.from_str('Selection')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('Selection')), libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('Selection'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	host.method_attributes(mut global, 'getSelection', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.window_receiver(mut vm)!
		mut owner := unsafe { &Host(host) }
		return owner.wrap_selection(host.document)
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	mut document_prototype := host.document_prototype
	host.method_attributes(mut document_prototype, 'getSelection', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		document := host.document_receiver(mut vm)!
		mut owner := unsafe { &Host(host) }
		return owner.wrap_selection(document)
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	for name in ['anchorNode', 'anchorOffset', 'focusNode', 'focusOffset', 'isCollapsed', 'rangeCount',
		'type', 'direction'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.selection_receiver(mut vm)!
			if name in ['anchorNode', 'focusNode'] {
				node := if name == 'anchorNode' {
					native.anchor_node()
				} else {
					native.focus_node()
				}
				mut owner := unsafe { &Host(host) }
				return if found := node { owner.wrap_node(found) } else { libjs.js_null() }
			}
			if name == 'isCollapsed' { return libjs.Value.from_bool(native.is_collapsed()) }
			if name in ['type', 'direction'] {
				return libjs.Value.from_string(vm.create_string_from_str(if name == 'type' {
					native.type_()
				} else {
					native.direction()
				}))
			}
			return libjs.Value.from_f64(f64(match name {
				'anchorOffset' { native.anchor_offset() }
				'focusOffset' { native.focus_offset() }
				else { native.range_count() }
			}))
		}, unsafe { nil })
	}
	host.method_attributes(mut prototype, 'toString', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_string(vm.create_string_from_str(host.selection_receiver(mut vm)!.to_string()))
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	for name in ['removeAllRanges', 'empty', 'collapseToStart', 'collapseToEnd', 'deleteFromDocument'] {
		host.method_attributes(mut prototype, name, 0, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut native := host.selection_receiver(mut vm)!
			mut owner := unsafe { &Host(host) }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			match name {
				'removeAllRanges', 'empty' { native.remove_all_ranges() }
				'collapseToStart' {
					native.collapse_to_start() or { return owner.dom_error(mut vm, err) }
				}
				'collapseToEnd' {
					native.collapse_to_end() or { return owner.dom_error(mut vm, err) }
				}
				else { native.delete_from_document() or { return owner.dom_error(mut vm, err) } }
			}
			owner.changed()
			return libjs.js_undefined()
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	for name in ['collapse', 'setPosition', 'extend', 'selectAllChildren', 'containsNode'] {
		host.method_attributes(mut prototype, name, 1, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut native := host.selection_receiver(mut vm)!
			if vm.argument_count() == 0 {
				return vm.throw_error(.type_error, name + ' requires a Node')
			}
			node := if name in ['collapse', 'setPosition'] && vm.argument(0).is_nullish() {
				?&dom.Node(none)
			} else {
				?&dom.Node(host.tree_node_argument(mut vm, vm.argument(0))!)
			}
			mut owner := unsafe { &Host(host) }
			if name == 'containsNode' {
				actual := node or { return vm.throw_error(.type_error, 'Node argument required') }
				return libjs.Value.from_bool(native.contains_node(actual, vm.argument(1).to_boolean()))
			}
			offset := if name == 'selectAllChildren' {
				u32(0)
			} else {
				vm.argument(1).to_u32(mut vm)!
			}
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			match name {
				'collapse', 'setPosition' {
					native.collapse(node, int(offset)) or { return owner.dom_error(mut vm, err) }
				}
				'extend' {
					actual := node or { return vm.throw_error(.type_error, 'Node argument required') }
					native.extend(actual, int(offset)) or { return owner.dom_error(mut vm, err) }
				}
				else {
					actual := node or { return vm.throw_error(.type_error, 'Node argument required') }
					native.select_all_children(actual) or { return owner.dom_error(mut vm, err) }
				}
			}
			owner.changed()
			return libjs.js_undefined()
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	host.method_attributes(mut prototype, 'setBaseAndExtent', 4, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut native := host.selection_receiver(mut vm)!
		if vm.argument_count() < 4 {
			return vm.throw_error(.type_error, 'setBaseAndExtent requires four arguments')
		}
		anchor := host.tree_node_argument(mut vm, vm.argument(0))!
		a := vm.argument(1).to_u32(mut vm)!
		focus := host.tree_node_argument(mut vm, vm.argument(2))!
		b := vm.argument(3).to_u32(mut vm)!
		mut owner := unsafe { &Host(host) }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		native.set_base_and_extent(anchor, int(a), focus, int(b)) or { return owner.dom_error(mut vm, err) }
		owner.changed()
		return libjs.js_undefined()
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
}
