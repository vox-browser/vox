// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform

// Both views delegate to the select's real option owner. Selectedness can
// change without an attribute/DOM generation change, so query it on each read.
@[heap]
struct SelectCollectionView {
	native &html.HTMLOptionsCollection
	selected bool
}

fn (view &SelectCollectionView) length() int {
	return if view.selected { html.html_select_element_selected_options(view.native.select_element).len } else { int(view.native.length()) }
}

fn (view &SelectCollectionView) item(index int) ?&dom.Element {
	if index < 0 || u64(index) > u64(0xffff_ffff) { return none }
	if !view.selected {
		option := view.native.item(u32(index)) or { return none }
		return unsafe { &dom.Element(option) }
	}
	options := html.html_select_element_selected_options(view.native.select_element)
	if index >= options.len { return none }
	return unsafe { &dom.Element(options[index]) }
}

fn (view &SelectCollectionView) named_item(name string) ?&dom.Element {
	if name == '' { return none }
	if !view.selected {
		option := view.native.named_item(name) or { return none }
		return unsafe { &dom.Element(option) }
	}
	for option in html.html_select_element_selected_options(view.native.select_element) {
		element := unsafe { &dom.Element(option) }
		if element.get_attribute_value('id') == name || element.get_attribute_value('name') == name { return element }
	}
	return none
}

fn (mut host Host) wrap_select_collection(native &html.HTMLOptionsCollection, selected bool) libjs.Value {
	if selected {
		if object := host.selected_options_wrappers[voidptr(native.select_element)] { return libjs.Value.from_object(object) }
	} else {
		if object := host.collection_wrappers[voidptr(native)] { return libjs.Value.from_object(object) }
	}
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	view := &SelectCollectionView{native: native, selected: selected}
	value := host.wrap_collection_view(if selected { voidptr(view) } else { voidptr(native) }, NativeHTMLCollectionView(view), if selected { host.collection_prototype } else { host.options_collection_prototype }, if selected { 'HTMLCollection' } else { 'HTMLOptionsCollection' })
	if selected { host.selected_options_wrappers[voidptr(native.select_element)] = value.as_object() }
	else {
		host.options_collections[voidptr(value.as_object())] = native
		mut object := value.as_object()
		legacy := object.legacy_platform_object or { libjs.LegacyPlatformObject{} }
		object.legacy_platform_object = libjs.LegacyPlatformObject{...legacy, indexed_setter: libjs.LegacyIndexedPropertySetter(&OptionIndexedSetter{host: &host, native: native})}
	}
	return value
}

fn (host &Host) options_collection_receiver(mut vm libjs.VM) !&html.HTMLOptionsCollection {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if native := host.options_collections[voidptr(vm.this_value().as_object())] { return native }
	}
	return vm.throw_error(.type_error, 'Expected an HTMLOptionsCollection')
}

fn (host &Host) select_collection_receiver(mut vm libjs.VM, on_select bool) !&html.HTMLOptionsCollection {
	if !on_select { return host.options_collection_receiver(mut vm) }
	element := host.form_control_receiver(mut vm, 'select')!
	mut model := prepare_libjs_select(element)
	return model.options()
}

fn (host &Host) add_select_option(mut vm libjs.VM, native &html.HTMLOptionsCollection) ! {
	if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'add requires an option or optgroup') }
	element := host.form_data_element(mut vm, vm.argument(0), false)!
	if element.local_name() !in ['option', 'optgroup'] { return vm.throw_error(.type_error, 'Expected an option or optgroup') }
	before := vm.argument(1)
	mut before_element := ?&dom.HTMLElement(none)
	mut before_index := ?i32(none)
	if !before.is_nullish() {
		if before.is_object() {
			if node := host.nodes[voidptr(before.as_object())] {
				if target := node.as_element() {
					if target.is_html_element() { before_element = unsafe { &dom.HTMLElement(target) } }
				}
			}
		}
		if before_element == none { before_index = before.to_i32(mut vm)! }
	}
	native.add(unsafe { &dom.HTMLElement(element) }, before_element, before_index)!
}

fn (mut host Host) install_select_collections() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.collection_prototype)
	host.options_collection_prototype = prototype
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal HTMLOptionsCollection constructor') },
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal HTMLOptionsCollection constructor') }, 0, libjs.PropertyName.from_str('HTMLOptionsCollection')).object
	mut global := host.realm.global_object_record()
	parent := global.get(mut vm, libjs.PropertyName.from_str('HTMLCollection'))!
	if !constructor.internal_set_prototype_of(parent.as_object()) { return error('Unable to set options constructor ancestry') }
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('HTMLOptionsCollection')), libjs.attribute_configurable)
	global.define_direct_property(libjs.PropertyName.from_str('HTMLOptionsCollection'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	mut select_prototype := host.html_element_prototypes['HTMLSelectElement'] or { return error('Missing select prototype') }
	for name in ['options', 'selectedOptions'] {
		host.accessor(mut select_prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			element := host.form_control_receiver(mut vm, 'select')!
			persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
			mut model := prepare_libjs_select(element)
			mut owner := unsafe { &Host(host) }; return owner.wrap_select_collection(model.options(), name == 'selectedOptions')
		}, unsafe { nil })
	}
	for on_select in [false, true] {
		mut target := if on_select { select_prototype } else { prototype }
		for name in if on_select { ['length'] } else { ['length', 'selectedIndex'] } {
			host.accessor(mut target, name, fn [host, on_select, name] (mut vm libjs.VM) !libjs.Value {
				persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
				native := host.select_collection_receiver(mut vm, on_select)!
				return libjs.Value.from_f64(f64(if name == 'length' { int(native.length()) } else { int(native.selected_index()) }))
			}, fn [host, on_select, name] (mut vm libjs.VM) !libjs.Value {
				persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
				native := host.select_collection_receiver(mut vm, on_select)!
				mut owner := unsafe { &Host(host) }
				if name == 'length' { native.set_length(vm.argument(0).to_u32(mut vm)!) or { return owner.dom_error(mut vm, err) } }
				else { native.set_selected_index(vm.argument(0).to_i32(mut vm)!) }
				owner.finish_form_mutation(); return libjs.js_undefined()
			})
		}
		for name in if on_select { ['add', 'remove', 'item', 'namedItem'] } else { ['add', 'remove'] } {
			host.method_attributes(mut target, name, if name == 'remove' && on_select { 0 } else { 1 }, fn [host, on_select, name] (mut vm libjs.VM) !libjs.Value {
				persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
				native := host.select_collection_receiver(mut vm, on_select)!
				mut owner := unsafe { &Host(host) }
				if name == 'remove' && on_select && vm.argument_count() == 0 {
					mut node := unsafe { &dom.Element(native.select_element) }.as_node(); node.remove(false)
				} else {
					if vm.argument_count() == 0 { return vm.throw_error(.type_error, '${name} requires an argument') }
					if name == 'add' { host.add_select_option(mut vm, native) or { return owner.dom_error(mut vm, err) } }
					else if name == 'remove' { native.remove(vm.argument(0).to_i32(mut vm)!) }
					else {
						option := if name == 'item' { native.item(vm.argument(0).to_u32(mut vm)!) } else { native.named_item(vm.argument(0).to_primitive_string(mut vm)!.str()) }
						return if element := option { owner.wrap_node(unsafe { &dom.Element(element) }.as_node()) } else { libjs.js_null() }
					}
				}
				owner.finish_form_mutation(); return libjs.js_undefined()
			}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
		}
	}
}
