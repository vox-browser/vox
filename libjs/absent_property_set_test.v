module libjs

fn absent_set_eval(source string) !Value {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'absent-property-set.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 2000000 })
}

fn test_absent_property_set_follows_ordinary_set() {
	defer { set_absent_property_set_for_testing(true) }
	for enabled in [false, true] {
		set_absent_property_set_for_testing(enabled)
		for source in [
			'function C(){for(var i=0;i<20;i++)this["f"+i]=i}var c=new C();c.f19===19&&Object.keys(c).length===20&&Object.keys(c)[0]==="f0"',
			'var log=[];var p={set x(v){log.push(v)}};var o=Object.create(p);o.x=5;log.join()==="5"&&!o.hasOwnProperty("x")',
			'var p={};Object.defineProperty(p,"x",{value:1,writable:false});var o=Object.create(p);o.x=5;o.x===1&&!o.hasOwnProperty("x")',
			'"use strict";var p={};Object.defineProperty(p,"x",{value:1,writable:false});var o=Object.create(p);try{o.x=5;false}catch(e){e instanceof TypeError}',
			'var o=Object.preventExtensions({a:1});o.b=2;o.b===undefined&&o.a===1',
			'"use strict";var o=Object.freeze({});try{o.b=2;false}catch(e){e instanceof TypeError}',
			'var p={y:1};var o=Object.create(p);o.y=2;o.y===2&&p.y===1&&o.hasOwnProperty("y")',
			'var o=Object.create(null);o.z=3;o.z===3&&Object.keys(o).join()==="z"',
			'var seen=[];var pr=new Proxy({},{set(t,k,v,r){seen.push(k);return Reflect.set(t,k,v,r)}});var o=Object.create(pr);o.q=1;seen.join()==="q"&&o.q===1',
			'var a=[];var o=Object.create(a);o.w=1;o.w===1&&a.w===undefined',
			'var s=Symbol("s");var o={};o[s]=1;o[s]===1&&Object.getOwnPropertySymbols(o).length===1',
			'var o={};o[7]=1;o["8"]=2;Object.keys(o).join()==="7,8"',
			'class A{constructor(){this.a=1;this.b=2}};class B extends A{constructor(){super();this.c=3}};var b=new B();Object.keys(b).join()==="a,b,c"',
			'var p={};Object.defineProperty(p,"g",{get(){return 7}});var o=Object.create(p);o.g=1;o.g===7&&!o.hasOwnProperty("g")',
		] {
			assert absent_set_eval(source)!.as_bool(), '${enabled}: ${source}'
		}
	}
}
