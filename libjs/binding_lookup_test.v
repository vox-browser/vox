module libjs

import platform

fn test_linear_binding_lookup_matches_live_utf16_names_in_slot_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut env := DeclarativeEnvironment.create(none)
	units := [u16(0x78), 0xd800]
	name := utf16_string_from_code_units(units)
	assert env.find_binding_index_linear(name) == -1
	env.create_mutable_binding(mut vm, name, true)!
	env.create_mutable_binding(mut vm, utf16_string('tail'), true)!
	assert env.find_binding_index_linear(utf16_string_from_code_units(units)) == 0
	assert env.delete_binding(mut vm, name)!
	assert env.find_binding_index_linear(name) == -1
	assert env.find_binding_index_linear(utf16_string('tail')) == 1
	env.create_mutable_binding(mut vm, utf16_string_from_code_units(units), true)!
	assert env.find_binding_index_linear(name) == 2
	assert env.find_binding_index_linear(utf16_string_from_code_units([u16(0x78), 0xdc00])) == -1
	assert env.find_binding_index_linear(utf16_string('x')) == -1
	lone := utf16_string_from_code_units([u16(0xd800)])
	env.create_mutable_binding(mut vm, lone, true)!
	assert env.find_binding_index_linear(utf16_string_from_code_units([u16(0xd800)])) == 3
	assert env.find_binding_index_linear(utf16_string_from_code_units([u16(0xdc00)])) == -1
	assert env.delete_binding(mut vm, lone)!
	assert env.find_binding_index_linear(lone) == -1
}

fn binding_lookup_fixture(mut vm VM) !&DeclarativeEnvironment {
	mut env := DeclarativeEnvironment.create(none)
	for index in 0 .. 96 {
		name := utf16_string('binding${index}')
		env.create_mutable_binding(mut vm, name, true)!
		env.initialize_binding(mut vm, name, Value.from_i32(index), .normal)!
	}
	return env
}

fn test_binding_lookup_hints_read_live_values_and_preserve_deletion_recreation_and_tdz() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut env := binding_lookup_fixture(mut vm)!
	// Initialization already hinted every name; start from an empty table so the
	// first read misses and the second uses the hint it recorded.
	env.binding_lookup_hints = none
	diagnose_binding_lookup_for_testing(true)
	assert env.get_binding_value(mut vm, utf16_string('binding17'), false)!.as_i32() == 17
	assert env.get_binding_value(mut vm, utf16_string('binding17'), false)!.as_i32() == 17
	activity := diagnose_binding_lookup_for_testing(false)
	assert activity.hits > 0 && activity.misses > 0
	env.set_mutable_binding(mut vm, utf16_string('binding17'), Value.from_i32(42), false)!
	assert env.get_binding_value(mut vm, utf16_string('binding17'), false)!.as_i32() == 42
	assert env.delete_binding(mut vm, utf16_string('binding17'))!
	assert !env.has_binding_named(utf16_string('binding17'))
	env.create_mutable_binding(mut vm, utf16_string('binding17'), true)!
	env.initialize_binding(mut vm, utf16_string('binding17'), Value.from_i32(9), .normal)!
	assert env.get_binding_value(mut vm, utf16_string('binding17'), false)!.as_i32() == 9
	assert !env.has_binding_named(utf16_string('future'))
	env.create_immutable_binding(mut vm, utf16_string('future'), true)!
	assert env.has_binding_named(utf16_string('future'))
	if _ := env.get_binding_value(mut vm, utf16_string('future'), true) {
		assert false
	}
	env.initialize_binding(mut vm, utf16_string('future'), Value.from_i32(88), .normal)!
	assert env.get_binding_value(mut vm, utf16_string('future'), true)!.as_i32() == 88
}

fn test_binding_lookup_collisions_bounds_name_edits_and_hint_limit_take_live_fallbacks() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut env := binding_lookup_fixture(mut vm)!
	for index in 0 .. 96 {
		assert env.find_binding_index(utf16_string('binding${index}')) == index
	}
	mut hints := env.binding_lookup_hints or { panic('Expected bounded hints') }
	assert hints.positions.count <= binding_lookup_hint_limit
	key := utf16_string('binding80')
	hints.positions.set(binding_lookup_hash(key), 4)
	assert env.find_binding_index(key) == 80
	env.bindings[80].name = utf16_string('renamed')
	assert env.find_binding_index(key) == -1
	assert env.find_binding_index(utf16_string('renamed')) == 80
	mut kept := []DeclarativeBinding{}
	for index in 0 .. 20 { kept << env.bindings[index] }
	env.bindings = kept
	assert env.find_binding_index(utf16_string('renamed')) == -1
	assert env.find_binding_index(utf16_string('binding17')) == 17
}

fn test_binding_lookup_table_outlives_temporary_storage_and_handles_utf16_names() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut env := binding_lookup_fixture(mut vm)!
	env.binding_lookup_hints = none
	mut arena := platform.new_arena('binding hints')
	entry := arena.enter()
	assert env.find_binding_index(utf16_string('binding23')) == 23
	for index in 32 .. 80 {
		assert env.find_binding_index(utf16_string('binding${index}')) == index
	}
	arena.leave(entry)
	hints := env.binding_lookup_hints or { panic('Missing hints') }
	assert !arena.contains(hints)
	arena.reset()
	arena.release()
	assert env.find_binding_index(utf16_string('binding23')) == 23
	for units in [[u16(0), 0xd800], [u16(0x61), 0xdc00], [u16(0x03b1), 0x03b2]] {
		name := utf16_string_from_code_units(units)
		env.create_mutable_binding(mut vm, name, true)!
		env.initialize_binding(mut vm, name, Value.from_i32(71), .normal)!
		assert env.get_binding_value(mut vm, utf16_string_from_code_units(units), false)!.as_i32() == 71
		assert env.get_binding_value(mut vm, utf16_string_from_code_units(units), false)!.as_i32() == 71
	}
}

fn test_binding_lookup_preserves_captured_function_environment_live_bindings() {
	for enabled in [false, true] {
		set_binding_lookup_hints_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		mut declarations_ := []string{}
		mut terms := []string{}
		for index in 0 .. 24 {
			declarations_ << 'a${index}=${index}'
			terms << 'a${index}'
		}
		declarations := declarations_.join(',')
		sum := terms.join('+')
		mut script := Script.parse('function outer(){var ${declarations};return {read(){return ${sum}},write(v){a7=v}}}var obj=outer();var total=0;for(var i=0;i<5;i++)total+=obj.read();obj.write(100);total===1380&&obj.read()===369', vm.realm(), 'bindings.js', unsafe { nil })!
		assert vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })!.as_bool()
	}
	set_binding_lookup_hints_for_testing(true)
}
