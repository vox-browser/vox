module libjs

fn literal_eval(source string) !Value {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'literal-properties.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 200000 })
}

fn test_literal_property_fast_path_preserves_definition_semantics() {
	defer { set_literal_property_fast_path_for_testing(true) }
	for enabled in [false, true] {
		set_literal_property_fast_path_for_testing(enabled)
		for source in [
			'var o={a:1,b:2,a:3};JSON.stringify(o)=="{\\"a\\":3,\\"b\\":2}"&&Object.keys(o).join()=="a,b"',
			'var o={get a(){return 1},a:2};var d=Object.getOwnPropertyDescriptor(o,"a");d.value===2&&d.writable&&d.enumerable&&d.configurable',
			'var o={a:1,get a(){return 5}};o.a===5&&Object.getOwnPropertyDescriptor(o,"a").set===undefined',
			'var o={b:1,2:"x",a:2,1:"y"};Object.keys(o).join()=="1,2,b,a"',
			'var s=Symbol("k");var o={[s]:1,x:2};o[s]===1&&Object.getOwnPropertySymbols(o).length===1',
			'var log=[];var k={toString(){log.push("k");return "z"}};var o={[k]:(log.push("v"),1)};o.z===1&&log.join()=="k,v"',
			'var o={__proto__:{p:1},q:2};o.p===1&&!Object.prototype.hasOwnProperty.call(o,"__proto__")',
			'var o={"__proto__":null,x:1};Object.getPrototypeOf(o)===null&&o.x===1',
			'var o={["__proto__"]:5};Object.getOwnPropertyDescriptor(o,"__proto__").value===5',
			'var a=[1,...[2,3],4];a.length===4&&a.join()=="1,2,3,4"',
			'var o={...{a:1,b:2},b:3};JSON.stringify(o)=="{\\"a\\":1,\\"b\\":3}"',
			'var o={1.5:1,"01":2,1e3:3};Object.keys(o).join()=="1000,1.5,01"',
			'var o={a:1};Object.preventExtensions(o);try{Object.defineProperty(o,"b",{value:1});false}catch(e){e instanceof TypeError}',
			'var o={length:3,0:"a"};Array.prototype.join.call(o,"-")=="a--"',
		] {
			assert literal_eval(source)!.as_bool(), '${enabled}: ${source}'
		}
	}
}

fn test_literal_constant_keys_skip_key_conversion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('function f(k){return {a:1,"b":2,3:3,[k]:4}}var o=f("c");o.a+o.b+o[3]+o.c===10', vm.realm(), 'literal-keys.js', unsafe { nil })!
	assert vm.run(mut script)!.as_bool()
	global := script.realm.global_object or { panic('Missing global') }
	value := global.internal_get(mut vm, PropertyName.from_str('f'), Value.from_object(global))!
	callable := value.as_object().callable or { panic('Missing function') }
	if callable is ECMAScriptFunction {
		executable := callable.executable or { panic('Missing bytecode') }
		// Only the computed key is converted before its value is evaluated.
		assert executable.instructions.filter(it.op == .to_property_key).len == 1
		assert executable.instructions.filter(it.op == .define_property).len == 4
	} else {
		assert false
	}
}

fn test_fresh_literal_names_skip_only_provably_new_keys() {
	defer { set_literal_property_fast_path_for_testing(true) }
	for enabled in [false, true] {
		set_literal_property_fast_path_for_testing(enabled)
		for source in [
			'var o={a:1,b:2,a:3};o.a===3&&Object.keys(o).join()==="a,b"',
			'var o={a:1,"a":2};o.a===2&&Object.keys(o).length===1',
			'var o={a:1,...{a:2},a:3,b:4};o.a===3&&Object.keys(o).join()==="a,b"',
			'var o={a:1,["a"]:2,a:3};o.a===3&&Object.keys(o).length===1',
			'var o={get a(){return 1},a:2};var d=Object.getOwnPropertyDescriptor(o,"a");d.value===2&&d.writable',
			'var o={"1":1,1:2,"01":3};o[1]===2&&o["01"]===3&&Object.keys(o).join()==="1,01"',
			'var o={};var src="";for(var i=0;i<60;i++)src+="k"+i+":"+i+",";var big=Function("return {"+src+"k0:99}")();big.k0===99&&big.k59===59&&Object.keys(big).length===60',
			'var o={x:1,y:2,z:3,w:4,v:5,u:6,t:7,s:8,r:9};Object.keys(o).join()==="x,y,z,w,v,u,t,s,r"&&o.r===9',
		] {
			assert literal_eval(source)!.as_bool(), '${enabled}: ${source}'
		}
	}
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('function f(k,s){return {a:1,b:2,a:3,[k]:4,c:5,...s,d:6}}f("z",{})', vm.realm(), 'fresh-literal.js', unsafe { nil })!
	vm.run(mut script)!
	global := script.realm.global_object or { panic('Missing global') }
	value := global.internal_get(mut vm, PropertyName.from_str('f'), Value.from_object(global))!
	callable := value.as_object().callable or { panic('Missing function') }
	if callable is ECMAScriptFunction {
		executable := callable.executable or { panic('Missing bytecode') }
		flags := executable.instructions.filter(it.op == .define_property).map(it.annex_b)
		// a, b fresh; the repeated a, the computed key and everything after it are checked.
		assert flags == [true, true, false, false, false, false], '${flags}'
	} else {
		assert false
	}
}
