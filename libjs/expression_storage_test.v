// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn test_retained_expression_nodes_survive_parsing_and_delayed_closure_compilation() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('function make(which){var data=[{n:20},{n:22}];return function(){return which?data[0].n+data[1].n:data[1].n-data[0].n}};[make(true),make(false)]', vm.realm(), 'retained-expressions.js', unsafe { nil })!
	functions := vm.run(mut script)!.as_object()
	first := functions.get(mut vm, PropertyName.from_str('0'))!
	second := functions.get(mut vm, PropertyName.from_str('1'))!
	// Reuse parser/call stack frames before compiling either retained body.
	for index in 0 .. 100 {
		mut other := Script.parse('var noise={x:[1,2,3]};noise.x[0]+noise.x[1]*noise.x[2]', vm.realm(), 'noise-${index}.js', unsafe { nil })!
		assert vm.run(mut other)!.number == 7
	}
	assert call(mut vm, first, js_undefined(), [])!.number == 42
	assert call(mut vm, second, js_undefined(), [])!.number == 2
	assert call(mut vm, first, js_undefined(), [])!.number == 42
}

fn test_expression_snapshots_preserve_nested_member_and_assignment_owners() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('var order="";var o={a:{b:20},c:21};function key(){order+="k";return "b"};function value(){order+="v";return 22};o.a[key()]+=value();var result=o.a.b+":"+order;o.a.b=1;result', vm.realm(), 'expression-owners.js', unsafe { nil })!
	assert vm.run(mut script)!.as_string().str() == '42:kv'
}
