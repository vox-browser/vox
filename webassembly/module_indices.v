// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// AbstractMachine/Validator.cpp: module context, indices and start signature.
module webassembly

pub struct BinaryValidationContext {
pub mut:
	types                   []BinaryDefinedType
	canonical_types         []&BinaryCanonicalType
	functions               []BinaryDefinedType
	function_type_indices   []?u32
	structs                 []BinaryDefinedType
	arrays                  []BinaryDefinedType
	tables                  []BinaryTableType
	memories                []WasmLimits
	globals                 []BinaryGlobalType
	globals_without_internal_globals []BinaryGlobalType
	locals                  []BinaryValueType
	current_function_parameter_count int
	elements                []BinaryValueType
	datas                   []bool
	tags                    []BinaryTagType
	data_count              ?u32
	references              map[u32]bool
	imported_function_count int
}

fn validate_binary_export_names(exports []ModuleExportDescriptor, tags []BinaryTagExport) ! {
	mut names := map[string]bool{}
	for entry in exports {
		if entry.name in names {
			return error("CompileError: Duplicate exported name '${entry.name}'")
		}
		names[entry.name] = true
	}
	for entry in tags {
		if entry.name in names {
			return error("CompileError: Duplicate exported name '${entry.name}'")
		}
		names[entry.name] = true
	}
}

fn validate_binary_type_index(index u32, types []BinaryDefinedType) ! {
	if u64(index) >= u64(types.len) { return error('CompileError: invalid TypeIndex') }
}

fn validate_binary_tag_type(tag BinaryTagType, types []BinaryDefinedType) ! {
	validate_binary_type_index(tag.type_index, types)!
	type_ := types[tag.type_index]
	if type_.kind != .function_ || type_.results.len != 0 {
		return error('CompileError: invalid TagType')
	}
}

fn validate_binary_table_type(table BinaryTableType, types []BinaryDefinedType) ! {
	validate_binary_value_type(table.element_type, types)!
	bound := if table.limits.address_type == .i64 { ?u64(none) } else { ?u64(u64(max_u32)) }
	validate_limits(table.limits, bound)!
}

fn (mut context BinaryValidationContext) scan_declared_references(expression BinaryExpression) {
	for instruction in expression.instructions {
		if instruction.opcode == binary_op_ref_func {
			index := instruction.arguments as BinaryIndexArgument
			context.references[index.index] = true
		}
	}
}

// Function imports must reference function types, not struct or array definitions.
fn build_binary_validation_context(compiled &Module) !BinaryValidationContext {
	mut context := BinaryValidationContext{ types: compiled.types.clone(), canonical_types: compiled.canonical_types.clone(), data_count: compiled.data_count }
	for entry in compiled.import_entries {
		match entry.kind {
			.function_ {
				validate_binary_type_index(entry.function_type_index, context.types)!
				type_ := context.types[entry.function_type_index]
				if type_.kind != .function_ {
					return error('CompileError: invalid function import type')
				}
				context.functions << type_
				context.function_type_indices << ?u32(entry.function_type_index)
				context.imported_function_count++
			}
			.table {
				context.tables << (entry.table_type or { panic('missing parsed table import type') })
			}
			.memory { context.memories << entry.memory_type }
			.global {
				type_ := entry.global_type or { panic('missing parsed global import type') }
				context.globals_without_internal_globals << type_
				context.globals << type_
			}
		}
	}
	for entry in compiled.tag_import_entries { context.tags << entry.type_ }
	validate_module_function_count(compiled.function_type_indices, compiled.function_bodies)!
	for index in compiled.function_type_indices {
		validate_binary_type_index(index, context.types)!
		if context.types[index].kind != .function_ {
			return error('CompileError: invalid TypeIndex')
		}
		context.functions << context.types[index]
		context.function_type_indices << ?u32(index)
	}
	for entry in compiled.table_definitions { context.tables << entry.type_ }
	context.memories << compiled.memory_types
	for entry in compiled.global_definitions { context.globals << entry.type_ }
	for segment in compiled.element_segments { context.elements << segment.element_type }
	context.datas = []bool{len: compiled.data_segments.len}
	context.tags << compiled.tag_types
	for entry in compiled.export_entries {
		if entry.kind == .function_ { context.references[entry.index] = true }
	}
	for segment in compiled.element_segments {
		for expression in segment.items { context.scan_declared_references(expression) }
	}
	for entry in compiled.global_definitions { context.scan_declared_references(entry.initializer) }
	for entry in compiled.table_definitions { context.scan_declared_references(entry.initializer) }
	return context
}

fn validate_binary_module_indices(compiled &Module) !BinaryValidationContext {
	context := build_binary_validation_context(compiled)!
	for entry in compiled.import_entries {
		match entry.kind {
			.function_ { validate_binary_type_index(entry.function_type_index, context.types)! }
			.table {
				validate_binary_table_type(entry.table_type or { panic('missing parsed table import type') }, context.types)!
			}
			.memory { validate_memory_type(entry.memory_type)! }
			.global {
				validate_binary_value_type((entry.global_type or { panic('missing parsed global import type') }).type_, context.types)!
			}
		}
	}
	for entry in compiled.tag_import_entries {
		validate_binary_tag_type(entry.type_, context.types)!
	}
	for entry in compiled.export_entries {
		count := match entry.kind {
			.function_ { context.functions.len }
			.table { context.tables.len }
			.memory { context.memories.len }
			.global { context.globals.len }
		}
		if u64(entry.index) >= u64(count) {
			return error('CompileError: invalid ${match entry.kind {
				.function_ { 'FunctionIndex' }
				.table { 'TableIndex' }
				.memory { 'MemoryIndex' }
				.global { 'GlobalIndex' }
			}}')
		}
	}
	for entry in compiled.tag_export_entries {
		if u64(entry.index) >= u64(context.tags.len) {
			return error('CompileError: invalid TagIndex')
		}
	}
	if index := compiled.start_function_index {
		if u64(index) >= u64(context.functions.len) {
			return error('CompileError: invalid FunctionIndex')
		}
		if context.functions[index].parameters.len != 0 || context.functions[index].results.len != 0 {
			return error('CompileError: invalid start function signature')
		}
	}
	return context
}
