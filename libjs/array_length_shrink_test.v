module libjs

fn array_shrink_eval(source string) !string {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'array-shrink.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 3000000 })!
	assert value.is_string(), source
	return value.as_string().str()
}

// Shrinking an array's length removes configurable indices at and above the
// new length in place, keeps named properties and their order, and stops
// above the highest non-configurable index.
fn test_array_length_shrinks_in_place_with_spec_results() {
	for source, expected in {
		'var a=[];for(var i=0;i<20000;i++)a.push(i);var s=0;while(a.length)s+=a.pop();[s,a.length,JSON.stringify(a)].join()': '199990000,0,[]'
		'var a=[0,1,2,3,4,5];a.x=1;a.length=2;a.y=2;a[4]=9;[a.length,Object.keys(a).join(),a[2],a[4]].join()':                     '5,0,1,4,x,y,,9'
		'var a=[0,1,2,3,4];Object.defineProperty(a,3,{value:3,configurable:false});a.length=1;[a.length,Object.keys(a).join()].join(":")': '4:0,1,2,3'
		'"use strict";var a=[0,1,2];Object.defineProperty(a,1,{value:1,configurable:false});var e;try{a.length=0}catch(x){e=x.name}[a.length,e,Object.keys(a).join()].join()': '2,TypeError,0,1'
		'var a=[1,,3,,5];a.length=3;[a.length,0 in a,1 in a,2 in a,3 in a].join()':                                              '3,true,false,true,false'
		'var a=[1,2,3];a.length=0;a.push(7);[a.length,a[0],a.join()].join()':                                                    '1,7,7'
		'var a=[];for(var i=0;i<100;i++)a[i]=i;a.length=50;var t=0;for(var j=0;j<100;j++)t+=(j in a)?1:0;[t,a[49],a[50]].join()': '50,49,'
	} {
		assert array_shrink_eval(source)! == expected, source
	}
}

// pop() keeps its results for dense arrays and for every array the fast
// path leaves to the generic steps.
fn test_array_pop_matches_generic_steps() {
	for source, expected in {
		'var a=[1,2,3];[a.pop(),a.pop(),a.length,a.pop(),a.pop(),a.length].join()':                                        '3,2,1,1,,0'
		'var a=[1,2,3];a.x=1;[a.pop(),a.length,Object.keys(a).join()].join(":")':                                           '3:2:0,1,x'
		'var a=[1,,3];a.length=4;[a.pop(),a.length,a.pop(),a.length].join()':                                               ',3,3,2'
		'var a=[1,2];Object.defineProperty(a,1,{get(){return 9},configurable:true});[a.pop(),a.length].join()':           '9,1'
		'"use strict";var a=[1,2];Object.defineProperty(a,1,{value:2,configurable:false});var e;try{a.pop()}catch(x){e=x.name}[e,a.length].join()': 'TypeError,2'
		'"use strict";var a=[1,2];Object.defineProperty(a,"length",{writable:false});var e;try{a.pop()}catch(x){e=x.name}[e,a.length,a[1]].join()': 'TypeError,2,'
		'var o={length:2,0:"a",1:"b"};var v=Array.prototype.pop.call(o);[v,o.length,1 in o].join()':                        'b,1,false'
		'var a=[];a[5]=1;a[0]=0;[a.pop(),a.length,a.pop(),a.length].join()':                                               '1,5,,4'
	} {
		assert array_shrink_eval(source)! == expected, source
	}
}
