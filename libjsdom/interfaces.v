// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

// WebIDL interface objects share the exact native wrapper prototypes used by
// document queries and mutations. SVG interfaces and EventTarget prototype
// ancestry remain separate binding slices.
fn (mut host Host) install_node_interfaces() ! {
	mut vm := host.vm
	mut global := host.realm.global_object_record()
	mut node_constructor := &libjs.Object(unsafe { nil })
	mut element_constructor := &libjs.Object(unsafe { nil })
	host.html_element_prototype = libjs.Object.create(host.realm, host.element_prototype)
	for name in ['Node', 'Element', 'HTMLElement', 'Document', 'DocumentFragment'] {
		mut prototype := match name {
			'Node' { host.node_prototype }
			'Element' { host.element_prototype }
			'HTMLElement' { host.html_element_prototype }
			'DocumentFragment' { host.fragment_prototype }
			else { host.document_prototype }
		}
		construct := fn [host, name] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
			host.require_open(mut vm)!
			if name == 'HTMLElement' {
				mut owner := unsafe { &Host(host) }
				return owner.construct_html_element(mut vm, new_target, 'HTMLElement')
			}
			if name == 'DocumentFragment' {
				persistent := platform.enter_persistent()
				defer { platform.leave_persistent(persistent) }
				parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
				mut owner := unsafe { &Host(host) }
				fragment := dom.DocumentFragment.construct_impl(host.document)!
				mut object := owner.wrap_node(unsafe { &dom.Node(fragment) }).as_object()
				if parent.is_object() { object.internal_set_prototype_of(parent.as_object()) }
				return object
			}
			if name != 'Document' { return vm.throw_error(.type_error, 'Illegal ' + name + ' constructor') }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
			mut owner := unsafe { &Host(host) }
			native := dom.Document.construct_impl()
			owner.owned_documents << native
			mut object := owner.wrap_node(native.as_node()).as_object()
			if parent.is_object() { object.internal_set_prototype_of(parent.as_object()) }
			return object
		}
		host.closures << voidptr(construct)
		mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
			fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'DOM interface constructor requires new') },
			construct, 0, libjs.PropertyName.from_str(name)).object
		if name == 'Node' { node_constructor = constructor }
		else { if !constructor.internal_set_prototype_of(if name == 'HTMLElement' { element_constructor } else { node_constructor }) { return error('Unable to set DOM interface ancestry') } }
		if name == 'Element' { element_constructor = constructor }
		constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
		prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
		prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str(name)), libjs.attribute_configurable)
		global.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	}
	mut prototype := host.node_prototype
	for name, number in {
		'ELEMENT_NODE': 1, 'ATTRIBUTE_NODE': 2, 'TEXT_NODE': 3, 'CDATA_SECTION_NODE': 4,
		'ENTITY_REFERENCE_NODE': 5, 'ENTITY_NODE': 6, 'PROCESSING_INSTRUCTION_NODE': 7,
		'COMMENT_NODE': 8, 'DOCUMENT_NODE': 9, 'DOCUMENT_TYPE_NODE': 10,
		'DOCUMENT_FRAGMENT_NODE': 11, 'NOTATION_NODE': 12,
		'DOCUMENT_POSITION_DISCONNECTED': 1, 'DOCUMENT_POSITION_PRECEDING': 2,
		'DOCUMENT_POSITION_FOLLOWING': 4, 'DOCUMENT_POSITION_CONTAINS': 8,
		'DOCUMENT_POSITION_CONTAINED_BY': 16, 'DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC': 32,
	} {
		value := libjs.Value.from_i32(i32(number))
		node_constructor.define_direct_property(libjs.PropertyName.from_str(name), value, libjs.attribute_enumerable)
		prototype.define_direct_property(libjs.PropertyName.from_str(name), value, libjs.attribute_enumerable)
	}
}
