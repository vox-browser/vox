// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn async_creation_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'async-creation.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_async_function_creation_is_lazy_and_preserves_source_and_metadata() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert async_creation_eval(mut vm, 'var calls=0;async function task(a,b){calls++;await a;return b};typeof task+":"+task.name+":"+task.length+":"+calls')!.as_string().str() == 'function:task:2:0'
	assert async_creation_eval(mut vm, 'Object.prototype.toString.call(task)==="[object AsyncFunction]"&&!Object.prototype.hasOwnProperty.call(task,"prototype")&&task.toString()==="async function task(a,b){calls++;await a;return b}"')!.as_bool()
	assert async_creation_eval(mut vm, 'var arrow=async x=>await x;var named=async function inner(){return inner};Object.getPrototypeOf(arrow)===Object.getPrototypeOf(task)&&Object.getPrototypeOf(named)===Object.getPrototypeOf(task)&&named.name==="inner"&&typeof inner==="undefined"')!.as_bool()
	assert async_creation_eval(mut vm, 'var caught=false;try{new task()}catch(e){caught=e instanceof TypeError};caught&&calls===0')!.as_bool()
}

fn test_module_async_exports_instantiate_without_executing_their_bodies() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut record := SourceTextModule.parse('export async function later(x){return await x};export const initialized=42', vm.realm(), 'async-export.mjs', unsafe { nil })!
	record.link(mut vm)!
	assert record.evaluate(mut vm)!.promise.state == .fulfilled
	assert record.export_value(mut vm, utf16_string('later'))!.is_function()
	assert record.export_value(mut vm, utf16_string('initialized'))!.number == 42
}

fn test_async_call_returns_promise_and_runs_its_body_after_lazy_creation() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	async_creation_eval(mut vm, 'var effects=0;async function pending(){effects++;return 42}')!
	value := async_creation_eval(mut vm, 'pending()')!
	assert value.as_object().promise_record?.state == .fulfilled
	assert value.as_object().promise_record?.result.number == 42
	assert async_creation_eval(mut vm, 'effects')!.number == 1
	assert vm.interpreter_stack().depth() == 0
}
