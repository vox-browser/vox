module libjs

import platform

fn test_global_binding_hints_read_live_values_after_deletion_reordering_and_accessors() {
	defer { set_global_binding_hints_for_testing(true) }
	for enabled in [false, true] {
		set_global_binding_hints_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		vm.diagnose_native_code(true)!
		for source in [
			'globalThis.hinted=1;function readHint(){return hinted}readHint()===1',
			'hinted=42;readHint()===42',
			'delete globalThis.hinted;globalThis.otherHint=1;globalThis.hinted=43;readHint()===43',
			'Object.defineProperty(globalThis,"hinted",{get(){return 44},configurable:true});readHint()===44',
			'Object.defineProperty(globalThis,"hinted",{value:45,writable:true,configurable:true});readHint()===45',
			'function shadowHint(hinted){return hinted}shadowHint(46)===46',
			'var hintThrows=false;Object.defineProperty(globalThis,"hinted",{get(){throw 47},configurable:true});try{readHint()}catch(e){hintThrows=e===47}hintThrows',
		] {
			mut script := Script.parse(source, vm.realm(), 'global-hint.js', unsafe { nil })!
			assert vm.run(mut script)!.to_boolean(), source
		}
		activity := vm.diagnose_native_code(false)!
		assert (activity.global_binding_hint_hits > 0) == enabled
	}
}

fn test_global_binding_hints_validate_borrowed_name_contents_and_live_indices() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	object.define_direct_property(PropertyName.from_str('first'), Value.from_i32(1), 7)
	object.define_direct_property(PropertyName.from_str('later'), Value.from_i32(2), 7)
	mut name := utf16_string('first')
	assert vm.live_global_data_binding(object, name)?.as_i32() == 1
	for i, unit in utf16('later') { name.data[i] = unit }
	assert vm.live_global_data_binding(object, name)?.as_i32() == 2
	assert object.internal_delete(PropertyName.from_str('first'))
	assert vm.live_global_data_binding(object, name)?.as_i32() == 2
	object.define_direct_property(PropertyName.from_str('later'), Value.from_i32(42), 7)
	assert vm.live_global_data_binding(object, name)?.as_i32() == 42
	assert object.internal_delete(PropertyName.from_str('later'))
	assert vm.live_global_data_binding(object, name) == none
	object.define_direct_property(PropertyName.from_str('later'), Value.from_i32(43), 7)
	assert vm.live_global_data_binding(object, name)?.as_i32() == 43
	other := Object.create(vm.realm(), none)
	assert vm.live_global_data_binding(other, name) == none
}

fn test_global_binding_hint_storage_is_bounded_rooted_and_does_not_grow_on_hits() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	for index in 0 .. 600 {
		name := utf16_string('name${index}')
		object.define_direct_property(PropertyName.from_utf16(name), Value.from_i32(index), 7)
		assert vm.live_global_data_binding(object, name)?.as_i32() == index
	}
	assert vm.global_binding_hints.len == global_binding_hint_slots
	roots := vm.heap_roots()
	for hint in vm.global_binding_hints {
		if hint.owner != unsafe { nil } {
			assert roots.contains(voidptr(hint.owner)) && roots.contains(voidptr(hint.object))
		}
	}
	name := utf16_string('name599')
	assert vm.live_global_data_binding(object, name)?.as_i32() == 599
	before := platform.thread_arena_usage().used
	for _ in 0 .. 10000 { assert vm.live_global_data_binding(object, name)?.as_i32() == 599 }
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	assert vm.global_binding_hints.len == global_binding_hint_slots
}

fn test_global_binding_hints_do_not_bypass_global_lexicals_with_or_inherited_properties() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	name := utf16_string('hinted')
	object.define_direct_property(PropertyName.from_utf16(name), Value.from_i32(1), 7)
	mut environment := GlobalEnvironment.create(object, object)
	assert vm.own_global_data_binding(Environment(environment), name)?.as_i32() == 1
	assert vm.own_global_data_binding(Environment(environment), name)?.as_i32() == 1
	environment.declarative_record.create_mutable_binding(mut vm, name, false)!
	assert vm.own_global_data_binding(Environment(environment), name) == none
	if _ := environment.get_binding_value(mut vm, name, false) { assert false }
	else { assert is_throw_completion(err) }
	environment.declarative_record.initialize_binding(mut vm, name, Value.from_i32(42), .normal)!
	assert environment.get_binding_value(mut vm, name, false)!.as_i32() == 42
	assert vm.own_global_data_binding(Environment(environment), name) == none
	environment.object_record.with_environment = true
	assert vm.own_global_data_binding(Environment(environment), utf16_string('missing')) == none
	mut child := Object.create(vm.realm(), object)
	inherited := GlobalEnvironment.create(child, child)
	assert vm.own_global_data_binding(Environment(inherited), name) == none
	assert inherited.object_record.get_binding_value(mut vm, name, false)!.as_i32() == 1
}
