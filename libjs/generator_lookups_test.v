module libjs

fn generator_lookups_eval(source string) !string {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'generator-lookups.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 2000000 })!
	assert value.is_string(), source
	return value.as_string().str()
}

// Past the linear-scan sizes, identifier, var-binding and function-id lookups
// keep one identifier per name, one var binding per name (also when a
// function and a var share it) and every declared function.
fn test_large_bodies_keep_identifiers_bindings_and_functions() {
	mut source := ''
	for index in 0 .. 120 {
		source += 'var v${index}=${index};function f${index}(){return v${index}}'
	}
	source += 'var v3=33;function f5(){return "second"}var f7;var shared=1;function shared(){}'
	source += 'var total=0;for(var i=0;i<120;i++)total+=globalThis["f"+i]===f5?0:globalThis["f"+i]();'
	source += '[total,f5(),typeof f7,v3,typeof shared,Object.keys(globalThis).filter(k=>k[0]=="v").length].join()'
	// 0..119 except f5 (returns "second"): sum - 5, with v3 = 33.
	assert generator_lookups_eval(source)! == '${7140 - 5 + 30},second,function,33,number,120'
	mut body := '(function(){'
	for index in 0 .. 60 { body += 'var a${index}=${index};' }
	body += 'function inner(){return a0+a59+a30}var r=inner();'
	for index in 0 .. 60 { body += 'a${index}++;' }
	body += 'return String(r+inner())})()'
	assert generator_lookups_eval(body)! == '${89 + 92}'
}
