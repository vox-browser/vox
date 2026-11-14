// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/ModuleEnvironment.cpp::CreateImportBinding / GetBindingValue.
struct ModuleImportBinding {
	name Utf16String
	target &SourceTextModule
	target_name Utf16String
}

pub fn (environment &ModuleEnvironment) has_binding(mut vm VM, name Utf16String) !(bool, ?int) {
	if environment.imports.any(it.name==name) { return true,none }
	return environment.DeclarativeEnvironment.has_binding(mut vm,name)
}

pub fn (mut environment ModuleEnvironment) get_binding_value(mut vm VM,name Utf16String,strict bool) !Value {
	for binding in environment.imports {
		if binding.name!=name { continue }
		mut target := binding.target.module_environment or { return vm.throw_error(.reference_error,'Imported module has no environment') }
		return target.get_binding_value(mut vm,binding.target_name,true)
	}
	return environment.DeclarativeEnvironment.get_binding_value(mut vm,name,strict)
}

pub fn (mut environment ModuleEnvironment) set_mutable_binding(mut vm VM,name Utf16String,value Value,strict bool) ! {
	if environment.imports.any(it.name==name) { return vm.throw_error(.type_error,'Cannot assign to imported binding ${name.str()}') }
	environment.DeclarativeEnvironment.set_mutable_binding(mut vm,name,value,strict)!
}

fn (mut module_record SourceTextModule) initialize_module_imports(mut vm VM,mut environment ModuleEnvironment) ! {
	program := module_record.parsed.program.kind.program_data or { return error('Missing module program') }
	for statement in program.scope.children {
		if statement.kind.tag!=.import_stmt { continue }
		data := statement.kind.import_data or { return error('Missing import declaration') }
		mut target := module_record.imported_source_module(mut vm,data.module_request)!
		for entry in data.entries {
			if name := entry.import_name {
				resolution := target.resolve_module_export(name,[]) or { return vm.throw_error(.syntax_error,'Module has no export named ${name.str()}') }
				if resolution.ambiguous { return vm.throw_error(.syntax_error,'Ambiguous module export ${name.str()}') }
				if resolution.namespace {
					mut actual := unsafe { &SourceTextModule(resolution.target) }
					environment.create_immutable_binding(mut vm,entry.local_name,true)!
					environment.initialize_binding(mut vm,entry.local_name,Value.from_object(actual.get_module_namespace(mut vm)!),.normal)!
				} else {
					environment.imports << ModuleImportBinding{entry.local_name,resolution.target,resolution.name}
				}
			} else {
				environment.create_immutable_binding(mut vm,entry.local_name,true)!
				environment.initialize_binding(mut vm,entry.local_name,Value.from_object(target.get_module_namespace(mut vm)!),.normal)!
			}
		}
	}
}
