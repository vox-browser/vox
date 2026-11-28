// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import encoding
import libjs
import platform

fn (host &Host) text_encoder_receiver(mut vm libjs.VM) !&encoding.TextEncoder {
	host.require_open(mut vm)!
	if vm.this_value().is_object() { if encoder := host.text_encoders[voidptr(vm.this_value().as_object())] { return encoder } }
	return vm.throw_error(.type_error, 'TextEncoder method called on incompatible receiver')
}

fn (host &Host) text_decoder_receiver(mut vm libjs.VM) !&encoding.TextDecoder {
	host.require_open(mut vm)!
	if vm.this_value().is_object() { if decoder := host.text_decoders[voidptr(vm.this_value().as_object())] { return decoder } }
	return vm.throw_error(.type_error, 'TextDecoder method called on incompatible receiver')
}

fn text_encoding_dictionary(mut vm libjs.VM, value libjs.Value) ! {
	if !value.is_nullish() && !value.is_object() { return vm.throw_error(.type_error, 'Text encoding options must be an object') }
}

fn text_encoding_member(mut vm libjs.VM, value libjs.Value, name string) !libjs.Value {
	return if value.is_object() { value.as_object().get(mut vm, libjs.PropertyName.from_str(name))! } else { libjs.js_undefined() }
}

fn (mut host Host) install_text_encoding() {
	mut vm := host.vm
	mut encoder := libjs.Object.create(host.realm, host.realm.object_prototype)
	mut decoder := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.text_encoder_prototype, host.text_decoder_prototype = encoder, decoder
	for is_encoder in [true, false] {
		name := if is_encoder { 'TextEncoder' } else { 'TextDecoder' }
		mut prototype := if is_encoder { encoder } else { decoder }
		construct := fn [host, is_encoder] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
			host.require_open(mut vm)!
			mut label := 'utf-8'
			mut fatal := false
			mut ignore_bom := false
			if !is_encoder {
				if !vm.argument(0).is_undefined() { label = vm.argument(0).to_primitive_string(mut vm)!.str() }
				options := vm.argument(1)
				text_encoding_dictionary(mut vm, options)!
				fatal = text_encoding_member(mut vm, options, 'fatal')!.to_boolean()
				ignore_bom = text_encoding_member(mut vm, options, 'ignoreBOM')!.to_boolean()
			}
			parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			mut object := libjs.Object.create(host.realm, if parent.is_object() { parent.as_object() } else if is_encoder { host.text_encoder_prototype } else { host.text_decoder_prototype })
			object.class_name = if is_encoder { 'TextEncoder' } else { 'TextDecoder' }
			if is_encoder { owner.text_encoders[voidptr(object)] = encoding.TextEncoder.construct_impl() }
			else {
				native := encoding.TextDecoder.construct_impl(label, encoding.TextDecoderOptions{fatal: fatal, ignore_bom: ignore_bom}) or { return vm.throw_error(.range_error, err.msg()) }
				owner.text_decoders[voidptr(object)] = native
			}
			return object
		}
		host.closures << voidptr(construct)
		mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
			fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Text encoding constructor requires new') },
			construct, 0, libjs.PropertyName.from_str(name)).object
		constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
		prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
		prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str(name)), libjs.attribute_configurable)
		mut global := host.realm.global_object_record()
		global.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	}
	host.accessor(mut encoder, 'encoding', fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.text_encoder_receiver(mut vm)!
		return libjs.Value.from_string(vm.create_string_from_str(native.encoding()))
	}, unsafe { nil })
	for name in ['encoding', 'fatal', 'ignoreBOM'] {
		host.accessor(mut decoder, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.text_decoder_receiver(mut vm)!
			return match name {
				'fatal' { libjs.Value.from_bool(native.fatal()) }
				'ignoreBOM' { libjs.Value.from_bool(native.ignore_bom()) }
				else { libjs.Value.from_string(vm.create_string_from_str(native.encoding())) }
			}
		}, unsafe { nil })
	}
	attributes := libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable
	host.method_attributes(mut encoder, 'encode', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.text_encoder_receiver(mut vm)!
		source := if vm.argument(0).is_undefined() { '' } else { vm.argument(0).to_primitive_string(mut vm)!.utf16.to_well_formed_utf8() }
		charge_buffer_source_work(mut vm, u64(source.len))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		return host.uint8_array_from_bytes(native.encode(source))
	}, attributes)
	host.method_attributes(mut encoder, 'encodeInto', 2, fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.text_encoder_receiver(mut vm)!
		if vm.argument_count() < 2 { return vm.throw_error(.type_error, 'TextEncoder.encodeInto requires source and destination') }
		source := vm.argument(0).to_primitive_string(mut vm)!.utf16.to_well_formed_utf8()
		if !vm.argument(1).is_object() { return vm.throw_error(.type_error, 'TextEncoder destination must be a Uint8Array') }
		array := vm.argument(1).as_object().typed_array or { return vm.throw_error(.type_error, 'TextEncoder destination must be a Uint8Array') }
		if array.kind != .uint8 { return vm.throw_error(.type_error, 'TextEncoder destination must be a Uint8Array') }
		if !array.viewed_buffer.is_fixed_length() { return vm.throw_error(.type_error, 'TextEncoder destination must have a fixed-length buffer') }
		record := libjs.make_typed_array_with_buffer_witness_record(array, .seq_cst)
		length := if libjs.is_typed_array_out_of_bounds(record) { 0 } else { int(libjs.typed_array_byte_length(record)) }
		capacity := if source.len < length { source.len } else { length }
		charge_buffer_source_work(mut vm, u64(source.len))!
		mut bytes := []u8{len: capacity}
		counts := native.encode_into_result(source, mut bytes)
		mut buffer := array.viewed_buffer
		if counts.written > 0 {
			if buffer.is_shared_array_buffer() {
				for index in 0 .. int(counts.written) { buffer.set_value(mut vm, uint(array.byte_offset) + uint(index), .uint8, libjs.Value.from_i32(i32(bytes[index])), true, .unordered, true) }
			} else { buffer.overwrite(uint(array.byte_offset), bytes[..int(counts.written)]) }
		}
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut result := libjs.Object.create(host.realm, host.realm.object_prototype)
		result.define_direct_property(libjs.PropertyName.from_str('read'), libjs.Value.from_f64(f64(counts.read)), libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
		result.define_direct_property(libjs.PropertyName.from_str('written'), libjs.Value.from_f64(f64(counts.written)), libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
		return libjs.Value.from_object(result)
	}, attributes)
	host.method_attributes(mut decoder, 'decode', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.text_decoder_receiver(mut vm)!
		input := vm.argument(0)
		object := if input.is_undefined() { ?&libjs.Object(none) } else { ?&libjs.Object(native_buffer_source(mut vm, input, true)!) }
		options := vm.argument(1)
		text_encoding_dictionary(mut vm, options)!
		stream := text_encoding_member(mut vm, options, 'stream')!.to_boolean()
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		bytes := if source := object { copy_native_buffer_source(mut vm, source)! } else { []u8{} }
		decoded := native.decode(bytes, encoding.TextDecodeOptions{stream: stream}) or { return vm.throw_error(.type_error, err.msg()) }
		return libjs.Value.from_string(vm.create_string_from_str(decoded))
	}, attributes)
}
