module libjs

@[heap]
struct CachedAccessorState {
mut:
	calls int
}

fn counting_cached_getter(mut vm VM, mut state CachedAccessorState) &Object {
	function := NativeFunction.create(mut vm, vm.realm(), none, fn [mut state] (mut vm VM) !Value {
		state.calls++
		return Value.from_i32(state.calls)
	}, 0, PropertyName.from_str('value'), 'get')
	return function.object
}

fn test_cached_accessor_values_are_shared_only_with_holder_and_direct_children() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut state := &CachedAccessorState{}
	getter := counting_cached_getter(mut vm, mut state)
	key := PropertyName.from_str('value')
	mut holder := Object.create(vm.realm(), none)
	holder.define_direct_cached_accessor(key, getter, none, attribute_configurable)
	child := Object.create(vm.realm(), holder)
	grandchild := Object.create(vm.realm(), child)
	assert child.get(mut vm, key)!.number == 1
	assert holder.get(mut vm, key)!.number == 1
	assert child.get(mut vm, key)!.number == 1
	assert grandchild.get(mut vm, key)!.number == 2
	assert grandchild.get(mut vm, key)!.number == 3
	assert holder.internal_get(mut vm, key, js_null())!.number == 4
	assert holder.get(mut vm, key)!.number == 1
	assert state.calls == 4
	assert holder.own_property_keys().len == 1
	accessor := holder.get_without_side_effects(key).as_accessor()
	cache_key := accessor.cached_value_key?
	assert cache_key.is_private()
	assert holder.get_engine_private_property(cache_key)?.value.number == 1
	// Private caches can be cleared even after preventing ordinary extensions.
	assert holder.internal_prevent_extensions()
	holder.clear_cached_accessor_value(key)
	assert holder.get_engine_private_property(cache_key) == none
	assert holder.get(mut vm, key)!.number == 5
	assert holder.get(mut vm, key)!.number == 5
	assert state.calls == 5
}

fn test_cached_undefined_is_distinct_from_an_absent_cache_entry() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut state := &CachedAccessorState{}
	function := NativeFunction.create(mut vm, vm.realm(), none, fn [mut state] (mut vm VM) !Value {
		state.calls++
		return js_undefined()
	}, 0, PropertyName.from_str('value'), 'get')
	mut holder := Object.create(vm.realm(), none)
	key := PropertyName.from_str('value')
	holder.define_direct_cached_accessor(key, function.object, none, 0)
	assert holder.get(mut vm, key)!.is_undefined()
	assert holder.get(mut vm, key)!.is_undefined()
	assert state.calls == 1
	cache_key := holder.get_without_side_effects(key).as_accessor().cached_value_key?
	assert holder.get_engine_private_property(cache_key)?.value.is_undefined()
}

fn test_getters_replacing_or_deleting_their_accessor_cannot_publish_stale_cache_values() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	key := PropertyName.from_str('value')
	for action in ['delete', 'data', 'accessor'] {
		mut holder := Object.create(vm.realm(), none)
		replacement := NativeFunction.create(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
			return Value.from_i32(42)
		}, 0, key, 'get')
		getter := NativeFunction.create(mut vm, vm.realm(), none, fn [mut holder, key, action, replacement] (mut vm VM) !Value {
			assert holder.internal_delete(key)
			if action == 'data' { holder.create_data_property(mut vm, key, Value.from_i32(42)) or {
					panic(err)} }
			if action == 'accessor' {
				holder.define_direct_cached_accessor(key, replacement.object, none,
					attribute_configurable)
			}
			return Value.from_i32(17)
		}, 0, key, 'get')
		holder.define_direct_cached_accessor(key, getter.object, none, attribute_configurable)
		old_cache_key := holder.get_without_side_effects(key).as_accessor().cached_value_key?
		assert holder.get(mut vm, key)!.number == 17
		assert holder.get_engine_private_property(old_cache_key) == none
		if action == 'delete' {
			assert holder.get(mut vm, key)!.is_undefined()
		} else {
			assert holder.get(mut vm, key)!.number == 42
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_throwing_cached_getters_retry_without_installing_a_value() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut state := &CachedAccessorState{}
	key := PropertyName.from_str('value')
	getter := NativeFunction.create(mut vm, vm.realm(), none, fn [mut state] (mut vm VM) !Value {
		state.calls++
		return throw_completion(Value.from_i32(17))
	}, 0, key, 'get')
	mut holder := Object.create(vm.realm(), none)
	holder.define_direct_cached_accessor(key, getter.object, none, 0)
	for _ in 0 .. 2 {
		if _ := holder.get(mut vm, key) {
			assert false
		} else {
			assert thrown_value(err).number == 17
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
	assert state.calls == 2
	cache_key := holder.get_without_side_effects(key).as_accessor().cached_value_key?
	assert holder.get_engine_private_property(cache_key) == none
}

fn test_native_accessor_metadata_and_direct_partial_updates_follow_upstream() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut holder := Object.create(vm.realm(), none)
	prototype := Object.create(vm.realm(), none)
	key := PropertyName.from_str('value')
	holder.define_native_accessor(mut vm, vm.realm(), key, fn (mut vm VM) !Value {
		return Value.from_i32(42)
	}, fn (mut vm VM) !Value {
		mut receiver := vm.this_value().as_object()
		receiver.create_data_property(mut vm, PropertyName.from_str('written'), vm.argument(0)) or {
			panic(err)
		}
		return js_undefined()
	}, attribute_configurable, prototype)
	descriptor := holder.internal_get_own_property(key)?
	for field in ['get', 'set'] {
		function := if field == 'get' {
			descriptor.getter?.as_object()
		} else {
			descriptor.setter?.as_object()
		}
		assert function.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == '${field} value'
		assert function.get(mut vm, PropertyName.from_str('length'))!.number == if field == 'get' {
			0
		} else {
			1
		}
		assert function.internal_get_prototype_of()? == prototype
	}
	assert holder.get(mut vm, key)!.number == 42
	holder.set(mut vm, key, Value.from_i32(17), .yes)!
	assert holder.get(mut vm, PropertyName.from_str('written'))!.number == 17
	mut state := &CachedAccessorState{}
	other_getter := counting_cached_getter(mut vm, mut state)
	original := holder.get_without_side_effects(key).as_accessor()
	holder.define_direct_accessor(key, other_getter, none, attribute_enumerable)
	assert holder.get_without_side_effects(key).as_accessor() == original
	updated := holder.internal_get_own_property(key)?
	assert same_value(updated.setter?, descriptor.setter?)
	assert !updated.enumerable? && updated.configurable?
	assert holder.get(mut vm, key)!.number == 1
	holder.define_direct_cached_accessor(key, none, none, 0)
	cache_key := original.cached_value_key?
	assert holder.get(mut vm, key)!.number == 2
	holder.define_direct_cached_accessor(key, none, none, 0)
	assert original.cached_value_key? == cache_key
	assert holder.get(mut vm, key)!.number == 3
}
