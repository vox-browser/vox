module libjs

fn local_operand_eval(source string) !Value {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'local-operands.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn local_operand_string(source string) !string {
	value := local_operand_eval(source)!
	assert value.is_string(), source
	return value.as_string().str()
}

fn local_operand_function(source string, name string) !&Executable {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'local-operands.js', unsafe { nil })!
	vm.run(mut script)!
	global := script.realm.global_object or { return error('Missing global') }
	value := global.internal_get(mut vm, PropertyName.from_str(name), Value.from_object(global))!
	callable := value.as_object().callable or { return error('Missing function') }
	if callable is ECMAScriptFunction {
		return callable.executable or { return error('Missing bytecode') }
	}
	return error('Not an ECMAScript function')
}

// Every later evaluation that can assign a local still sees the earlier read.
fn test_local_operands_preserve_left_to_right_reads() {
	for enabled in [false, true] {
		set_register_bindings_for_testing(enabled)
		for source, expected in {
			'function f(){var a=1;return a+(a=2)}f()':                                          3.0
			'function f(){var a=1;return a+a++}f()':                                            2.0
			'function f(){var a=1;return a*10+(a+=1)}f()':                                      12.0
			'function f(){let a=1;return (a=5)+a}f()':                                          10.0
			'function f(){var s=1;s+=(s=10);return s}f()':                                      11.0
			'function f(){var s=1;s+=s*2;return s}f()':                                         3.0
			'function f(){var s=2;s*=s++;return s}f()':                                         4.0
			'function f(){var a=1,b;b=a;a=2;return b}f()':                                      1.0
			'function f(){var a=5,b=(a=7);return b+a}f()':                                      14.0
			'function f(){var a=1,b=a;a=9;return b}f()':                                        1.0
			'function f(){var a=0,b=2;return (a||b)+a}f()':                                     2.0
			'function f(){var a=3;return a?a:0}f()':                                            3.0
			'function f(){var a=1;try{return a}finally{a=2}}f()':                               1.0
			'function f(){var s=0;try{s=1}finally{s+=1}return s}f()':                         2.0
			'function f(){var s=0;for(;;){try{break}finally{s=5}}return s}f()':               5.0
			'function f(){var t=0;if(t)return 1;return 2}f()':                                  2.0
			'function f(){var t=0,n=0;while(t<3){t=t+1;n+=t}return n}f()':                      6.0
			'function f(){var i=0;do{i++}while(i<4);return i}f()':                              4.0
			'function f(){var a=4;return -a+!a+~a}f()':                                         -9.0
			'function f(){var o={v:5,f(){return this.v}},a=o;return a.f(a=null)}f()':           5.0
			'function f(){var o={x:1,y:2},k="x";return o[k]+o[(k="y")]}f()':                    3.0
			'function f(){var o={x:1},p={x:2};return o[(o=p,"x")]+o.x}f()':                     3.0
			'function f(){var o={},k="x";o[k]=(k="y");return o.x=="y"&&k=="y"?1:0}f()':       1.0
			'function f(){var o={n:1};o.n+=(o={n:10}).n;return o.n}f()':                       10.0
			'function f(){var o={n:1},a=o;a.n++;return o.n}f()':                                2.0
			'function f(){var g=function(x,y){return x*10+y},i=0;return g(i,++i)}f()':          1.0
			'function f(){var g=function(x){return x*2},a=21;return g(a)}f()':                  42.0
			'function f(){var g=function(x){return x},h=function(){return 7};return g(h)()}f()': 7.0
			'function f(){var g=function(){return 1};return g(g=null)}f()':                     1.0
		} {
			actual := local_operand_eval(source)!
			assert actual.is_number(), source
			assert actual.number == expected, '${source}: ${actual.number}'
		}
		assert local_operand_string('function f(){var i="5";var j=i++;return typeof j+j+i}f()')! == 'number56'
		assert local_operand_string('function f(){var i=1,g=function(a,b,c){return ""+a+b+c};return g(i,i+=1,i)}f()')! == '122'
		assert local_operand_string('function f(){var a="x";return a+(a="y")+a}f()')! == 'xyy'
	}
	set_register_bindings_for_testing(true)
}

fn test_local_operands_keep_script_completion_and_drop_function_completion() {
	assert local_operand_eval('var x=3; x+1;')!.number == 4
	assert local_operand_eval('1; if (true) { 2; }')!.number == 2
	assert local_operand_eval('function f(){1;2;} f()')!.is_undefined()
	assert local_operand_eval('function f(){try{1}finally{2}} f()')!.is_undefined()
}

// A local loop reads its bindings in place and never copies a completion.
fn test_local_operands_emit_loops_without_copies() {
	set_register_bindings_for_testing(true)
	executable := local_operand_function('function f(){var s=0,i=0;while(i<5){s=s+i;i=i+1}return s}f()',
		'f')!
	accumulator := Operand.register(register_accumulator)
	assert !executable.instructions.any(it.op == .mov && it.dst == accumulator)
	mut adds := 0
	for instruction in executable.instructions {
		if instruction.op == .add {
			adds++
			assert instruction.lhs.operand_type()! == .local
		}
		if instruction.op == .less_than {
			assert instruction.lhs.operand_type()! == .local
		}
	}
	assert adds == 2
	// Two initializers and two stores; reads never copy a local into a register.
	assert executable.instructions.filter(it.op == .mov).len == 4
}
