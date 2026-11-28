// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn test_host_scheduled_promise_jobs_share_and_restore_native_execution_budgets() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	owner := &vm
	job := fn [owner] () !Value {
		mut agent := unsafe { &VM(owner) }
		for _ in 0 .. 100 { agent.consume_execution_budget()! }
		return Value.from_i32(42)
	}
	vm.run_promise_job_with_limits(job, ExecutionLimits{max_instructions: 20}) or {
		assert thrown_value(err).as_object().error_message()?.contains('instruction budget')
		assert vm.run_promise_job_with_limits(job, ExecutionLimits{max_instructions: 200})!.number == 42
		assert vm.external_budget_depth == 0 && !vm.instruction_budget_active
		return
	}
	assert false, 'Host-scheduled jobs must enforce their shared execution budget'
}
