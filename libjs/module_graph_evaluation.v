// SPDX-License-Identifier: BSD-2-Clause
module libjs

struct ModuleEvaluationState {
mut:
	index int
	stack []&SourceTextModule
}

// CyclicModule.cpp::InnerModuleEvaluation, synchronous graph path. TLA is
// rejected by compilation; a component settles only after every body succeeds.
fn (mut module_record SourceTextModule) inner_module_evaluate(mut vm VM,mut state ModuleEvaluationState) ! {
	if module_record.module_status==.evaluated {
		capability := module_record.module_evaluation or { return error('Evaluated module has no result') }
		if capability.promise.state==.rejected { return throw_completion(capability.promise.result) }
		return
	}
	if module_record.module_status==.evaluating { return }
	if module_record.module_status!=.linked { return vm.throw_error(.internal_error,'Module must be linked before evaluation') }
	if vm.stack_info_.size_free()<512*1024 || state.index>=4096 { return vm.throw_error(.internal_error,'LibJS module evaluation graph budget exceeded') }
	module_record.module_evaluation=PromiseCapability.create(Promise.create(module_record.module_realm),none,none)
	module_record.module_status=.evaluating
	module_record.module_dfs_index=state.index
	module_record.module_dfs_ancestor=state.index
	state.index++;state.stack << &module_record
	for request in module_record.requested_module_requests() {
		vm.consume_execution_budget()!
		mut target := module_record.imported_source_module(mut vm,request)!
		target.inner_module_evaluate(mut vm,mut state)!
		if target.module_status==.evaluating && target.module_dfs_ancestor<module_record.module_dfs_ancestor {
			module_record.module_dfs_ancestor=target.module_dfs_ancestor
		}
	}
	executable := module_record.module_executable or { return error('Module has no executable') }
	module_record.run_module_frame(mut vm,executable,module_record.module_body_start,ExecutionLimits{})!
	if module_record.module_dfs_ancestor==module_record.module_dfs_index {
		for state.stack.len>0 {
			mut target := state.stack.pop();target.module_status=.evaluated
			capability := target.module_evaluation or { return error('Module has no evaluation promise') }
			mut promise := capability.promise
			promise.fulfill(js_undefined())
			if voidptr(target)==voidptr(&module_record) { break }
		}
	}
}

fn (mut module_record SourceTextModule) evaluate_module_graph(mut vm VM,limits ExecutionLimits) !&PromiseCapability {
	if capability := module_record.module_evaluation { return capability }
	if module_record.module_status!=.linked { return vm.throw_error(.internal_error,'Module must be linked before evaluation') }
	outer := vm.run_executable_depth==0 && vm.external_budget_depth==0
	previous_budget,previous_active := vm.instruction_budget,vm.instruction_budget_active
	if outer { vm.instruction_budget=limits.max_instructions;vm.instruction_budget_active=limits.max_instructions!=0 }
	vm.external_budget_depth++
	defer {
		vm.external_budget_depth--
		if outer { vm.instruction_budget=previous_budget;vm.instruction_budget_active=previous_active }
	}
	mut state := ModuleEvaluationState{}
	module_record.inner_module_evaluate(mut vm,mut state) or {
		reason := if is_throw_completion(err) { thrown_value(err) } else { thrown_value(vm.throw_error(.internal_error,err.msg())) }
		if module_record.module_evaluation==none {
			module_record.module_evaluation=PromiseCapability.create(Promise.create(module_record.module_realm),none,none)
			state.stack << &module_record
		}
		for mut target in state.stack {
			target.module_status=.evaluated
			capability := target.module_evaluation or { continue }
			mut promise := capability.promise
			if promise.state==.pending { promise.reject(mut vm,reason) }
		}
	}
	return module_record.module_evaluation or { return error('Module evaluation did not produce a result') }
}
