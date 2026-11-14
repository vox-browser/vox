// SPDX-License-Identifier: BSD-2-Clause
module libjs

struct ModuleExportResolve {
	target &SourceTextModule
	name Utf16String
}

struct ResolvedModuleExport {
	target &SourceTextModule
	name Utf16String
	namespace bool
	ambiguous bool
}

fn (module_record &SourceTextModule) find_imported_source_module(request ModuleRequest) ?&SourceTextModule {
	for loaded in module_record.loaded {
		if module_requests_equal(loaded,request) && loaded.module_record is SourceTextModule { return loaded.module_record }
	}
	return none
}

// SourceTextModule.cpp::ResolveExport, retaining binding identity through aliases
// and star exports rather than copying a value from the exporting environment.
fn (module_record &SourceTextModule) resolve_module_export(name Utf16String,visited []ModuleExportResolve) ?ResolvedModuleExport {
	if visited.len>=4096 || StackInfo.new().size_free()<512*1024 { return none }
	if visited.any(voidptr(it.target)==voidptr(module_record) && it.name==name) { return none }
	mut seen := visited.clone();seen << ModuleExportResolve{module_record,name}
	program := module_record.parsed.program.kind.program_data or { return none }
	for statement in program.scope.children {
		if statement.kind.tag!=.export_stmt { continue }
		export := statement.kind.export_data or { continue }
		for entry in export.entries {
			if (entry.export_name or { continue })!=name { continue }
			if request := export.module_request {
				target := module_record.find_imported_source_module(request) or { return none }
				if entry.kind==.module_request_all { return ResolvedModuleExport{target:target,namespace:true} }
				return target.resolve_module_export(entry.local_or_import_name or { return none },seen)
			}
			local := entry.local_or_import_name or { return none }
			for imported in program.scope.children {
				if imported.kind.tag!=.import_stmt { continue }
				data := imported.kind.import_data or { continue }
				for binding in data.entries {
					if binding.local_name!=local { continue }
					target := module_record.find_imported_source_module(data.module_request) or { return none }
					if original := binding.import_name { return target.resolve_module_export(original,seen) }
					return ResolvedModuleExport{target:target,namespace:true}
				}
			}
			return ResolvedModuleExport{target:module_record,name:local}
		}
	}
	if name==utf16_string('default') { return none }
	mut star := ?ResolvedModuleExport(none)
	for statement in program.scope.children {
		if statement.kind.tag!=.export_stmt { continue }
		export := statement.kind.export_data or { continue }
		if !export.entries.any(it.kind==.module_request_all_but_default) { continue }
		target := module_record.find_imported_source_module(export.module_request or { continue }) or { continue }
		resolution := target.resolve_module_export(name,seen) or { continue }
		if resolution.ambiguous { return resolution }
		if prior := star {
			if voidptr(prior.target)!=voidptr(resolution.target) || prior.name!=resolution.name || prior.namespace!=resolution.namespace {
				return ResolvedModuleExport{target:module_record,ambiguous:true}
			}
		} else { star=resolution }
	}
	return star
}

fn (module_record &SourceTextModule) module_export_names(visited []voidptr) []Utf16String {
	if visited.len>=4096 || StackInfo.new().size_free()<512*1024 { return [] }
	if visited.contains(voidptr(module_record)) { return [] }
	mut seen := visited.clone();seen << voidptr(module_record)
	mut names := []Utf16String{}
	program := module_record.parsed.program.kind.program_data or { return names }
	for statement in program.scope.children {
		if statement.kind.tag!=.export_stmt { continue }
		export := statement.kind.export_data or { continue }
		for entry in export.entries {
			if name := entry.export_name { if !names.contains(name) { names << name } }
			if entry.kind!=.module_request_all_but_default { continue }
			target := module_record.find_imported_source_module(export.module_request or { continue }) or { continue }
			for name in target.module_export_names(seen) { if name!=utf16_string('default') && !names.contains(name) { names << name } }
		}
	}
	return names
}

pub fn (module_record &SourceTextModule) export_value(mut vm VM,name Utf16String) !Value {
	resolution := module_record.resolve_module_export(name,[]) or { return vm.throw_error(.syntax_error,'Module has no export named ${name.str()}') }
	if resolution.ambiguous { return vm.throw_error(.syntax_error,'Ambiguous module export ${name.str()}') }
	mut target := unsafe { &SourceTextModule(resolution.target) }
	if resolution.namespace { return Value.from_object(target.get_module_namespace(mut vm)!) }
	mut environment := target.module_environment or { return vm.throw_error(.reference_error,'Module has no environment') }
	return environment.get_binding_value(mut vm,resolution.name,true)
}

// Namespace read adapter. Null prototype, stable identity, sorted live exports,
// read-only writes and non-extensibility are preserved. Its legacy non-throwing
// descriptor boundary uses accessors; full namespace data-descriptor/freeze
// semantics remain a separate Object internal-method migration.
struct ModuleNamespaceProperty {
	key PropertyName
	getter Value
}

@[heap]
struct ModuleNamespaceProperties { properties []ModuleNamespaceProperty }

fn (properties &ModuleNamespaceProperties) own_property_keys() []PropertyName {
	return properties.properties.map(it.key)
}

fn (properties &ModuleNamespaceProperties) get_own_property(key PropertyName) ?PropertyDescriptor {
	for property in properties.properties {
		if property.key.equals(key) { return PropertyDescriptor{getter:property.getter,setter:js_undefined(),enumerable:true,configurable:false} }
	}
	return none
}

fn module_name_less(a Utf16String,b Utf16String) bool {
	bound := if a.data.len<b.data.len { a.data.len } else { b.data.len }
	for index in 0 .. bound { if a.data[index]!=b.data[index] { return a.data[index]<b.data[index] } }
	return a.data.len<b.data.len
}

pub fn (mut module_record SourceTextModule) get_module_namespace(mut vm VM) !&Object {
	if namespace := module_record.module_namespace_ { return namespace }
	if module_record.module_status==.unlinked { return vm.throw_error(.internal_error,'Module must be linked before its namespace is observed') }
	mut names := module_record.module_export_names([])
	for index in 1 .. names.len {
		mut cursor := index
		for cursor>0 && module_name_less(names[cursor],names[cursor-1]) {
			names[cursor],names[cursor-1]=names[cursor-1],names[cursor];cursor--
		}
	}
	mut object := Object.create(module_record.module_realm,none)
	object.class_name='Module'
	module_record.module_namespace_=object
	mut properties := []ModuleNamespaceProperty{}
	owner := &module_record
	for name in names {
		resolved := module_record.resolve_module_export(name,[]) or { continue }
		if resolved.ambiguous { continue }
		key := PropertyName.from_utf16(name)
		getter := NativeFunction.create(mut vm,module_record.module_realm,module_record.module_realm.function_prototype,
			fn [owner,name] (mut vm VM) !Value { return owner.export_value(mut vm,name) },0,key,'get')
		properties << ModuleNamespaceProperty{key,Value.from_object(getter.object)}
	}
	object.host_properties=&ModuleNamespaceProperties{properties:properties}
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),Value.from_string(vm.create_string_from_str('Module')),0)
	object.internal_prevent_extensions()
	return object
}
