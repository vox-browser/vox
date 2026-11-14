// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn test_repeated_function_creation_keeps_exact_utf16_source_without_reencoding_the_program() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	// The UTF-16 offsets include an astral character before both functions.
	// Creating many tiny closures from a large script must retain only their
	// source spans, rather than allocate the entire program for every closure.
	source := '/*' + 'x'.repeat(512 * 1024) + '😀*/\n' +
		'function factory(){return function inner(){return "😀";}};' +
		'var closures=[];for(var i=0;i<1000;i++){closures.push(factory())};' +
		'closures[999].toString()+":"+closures[999]().length+":"+closures.length'
	mut script := Script.parse(source, vm.realm(), 'large-source.js', unsafe { nil })!
	result := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})!
	assert result.as_string().str() == 'function inner(){return "😀";}:2:1000'
}

fn test_function_source_retains_defining_module_and_survives_other_scripts() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut module_record := SourceTextModule.parse('/*é😀*/export function factory(){return ()=>"é😀"}',
		vm.realm(), 'owner.mjs', unsafe { nil })!
	module_record.link(mut vm)!
	assert module_record.evaluate(mut vm)!.promise.state == .fulfilled
	factory := module_record.export_value(mut vm, utf16_string('factory'))!
	first := call(mut vm, factory, js_undefined(), [])!
	mut unrelated := Script.parse('"unrelated"', vm.realm(), 'other.js', unsafe { nil })!
	assert vm.run(mut unrelated)!.as_string().str() == 'unrelated'
	second := call(mut vm, factory, js_undefined(), [])!
	for closure in [first, second] {
		assert closure.as_object().function_source_text?.str() == '()=>"é😀"'
		assert call(mut vm, closure, js_undefined(), [])!.as_string().str() == 'é😀'
	}
}
