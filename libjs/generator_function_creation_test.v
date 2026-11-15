// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn generator_creation_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'generator-creation.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_generator_declarations_expressions_and_methods_are_created_without_running_bodies() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert generator_creation_eval(mut vm, 'var effects=0;function* g(a,b=effects++){effects++;yield a;return b}var h=function* inner(){yield inner};var methods={*walk(){yield 1}};typeof g==="function"&&g.name==="g"&&g.length===1&&effects===0&&h.name==="inner"&&typeof inner==="undefined"&&methods.walk.name==="walk"&&Object.getPrototypeOf(methods.walk)===Object.getPrototypeOf(g)&&Object.prototype.hasOwnProperty.call(methods.walk,"prototype")&&g.toString()==="function* g(a,b=effects++){effects++;yield a;return b}"')!.as_bool()
	assert generator_creation_eval(mut vm, 'Object.prototype.toString.call(g)==="[object GeneratorFunction]"&&Object.prototype.toString.call(g.prototype)==="[object Generator]"&&Object.getPrototypeOf(g.prototype)===Object.getPrototypeOf(h.prototype)&&g.prototype!==h.prototype&&!Object.prototype.hasOwnProperty.call(g.prototype,"constructor")&&Object.getPrototypeOf(g.prototype).constructor===Object.getPrototypeOf(g)&&Object.getPrototypeOf(Object.getPrototypeOf(g))===Object.getPrototypeOf(function(){})')!.as_bool()
	assert generator_creation_eval(mut vm, 'var d=Object.getOwnPropertyDescriptor(g,"prototype"),p=Object.getPrototypeOf(g),tag=Object.getOwnPropertyDescriptor(p,Symbol.toStringTag);d.writable&&!d.configurable&&!d.enumerable&&!tag.writable&&!tag.enumerable&&tag.configurable&&p.prototype===Object.getPrototypeOf(g.prototype)&&Object.getOwnPropertyNames(g).join(",")==="length,name,prototype"')!.as_bool()
}

fn test_async_generator_creation_has_separate_function_generator_and_iterator_prototypes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert generator_creation_eval(mut vm, 'var effects=0;async function* g(x){effects++;yield await x}function* sync(){}var methods={async *walk(){yield 1}};var p=Object.getPrototypeOf(g.prototype),it=Object.getPrototypeOf(p),identity=it[Symbol.asyncIterator];g.name==="g"&&g.length===1&&effects===0&&Object.prototype.toString.call(g)==="[object AsyncGeneratorFunction]"&&Object.prototype.toString.call(g.prototype)==="[object AsyncGenerator]"&&Object.getPrototypeOf(g)!==Object.getPrototypeOf(sync)&&Object.getPrototypeOf(g)===Object.getPrototypeOf(methods.walk)&&p.constructor===Object.getPrototypeOf(g)&&it!==Object.getPrototypeOf(Object.getPrototypeOf(sync.prototype))&&identity.call(g.prototype)===g.prototype&&identity.call(42)===42&&identity.length===0&&g.toString()==="async function* g(x){effects++;yield await x}"')!.as_bool()
}

fn test_generator_exports_instantiate_and_are_not_constructors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut record := SourceTextModule.parse('export function* sync(){yield 1};export async function* later(){yield await 2};export const initialized=42', vm.realm(), 'generators.mjs', unsafe { nil })!
	record.link(mut vm)!
	assert record.evaluate(mut vm)!.promise.state == .fulfilled
	assert record.export_value(mut vm, utf16_string('sync'))!.is_function()
	assert record.export_value(mut vm, utf16_string('later'))!.is_function()
	assert record.export_value(mut vm, utf16_string('initialized'))!.number == 42
	assert generator_creation_eval(mut vm, 'var effects=0,n=0;function* g(){effects++;yield 1}async function* a(){effects++;yield 2}for(var f of [g,a])try{new f()}catch(e){if(e instanceof TypeError)n++}n===2&&effects===0')!.as_bool()
}

fn test_async_generator_execution_remains_explicitly_unsupported_without_running_body() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	generator_creation_eval(mut vm, 'var effects=0;function* g(){effects++;yield 1}async function* a(){effects++;yield 2}')!
	for name in ['a'] {
		if _ := generator_creation_eval(mut vm, name+'()') { assert false } else {
			assert err.msg() == 'LibJS async generator execution is not translated yet'
		}
	}
	assert generator_creation_eval(mut vm, 'effects')!.number == 0
	assert vm.interpreter_stack().depth() == 0
}

fn test_generator_creation_uses_persisted_native_code_in_a_fresh_vm_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-generator-create-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert generator_creation_eval(mut vm, 'function factory(){return function* made(x){yield x}}var f=factory();f.name==="made"&&f.length===1&&Object.prototype.toString.call(f)==="[object GeneratorFunction]"')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
