module libjs

fn test_bytecode_compiler_rejects_deep_ast_spines_without_exhausting_native_stack() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	// A left-associative binary spine needs very little parser recursion, but
	// its AST was previously visited recursively without a compiler reserve.
	mut script := Script.parse('1' + '+1'.repeat(5000), vm.realm(), 'deep-spine.js', unsafe { nil })!
	vm.run(mut script) or {
		assert err.msg().contains('compilation stack budget'), err.msg()
		assert vm.execution_context_stack().len == 1
		assert vm.interpreter_stack().depth() == 0
		mut later := Script.parse('6*7', vm.realm(), 'later.js', unsafe { nil })!
		assert vm.run(mut later)!.number == 42
		return
	}
	assert false, 'The AST compiler must keep its native stack reserve'
}
