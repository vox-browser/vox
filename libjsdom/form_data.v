// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import fileapi
import html
import libjs
import platform
import xhr

fn (mut host Host) wrap_form_data(native &xhr.FormData, parent ?&libjs.Object) libjs.Value {
	if object := host.form_data_wrappers[voidptr(native)] { return libjs.Value.from_object(object) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := libjs.Object.create(host.realm, parent or { host.form_data_prototype })
	object.class_name = 'FormData'
	host.form_data[voidptr(object)] = native
	host.form_data_wrappers[voidptr(native)] = object
	return libjs.Value.from_object(object)
}

fn (host &Host) form_data_value(mut vm libjs.VM, value libjs.Value) !&xhr.FormData {
	host.require_open(mut vm)!
	if value.is_object() { if data := host.form_data[voidptr(value.as_object())] { return data } }
	return vm.throw_error(.type_error, 'Expected a FormData object')
}

fn (host &Host) form_data_element(mut vm libjs.VM, value libjs.Value, form bool) !&dom.Element {
	if value.is_object() {
		if node := host.nodes[voidptr(value.as_object())] {
			if element := node.as_element() {
				if element.is_html_element() && (!form || element.local_name() == 'form') { return element }
			}
		}
	}
	return vm.throw_error(.type_error, if form { 'Expected an HTMLFormElement' } else { 'Expected an HTMLElement' })
}

fn (mut host Host) form_entry_value(mut vm libjs.VM, value xhr.FormDataEntryValue) libjs.Value {
	return match value {
		string { libjs.Value.from_string(vm.create_string_from_str(value)) }
		xhr.FormDataFile { host.wrap_file(value.file, none) }
	}
}

fn (mut host Host) install_form_data() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.form_data_prototype = prototype
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		form := if vm.argument(0).is_undefined() { ?&dom.Element(none) } else { ?&dom.Element(host.form_data_element(mut vm, vm.argument(0), true)!) }
		submitter := if vm.argument(1).is_nullish() { ?&dom.Element(none) } else { ?&dom.Element(host.form_data_element(mut vm, vm.argument(1), false)!) }
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		mut owner := unsafe { &Host(host) }
		mut native := xhr.FormData.create()
		if element := form {
			model := html.HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(element) })
			mut control := ?&html.FormAssociatedElement(none)
			if button := submitter {
				control = match button.local_name() {
					'button' { html.HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(button) }).control }
					'input' { html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(button) }).control }
					else { html.FormAssociatedElement.create(button) }
				}
			}
			native = xhr.FormData.create_from_form(model, control) or { return owner.dom_error(mut vm, err) }
		}
		return owner.wrap_form_data(native, if parent.is_object() { ?&libjs.Object(parent.as_object()) } else { none }).as_object()
	}
	host.closures << voidptr(construct)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'FormData requires new') }, construct, 0, libjs.PropertyName.from_str('FormData')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('FormData')), libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('FormData'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	attributes := libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable
	for method in ['append', 'set', 'delete', 'get', 'getAll', 'has'] {
		host.method_attributes(mut prototype, method, if method in ['append', 'set'] { 2 } else { 1 }, fn [host, method] (mut vm libjs.VM) !libjs.Value {
			mut native := unsafe { &xhr.FormData(host.form_data_value(mut vm, vm.this_value())!) }
			writes := method in ['append', 'set']
			if vm.argument_count() < if writes { 2 } else { 1 } { return vm.throw_error(.type_error, 'Missing FormData arguments') }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			// Three arguments select the Blob overload before conversions. An
			// explicitly undefined filename still selects that overload.
			mut blob := ?&fileapi.Blob(none)
			if writes && vm.argument(1).is_object() {
				if actual := host.blobs[voidptr(vm.argument(1).as_object())] { blob = actual }
			}
			if writes && vm.argument_count() >= 3 && blob == none { return vm.throw_error(.type_error, 'FormData filename requires a Blob value') }
			name := query_usv(mut vm, vm.argument(0))!
			if writes {
				if actual := blob {
					filename := if vm.argument(2).is_undefined() { ?string(none) } else { ?string(query_usv(mut vm, vm.argument(2))!) }
					if file := host.files[voidptr(vm.argument(1).as_object())] {
						if filename != none { charge_buffer_source_work(mut vm, actual.size())! }
						if method == 'append' { native.append_file(name, file, filename) } else { native.set_file(name, file, filename) }
					} else {
						charge_buffer_source_work(mut vm, actual.size())!
						if method == 'append' { native.append_blob(name, actual, filename) } else { native.set_blob(name, actual, filename) }
					}
				} else {
					value := query_usv(mut vm, vm.argument(1))!
					if method == 'append' { native.append(name, value) } else { native.set(name, value) }
				}
				return libjs.js_undefined()
			}
			if method == 'delete' { native.delete(name); return libjs.js_undefined() }
			if method == 'has' { return libjs.Value.from_bool(native.has(name)) }
			if method == 'get' { return if value := native.get(name) { owner.form_entry_value(mut vm, value) } else { libjs.js_null() } }
			mut values := []libjs.Value{}
			for value in native.get_all(name) { vm.consume_execution_budget()!; values << owner.form_entry_value(mut vm, value) }
			return libjs.Value.from_object(libjs.ArrayObject.create_from(mut vm, host.realm, values, host.realm.array_prototype_record())!.object)
		}, attributes)
	}
	host.install_form_data_iteration(mut prototype)!
	host.install_form_data_events()!
}
