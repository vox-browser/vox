module libjs

fn inline_pure_eval(source string) !string {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'inline-pure-ops.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 200000 })!
	assert value.is_string(), source
	return value.as_string().str()
}

// Inline strict equality, ToBoolean branches and logical not agree with the
// generic operations for every value kind; BigInts, equal-length strings at
// different addresses and uninitialized operands keep execute_instruction().
fn test_inline_strict_equality_branches_and_not_match_generic_semantics() {
	for source, expected in {
		'(function(){var o={},p={},s=Symbol(),t=Symbol(),u,n=null;return [o===o,o===p,s===s,s===t,u===undefined,n===null,u===n,n!==u,true===true,true===false,1===1.0,NaN===NaN,0===-0,1==="1",o!==o].join()})()': 'true,false,true,false,true,true,false,true,true,false,true,false,true,false,false'
		'(function(){var a="abc",b="ab"+"c",c="abd",d="ab",e="";return [a===b,a===c,a===d,a!==d,e==="",e===a,"x"===String.fromCharCode(120)].join()})()': 'true,false,false,true,true,false,true'
		'(function(){var a=1n,b=1n,c=2n;return [a===b,a===c,a!==c,a===1].join()})()': 'true,false,true,false'
		'(function(){var r=[];var vs=[0,-0,NaN,1,-1,"",""+"x","0",null,undefined,{},[],Symbol(),0n,1n,true,false];for(var i=0;i<vs.length;i++){var v=vs[i];var t=0;if(v)t=1;r.push(t+(!v?"n":"y"))}return r.join()})()': '0n,0n,0n,1y,1y,0n,1y,1y,0n,0n,1y,1y,1y,0n,1y,1y,0n'
		'(function(){var x=0,y="",z;var c=0;while(!x){x++;c++}do{c++}while(y);for(;z;){c=-1}return String(c+(!!z?1:0)+(!x?10:20))})()': '22'
		'(function(){try{if(q){}let q=1}catch(e){return e.name}})()': 'ReferenceError'
		'(function(){try{return String(!q);let q=1}catch(e){return e.name}})()': 'ReferenceError'
		'(function(){try{return String(q===1);let q=1}catch(e){return e.name}})()': 'ReferenceError'
	} {
		assert inline_pure_eval(source)! == expected, source
	}
}
