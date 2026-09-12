// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebAssembly/WebAssemblyModule.{h,cpp}. The V module record
// models ECMAScript environments and module linking explicitly while native
// LibWasm execution remains the embedding boundary.
module webassembly

import webidl

pub struct WebAssemblyResolvedBinding {
pub:
	module       &WebAssemblyModule = unsafe { nil }
	binding_name string
	valid        bool
}

@[heap]
pub struct WebAssemblyModuleEnvironment {
pub mut:
	bindings    map[string]ExternalValue
	initialized map[string]bool
	immutable   map[string]bool
}

pub fn WebAssemblyModuleEnvironment.create() &WebAssemblyModuleEnvironment {
	return &WebAssemblyModuleEnvironment{
		bindings: map[string]ExternalValue{}
		initialized: map[string]bool{}
		immutable: map[string]bool{}
	}
}

pub fn (mut environment WebAssemblyModuleEnvironment) create_immutable_binding(name string, kind ImportExportKind) ! {
	if name in environment.bindings {
		return error('SyntaxError: Duplicate WebAssembly export binding ${name}')
	}
	environment.bindings[name] = ExternalValue{
		kind: kind
		value: webidl.undefined_value()
	}
	environment.initialized[name] = false
	environment.immutable[name] = true
}

pub fn (mut environment WebAssemblyModuleEnvironment) initialize_binding(name string, value ExternalValue) ! {
	if name !in environment.bindings {
		return error('ReferenceError: WebAssembly export binding ${name} does not exist')
	}
	if environment.initialized[name] {
		return error('ReferenceError: WebAssembly export binding ${name} is already initialized')
	}
	environment.bindings[name] = value
	environment.initialized[name] = true
}

pub fn (environment &WebAssemblyModuleEnvironment) get_binding_value(name string) !ExternalValue {
	if !environment.initialized[name] {
		return error('ReferenceError: WebAssembly export binding ${name} is uninitialized')
	}
	return environment.bindings[name] or {
		return error('ReferenceError: WebAssembly export binding ${name} does not exist')
	}
}

@[heap]
pub struct WebAssemblyModule {
pub:
	realm             string
	filename          string
	module_source     &Module
	requested_modules []string
mut:
	instance_             &Instance = unsafe { nil }
	module_record_        &WebAssemblyModule = unsafe { nil }
	environment_          &WebAssemblyModuleEnvironment = unsafe { nil }
	cached_export_names_  []string
	has_cached_exports_   bool
	linked_wasm_modules_  map[string]&WebAssemblyModule
	linked_js_namespaces_ map[string]map[string]ExternalValue
}

pub fn WebAssemblyModule.create(realm string, filename string, module_source &Module) &WebAssemblyModule {
	mut requested_modules := []string{}
	for entry in module_source.import_entries {
		if entry.module !in requested_modules {
			requested_modules << entry.module
		}
	}
	mut record := &WebAssemblyModule{
		realm: realm
		filename: filename
		module_source: module_source
		requested_modules: requested_modules
		linked_wasm_modules_: map[string]&WebAssemblyModule{}
		linked_js_namespaces_: map[string]map[string]ExternalValue{}
	}
	record.module_record_ = record
	return record
}

pub fn WebAssemblyModule.parse(bytes []u8, realm string, filename string) !&WebAssemblyModule {
	stable_bytes := bytes.clone()
	module_source := compile_a_webassembly_module(stable_bytes)!
	for entry in module_source.import_entries {
		if entry.module.starts_with('wasm-js:') {
			return error('LinkError: Import with invalid module name')
		}
		if entry.name.starts_with('wasm:') || entry.name.starts_with('wasm-js:') {
			return error('LinkError: Import with invalid name')
		}
	}
	for entry in module_source.export_entries {
		if entry.name.starts_with('wasm:') || entry.name.starts_with('wasm-js:') {
			return error('LinkError: Export with invalid name')
		}
	}
	return WebAssemblyModule.create(realm, filename, module_source)
}

pub fn (mut record WebAssemblyModule) export_name_list() []string {
	if record.has_cached_exports_ {
		return record.cached_export_names_.clone()
	}
	mut names := []string{cap: record.module_source.export_entries.len}
	for entry in record.module_source.export_entries {
		names << entry.name
	}
	record.cached_export_names_ = names.clone()
	record.has_cached_exports_ = true
	return names
}

pub fn (mut record WebAssemblyModule) get_exported_names() []string {
	return record.export_name_list()
}

pub fn (mut record WebAssemblyModule) resolve_export(export_name string) WebAssemblyResolvedBinding {
	if export_name in record.export_name_list() {
		return WebAssemblyResolvedBinding{
			module: &record
			binding_name: export_name
			valid: true
		}
	}
	return WebAssemblyResolvedBinding{}
}

pub fn (mut record WebAssemblyModule) initialize_environment() ! {
	mut environment := WebAssemblyModuleEnvironment.create()
	for entry in record.module_source.export_entries {
		environment.create_immutable_binding(entry.name, entry.kind)!
	}
	record.environment_ = environment
}

pub fn (mut record WebAssemblyModule) link_webassembly_module(name string, module_record &WebAssemblyModule) {
	record.linked_wasm_modules_[name] = module_record
}

pub fn (mut record WebAssemblyModule) link_javascript_module(name string, namespace map[string]ExternalValue) {
	record.linked_js_namespaces_[name] = namespace.clone()
}

fn (record &WebAssemblyModule) resolve_import(entry ModuleImportDescriptor) !ExternalValue {
	if imported_module := record.linked_wasm_modules_[entry.module] {
		if isnil(imported_module.instance_) {
			return error('LinkError: Module ${entry.module} has not been instantiated')
		}
		for export_ in imported_module.instance_.module_instance().exports_ {
			if export_.name == entry.name {
				if export_.kind != entry.kind {
					return error('LinkError: ${entry.module}::${entry.name}: import and export kinds do not match')
				}
				return export_.value
			}
		}
		return error('LinkError: Import ${entry.module}.${entry.name} is missing')
	}
	namespace := (record.linked_js_namespaces_[entry.module] or {
		return error('LinkError: Import module=${entry.module} is not linked')
	}).clone()
	value := namespace[entry.name] or {
		return error('LinkError: Import ${entry.module}.${entry.name} is missing')
	}
	if value.kind != entry.kind {
		return error('LinkError: Import ${entry.module}.${entry.name} has the wrong kind')
	}
	return value
}

pub fn (mut record WebAssemblyModule) execute_module() ! {
	if isnil(record.environment_) {
		record.initialize_environment()!
	}
	mut imports := ImportObject{}
	for entry in record.module_source.import_entries {
		if entry.module !in imports {
			imports[entry.module] = map[string]ExternalValue{}
		}
		mut namespace := imports[entry.module].clone()
		namespace[entry.name] = record.resolve_import(entry)!
		imports[entry.module] = namespace.clone()
	}
	instance := Instance.create_for_realm(record.realm, record.module_source, imports)!
	record.instance_ = instance
	mut environment := record.environment_
	for export_ in instance.module_instance().exports_ {
		if export_.kind == .global {
			global := instance.global_instance(export_.address)
			environment.initialize_binding(export_.name, ExternalValue{
				kind: .global
				value: global.value()!
			})!
		} else {
			environment.initialize_binding(export_.name, export_.value)!
		}
	}
}

pub fn (record &WebAssemblyModule) instance() ?&Instance {
	if isnil(record.instance_) {
		return none
	}
	return record.instance_
}

pub fn (record &WebAssemblyModule) environment() ?&WebAssemblyModuleEnvironment {
	if isnil(record.environment_) {
		return none
	}
	return record.environment_
}

pub fn (record &WebAssemblyModule) module_record() &WebAssemblyModule {
	return record.module_record_
}
