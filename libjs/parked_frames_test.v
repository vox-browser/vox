module libjs

fn parked_frames_eval(mut vm VM, source string) !string {
	mut script := Script.parse(source, vm.realm(), 'parked-frames.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 20000000 })!
	assert value.is_string(), source
	return value.as_string().str()
}

const parked_frame_sources = {
	// Repeated calls, recursion of the same body and varying argument counts.
	'function f(a,b,c){var k="const";return [a,b,c,k].join()}function fact(n){return n<2?1:n*fact(n-1)}var r=[];for(var i=0;i<3;i++)r.push(f(i),f(i,1,2),f(),fact(6));r.join("|")': '0,,,const|0,1,2,const|,,,const|720|1,,,const|1,1,2,const|,,,const|720|2,,,const|2,1,2,const|,,,const|720'
	// Exceptions through a body, closures over its environment, arguments objects.
	'function thrower(x){var y=x*2;if(x%2)throw new Error("e"+y);return y}function maker(v){var w=v+1;return function(){return w}}function args(){return arguments.length+":"+Array.prototype.join.call(arguments,"")}var r=[];var keep=[];for(var i=0;i<4;i++){try{r.push(thrower(i))}catch(e){r.push(e.message)}keep.push(maker(i));r.push(args(i,i),args())}r.push(keep.map(function(g){return g()}).join(""));r.join()': '0,2:00,0:,e2,2:11,0:,4,2:22,0:,e6,2:33,0:,1234'
	// Generators and async functions keep their own frames.
	'function* gen(n){for(var i=0;i<n;i++)yield i*10}async function af(x){var y=await x;return y+1}var r=[];for(var j=0;j<3;j++){r.push([...gen(3)].join("/"));af(j).then(function(v){r.push("a"+v)})}r.join()': '0/10/20,0/10/20,0/10/20'
	// Many bodies sharing the 256 slots, called in rotating order.
	'var fs=[];for(var i=0;i<300;i++)fs.push(new Function("a","var x"+i+"=a+"+i+";return x"+i));var s=0;for(var round=0;round<3;round++)for(var j=0;j<300;j++)s+=fs[(j*7+round)%300](j);String(s)': '269100'
}

fn test_parked_frames_match_the_pool() {
	defer { set_parked_frames_for_testing(true) }
	for enabled in [false, true] {
		set_parked_frames_for_testing(enabled)
		parked_frame_hits_for_testing()
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		for source, expected in parked_frame_sources {
			assert parked_frames_eval(mut vm, source)! == expected, '${enabled}: ${source}'
			stack := vm.interpreter_stack()
			assert stack.top() == 0 && stack.depth() == 0, source
		}
		hits := parked_frame_hits_for_testing()
		if enabled {
			assert hits > 100
			assert vm.interpreter_stack().parked_contexts().len > 0
		} else {
			assert hits == 0 && vm.interpreter_stack().parked_contexts().len == 0
		}
	}
}

// Parked frames are cleared and their cached call environments are visible to
// root walks, like the pool's.
fn test_parked_frames_are_cleared_and_walked() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert parked_frames_eval(mut vm, 'function f(a){var big={payload:a};return String(a)}var r="";for(var i=0;i<5;i++)r=f(i);r')! == '4'
	parked := vm.interpreter_stack().parked_contexts()
	assert parked.len > 0
	for context in parked {
		assert !context.stack_allocated && context.function == none && context.this_value == none
		for value in context.values {
			assert !value.is_object()
		}
	}
	mut roots := HeapRoots{}
	vm.gather_roots(mut roots)
}
