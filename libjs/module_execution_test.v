module libjs

fn test_import_free_modules_keep_live_private_bindings_and_hoist_functions_at_link() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut global := Script.parse('var value=99;',vm.realm(),'global.js',unsafe { nil })!
	vm.run(mut global)!
	mut module_record := SourceTextModule.parse('export let value=1;export function inc(){value++}globalThis.moduleThis=this;export default value+1;',vm.realm(),'main.js',unsafe { nil })!
	module_record.link(mut vm)!
	function := module_record.local_export_value(mut vm,'inc')!
	assert function.is_function()
	if _ := module_record.local_export_value(mut vm,'value') {
		assert false,'A lexical export remains in its TDZ before evaluation'
	} else {
		assert thrown_value(err).as_object().error_kind()? == .reference_error
	}
	assert module_record.evaluate(mut vm)!.promise.state == .fulfilled
	assert module_record.local_export_value(mut vm,'default')!.number == 2
	assert module_record.local_export_value(mut vm,'value')!.number == 1
	call(mut vm,function,js_undefined(),[])!
	assert module_record.local_export_value(mut vm,'value')!.number == 2
	mut globals := vm.realm().global_object_record()
	assert globals.get(mut vm,PropertyName.from_str('value'))!.number == 99
	assert globals.get(mut vm,PropertyName.from_str('moduleThis'))!.is_undefined()
	assert globals.get(mut vm,PropertyName.from_str('inc'))!.is_undefined()
	assert vm.execution_context_stack().len == 1
	assert vm.interpreter_stack().depth() == 0
}

fn test_module_evaluation_caches_errors_and_runs_each_body_once() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut module_record := SourceTextModule.parse('globalThis.runs=(globalThis.runs||0)+1;throw 7;',vm.realm(),'failure.js',unsafe { nil })!
	module_record.link(mut vm)!
	first := module_record.evaluate(mut vm)!
	assert first.promise.state == .rejected
	assert first.promise.result.number == 7
	second := module_record.evaluate(mut vm)!
	assert voidptr(first) == voidptr(second)
	mut globals := vm.realm().global_object_record()
	assert globals.get(mut vm,PropertyName.from_str('runs'))!.number == 1
	assert vm.execution_context_stack().len == 1
	assert vm.interpreter_stack().depth() == 0
}

fn test_module_default_functions_are_available_before_body_evaluation() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut module_record := SourceTextModule.parse('export default function answer(){return 42}',vm.realm(),'answer.js',unsafe { nil })!
	module_record.link(mut vm)!
	assert call(mut vm,module_record.local_export_value(mut vm,'default')!,js_undefined(),[])!.number == 42
	assert module_record.evaluate(mut vm)!.promise.state == .fulfilled
	for source in ['export default function(){return 42}', 'export default ()=>42'] {
		mut anonymous := SourceTextModule.parse(source,vm.realm(),'anonymous.js',unsafe { nil })!
		anonymous.link(mut vm)!
		assert anonymous.evaluate(mut vm)!.promise.state == .fulfilled
		mut function := anonymous.local_export_value(mut vm,'default')!.as_object()
		assert function.get(mut vm,PropertyName.from_str('name'))!.as_string().str() == 'default'
		assert call(mut vm,Value.from_object(function),js_undefined(),[])!.number == 42
	}
}

fn test_module_budget_failure_restores_the_vm_and_dependency_support_stays_explicit() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut module_record := SourceTextModule.parse('while(true){}',vm.realm(),'loop.js',unsafe { nil })!
	module_record.link(mut vm)!
	result := module_record.evaluate_with_limits(mut vm,ExecutionLimits{max_instructions:128})!
	assert result.promise.state == .rejected
	assert result.promise.result.as_object().error_message()?.contains('instruction budget')
	for source in ['import "./dependency.js";','export * from "./dependency.js";','await 1;'] {
		mut unsupported := SourceTextModule.parse(source,vm.realm(),'unsupported.js',unsafe { nil })!
		unsupported.link(mut vm) or {
			assert thrown_value(err).as_object().error_kind()? == .internal_error
			continue
		}
		assert false,'Unsupported module operation must be explicit'
	}
	mut later := Script.parse('6*7',vm.realm(),'later.js',unsafe { nil })!
	assert vm.run(mut later)!.number == 42
}
