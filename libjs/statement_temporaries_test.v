module libjs

fn temporary_statement_eval(source string, budget u64) !Value {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'statement-temporaries.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: budget})
}

fn test_statement_temporaries_keep_locals_captures_loops_and_completions() {
	defer { set_statement_temporary_reuse_for_testing(true) }
	for enabled in [false, true] {
		set_statement_temporary_reuse_for_testing(enabled)
		for source in [
			'var x=20;x+=1;x*=2;x',
			'21;var x=1;{let a=2};42',
			'function f(a){var x=a+1;var y=x*2;return y}f(20)',
			'function f(a){var get=()=>a;var x=21;a=x*2;return get()}f(0)',
			'function f(){var x=0;for(var y of [20,21]){x+=y}x++;return x}f()',
			'function f(){var x=0;outer:for(var i=0;i<10;i++){for(var j=0;j<10;j++){x=42;break outer}}return x}f()',
			'function f(){var x=0;try{throw 20}catch(e){x=e}finally{x++}return x*2}f()',
			'function f(){var x=21;try{return x*2}finally{x=0}}f()',
			'function* f(){var x=20;yield x+1;x+=22;return x}var g=f();g.next();g.next().value',
			'var a=0;try{a=21}finally{a*=2}a',
		] {
			assert temporary_statement_eval(source, 100000)!.number == 42, source
		}
	}
}

fn test_statement_temporaries_reduce_registers_without_changing_instruction_count() {
	defer { set_statement_temporary_reuse_for_testing(true) }
	mut sizes := []u32{}
	mut lengths := []u32{}
	for enabled in [false, true] {
		set_statement_temporary_reuse_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		mut script := Script.parse('var a=1+2;var b=a+3;var c=b+4;c', vm.realm(), 'reuse-size.js', unsafe { nil })!
		executable := script.compile(mut vm)!
		sizes << executable.registers_and_locals_count
		lengths << executable.bytecode_length
		assert vm.run(mut script)!.number == 10
	}
	assert sizes[1] < sizes[0] && lengths[0] == lengths[1]
}
