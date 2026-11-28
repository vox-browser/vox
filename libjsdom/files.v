// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import fileapi
import libjs
import platform
import webidl

fn file_options(mut vm libjs.VM, value libjs.Value) !fileapi.FilePropertyBag {
	if !value.is_nullish() && !value.is_object() { return vm.throw_error(.type_error, 'File options must be an object') }
	ending_value := text_encoding_member(mut vm, value, 'endings')!
	ending := if ending_value.is_undefined() { 'transparent' } else { ending_value.to_primitive_string(mut vm)!.str() }
	if ending !in ['transparent', 'native'] { return vm.throw_error(.type_error, 'Invalid File endings') }
	modified_value := text_encoding_member(mut vm, value, 'lastModified')!
	modified := if modified_value.is_undefined() { ?i64(none) } else {
		number := modified_value.to_number(mut vm)!.number
		?i64(i64(webidl.convert_to_int(webidl.number_value(number), 64, true, .no, .no)!))
	}
	type_value := text_encoding_member(mut vm, value, 'type')!
	return fileapi.FilePropertyBag{
		BlobPropertyBag: fileapi.BlobPropertyBag{endings: if ending == 'native' { .native } else { .transparent }, type_: if type_value.is_undefined() { '' } else { type_value.to_primitive_string(mut vm)!.str() }}
		last_modified: modified
	}
}

fn (mut host Host) wrap_file(native &fileapi.File, parent ?&libjs.Object) libjs.Value {
	if wrapper := host.file_wrappers[voidptr(native)] { return libjs.Value.from_object(wrapper) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := libjs.Object.create(host.realm, parent or { host.file_prototype })
	object.class_name = 'File'
	host.files[voidptr(object)] = native
	host.file_wrappers[voidptr(native)] = object
	host.blobs[voidptr(object)] = native.as_blob()
	host.blob_wrappers[voidptr(native.as_blob())] = object
	return libjs.Value.from_object(object)
}

fn (host &Host) file_receiver(mut vm libjs.VM) !&fileapi.File {
	host.require_open(mut vm)!
	if vm.this_value().is_object() { if file := host.files[voidptr(vm.this_value().as_object())] { return file } }
	return vm.throw_error(.type_error, 'File member called on incompatible receiver')
}

fn (mut host Host) install_files() {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.blob_prototype)
	host.file_prototype = prototype
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		if vm.argument_count() < 2 { return vm.throw_error(.type_error, 'File requires bits and a filename') }
		if !vm.argument(0).is_object() { return vm.throw_error(.type_error, 'File bits must be an iterable object') }
		pending := host.blob_parts(mut vm, vm.argument(0))!
		name := query_usv(mut vm, vm.argument(1))!
		options := file_options(mut vm, vm.argument(2))!
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		native := fileapi.File.construct_impl(materialize_blob_parts(mut vm, pending)!, name, options)
		mut owner := unsafe { &Host(host) }
		return owner.wrap_file(native, if parent.is_object() { ?&libjs.Object(parent.as_object()) } else { none }).as_object()
	}
	host.closures << voidptr(construct)
	mut global := host.realm.global_object_record()
	blob_constructor := global.get(mut vm, libjs.PropertyName.from_str('Blob')) or { panic(err) }
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, blob_constructor.as_object(),
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'File requires new') }, construct, 2, libjs.PropertyName.from_str('File')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('File')), libjs.attribute_configurable)
	global.define_direct_property(libjs.PropertyName.from_str('File'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	for name in ['name', 'lastModified'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.file_receiver(mut vm)!
			return if name == 'name' { libjs.Value.from_string(vm.create_string(native.name_utf16())) } else { libjs.Value.from_f64(f64(native.last_modified())) }
		}, unsafe { nil })
	}
}
