module libjs

fn for_environment_eval(source string) !bool {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'for-environments.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})!.as_bool()
}

fn test_for_let_closures_keep_initial_and_per_iteration_bindings() {
	assert for_environment_eval('var initial,values=[];for(let i=0,read=(initial=()=>i);i<3;i++){values.push(()=>i)}initial()===0&&values[0]()===0&&values[1]()===1&&values[2]()===2')!
	assert for_environment_eval('var values=[];for(let [i,j]=[0,40];i<3;i++,j++){values.push(()=>j);if(i===1)continue}values[0]()===40&&values[1]()===41&&values[2]()===42')!
}

fn test_iteration_copies_preserve_break_finally_var_and_const_behavior() {
	assert for_environment_eval('var values=[],order="";for(let i=0;i<4;i++){try{values.push(()=>i);if(i===1)continue;if(i===2)break}finally{order+=i}}order==="012"&&values[0]()===0&&values[1]()===1&&values[2]()===2')!
	assert for_environment_eval('var values=[];for(var i=0;i<3;i++)values.push(()=>i);values[0]()===3&&values[2]()===3')!
	assert for_environment_eval('var read;for(const i=42;true;){read=()=>i;break}read()===42&&typeof i==="undefined"')!
}
