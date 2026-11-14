module libjs

fn test_collection_literals_and_installed_methods_execute_through_bytecode() {
	for source, expected in {
		'var a=[1,,3]; a.length+":"+(1 in a)': '"3:false"'
		'var a=[2,3];a.unshift(1);a.splice(1,1,42);a.join(" ")': '"1 42 3"'
		'var a=[1,2,3];a.splice(1,0,4,5).length+":"+a.join()': '"0:1,4,5,2,3"'
		'var a=[1,2,3,4];a.splice(-3,2).join()+":"+a.join()': '"2,3:1,4"'
		'var a=[1,,3];var b=a.slice(0,-1);b.length+":"+(1 in b)': '"2:false"'
		'var o={x:40};o.x+=2;o.x': '42'
		'var o={length:3,0:1,2:3};Array.prototype.indexOf.call(o,3)': '2'
		'var a=[1,2,3];var n=0;a.forEach(function(x,i){n+=x+i});n': '9'
		'var a=[];a.push(a);a.join()': '""'
		'"a b c".split(" ").slice(1).join("-")': '"b-c"'
		'"😀x".substring(2)+":"+"ABC".toLowerCase()': '"x:abc"'
		'function f(){return this.length} f.call("😀")': '2'
		'Array.isArray(Array(3)) && Array(3).length===3': 'true'
		'Array[Symbol.species]===Array && Array.prototype.join.length===1': 'true'
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		mut script := Script.parse(source, vm.realm(), 'collections.js', unsafe { nil })!
		assert vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})!.str() == expected, source
	}
}

fn test_borrowed_array_methods_propagate_exceptions_and_enforce_instruction_budget() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for source in ['Array.prototype.forEach.call({length:9007199254740991},function(){})',
		'[1].forEach(function(){throw 42})', 'Array(-1)'] {
		mut script := Script.parse(source, vm.realm(), 'array-errors.js', unsafe { nil })!
		if _ := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 1000}) { assert false }
		assert vm.execution_context_stack().len == 1
		assert vm.interpreter_stack().depth() == 0
	}
}
