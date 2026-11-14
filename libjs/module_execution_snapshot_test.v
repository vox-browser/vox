// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn test_module_execution_snapshot_is_read_only_through_link_and_evaluation() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut record := SourceTextModule.parse('export const answer=42', vm.realm(), 'snapshot.mjs', unsafe { nil })!
	assert record.execution_snapshot().status == 'unlinked'
	assert record.execution_snapshot().promise_state == ''
	record.link(mut vm)!
	linked_generation := vm.execution_generation()
	assert record.execution_snapshot().status == 'linked'
	assert record.execution_snapshot().promise_state == ''
	assert vm.execution_generation() == linked_generation
	assert record.evaluate(mut vm)!.promise.state == .fulfilled
	generation := vm.execution_generation()
	assert record.execution_snapshot().status == 'evaluated'
	assert record.execution_snapshot().promise_state == 'fulfilled'
	assert vm.execution_generation() == generation
}

fn test_module_execution_snapshot_exposes_cached_rejection_without_converting_it() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut record := SourceTextModule.parse('var reason={};reason.toString=function(){throw 99};throw reason', vm.realm(), 'failed-snapshot.mjs', unsafe { nil })!
	record.link(mut vm)!
	assert record.evaluate(mut vm)!.promise.state == .rejected
	snapshot := record.execution_snapshot()
	assert snapshot.status == 'evaluated' && snapshot.promise_state == 'rejected'
}
