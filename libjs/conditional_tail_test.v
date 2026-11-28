module libjs

fn conditional_tail_result(source string) !Value {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'conditional-resource-map.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})!
}

fn test_long_conditional_resource_maps_parse_and_execute_without_native_recursion() {
	mut source := 'function resource(key){return '
	for index in 0 .. 1000 { source += 'key===${index}?${index}+100:' }
	source += '-1} resource(0)+resource(500)+resource(999)+resource(-1);'
	parsed := parse_source(source, .script)
	assert !parsed.has_errors(), '${parsed.diagnostics}'
	assert !parsed.reached_recursion_limit
	assert conditional_tail_result(source)!.number == 1798
}

fn test_conditional_tail_preserves_precedence_evaluation_order_and_nested_arms() {
	for source, expected in {
		'false?1:true?2:3': f64(2)
		'false?1:false||true?2:3': 2
		'false?1:false?2:3': 3
		'true?false?1:2:3': 2
		'var x=0;false?1:x=true?2:3;x': 2
		'var x=0;false?1:(x)=true?2:3;x': 2
		'var x=0;false?1:x+=true?2:3;x': 2
		'var x=0;false?x++:false?x++:++x;x': 1
		'var f=false?null:x=>x?2:3;f(true)': 2
		'var f=false?null:(x)=>x?2:3;f(false)': 3
		'var x=0;for(var y=false?1:2;y<3;y++)x+=y;x': 2
	} {
		assert conditional_tail_result(source)!.number == expected, source
	}
	assert parse_source('false ? 1 : ({x}) = {x:2}', .script).has_errors()
	assert parse_source('('.repeat(40)+'1'+')'.repeat(40), .script).reached_recursion_limit
}

fn test_conditional_tail_retains_right_associative_ast_and_operator_positions() {
	parsed := parse_source('a ? b : c ? d : e;', .script)
	assert !parsed.has_errors()
	program := parsed.program.kind.program_data?
	root := program.scope.children[0].kind.expression?
	assert root.kind.tag == .conditional
	assert root.range.start.offset == 2
	first := root.kind.conditional_data?
	assert first.test.kind.identifier?.name.str() == 'a'
	assert first.consequent.kind.identifier?.name.str() == 'b'
	other := first.alternate
	assert other.kind.tag == .conditional
	assert other.range.start.offset == 10
	second := other.kind.conditional_data?
	assert second.test.kind.identifier?.name.str() == 'c'
	assert second.consequent.kind.identifier?.name.str() == 'd'
	assert second.alternate.kind.identifier?.name.str() == 'e'
}

fn test_retained_conditional_branches_preserve_their_nested_functions() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('function keep(){return function(x){return (()=>x>0)()?(()=>x+30)():(()=>x-1)()}};keep()', vm.realm(), 'conditional-owners.js', unsafe { nil })!
	closure := vm.run(mut script)!
	for _ in 0 .. 20 {
		assert !parse_source('function unrelated(){return false?1:true?2:3}', .script).has_errors()
	}
	assert call(mut vm, closure, js_undefined(), [Value.from_i32(12)])!.number == 42
	assert call(mut vm, closure, js_undefined(), [Value.from_i32(-2)])!.number == -3
}
