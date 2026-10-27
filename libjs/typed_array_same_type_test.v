module libjs

@[heap]
struct TypedSameTypeLog {
mut:
	lookups   int
	arguments []Value
}

fn test_typed_array_create_same_type_looks_up_current_realm_intrinsic_without_reading_constructor() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	local := vm.realm()
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	parent := Object.create(local, none)
	foreign_parent := Object.create(foreign, none)
	for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
		.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
		buffer := ArrayBufferObject.create(mut vm, foreign, 0, foreign_parent)!
		exemplar := TypedArray.create(foreign, kind, 0, buffer, foreign_parent)
		mut object := exemplar.object
		object.define_native_accessor(mut vm, foreign, PropertyName.from_str('constructor'), fn (mut vm VM) !Value {
			return throw_completion(Value.from_i32(99))
		}, unsafe { nil }, attribute_configurable, foreign.function_prototype)
		mut log := &TypedSameTypeLog{}
		constructor := NativeFunction.create_constructor(mut vm, local, local.function_prototype, fn (mut vm VM) !Value {
			return js_undefined()
		}, fn [kind, parent, mut log] (mut vm VM, target &Object) !&Object {
			log.arguments = vm.running_execution_context().arguments().clone()
			getter := fn [parent] (realm &Realm) &Object {
				return parent
			}
			return construct_typed_array(mut vm, kind, target, getter)!.object
		}, 3, PropertyName.from_str('Host'))
		getter := fn [local, kind, constructor, mut log] (realm &Realm, requested BufferElementType) &Object {
			assert voidptr(realm) == voidptr(local) && requested == kind
			log.lookups++
			return constructor.object
		}
		result := typed_array_create_same_type(mut vm, exemplar, [
			Value.from_i32(3)], getter)!
		assert result.kind == kind && result.array_length.length() == 3
		assert voidptr(result.object.prototype?) == voidptr(parent)
		assert !result.viewed_buffer.shares_storage_with(buffer)
		assert log.lookups == 1 && log.arguments == [Value.from_i32(3)]
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_typed_array_create_same_type_propagates_constructor_errors_and_result_validation() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for mode in ['throw', 'fake', 'short', 'detached', 'out of bounds'] {
		mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 2, parent)!
		buffer.maximum_byte_length = uint(4)
		exemplar := TypedArray.create(vm.realm(), .uint8, 2, buffer, parent)
		result := if mode == 'fake' { parent } else { exemplar.object }
		if mode == 'detached' { detach_array_buffer(mut vm, mut buffer, none)! }
		if mode == 'out of bounds' { assert buffer.try_resize(1, true)
		 }
		constructor := NativeFunction.create_constructor(mut vm, vm.realm(),
			vm.realm().function_prototype, fn (mut vm VM) !Value {
			return js_undefined()
		}, fn [mode, result] (mut vm VM, target &Object) !&Object {
			assert vm.argument_count() == 1 && vm.argument(0).number == 3
			if mode == 'throw' { return throw_completion(Value.from_i32(99)) }
			return result
		}, 1, PropertyName.from_str('Host'))
		getter := fn [constructor] (realm &Realm, kind BufferElementType) &Object {
			return constructor.object
		}
		if _ := typed_array_create_same_type(mut vm, exemplar, [
			Value.from_i32(3)], getter)
		{
			assert false
		} else {
			if mode == 'throw' {
				assert thrown_value(err).number == 99
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}
