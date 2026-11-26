module libjs

fn array_lookup_eval(source string) !Value {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'array-element-lookup.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 2000000 })
}

fn test_array_index_positions_preserve_element_semantics() {
	defer { set_array_index_positions_for_testing(true) }
	for enabled in [false, true] {
		set_array_index_positions_for_testing(enabled)
		for source in [
			'var a=[];for(var i=0;i<40;i++)a.push(i*2);a[39]===78&&a.length===40&&a.indexOf(50)===25',
			'var a=[];a[30]=1;a[2]=2;for(var i=0;i<20;i++)a[i+40]=i;a[30]===1&&a[2]===2&&a[45]===5&&!(3 in a)&&a.length===60',
			'var a=Array.from({length:30},(v,i)=>i);a.length=10;a[25]===undefined&&!(25 in a)&&a.length===10&&a[9]===9',
			'var a=Array.from({length:30},(v,i)=>i);delete a[12];a[12]=99;a[12]===99&&Object.keys(a).length===30&&a.indexOf(99)===12',
			'var a=Array.from({length:30},(v,i)=>i);Object.defineProperty(a,5,{get(){return "g"}});a[5]==="g"&&a[6]===6',
			'var a=Array.from({length:20},(v,i)=>i);Object.defineProperty(a,"length",{writable:false});var ok=false;try{"use strict";a.push(1)}catch(e){ok=e instanceof TypeError}ok&&a.length===20&&a[20]===undefined',
			'var a=Array.from({length:20},(v,i)=>i);a.foo=1;a[100]=7;a[100]===7&&a.length===101&&a.foo===1&&a[50]===undefined',
			'var a=new Array(25);a[24]=1;a[3]=2;a.length===25&&a[24]===1&&a[3]===2&&a[0]===undefined&&!(0 in a)',
			'var a=Array.from({length:20},(v,i)=>i);a.splice(5,3);a.length===17&&a[5]===8&&a[16]===19&&a[17]===undefined',
			'var a=Array.from({length:20},(v,i)=>i);a.unshift(-1);a[0]===-1&&a[20]===19&&a.length===21',
			'var a=Array.from({length:20},(v,i)=>i);a.reverse();a[0]===19&&a[19]===0',
			'var a=Array.from({length:20},(v,i)=>20-i);a.sort((x,y)=>x-y);a[0]===1&&a[19]===20',
			'Array.prototype[50]="p";var a=Array.from({length:20},(v,i)=>i);var r=a[50]==="p"&&!a.hasOwnProperty(50);delete Array.prototype[50];r',
		] {
			assert array_lookup_eval(source)!.as_bool(), '${enabled}: ${source}'
		}
	}
}

fn test_array_named_property_count_never_undercounts() {
	defer { set_array_index_positions_for_testing(true) }
	for enabled in [false, true] {
		set_array_index_positions_for_testing(enabled)
		for source in [
			'var a=Array.from({length:30},(v,i)=>i);a.foo=1;a.foo===1&&("foo" in a)&&a.hasOwnProperty("foo")&&!a.hasOwnProperty("bar")',
			'var a=Array.from({length:30},(v,i)=>i);var s=Symbol("s");a[s]=2;a[s]===2&&Object.getOwnPropertySymbols(a).length===1',
			'var a=Array.from({length:30},(v,i)=>i);a.foo=1;delete a.foo;a.bar=3;a.foo===undefined&&a.bar===3&&Object.keys(a).length===31',
			'var a=Array.from({length:30},(v,i)=>i);a[4294967295]=5;a[4294967295]===5&&a.length===30&&Object.keys(a).includes("4294967295")',
			'var a=Array.from({length:30},(v,i)=>i);Object.defineProperty(a,"x",{get(){return 9}});a.x===9',
			'var a=Array.from({length:30},(v,i)=>i);a.push.call(a,1);typeof a.push==="function"&&a.length===31&&a[Symbol.iterator]===Array.prototype[Symbol.iterator]',
			'var m=/(a)(b)/.exec("xab");m.index===1&&m.input==="xab"&&m[2]==="b"',
			'var a=[];for(var i=0;i<40;i++)a.push(i);var t=0;for(var v of a)t+=v;t===780&&a.map(x=>x*2)[39]===78',
		] {
			assert array_lookup_eval(source)!.as_bool(), '${enabled}: ${source}'
		}
	}
}
