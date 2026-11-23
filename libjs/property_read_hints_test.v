module libjs

fn property_hint_eval(source string) !Value {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'property-read-hints.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 200000 })
}

fn property_hint_string(source string) !string {
	value := property_hint_eval(source)!
	assert value.is_string(), source
	return value.as_string().str()
}

// One get_property site sees reordered, deleted, redefined and shadowed
// properties and exotic receivers; each read must match an unhinted [[Get]].
fn test_property_read_hints_follow_changing_receivers() {
	for source, expected in {
		'function g(o){return o.x}[g({x:1,y:2}),g({y:3,x:4}),g({x:5}),g({y:6}),g({x:7,y:8})].join()':                  '1,4,5,,7'
		'function g(o){return o.x}var o={a:1,x:2};var r=[g(o)];delete o.a;r.push(g(o));delete o.x;r.push(g(o));r.join()': '2,2,'
		'function g(o){return o.x}var o={x:1};var r=[g(o)];Object.defineProperty(o,"x",{get(){return 9}});r.push(g(o));r.join()': '1,9'
		'function g(o){return o.x}var p={x:"p"};var o=Object.create(p);var r=[g(o)];o.x="own";r.push(g(o));delete o.x;r.push(g(o));r.join()': 'p,own,p'
		'function g(o){return o.x}var o={x:1,y:2};g(o);var q={y:3};Object.setPrototypeOf(q,{x:"proto"});[g(o),g(q)].join()': '1,proto'
		'function g(o){return o.length}[g([1,2,3]),g({length:4}),g("abcde"),g(function(a,b){})].join()':              '3,4,5,2'
		'function g(o,k){return o[k]}var s=Symbol("s");var o={a:1};o[s]=2;o[3]=4;[g(o,"a"),g(o,s),g(o,3),g(o,"3"),g([7,8],1)].join()': '1,2,4,4,8'
		'function g(o){return o.x}var t={x:1};var p=new Proxy(t,{get(target,key){return "trap:"+key}});[g(t),g(p),g(t)].join()': '1,trap:x,1'
		'function g(o){return o.x}function f(){return g(arguments)}var a={x:"plain"};[g(a),f(1),g(new String("s")),g(a)].join()': 'plain,,,plain'
		'function g(o){return o.v}function P(v){this.v=v}var r=[];for(var i=0;i<5;i++){r.push(g(new P(i)))}r.join()': '0,1,2,3,4'
		'function g(o){return o.x}var o={x:1,get y(){return 2}};var r=[g(o)];o.x=5;r.push(g(o));o={get x(){return 6}};r.push(g(o));r.join()': '1,5,6'
	} {
		assert property_hint_string(source)! == expected, source
	}
}

fn test_property_read_hints_hit_for_one_construction_order() {
	diagnose_property_hints_for_testing(true)
	assert property_hint_eval('function P(i){this.a=i;this.b=i+1;this.c=i+2}function g(o){return o.c}var n=0;for(var i=0;i<20;i++){n+=g(new P(i))}n')!.number == 230
	hits := diagnose_property_hints_for_testing(false)
	assert hits >= 19
}
