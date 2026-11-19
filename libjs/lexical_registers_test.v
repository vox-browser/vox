module libjs

fn lexical_eval(source string) !Value {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'lexical-registers.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 200000 })
}

fn lexical_function_for_test(mut vm VM, script &Script, name string) &ECMAScriptFunction {
	global := script.realm.global_object or { panic('Missing global') }
	value := global.internal_get(mut vm, PropertyName.from_str(name), Value.from_object(global)) or { panic(err) }
	callable := value.as_object().callable or { panic('Missing function') }
	if callable is ECMAScriptFunction { return callable }
	panic('Not an ECMAScript function')
}

fn test_lexical_registers_preserve_block_loop_and_destructuring_semantics() {
	defer { set_lexical_registers_for_testing(true) }
	for enabled in [false, true] {
		set_lexical_registers_for_testing(enabled)
		for source in [
			'function f(n){let s=0;for(let i=0;i<n;i++){const d=i*2;s+=d}return s}f(7)',
			'function f(a){let t="";for(const x of a){t+=x}return t=="abc"?42:0}f(["a","b","c"])',
			'function f(o){let n=0;for(const k in o){n+=o[k]}return n}f({a:40,b:2})',
			'function f(o){const {a,b:[c,d=a]}=o;return a+c+d}f({a:20,b:[2]})',
			'function f(){const fs=[];for(let i=0;i<3;i++)fs.push(()=>i);return fs.map(g=>g()).join()=="0,1,2"?42:0}f()',
			'function f(){let r=[];for(let i=0;i<2;i++){let u;if(i==0)u=5;r.push(u)}return r.join()=="5,"?42:0}f()',
			'function f(){let r=[];{let a=1;{let a=2;r.push(a)}r.push(a)}return r.join()=="2,1"?42:0}f()',
			'function f(){var x="outer";{let x="inner";x+="!"}return x=="outer"?42:0}f()',
			'function f(){var x="outer";const g=()=>x;{let x="inner";x+="!"}return g()=="outer"?42:0}f()',
			'function f(){let n=0;outer:for(let i=0;i<5;i++){for(let j=0;j<5;j++){if(j>i)continue outer;if(i==4)break outer;n++}}return n+32}f()',
			'function f(){let r=0;{class C{v(){return 40}};let c=new C;r=c.v()+2}return r}f()',
			'function f(){let s=0;try{const t=40;throw t}catch(e){let u=e+2;s=u}finally{let z=0;s+=z}return s}f()',
			'function f(v){switch(v){case 1:{let w=42;return w}default:return 0}}f(1)',
			'function f(){let x=1;let g=function(){return 41};x+=g();return x}f()',
			'function f(){let x=40;x++;++x;return x}f()',
			'var f=(n)=>{let a=[];for(const [k,v] of Object.entries({p:n})){a.push(k,v)}return a[1]+(a[0]=="p"?2:0)};f(40)',
		] {
			assert lexical_eval(source)!.number == 42, '${enabled}: ${source}'
		}
	}
}

fn test_lexical_registers_keep_tdz_and_const_errors() {
	defer { set_lexical_registers_for_testing(true) }
	for enabled in [false, true] {
		set_lexical_registers_for_testing(enabled)
		before := lexical_register_recompilations_for_testing()
		for source in [
			'function f(){try{x;let x=1;return 0}catch(e){return e instanceof ReferenceError?42:0}}f()',
			'function f(){try{let z=z+1;return 0}catch(e){return e instanceof ReferenceError?42:0}}f()',
			'function f(){try{typeof w;let w;return 0}catch(e){return e instanceof ReferenceError?42:0}}f()',
			'function f(){try{q=1;let q;return 0}catch(e){return e instanceof ReferenceError?42:0}}f()',
			'function f(){const c=1;try{c=2;return 0}catch(e){return e instanceof TypeError&&c===1?42:0}}f()',
			'function f(){const c=1;try{c++;return 0}catch(e){return e instanceof TypeError&&c===1?42:0}}f()',
			'function f(){const c=1;try{[c]=[2];return 0}catch(e){return e instanceof TypeError&&c===1?42:0}}f()',
			'function f(){const c=1;try{for(c of [2]){}return 0}catch(e){return e instanceof TypeError&&c===1?42:0}}f()',
			'function f(){try{for(const q of q){}return 0}catch(e){return e instanceof ReferenceError?42:0}}f()',
			'function f(){let r=[];for(let j=0;j<2;j++){try{if(j==1)r.push(y)}catch(e){r.push("tdz")}let y=j;r.push(y)}return r.join()=="0,tdz,1"?42:0}f()',
			'function f(v){switch(v){case 0:let s="zero";return s;case 1:try{return s}catch(e){return "tdz"}}}f(0)=="zero"&&f(1)=="tdz"?42:0',
			'function f(){let a=1,b=a+41;return b}f()',
			'function f(){const {a,b=a+40}={a:2};return a+b-2}f()',
		] {
			assert lexical_eval(source)!.number == 42, '${enabled}: ${source}'
		}
		recompiled := lexical_register_recompilations_for_testing() - before
		// Each function with an early read, a const write or a self-reference
		// compiles again; the last two cases initialize before every read.
		if enabled { assert recompiled == 10, '${recompiled}' } else { assert recompiled == 0 }
	}
}

fn test_lexical_registers_remove_block_environments() {
	defer { set_lexical_registers_for_testing(true) }
	for enabled in [false, true] {
		set_lexical_registers_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		mut script := Script.parse('function f(a){let s=0;for(let i=0;i<a.length;i++){const v=a[i];if(v){let w=v*2;s+=w}}for(const x of a){s+=x}return s}f([1,2,3])',
			vm.realm(), 'lexical-registers.js', unsafe { nil })!
		assert vm.run(mut script)!.number == 18
		function := lexical_function_for_test(mut vm, script, 'f')
		executable := function.executable or { panic('Missing bytecode') }
		environment_ops := executable.instructions.filter(it.op in [.enter_scope, .leave_scope,
			.create_mutable_binding, .create_immutable_binding, .initialize_binding, .get_binding,
			.set_binding]).len
		if enabled {
			assert environment_ops == 0
			// a stays a parameter register; s, i, v, w and x are lexical registers.
			assert executable.local_variable_names.len == 6
			// Call-time parameter metadata excludes lexical bindings.
			assert function.register_bindings.len == 1
		} else {
			assert environment_ops > 0
		}
	}
}
