module libjs

@[heap]
struct TypedSpeciesLog {
mut:
	events    []string
	arguments []Value
}

fn test_typed_array_default_factories_use_requested_realm_and_concrete_kind_without_construct() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	local := vm.realm()
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	parent := Object.create(local, none)
	foreign_parent := Object.create(foreign, none)
	for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
		.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
		mut buffer := ArrayBufferObject.create(mut vm, local, 0, parent)!
		exemplar := TypedArray.create(local, kind, 0, buffer, parent)
		getter := fn [foreign, foreign_parent, kind] (realm &Realm, requested BufferElementType) &Object {
			assert voidptr(realm) == voidptr(foreign) && requested == kind
			return foreign_parent
		}
		result := exemplar.create_default(mut vm, foreign, 3, getter)!
		assert result.kind == kind && result.array_length.length() == 3
		assert result.byte_length.length() == 3 * kind.size() && result.byte_offset == 0
		assert result.viewed_buffer.read_bytes(0, result.viewed_buffer.byte_length()) == []u8{len: int(3 * kind.size())}
		assert voidptr(result.object.prototype?) == voidptr(foreign_parent)
		assert voidptr(result.viewed_buffer.object.prototype?) == voidptr(foreign.array_buffer_prototype_record())
		assert !result.viewed_buffer.shares_storage_with(buffer)
		view := exemplar.create_default_view_on_buffer(foreign, buffer, getter)
		assert view.kind == kind && view.array_length.length() == 0
		assert voidptr(view.viewed_buffer) == voidptr(buffer)
		assert voidptr(view.object.prototype?) == voidptr(foreign_parent)
		detach_array_buffer(mut vm, mut buffer, none)!
		detached_view := exemplar.create_default_view_on_buffer(foreign, buffer, getter)
		assert detached_view.viewed_buffer.is_detached()
		if _ := exemplar.create_default(mut vm, foreign, u32(0x7fffffff) / u32(kind.size()) + 1,
			getter)
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
		}
	}
}

fn test_typed_array_species_default_identity_uses_fast_factory_after_lookup() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	for mode in ['undefined constructor', 'undefined species', 'null species', 'default species'] {
		buffer := ArrayBufferObject.create(mut vm, realm, 0, parent)!
		exemplar := TypedArray.create(realm, .uint8, 0, buffer, parent)
		mut log := &TypedSpeciesLog{}
		constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
			return js_undefined()
		}, fn (mut vm VM, target &Object) !&Object {
			return throw_completion(Value.from_i32(99))
		}, 1, PropertyName.from_str('Intrinsic'))
		mut holder := Object.create(realm, none)
		holder.define_native_accessor(mut vm, realm,
			PropertyName.from_symbol(vm.well_known_symbol_species()), fn [mode, constructor, mut log] (mut vm VM) !Value {
			log.events << 'species'
			return match mode {
				'null species' { js_null() }
				'default species' { Value.from_object(constructor.object) }
				else { js_undefined() }
			}
		}, unsafe { nil }, attribute_configurable, realm.function_prototype)
		mut object := exemplar.object
		object.define_native_accessor(mut vm, realm, PropertyName.from_str('constructor'), fn [mode, holder, mut log] (mut vm VM) !Value {
			log.events << 'constructor'
			return if mode == 'undefined constructor' {
				js_undefined()
			} else {
				Value.from_object(holder)
			}
		}, unsafe { nil }, attribute_configurable, realm.function_prototype)
		lookup := fn [realm, constructor, mut log] (requested &Realm, kind BufferElementType) &Object {
			assert voidptr(requested) == voidptr(realm) && kind == .uint8
			log.events << 'intrinsic'
			return constructor.object
		}
		factory := fn [exemplar, realm, parent, mut log] (mut vm VM) !&TypedArray {
			log.events << 'factory'
			getter := fn [parent] (realm &Realm, kind BufferElementType) &Object {
				return parent
			}
			return exemplar.create_default(mut vm, realm, 2, getter)
		}
		result := typed_array_species_create(mut vm, exemplar, factory, [
			Value.from_i32(2),
		], lookup)!
		assert result.array_length.length() == 2
		assert log.events == if mode == 'undefined constructor' {
			['intrinsic', 'constructor', 'factory']
		} else {
			['intrinsic', 'constructor', 'species', 'factory']
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_typed_array_species_custom_constructor_validation_and_content_type_order() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	for mode in ['valid', 'short', 'detached', 'out of bounds', 'wrong content', 'fake', 'throw',
		'invalid species', 'constructor throws'] {
		buffer := ArrayBufferObject.create(mut vm, realm, 0, parent)!
		exemplar := TypedArray.create(realm, .uint8, 0, buffer, parent)
		mut destination_buffer := ArrayBufferObject.create(mut vm, realm, 32, parent)!
		destination_buffer.maximum_byte_length = uint(64)
		kind := if mode == 'wrong content' {
			BufferElementType.big_int64
		} else {
			BufferElementType.int16
		}
		result := TypedArray.create(realm, kind, if mode == 'short' { u32(1) } else { u32(4) },
			destination_buffer, parent)
		if mode == 'detached' { detach_array_buffer(mut vm, mut destination_buffer, none)! }
		if mode == 'out of bounds' { assert destination_buffer.try_resize(1, true)
		 }
		mut log := &TypedSpeciesLog{}
		constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
			return js_undefined()
		}, fn [mode, result, parent, mut log] (mut vm VM, target &Object) !&Object {
			log.events << 'construct'
			log.arguments = vm.running_execution_context().arguments().clone()
			if mode == 'throw' { return throw_completion(Value.from_i32(77)) }
			return if mode == 'fake' { parent } else { result.object }
		}, 1, PropertyName.from_str('Species'))
		mut holder := Object.create(realm, none)
		holder.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_species()), if mode == 'invalid species' {
			Value.from_i32(42)
		} else {
			Value.from_object(constructor.object)
		}, 7)
		mut object := exemplar.object
		object.define_native_accessor(mut vm, realm, PropertyName.from_str('constructor'), fn [holder, mode] (mut vm VM) !Value {
			if mode == 'constructor throws' { return throw_completion(Value.from_i32(88)) }
			return Value.from_object(holder)
		}, unsafe { nil }, attribute_configurable, realm.function_prototype)
		default_constructor := NativeFunction.create_constructor(mut vm, realm,
			realm.function_prototype, fn (mut vm VM) !Value {
			return js_undefined()
		}, fn (mut vm VM, target &Object) !&Object {
			panic('fast constructor must not run')
		}, 1, PropertyName.from_str('Default'))
		lookup := fn [default_constructor] (realm &Realm, kind BufferElementType) &Object {
			return default_constructor.object
		}
		factory := fn (mut vm VM) !&TypedArray {
			panic('custom species must not call default factory')
		}
		if actual := typed_array_species_create(mut vm, exemplar, factory, [
			Value.from_i32(3),
		], lookup)
		{
			assert mode == 'valid' && voidptr(actual) == voidptr(result)
		} else {
			assert mode != 'valid'
			value := thrown_value(err)
			if mode == 'throw' {
				assert value.number == 77
			} else if mode == 'constructor throws' {
				assert value.number == 88
			} else {
				assert value.as_object().error_kind()? == .type_error
				if mode == 'wrong content' { assert value.as_object().error_message()?.str() == "Can't create BigInt64Array from Uint8Array"
				 }
			}
		}
		if mode !in ['invalid species', 'constructor throws'] {
			assert log.events == ['construct'] && log.arguments == [Value.from_i32(3)]
		} else {
			assert log.events.len == 0
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}
