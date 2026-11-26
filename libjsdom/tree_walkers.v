// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

@[heap]
struct TreeWalkerBinding {
mut:
	native       &dom.TreeWalker = unsafe { nil }
	filter       libjs.Value
	filter_error ?IError
}

fn (host &Host) tree_walker_receiver(mut vm libjs.VM) !&TreeWalkerBinding {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if binding := host.tree_walkers[voidptr(vm.this_value().as_object())] { return binding }
	}
	return vm.throw_error(.type_error, 'Expected TreeWalker')
}

fn (mut host Host) tree_walker_filter(mut binding TreeWalkerBinding, node &dom.Node) !int {
	mut vm := host.vm
	vm.consume_execution_budget()!
	mut function := binding.filter
	mut receiver := libjs.js_undefined()
	if !function.is_function() {
		function = function.as_object().get(mut vm, libjs.PropertyName.from_str('acceptNode'))!
		receiver = binding.filter
	}
	value := vm.call_with_limits(function, receiver, [host.wrap_node(node)], host.hooks.execution_limits)!
	return int(value.to_u16(mut vm)!)
}

fn (mut host Host) create_tree_walker(mut vm libjs.VM, document &dom.Document) !libjs.Value {
	if vm.argument_count() == 0 {
		return vm.throw_error(.type_error, 'createTreeWalker requires a root')
	}
	root := host.tree_node_argument(mut vm, vm.argument(0))!
	what := if vm.argument(1).is_undefined() {
		u32(0xffffffff)
	} else {
		vm.argument(1).to_u32(mut vm)!
	}
	filter := vm.argument(2)
	if !filter.is_nullish() && !filter.is_object() {
		return vm.throw_error(.type_error, 'NodeFilter requires a callback object')
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut binding := &TreeWalkerBinding{
		filter: if filter.is_nullish() {
			libjs.js_null()
		} else {
			filter
		}
	}
	mut native_filter := ?&dom.NodeFilter(none)
	if !filter.is_nullish() {
		accept := fn [host, binding] (node &dom.Node) int {
			mut owner := unsafe { &Host(host) }
			mut state := unsafe { &TreeWalkerBinding(binding) }
			if owner.closed || state.filter_error != none {
				return int(dom.NodeFilterResult.filter_reject)
			}
			return owner.tree_walker_filter(mut state, node) or {
				// The native callback ABI cannot throw. Stop invoking author code,
				// then rethrow the original completion at the binding boundary.
				state.filter_error = err
				return int(dom.NodeFilterResult.filter_reject)
			}
		}
		host.closures << voidptr(accept)
		native_filter = dom.NodeFilter.create(&dom.CallbackType{ accept_node: accept, callback_identity_: voidptr(filter.as_object()) })
	}
	binding.native = document.create_tree_walker(root, what, native_filter)
	object := libjs.Object.create(host.realm, host.tree_walker_prototype)
	host.tree_walkers[voidptr(object)] = binding
	return libjs.Value.from_object(object)
}

fn (mut host Host) install_tree_walkers() ! {
	mut vm := host.vm
	mut global := host.realm.global_object_record()
	// NodeFilter is a callback interface: constants are exposed on its object,
	// without a constructor or a prototype property.
	mut filter := libjs.Object.create(host.realm, host.realm.object_prototype)
	for name, value in {
		'FILTER_ACCEPT':               u32(1)
		'FILTER_REJECT':               u32(2)
		'FILTER_SKIP':                 u32(3)
		'SHOW_ALL':                    u32(0xffffffff)
		'SHOW_ELEMENT':                u32(1)
		'SHOW_ATTRIBUTE':              u32(2)
		'SHOW_TEXT':                   u32(4)
		'SHOW_CDATA_SECTION':          u32(8)
		'SHOW_ENTITY_REFERENCE':       u32(16)
		'SHOW_ENTITY':                 u32(32)
		'SHOW_PROCESSING_INSTRUCTION': u32(64)
		'SHOW_COMMENT':                u32(128)
		'SHOW_DOCUMENT':               u32(256)
		'SHOW_DOCUMENT_TYPE':          u32(512)
		'SHOW_DOCUMENT_FRAGMENT':      u32(1024)
		'SHOW_NOTATION':               u32(2048)
	} {
		filter.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_f64(f64(value)), libjs.attribute_enumerable)
	}
	global.define_direct_property(libjs.PropertyName.from_str('NodeFilter'), libjs.Value.from_object(filter), libjs.attribute_writable | libjs.attribute_configurable)
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.tree_walker_prototype = prototype
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value {
			return vm.throw_error(.type_error, 'Illegal TreeWalker constructor')
		},
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object {
			return vm.throw_error(.type_error, 'Illegal TreeWalker constructor')
		},
		0, libjs.PropertyName.from_str('TreeWalker')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('TreeWalker')), libjs.attribute_configurable)
	global.define_direct_property(libjs.PropertyName.from_str('TreeWalker'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	mut document := host.document_prototype
	host.method_attributes(mut document, 'createTreeWalker', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.document_receiver(mut vm)!
		mut owner := unsafe { &Host(host) }
		return owner.create_tree_walker(mut vm, native)
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	for name in ['root', 'whatToShow', 'filter', 'currentNode'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			binding := host.tree_walker_receiver(mut vm)!
			if name == 'filter' { return binding.filter }
			if name == 'whatToShow' {
				return libjs.Value.from_f64(f64(binding.native.what_to_show))
			}
			mut owner := unsafe { &Host(host) }
			return owner.wrap_node(if name == 'root' {
				binding.native.root
			} else {
				binding.native.current_node()
			})
		}, if name == 'currentNode' {
			fn [host] (mut vm libjs.VM) !libjs.Value {
				mut binding := host.tree_walker_receiver(mut vm)!
				node := host.tree_node_argument(mut vm, vm.argument(0))!
				binding.native.set_current_node(node)
				return libjs.js_undefined()
			}
		} else {
			unsafe { nil }
		})
	}
	for name in ['parentNode', 'firstChild', 'lastChild', 'previousSibling', 'nextSibling',
		'previousNode', 'nextNode'] {
		host.method_attributes(mut prototype, name, 0, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut binding := host.tree_walker_receiver(mut vm)!
			mut owner := unsafe { &Host(host) }
			if binding.native.active {
				return owner.dom_error(mut vm, error('InvalidStateError: The node filter is active'))
			}
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			binding.filter_error = none
			result := match name {
				'parentNode' { binding.native.parent_node() }
				'firstChild' { binding.native.first_child() }
				'lastChild' { binding.native.last_child() }
				'previousSibling' { binding.native.previous_sibling() }
				'nextSibling' { binding.native.next_sibling() }
				'previousNode' { binding.native.previous_node() }
				else { binding.native.next_node() }
			}
			if err := binding.filter_error {
				binding.filter_error = none
				return err
			}
			return if node := result { owner.wrap_node(node) } else { libjs.js_null() }
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
}
