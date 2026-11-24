module libjs

fn direct_iteration_eval(source string) !string {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'direct-iteration.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 5000000 })!
	assert value.is_string(), source
	return value.as_string().str()
}

const direct_iteration_sources = {
	// Holes read the prototype chain; accessor elements run with the array as receiver.
	'var a=[1,,3];Array.prototype[1]="proto";var r=[];for(var x of a)r.push(x);delete Array.prototype[1];for(var x of a)r.push(x);Object.defineProperty(a,2,{get(){return this===a?"getter":"bad"},configurable:true});for(var x of a)r.push(x);r.join()': '1,proto,3,1,,3,1,,getter'
	// Growth, shrinking and length writes during iteration are observed.
	'var a=[1,2,3];var r=[];for(var x of a){r.push(x);if(x===1)a.push(4);if(x===3)a.length=3}var b=[1,2,3,4];for(var y of b){r.push(y);b.pop()}r.join()': '1,2,3,1,2'
	// Named properties, a prototype index getter and a sparse length.
	'var a=[5,6];a.name="n";a[Symbol.iterator]===Array.prototype[Symbol.iterator];var r=[...a];Object.defineProperty(Array.prototype,7,{get(){return "p7"},configurable:true});var s=[];s.length=9;s[0]="z";r=r.concat([...s]);delete Array.prototype[7];r.join()': '5,6,z,,,,,,,p7,'
	// Proxies over arrays, array subclasses, typed arrays and array-likes.
	'var log=[];var p=new Proxy([1,2],{get(t,k,rc){if(typeof k==="string")log.push(k);return Reflect.get(t,k,rc)}});var r=[];for(var x of p)r.push(x);class Sub extends Array{};var s=Sub.from([7,8]);for(var y of s)r.push(y);for(var z of new Uint8Array([9,10]))r.push(z);for(var w of Array.prototype.values.call({length:2,0:"a",1:"b"}))r.push(w);r.join()+"|"+log.join()': '1,2,7,8,9,10,a,b|length,0,length,1,length'
	// entries/keys, destructuring, Array.from, spread and Map/Set iterators.
	'var a=["p","q"];var r=[];for(var [i,v] of a.entries())r.push(i+v);for(var k of a.keys())r.push(k);var [x,,z]=[1,2,3];r.push(x,z,Array.from([4,5]).join("+"),Math.max(...[6,7]));for(var [mk,mv] of new Map([["m",1]]))r.push(mk+mv);for(var sv of new Set([8,8,9]))r.push(sv);r.join()': '0p,1q,0,1,1,3,4+5,7,m1,8,9'
	// A replaced next() method is called for every step.
	'var it=Array.prototype[Symbol.iterator];var proto=Object.getPrototypeOf([][Symbol.iterator]());var next=proto.next;var calls=0;proto.next=function(){calls++;return next.call(this)};var r=[];for(var x of [1,2])r.push(x);proto.next=next;for(var y of [3])r.push(y);r.join()+"|"+calls': '1,2,3|3'
}

fn test_direct_array_iteration_matches_complete_gets() {
	defer { set_direct_array_iteration_for_testing(true) }
	for enabled in [false, true] {
		set_direct_array_iteration_for_testing(enabled)
		for source, expected in direct_iteration_sources {
			assert direct_iteration_eval(source)! == expected, '${enabled}: ${source}'
		}
	}
}

// Native iterator steps run in the depth's native frame and restore it.
fn test_native_iterator_steps_use_native_frames() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	native_frame_slot_reuses_for_testing()
	mut script := Script.parse('var s=0;for(var x of [1,2,3,4,5,6,7,8,9,10])s+=x;for(var c of "abc")s+=c.length;for(var [k,v] of new Map([[1,2],[3,4]]))s+=k+v;String(s)',
		vm.realm(), 'native-steps.js', unsafe { nil })!
	assert vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })!.as_string().str() == '68'
	assert native_frame_slot_reuses_for_testing() >= 12
	stack := vm.interpreter_stack()
	assert stack.native_frame_depth == 0 && stack.top() == 0 && stack.depth() == 0
}
