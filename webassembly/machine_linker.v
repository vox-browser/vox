// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/AbstractMachine/AbstractMachine.{h,cpp}: Linker.
module webassembly

pub struct BinaryMachineLinkName {
pub:
	module string
	name   string
	type_  BinaryImportDescription
}

// AK::Traits<Linker::Name> hashes and compares only module/name, not type.
// V maps require string keys; this length prefix preserves arbitrary bytes
// and unambiguously separates both source ByteStrings.
fn (name BinaryMachineLinkName) key() string {
	return '${name.module.len}:${name.module}${name.name}'
}

@[heap]
pub struct BinaryMachineQualifiedExports {
mut:
	values map[string]BinaryMachineExternValue
}

pub fn (mut exports BinaryMachineQualifiedExports) set(name BinaryMachineLinkName, value BinaryMachineExternValue) {
	exports.values[name.key()] = value
}

pub struct BinaryMachineLinkedValues {
pub:
	values []BinaryMachineExternValue
}

pub type BinaryMachineLinkResult = BinaryMachineLinkedValues | BinaryMachineLinkError

@[heap]
pub struct BinaryMachineLinker {
	module_ &Module
mut:
	resolved_imports_   map[string]BinaryMachineExternValue
	unresolved_imports_ map[string]BinaryMachineLinkName
	ordered_imports_    []BinaryMachineLinkName
	error_              ?BinaryMachineLinkError
}

pub fn BinaryMachineLinker.create(module_ &Module) &BinaryMachineLinker {
	return &BinaryMachineLinker{ module_: module_ }
}

fn (mut linker BinaryMachineLinker) populate() {
	if linker.ordered_imports_.len != 0 { return }
	for import_ in linker.module_.binary_import_entries {
		name := BinaryMachineLinkName{ module: import_.module, name: import_.name, type_: import_.description }
		linker.ordered_imports_ << name
		linker.unresolved_imports_[name.key()] = name
	}
}

// Source overload link(ModuleInstance const&): ignore the module qualifier.
pub fn (mut linker BinaryMachineLinker) link_module(instance &BinaryMachineModuleInstance) {
	linker.populate()
	if linker.unresolved_imports_.len == 0 { return }
	mut resolved := []string{}
	for key, import_ in linker.unresolved_imports_ {
		for export_ in instance.exports() {
			if export_.name() == import_.name {
				resolved << key
				linker.resolved_imports_[key] = export_.value()
				break
			}
		}
	}
	for key in resolved { linker.unresolved_imports_.delete(key) }
}

// Source overload link(HashMap<Name, ExternValue> const&).
pub fn (mut linker BinaryMachineLinker) link_exports(exports &BinaryMachineQualifiedExports) {
	linker.populate()
	if linker.unresolved_imports_.len == 0 { return }
	if exports.values.len == 0 { return }
	mut resolved := []string{}
	for key, _ in linker.unresolved_imports_ {
		if value := exports.values[key] {
			resolved << key
			linker.resolved_imports_[key] = value
		}
	}
	for key in resolved { linker.unresolved_imports_.delete(key) }
}

fn copy_binary_machine_link_error(source BinaryMachineLinkError) BinaryMachineLinkError {
	return BinaryMachineLinkError{ missing_imports: source.missing_imports.clone(), other_errors: source.other_errors.clone() }
}

pub fn (mut linker BinaryMachineLinker) finish() BinaryMachineLinkResult {
	linker.populate()
	if linker.unresolved_imports_.len != 0 {
		mut link_error := linker.error_ or { BinaryMachineLinkError{} }
		for _, entry in linker.unresolved_imports_ { link_error.missing_imports << entry.name }
		linker.error_ = link_error
		return copy_binary_machine_link_error(link_error)
	}
	if link_error := linker.error_ { return copy_binary_machine_link_error(link_error) }
	mut exports := []BinaryMachineExternValue{cap: linker.ordered_imports_.len}
	for import_ in linker.ordered_imports_ {
		value := linker.resolved_imports_[import_.key()] or { panic('Missing resolved source import') }
		exports << value
	}
	return BinaryMachineLinkedValues{ values: exports }
}
