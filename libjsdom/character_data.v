// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (host &Host) character_receiver(mut vm libjs.VM) !&dom.CharacterData {
	node := host.node(mut vm)!
	return node.as_character_data() or { return vm.throw_error(.type_error, 'CharacterData member requires a CharacterData receiver') }
}

fn (mut host Host) install_character_data() ! {
	host.character_data_prototype = libjs.Object.create(host.realm, host.node_prototype)
	host.text_prototype = libjs.Object.create(host.realm, host.character_data_prototype)
	host.comment_prototype = libjs.Object.create(host.realm, host.character_data_prototype)
	host.cdata_prototype = libjs.Object.create(host.realm, host.text_prototype)
	mut vm := host.vm
	mut global := host.realm.global_object_record()
	mut constructors := map[string]&libjs.Object{}
	for name in ['CharacterData', 'Text', 'Comment', 'CDATASection'] {
		mut prototype := match name { 'Text' { host.text_prototype } 'Comment' { host.comment_prototype } 'CDATASection' { host.cdata_prototype } else { host.character_data_prototype } }
		construct := fn [host, name] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
			host.require_open(mut vm)!
			if name !in ['Text', 'Comment'] { return vm.throw_error(.type_error, 'Illegal ' + name + ' constructor') }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			text := if vm.argument(0).is_undefined() { '' } else { vm.argument(0).to_primitive_string(mut vm)!.str() }
			parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
			mut owner := unsafe { &Host(host) }
			native := if name == 'Text' {
				(dom.Text.construct_impl(host.document, text) or { return owner.dom_error(mut vm, err) }).as_node()
			} else {
				(dom.Comment.construct_impl(host.document, text) or { return owner.dom_error(mut vm, err) }).as_node()
			}
			mut wrapper := owner.wrap_node(native).as_object()
			if parent.is_object() { wrapper.internal_set_prototype_of(parent.as_object()) }
			return wrapper
		}
		host.closures << voidptr(construct)
		mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
			fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'CharacterData constructor requires new') }, construct, 0, libjs.PropertyName.from_str(name)).object
		parent := if name == 'CharacterData' { global.get(mut vm, libjs.PropertyName.from_str('Node'))!.as_object() } else { constructors[if name == 'CDATASection' { 'Text' } else { 'CharacterData' }] or { return error('Missing CharacterData constructor') } }
		if !constructor.internal_set_prototype_of(parent) { return error('Unable to set CharacterData constructor ancestry') }
		constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
		prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
		prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str(name)), libjs.attribute_configurable)
		constructors[name] = constructor
		global.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	}
	mut prototype := host.character_data_prototype
	host.accessor(mut prototype, 'data', fn [host] (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_string(vm.create_string_from_str(host.character_receiver(mut vm)!.data()))
	}, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut native := host.character_receiver(mut vm)!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		text := if vm.argument(0).is_null() { '' } else { vm.argument(0).to_primitive_string(mut vm)!.str() }
		native.replace_data_with_mutation_steps(0, native.length(), text) or { mut owner := unsafe { &Host(host) }; return owner.dom_error(mut vm, err) }
		mut owner := unsafe { &Host(host) }; owner.changed()
		return libjs.js_undefined()
	})
	host.accessor(mut prototype, 'length', fn [host] (mut vm libjs.VM) !libjs.Value { return libjs.Value.from_f64(f64(host.character_receiver(mut vm)!.length())) }, unsafe { nil })
	for name in ['substringData', 'appendData', 'insertData', 'deleteData', 'replaceData'] {
		length := if name == 'appendData' { 1 } else if name == 'replaceData' { 3 } else { 2 }
		host.method_attributes(mut prototype, name, length, fn [host, name, length] (mut vm libjs.VM) !libjs.Value {
			mut native := host.character_receiver(mut vm)!
			if vm.argument_count() < length { return vm.throw_error(.type_error, name + ' requires ' + length.str() + ' arguments') }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			offset := if name == 'appendData' { 0 } else { int(vm.argument(0).to_u32(mut vm)!) }
			count := if name in ['substringData','deleteData','replaceData'] { int(vm.argument(1).to_u32(mut vm)!) } else { 0 }
			text := if name in ['appendData','insertData','replaceData'] { vm.argument(if name == 'appendData' { 0 } else if name == 'insertData' { 1 } else { 2 }).to_primitive_string(mut vm)!.str() } else { '' }
			mut owner := unsafe { &Host(host) }
			match name {
				'substringData' { return libjs.Value.from_string(vm.create_string_from_str(native.substring_data(offset, count) or { return owner.dom_error(mut vm, err) })) }
				'appendData' { native.append_data(text) or { return owner.dom_error(mut vm, err) } }
				'insertData' { native.insert_data(offset, text) or { return owner.dom_error(mut vm, err) } }
				'deleteData' { native.delete_data(offset, count) or { return owner.dom_error(mut vm, err) } }
				else { native.replace_data_with_mutation_steps(offset, count, text) or { return owner.dom_error(mut vm, err) } }
			}
			owner.changed()
			return libjs.js_undefined()
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	mut text := host.text_prototype
	host.accessor(mut text, 'wholeText', fn [host] (mut vm libjs.VM) !libjs.Value {
		node := host.node(mut vm)!
		if !node.is_text() { return vm.throw_error(.type_error, 'Text member requires Text') }
		return libjs.Value.from_string(vm.create_string_from_str(unsafe { &dom.Text(node) }.whole_text()))
	}, unsafe { nil })
	host.method_attributes(mut text, 'splitText', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		node := host.node(mut vm)!
		if !node.is_text() { return vm.throw_error(.type_error, 'Text member requires Text') }
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'splitText requires an offset') }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		offset := int(vm.argument(0).to_u32(mut vm)!)
		mut native := unsafe { &dom.Text(node) }
		mut owner := unsafe { &Host(host) }
		result := native.split_text(offset) or { return owner.dom_error(mut vm, err) }
		owner.changed()
		return owner.wrap_node(result.as_node())
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	mut document := host.document_prototype
	for name in ['createTextNode', 'createComment'] {
		host.method_attributes(mut document, name, 1, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			node := host.node(mut vm)!
			if !node.is_document() { return vm.throw_error(.type_error, name + ' requires Document') }
			if vm.argument_count() == 0 { return vm.throw_error(.type_error, name + ' requires data') }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			text := vm.argument(0).to_primitive_string(mut vm)!.str()
			mut owner := unsafe { &Host(host) }
			return owner.wrap_node(if name == 'createTextNode' { node.document().create_text_node(text).as_node() } else { node.document().create_comment(text).as_node() })
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
}
