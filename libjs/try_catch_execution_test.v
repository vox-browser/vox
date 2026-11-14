module libjs

fn catch_eval(mut vm VM,source string) !Value {
	mut script := Script.parse(source,vm.realm(),'catch.js',unsafe { nil })!
	return vm.run_with_limits(mut script,ExecutionLimits{max_instructions:100000})
}

fn test_try_catch_executes_real_throws_and_native_errors_with_private_catch_bindings() {
	mut vm := VM.create();create_simple_execution_context(mut vm)
	assert catch_eval(mut vm,'var answer=0;try{throw 42}catch(e){answer=e}answer')!.number==42
	assert catch_eval(mut vm,'typeof e')!.as_string().str()=='undefined'
	assert catch_eval(mut vm,'try{missing()}catch(e){e.message}')!.as_string().str().contains('missing')
	assert catch_eval(mut vm,'try{throw undefined}catch{42}')!.number==42
	assert catch_eval(mut vm,'function boom(){throw 21}try{boom()}catch(e){e*2}')!.number==42
	assert catch_eval(mut vm,'try{var hoisted=42}catch(e){var alsoHoisted=9}hoisted+":"+typeof alsoHoisted')!.as_string().str()=='42:undefined'
}

fn test_nested_catches_restore_lexical_environments_and_catch_rethrows_in_the_outer_handler() {
	mut vm := VM.create();create_simple_execution_context(mut vm)
	assert catch_eval(mut vm,'let x=40;try{let x=1;{let x=9;throw x}}catch(x){x=2}x+2')!.number==42
	assert catch_eval(mut vm,'try{try{throw 1}catch(e){throw e+1}}catch(e){e+40}')!.number==42
	assert catch_eval(mut vm,'var total=0;for(var i=0;i<4;i++){try{throw i}catch(e){if(e==2)break;total+=e}}total')!.number==1
	assert catch_eval(mut vm,'var total2=0;for(var j=0;j<4;j++){try{throw j}catch(e){if(e==2)continue;total2+=e}}total2')!.number==4
	assert catch_eval(mut vm,'function f(){try{return 42}catch(e){return 1}}f()')!.number==42
	catch_eval(mut vm,'try{throw 5}catch(e){throw e+2}') or { assert thrown_value(err).number==7;return }
	assert false,'Unhandled throws must leave the executable'
}
