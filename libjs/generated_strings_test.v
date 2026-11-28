module libjs

import platform

fn test_generated_strings_own_slices_preserve_code_units_and_keep_public_creation_contracts() {
	set_generated_strings_for_testing(true)
	mut vm := VM.create()
	mut units := [u16(0xd800), 0, 65, 0xdc00, 0xd83d, 0xde00]
	first := vm.create_generated_string(units)
	units[0] = 66
	assert first.utf16.data == [u16(0xd800), 0, 65, 0xdc00, 0xd83d, 0xde00]
	assert vm.create_generated_string(units).utf16.data[0] == 66
	assert voidptr(vm.create_generated_string([]u16{})) == voidptr(vm.empty_string())
	assert voidptr(vm.create_generated_string([u16(65)])) == voidptr(vm.single_ascii_character_string(65))
	parts := [utf16_string('immutable'), utf16_string(' result')]
	joined := vm.create_generated_join(parts)
	assert joined.str() == 'immutable result'
	assert voidptr(joined) == voidptr(vm.create_generated_string(utf16('immutable result')))
	assert voidptr(vm.create_generated_join([utf16_string(''), utf16_string('A')])) == voidptr(vm.single_ascii_character_string(65))
	long := utf16_string('eight888')
	assert voidptr(vm.create_string(long)) != voidptr(vm.create_string(long))
	wide := []u16{len: generated_string_cache_units + 1, init: u16(65)}
	assert voidptr(vm.create_generated_string(wide)) != voidptr(vm.create_generated_string(wide))
}

fn test_generated_string_cache_validates_collisions_evicts_and_reports_retained_roots() {
	mut vm := VM.create()
	retained := vm.create_generated_string(utf16('retained generated result'))
	assert vm.heap_roots().contains(voidptr(retained))
	for index in 0 .. 2048 {
		text := 'generated result ${index}'
		assert vm.create_generated_string(utf16(text)).str() == text
	}
	assert vm.generated_string_cache.len == generated_string_cache_slots
	assert retained.str() == 'retained generated result'
	units := utf16('collision check')
	slot := int(generated_string_hash_append(2166136261, units) & (generated_string_cache_slots - 1))
	vm.generated_string_cache[slot] = retained
	correct := vm.create_generated_string(units)
	assert correct.str() == 'collision check'
	assert voidptr(correct) != voidptr(retained)
	gc_collect()
	assert vm.create_generated_join([utf16_string('collision'), utf16_string(' check')]).str() == 'collision check'
	assert vm.heap_roots().contains(voidptr(correct))
}

fn test_generated_split_join_cache_keeps_getter_conversion_order_errors_cycles_and_budgets() {
	mut logs := []string{}
	for enabled in [false, true] {
		set_generated_strings_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		vm.diagnose_native_code(true)!
		mut script := Script.parse(r'
			var log="",a={length:2,get 0(){log+="g0";return {toString(){log+="c0";return "first"}}},get 1(){log+="g1";return "second"}};
			var sep={toString(){log+="s";return " "}};
			var x=Array.prototype.join.call(a,sep),y=Array.prototype.join.call(a,sep);
			var p="first second".split(" "),q="first second".split(" ");
			p[0]="changed";var c=[];c[0]=c;
			var threw=false;try{[Symbol()].join()}catch(e){threw=e instanceof TypeError}
			x==="first second"&&y===x&&q[0]==="first"&&c.join()===""&&threw&&"\ud800 \udc00".split(" ").join("").charCodeAt(1)===56320
		', vm.realm(), 'generated-strings.js', unsafe { nil })!
		assert vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})!.as_bool()
		activity := vm.diagnose_native_code(false)!
		assert (activity.generated_string_hits > 0) == enabled
		logs << vm.global_object().get(mut vm, PropertyName.from_str('log'))!.as_string().str()
		assert vm.array_join_objects.len == 0 && vm.interpreter_stack().depth() == 0
	}
	assert logs[0] == 'sg0c0g1sg0c0g1' && logs[1] == logs[0]
	set_generated_strings_for_testing(true)
}

fn test_generated_string_hits_do_not_retain_result_workspaces() {
	set_generated_strings_for_testing(true)
	mut vm := VM.create()
	units := utf16('repeated code-unit result')
	parts := [utf16_string('repeated '), utf16_string('code-unit result')]
	first := vm.create_generated_string(units)
	assert voidptr(vm.create_generated_join(parts)) == voidptr(first)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 10000 {
		assert voidptr(vm.create_generated_string(units)) == voidptr(first)
		assert voidptr(vm.create_generated_join(parts)) == voidptr(first)
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
}

fn test_generated_strings_keep_exact_join_and_split_execution_budgets() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for budget in 1 .. 120 {
		mut results := []string{}
		for enabled in [false, true] {
			set_generated_strings_for_testing(enabled)
			mut script := Script.parse('["first","second"].join(" ").split(" ")[0]',
				vm.realm(), 'generated-budget.js', unsafe { nil })!
			value := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: u64(budget)}) or {
				assert is_throw_completion(err)
				results << thrown_value(err).as_object().error_message() or { '' }
				continue
			}
			results << value.str()
		}
		assert results[0] == results[1], 'budget ${budget}'
		assert vm.interpreter_stack().depth() == 0
	}
	set_generated_strings_for_testing(true)
}
