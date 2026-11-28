// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn resolvers_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'promise-with-resolvers.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:100000})
}

fn test_promise_with_resolvers_retains_original_resolvers_and_only_settles_once() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	resolvers_eval(mut vm, 'var value,record=Promise.withResolvers();record.promise.then(v=>value=v);record.resolve(42);record.reject(99);record.resolve(100)')!
	assert resolvers_eval(mut vm, 'value===42&&Object.keys(record).join(":")==="promise:resolve:reject"&&Object.getPrototypeOf(record)===Object.prototype&&Promise.withResolvers.length===0')!.as_bool()
}

fn test_promise_with_resolvers_uses_generic_new_promise_capability() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert resolvers_eval(mut vm, 'class P extends Promise{}var r=P.withResolvers();r.promise instanceof P&&typeof r.resolve==="function"&&typeof r.reject==="function"')!.as_bool()
	assert resolvers_eval(mut vm, 'var yes=()=>1,no=()=>2;function C(executor){executor(yes,no)}var x=Promise.withResolvers.call(C);x.promise instanceof C&&x.resolve===yes&&x.reject===no')!.as_bool()
}
