// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn test_scope_rollback_preserves_storage_prefix_flags_and_tree() {
	mut collector := ScopeCollector.new()
	collector.records = []ScopeRecord{cap: 128}
	collector.open_scope(.program_scope, ScopeData.new_shared(), .script_top_level)
	collector.open_scope(.function_scope, ScopeData.new_shared(), .function_top_level)
	collector.records[1].variables['keep'] = ScopeVariable{flags: var_flag_var}
	collector.records[1].children = []int{cap: 8}
	collector.open_block_scope()
	collector.close_scope()
	collector.errors << ScopeError{message: 'retained'}
	checkpoint := collector.save_state()
	storage := collector.records.data
	capacity := collector.records.cap
	children_storage := collector.records[1].children.data
	children_capacity := collector.records[1].children.cap
	for _ in 0 .. 64 {
		collector.records[1].uses_this = true
		collector.open_scope(.function_scope, ScopeData.new_shared(), .function_top_level)
		collector.close_scope()
		collector.open_block_scope()
		collector.errors << ScopeError{message: 'speculative'}
		collector.load_state(checkpoint)
		assert collector.current == 1 && collector.records.len == 3
		assert !collector.records[1].uses_this && collector.records[1].children == [2]
		assert collector.records[1].variables['keep'].flags == var_flag_var
		assert collector.errors.len == 1 && collector.errors[0].message == 'retained'
		// Bound the storage retained by repeated failed arrow hypotheses.
		assert collector.records.data == storage && collector.records.cap == capacity
		assert collector.records[1].children.data == children_storage
		assert collector.records[1].children.cap == children_capacity
	}
}

fn test_repeated_parenthesized_expressions_preserve_functions_and_captures() {
	mut source := 'function outer(a){'
	for index in 0 .. 100 { source += 'var v${index}=(a+${index});' }
	source += 'return (b=>a+b)(2)}outer(40)'
	parsed := parse_source(source, .script)
	assert !parsed.has_errors()
	assert parsed.function_table.entries.len == 2
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'scope-rollback.js', unsafe { nil })!
	assert vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})!.number == 42
}
