module libjs

fn test_import_meta_execution_retains_per_module_identity_and_the_defining_module_in_functions() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	agent := &vm
	vm.host_get_import_meta_properties=fn [agent] (module_record Module) []ImportMetaProperty {
		mut vm := unsafe { &VM(agent) }
		return [ImportMetaProperty{PropertyName.from_str('url'),Value.from_string(vm.create_string_from_str(module_record.filename()))}]
	}
	mut a := SourceTextModule.parse('export const meta=import.meta;export function read(){return import.meta}import.meta.count=41;export const answer=import.meta.count+1;',vm.realm(),'https://modules.test/a.js',unsafe { nil })!
	a.link(mut vm)!
	assert a.evaluate(mut vm)!.promise.state==.fulfilled
	meta := a.export_value(mut vm,utf16_string('meta'))!.as_object()
	assert meta.internal_get_prototype_of()==none
	assert meta.get(mut vm,PropertyName.from_str('url'))!.as_string().str()=='https://modules.test/a.js'
	assert a.export_value(mut vm,utf16_string('answer'))!.number==42
	mut b := SourceTextModule.parse('export default import.meta;',vm.realm(),'https://modules.test/b.js',unsafe { nil })!
	b.link(mut vm)!
	assert b.evaluate(mut vm)!.promise.state==.fulfilled
	assert voidptr(b.export_value(mut vm,utf16_string('default'))!.as_object())!=voidptr(meta)
	read := a.export_value(mut vm,utf16_string('read'))!
	assert voidptr(call(mut vm,read,js_undefined(),[])!.as_object())==voidptr(meta)
}
