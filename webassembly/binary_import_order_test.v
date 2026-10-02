// SPDX-License-Identifier: BSD-2-Clause
module webassembly

fn ordered_import_name(value string) []u8 {
	mut bytes := [u8(value.len)]
	bytes << value.bytes()
	return bytes
}

fn ordered_import_entry(name string, description []u8) []u8 {
	mut bytes := ordered_import_name('env')
	bytes << ordered_import_name(name)
	bytes << description
	return bytes
}

fn test_source_machine_imports_preserve_interleaved_tags_and_all_description_slots() {
	mut section := [u8(5)]
	for entry in [
		ordered_import_entry('f', [u8(0), 0]),
		ordered_import_entry('t', [u8(4), 0, 0]),
		ordered_import_entry('m', [u8(2), 0, 1]),
		ordered_import_entry('g', [u8(3), 0x7f, 1]),
		ordered_import_entry('table', [u8(1), 0x70, 0, 1]),
	] {
		section << entry
	}
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 1, 4, 1, 0x60, 0, 0, 2, u8(section.len)]
	bytes << section
	module_ := compile_module(bytes)!
	assert module_.binary_import_entries.map(it.name) == ['f', 't', 'm', 'g', 'table']
	assert module_.binary_import_entries.map(it.module) == ['env', 'env', 'env', 'env', 'env']
	function := module_.binary_import_entries[0].description
	tag := module_.binary_import_entries[1].description
	memory := module_.binary_import_entries[2].description
	global := module_.binary_import_entries[3].description
	table := module_.binary_import_entries[4].description
	assert function is BinaryImportTypeIndex
	assert tag is BinaryTagType
	assert memory is WasmLimits
	assert global is BinaryGlobalType
	assert table is BinaryTableType
	if function is BinaryImportTypeIndex {
		assert function.value == 0
	}
	if tag is BinaryTagType {
		assert tag.type_index == 0 && tag.flags == 0
	}
	if memory is WasmLimits {
		assert memory.minimum == 1 && memory.maximum == none
	}
	if global is BinaryGlobalType {
		assert global.type_.kind == .i32 && global.mutable_
	}
	if table is BinaryTableType {
		assert table.element_type.kind == .function_reference && table.limits.minimum == 1
	}
	// The public source Module API omits tags without changing machine ordering.
	assert module_.import_entries.map(it.name) == ['f', 'm', 'g', 'table']
	assert module_.tag_import_entries[0].name == 't'
}
