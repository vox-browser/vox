module libjs

fn operand_slots_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'operand-slots.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 500000 })
}

// Inline handlers read registers, locals, constants and arguments through
// slots resolved once per body, with and without the compiler's ownership.
fn test_operand_slots_address_every_operand_kind() {
	for immutable in [false, true] {
		mut vm := VM.create()
		vm.use_immutable_compiler_executables(immutable)!
		create_simple_execution_context(mut vm)
		source := 'function f(a,b){var o={k:a},s=0;for(var i=0;i<b;i++){s=s+o.k*2-i;o.k=o.k+1}return s+(a|0)+(b>>>1)}' +
			'function g(x){return f(x,4)+f(x+1,3)}[g(1),g(2),f(0,0)].join()'
		value := operand_slots_eval(mut vm, source)!
		assert value.as_string().str() == '35,51,0', '${immutable}'
		global := vm.realm().global_object or { panic('Missing global') }
		f := global.internal_get(mut vm, PropertyName.from_str('f'), Value.from_object(global))!
		callable := f.as_object().callable or { panic('Missing function') }
		if callable is ECMAScriptFunction {
			executable := callable.executable or { panic('Missing bytecode') }
			assert executable.operand_slots.len == executable.instructions.len
			bases := executable.operand_bases()
			for index, instruction in executable.instructions {
				slots := executable.operand_slots[index]
				assert slots.dst == operand_slot(instruction.dst, bases)
				assert slots.lhs == operand_slot(instruction.lhs, bases)
				assert slots.rhs == operand_slot(instruction.rhs, bases)
				assert slots.src == operand_slot(instruction.src, bases)
			}
		} else {
			assert false
		}
	}
}

// A changed layout (here, an extra constant moving the argument base)
// rebuilds the table instead of reusing stale slots.
fn test_operand_slots_follow_layout_changes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert operand_slots_eval(mut vm, 'function h(a,b){return a-b}h(9,4)')!.number == 5
	global := vm.realm().global_object or { panic('Missing global') }
	h := global.internal_get(mut vm, PropertyName.from_str('h'), Value.from_object(global))!
	callable := h.as_object().callable or { panic('Missing function') }
	if callable is ECMAScriptFunction {
		mut executable := callable.executable or { panic('Missing bytecode') }
		before := executable.operand_bases()
		executable.constants << Value.from_i32(0)
		after := executable.operand_bases()
		assert after[3] == before[3] + 1
		slots := executable.operand_slots_for(after)
		assert executable.operand_slot_bases[3] == after[3]
		assert voidptr(slots) == voidptr(executable.operand_slots.data)
	} else {
		assert false
	}
	assert operand_slots_eval(mut vm, 'h(10,3)')!.number == 7
}
