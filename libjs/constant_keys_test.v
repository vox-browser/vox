module libjs

fn constant_keys_eval(source string) !string {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'constant-keys.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 200000 })!
	assert value.is_string(), source
	return value.as_string().str()
}

// String constant keys convert once per compiled body. Index-like strings,
// computed and symbol keys, accessors, prototypes and literals keep their
// ToPropertyKey results.
fn test_constant_property_keys_match_to_property_key() {
	constant_key_hits = 0
	for source, expected in {
		'var o={a:1,"2":3,b:4};o.c=5;o["d"]=6;[o.a,o[2],o["2"],o.b,o.c,o.d,Object.keys(o).join("")].join()': '1,3,3,4,5,6,2abcd'
		'var o={};o["10"]=1;o[10]+=1;var a=[7,8];a["1"]=9;[o[10],a[1],a.length,Object.keys(o).join()].join()':  '2,9,2,10'
		'var k="x",s=Symbol("s"),o={[k]:1,[s]:2};o[k+"y"]=3;[o.x,o[s],o.xy].join()':                          '1,2,3'
		'var log=[],o={get g(){log.push("g");return 1},set g(v){log.push("s"+v)}};o.g=2;[o.g,log.join()].join()': '1,s2,g'
		'function P(){this.v=1}P.prototype.w=2;var p=new P;[p.v,p.w,"w" in p,p.hasOwnProperty("w")].join()':     '1,2,true,false'
		'function f(){var o={n:0};for(var i=0;i<5;i++){o.n=o.n+i}return o.n}[f(),f()].join()':                     '10,10'
		'var o={__proto__:{q:4},r:5};[o.q,o.r,Object.getPrototypeOf(o).q].join()':                                '4,5,4'
		'"use strict";var o=Object.freeze({f:1});var e;try{o.f=2}catch(x){e=x.name}[o.f,e].join()':               '1,TypeError'
	} {
		assert constant_keys_eval(source)! == expected, source
	}
	assert constant_key_hits > 0
}
