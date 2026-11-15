// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import fileapi
import libjs
import platform
import webidl

// WebIDL's union conversion retains BufferSource/Blob identity. The Blob
// constructor copies their bytes only after all later argument conversions.
struct BlobBindingPart {
	text string
	buffer ?&libjs.Object
	blob ?&fileapi.Blob
}

fn (host &Host) blob_part(mut vm libjs.VM, value libjs.Value) !BlobBindingPart {
	if value.is_object() {
		object := value.as_object()
		if blob := host.blobs[voidptr(object)] { return BlobBindingPart{blob: blob} }
		if object.array_buffer != none || object.typed_array != none || object.data_view != none {
			return BlobBindingPart{buffer: native_buffer_source(mut vm, value, false)!}
		}
	}
	return BlobBindingPart{text: value.to_primitive_string(mut vm)!.utf16.to_well_formed_utf8()}
}

fn (host &Host) blob_parts(mut vm libjs.VM, value libjs.Value) ![]BlobBindingPart {
	if value.is_undefined() { return []BlobBindingPart{} }
	if !value.is_object() { return vm.throw_error(.type_error, 'Blob parts must be an iterable object') }
	mut iterator := libjs.get_iterator_sync_value(mut vm, value)!
	mut parts := []BlobBindingPart{}
	for {
		vm.consume_execution_budget()!
		step := libjs.iterator_step_value(mut vm, mut iterator)!
		if step.done { return parts }
		part := host.blob_part(mut vm, step.value) or {
			return libjs.iterator_close(mut vm, iterator, libjs.completion_from_error(err)).release_error()
		}
		parts << part
	}
	return parts
}

fn blob_options(mut vm libjs.VM, value libjs.Value) !fileapi.BlobPropertyBag {
	if !value.is_nullish() && !value.is_object() { return vm.throw_error(.type_error, 'Blob options must be an object') }
	ending_value := text_encoding_member(mut vm, value, 'endings')!
	ending := if ending_value.is_undefined() { 'transparent' } else { ending_value.to_primitive_string(mut vm)!.str() }
	if ending !in ['transparent', 'native'] { return vm.throw_error(.type_error, 'Invalid Blob endings') }
	type_value := text_encoding_member(mut vm, value, 'type')!
	return fileapi.BlobPropertyBag{
		type_: if type_value.is_undefined() { '' } else { type_value.to_primitive_string(mut vm)!.str() }
		endings: if ending == 'native' { .native } else { .transparent }
	}
}

fn materialize_blob_parts(mut vm libjs.VM, pending []BlobBindingPart) ![]fileapi.BlobPart {
	mut parts := []fileapi.BlobPart{cap: pending.len}
	mut total := u64(0)
	for part in pending {
		vm.consume_execution_budget()!
		mut size := u64(part.text.len)
		if blob := part.blob { size = blob.size() }
		else if buffer := part.buffer {
			bytes := copy_native_buffer_source(mut vm, buffer)!
			size = u64(bytes.len)
			if size > u64(0x7fffffff) - total { return vm.throw_error(.range_error, 'Blob exceeds the native byte-vector limit') }
			total += size; parts << fileapi.BlobPart.from_bytes(bytes)
			continue
		}
		if size > u64(0x7fffffff) - total { return vm.throw_error(.range_error, 'Blob exceeds the native byte-vector limit') }
		total += size
		if blob := part.blob { parts << fileapi.BlobPart.from_blob(blob) }
		else { parts << fileapi.BlobPart.from_string(part.text) }
	}
	charge_buffer_source_work(mut vm, total)!
	return parts
}

fn (mut host Host) wrap_blob(native &fileapi.Blob, parent ?&libjs.Object) libjs.Value {
	if wrapper := host.blob_wrappers[voidptr(native)] { return libjs.Value.from_object(wrapper) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := libjs.Object.create(host.realm, parent or { host.blob_prototype })
	object.class_name = 'Blob'
	host.blobs[voidptr(object)] = native
	host.blob_wrappers[voidptr(native)] = object
	return libjs.Value.from_object(object)
}

fn (host &Host) blob_receiver(mut vm libjs.VM) !&fileapi.Blob {
	host.require_open(mut vm)!
	if vm.this_value().is_object() { if blob := host.blobs[voidptr(vm.this_value().as_object())] { return blob } }
	return vm.throw_error(.type_error, 'Blob member called on incompatible receiver')
}

fn blob_slice_position(mut vm libjs.VM, value libjs.Value) !i64 {
	// ToNumber runs on the actual JS value once; the existing WebIDL helper
	// supplies signed 64-bit Clamp, including NaN, infinities and ties to even.
	number := value.to_number(mut vm)!.number
	return i64(webidl.convert_to_int(webidl.number_value(number), 64, true, .no, .yes)!)
}

fn blob_relative_position(position ?i64, size i64, fallback i64) i64 {
	value := position or { return fallback }
	if value < 0 { return if size + value < 0 { 0 } else { size + value } }
	return if value > size { size } else { value }
}

fn (mut host Host) install_blobs() {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.blob_prototype = prototype
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		pending := host.blob_parts(mut vm, vm.argument(0))!
		options := blob_options(mut vm, vm.argument(1))!
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		parts := materialize_blob_parts(mut vm, pending)!
		native := fileapi.Blob.construct_impl(parts, options)
		mut owner := unsafe { &Host(host) }
		return owner.wrap_blob(native, if parent.is_object() { ?&libjs.Object(parent.as_object()) } else { none }).as_object()
	}
	host.closures << voidptr(construct)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Blob constructor requires new') },
		construct, 0, libjs.PropertyName.from_str('Blob')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('Blob')), libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('Blob'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	for name in ['size', 'type'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.blob_receiver(mut vm)!
			return if name == 'size' { libjs.Value.from_f64(f64(native.size())) } else { libjs.Value.from_string(vm.create_string(native.type_utf16())) }
		}, unsafe { nil })
	}
	attributes := libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable
	host.method_attributes(mut prototype, 'slice', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.blob_receiver(mut vm)!
		start := if vm.argument(0).is_undefined() { ?i64(none) } else { ?i64(blob_slice_position(mut vm, vm.argument(0))!) }
		end := if vm.argument(1).is_undefined() { ?i64(none) } else { ?i64(blob_slice_position(mut vm, vm.argument(1))!) }
		type_ := if vm.argument(2).is_undefined() { ?string(none) } else { ?string(vm.argument(2).to_primitive_string(mut vm)!.str()) }
		size := i64(native.size())
		first := blob_relative_position(start, size, 0)
		last := blob_relative_position(end, size, size)
		charge_buffer_source_work(mut vm, u64(if last > first { last - first } else { 0 }))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		return owner.wrap_blob(native.slice_blob(start, end, type_), none)
	}, attributes)
	for method in ['text', 'arrayBuffer', 'bytes'] {
		host.method_attributes(mut prototype, method, 0, fn [host, method] (mut vm libjs.VM) !libjs.Value {
			// Promise-returning WebIDL operations reject receiver failures.
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			capability := libjs.new_promise_capability(mut vm, libjs.Value.from_object(host.realm.promise_constructor_record()))!
			native := host.blob_receiver(mut vm) or {
				libjs.call(mut vm, capability.reject, libjs.js_undefined(), [libjs.thrown_value(err)])!
				return capability.promise
			}
			mut owner := unsafe { &Host(host) }
			owner.queue_blob_read(mut vm, native, method, capability) or {
				libjs.call(mut vm, capability.reject, libjs.js_undefined(), [host.fetch_error_value(mut vm, err)])!
			}
			return capability.promise
		}, attributes)
	}
}
