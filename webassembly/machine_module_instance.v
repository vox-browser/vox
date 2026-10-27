// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// AbstractMachine.{h,cpp}: ModuleInstance records and resolved owner tables.
module webassembly

pub struct BinaryMachineFunctionAddress {
pub:
	value u64
}

pub struct BinaryMachineTableAddress {
pub:
	value u64
}

pub struct BinaryMachineMemoryAddress {
pub:
	value u64
}

pub struct BinaryMachineGlobalAddress {
pub:
	value u64
}

pub struct BinaryMachineTagAddress {
pub:
	value u64
}

pub type BinaryMachineExternValue = BinaryMachineFunctionAddress
	| BinaryMachineTableAddress
	| BinaryMachineMemoryAddress
	| BinaryMachineGlobalAddress
	| BinaryMachineTagAddress

pub struct BinaryMachineExportInstance {
	name_  string
	value_ BinaryMachineExternValue
}

pub fn BinaryMachineExportInstance.create(name string, value BinaryMachineExternValue) BinaryMachineExportInstance {
	return BinaryMachineExportInstance{ name_: name, value_: value }
}

pub fn (export_ &BinaryMachineExportInstance) name() string { return export_.name_ }

pub fn (export_ &BinaryMachineExportInstance) value() BinaryMachineExternValue {
	return export_.value_
}

pub struct BinaryMachineCompiledFunctionEntry {
pub mut:
	handler_ptr          uint
	dispatches_ptr       uint
	src_dst_ptr          uint
	first_instruction    &BinaryInstruction           = unsafe { nil }
	expression           &BinaryExpression            = unsafe { nil }
	module               &BinaryMachineModuleInstance = unsafe { nil }
	total_local_count    u32
	arity                u32
	max_call_record_size u32
}

// V cannot return a pointer to an array header. This record retains the actual
// source vectors so mutable access still updates their owned headers.
pub struct BinaryMachineModuleContents {
pub mut:
	types           []BinaryDefinedType
	canonical_types []&BinaryCanonicalType
	tag_types       []BinaryTagType
	functions       []u64
	tables          []u64
	memories        []u64
	globals         []u64
	elements        []u64
	datas           []u64
	tags            []u64
	exports         []BinaryMachineExportInstance
}

pub struct BinaryMachineModuleConstruction {
pub:
	types                    []BinaryDefinedType
	functions                []u64
	tables                   []u64
	memories                 []u64
	globals                  []u64
	datas                    []u64
	tags                     []u64
	tag_types                []BinaryTagType
	exports                  []BinaryMachineExportInstance
	minimum_call_record_size uint
}

@[heap]
pub struct BinaryMachineModuleInstance {
pub mut:
	cached_minimum_call_record_allocation_size uint
mut:
	contents_                BinaryMachineModuleContents
	resolved_memories_       []&BinaryMachineMemoryInstance
	resolved_memories_built_ bool
	resolved_globals_        []&BinaryMachineGlobalInstance
	resolved_globals_built_  bool
	compiled_fn_table_       BinaryMachineCompiledFunctionTable
	compiled_fn_table_built_ bool
}

pub fn BinaryMachineModuleInstance.create() &BinaryMachineModuleInstance {
	return &BinaryMachineModuleInstance{}
}

pub fn BinaryMachineModuleInstance.create_with_contents(input BinaryMachineModuleConstruction) &BinaryMachineModuleInstance {
	return &BinaryMachineModuleInstance{
		cached_minimum_call_record_allocation_size: input.minimum_call_record_size
		contents_:                                  BinaryMachineModuleContents{
			types:     input.types
			functions: input.functions
			tables:    input.tables
			memories:  input.memories
			globals:   input.globals
			datas:     input.datas
			tags:      input.tags
			tag_types: input.tag_types
			exports:   input.exports
		}
	}
}

pub fn (mut instance BinaryMachineModuleInstance) contents() &BinaryMachineModuleContents {
	return &instance.contents_
}

pub fn (instance &BinaryMachineModuleInstance) types() []BinaryDefinedType {
	return instance.contents_.types
}

pub fn (instance &BinaryMachineModuleInstance) canonical_types() []&BinaryCanonicalType {
	return instance.contents_.canonical_types
}

pub fn (instance &BinaryMachineModuleInstance) functions() []u64 {
	return instance.contents_.functions
}

pub fn (instance &BinaryMachineModuleInstance) tables() []u64 { return instance.contents_.tables }

pub fn (instance &BinaryMachineModuleInstance) memories() []u64 {
	return instance.contents_.memories
}

pub fn (instance &BinaryMachineModuleInstance) globals() []u64 { return instance.contents_.globals }

pub fn (instance &BinaryMachineModuleInstance) elements() []u64 {
	return instance.contents_.elements
}

pub fn (instance &BinaryMachineModuleInstance) datas() []u64 { return instance.contents_.datas }

pub fn (instance &BinaryMachineModuleInstance) exports() []BinaryMachineExportInstance {
	return instance.contents_.exports
}

pub fn (instance &BinaryMachineModuleInstance) tags() []u64 { return instance.contents_.tags }

pub fn (instance &BinaryMachineModuleInstance) tag_types() []BinaryTagType {
	return instance.contents_.tag_types
}

pub fn (mut instance BinaryMachineModuleInstance) resolved_memories(store &BinaryMachineStore) &&BinaryMachineMemoryInstance {
	if instance.resolved_memories_built_ {
		return unsafe { &&BinaryMachineMemoryInstance(instance.resolved_memories_.data) }
	}
	instance.resolved_memories_.ensure_cap(instance.contents_.memories.len)
	for address in instance.contents_.memories {
		instance.resolved_memories_ << store.unsafe_get_memory(address)
	}
	instance.resolved_memories_built_ = true
	return unsafe { &&BinaryMachineMemoryInstance(instance.resolved_memories_.data) }
}

pub fn (mut instance BinaryMachineModuleInstance) resolved_globals(store &BinaryMachineStore) &&BinaryMachineGlobalInstance {
	if instance.resolved_globals_built_ {
		return unsafe { &&BinaryMachineGlobalInstance(instance.resolved_globals_.data) }
	}
	instance.resolved_globals_.ensure_cap(instance.contents_.globals.len)
	for address in instance.contents_.globals {
		instance.resolved_globals_ << store.unsafe_get_global(address)
	}
	instance.resolved_globals_built_ = true
	return unsafe { &&BinaryMachineGlobalInstance(instance.resolved_globals_.data) }
}
