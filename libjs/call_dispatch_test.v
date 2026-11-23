module libjs

// call() enters ordinary functions' bodies directly; every other callable
// kind keeps its own [[Call]].
fn test_call_dispatches_each_function_kind() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('var r=[];r.push([1].map(function(x){return x+1})[0]);r.push([1].map(x=>x+2)[0]);function* g(){yield 4}r.push([g].map(f=>f().next().value)[0]);async function a(){return 5}r.push(typeof [a].map(f=>f())[0].then);class C{constructor(){this.v=6}}try{[C].map(f=>f())}catch(e){r.push(e instanceof TypeError?6:0)}r.push([1].map(function(x){return x+this.k}.bind({k:6}))[0]);r.push(Reflect.apply(function(){return this===undefined?8:0},undefined,[]));r.join()',
		vm.realm(), 'call-dispatch.js', unsafe { nil })!
	result := vm.run(mut script)!
	assert result.is_string()
	assert result.as_string().str() == '2,3,4,function,6,7,0'
}
