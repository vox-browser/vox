// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Configuration.cpp::call, execute and execute_for_compiled_call.
module webassembly

pub fn (mut configuration BinaryMachineConfiguration) call(mut interpreter BinaryMachineInterpreter, address u64, mut arguments BinaryMachineArguments) BinaryMachineResult {
	prepared := configuration.prepare_call(address, mut arguments, false) or {
		if err is BinaryMachineTrap { return BinaryMachineResult.from_trap(err) }
		panic('Source unreachable call preparation error')
	}
	if host := prepared.host_function {
		return host.invoke(mut configuration, arguments.span())
	}
	configuration.ip_ = 0
	return configuration.execute(mut interpreter)
}

pub fn (mut configuration BinaryMachineConfiguration) execute(mut interpreter BinaryMachineInterpreter) BinaryMachineResult {
	interpreter.interpret(mut configuration)
	if interpreter.did_trap() {
		return BinaryMachineResult.from_trap(interpreter.trap())
	}
	count := configuration.frame().arity()
	mut stack := configuration.value_stack()
	span := stack.span()
	assert count <= span.size
	mut results := []BinaryMachineValue{len: int(count)}
	for index in uint(0) .. count {
		results[int(index)] = *span.at(span.size - count + index)
	}
	stack.shrink(stack.size() - count, true)
	results.reverse_in_place()
	label_index := configuration.frame().label_index()
	if uint(configuration.label_stack_.len) > label_index {
		configuration.label_stack_.trim(int(label_index))
	}
	return BinaryMachineResult.from_values(results)
}

pub fn (mut configuration BinaryMachineConfiguration) execute_for_compiled_call(mut interpreter BinaryMachineInterpreter, single_result &BinaryMachineValue) ! {
	interpreter.interpret(mut configuration)
	if interpreter.did_trap() { return interpreter.trap() }
	assert configuration.frame().arity() <= 1
	if configuration.frame().arity() == 1 {
		result := configuration.value_stack_.unsafe_take_last()
		if single_result != unsafe { nil } {
			unsafe { *single_result = result }
		}
	}
	if configuration.label_stack_.len > 0 {
		configuration.label_stack_.pop()
	}
}
