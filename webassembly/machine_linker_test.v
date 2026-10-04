// SPDX-License-Identifier: BSD-2-Clause
module webassembly

fn source_linker_import(module_ string, name string, description BinaryImportDescription) BinaryImport {
	return BinaryImport{ module: module_, name: name, description: description }
}

fn source_linker_name(import_ BinaryImport) BinaryMachineLinkName {
	return BinaryMachineLinkName{ module: import_.module, name: import_.name, type_: import_.description }
}

fn test_source_linker_reads_actual_binary_tag_order_and_retains_real_store_addresses() {
	imports := [u8(3), 3, `e`, `n`, `v`, 1, `m`, 2, 0, 0, 3, `e`, `n`, `v`, 1, `t`, 4, 0, 0, 3,
		`e`, `n`, `v`, 1, `f`, 0, 0]
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 1, 4, 1, 0x60, 0, 0, 2, u8(imports.len)]
	bytes << imports
	module_ := compile_module(bytes)!
	mut store := BinaryMachineStore.create()
	memory := store.allocate_memory(WasmLimits{})?
	mut memory_instance := store.get_memory(memory)?
	defer { memory_instance.destroy() }
	tag := store.allocate_tag(BinaryMachineFunctionType{}, module_.canonical_types[0], 0)?
	callable := fn (mut _ BinaryMachineConfiguration, _ BinaryMachineValueSpan) BinaryMachineResult {
		return BinaryMachineResult.from_values([])
	}
	_ := store.allocate_host_function(BinaryMachineHostFunction.create(callable, BinaryMachineFunctionType{}, 'unrelated'))?
	function := store.allocate_host_function(BinaryMachineHostFunction.create(callable, BinaryMachineFunctionType{}, '2'))?
	mut exports := &BinaryMachineQualifiedExports{}
	exports.set(source_linker_name(module_.binary_import_entries[2]), BinaryMachineFunctionAddress{ value: function })
	exports.set(source_linker_name(module_.binary_import_entries[0]), BinaryMachineMemoryAddress{ value: memory })
	exports.set(source_linker_name(module_.binary_import_entries[1]), BinaryMachineTagAddress{ value: tag })
	mut linker := BinaryMachineLinker.create(module_)
	linker.link_exports(exports)
	result := linker.finish()
	assert result is BinaryMachineLinkedValues
	if result is BinaryMachineLinkedValues {
		assert result.values == [
			BinaryMachineExternValue(BinaryMachineMemoryAddress{ value: memory }),
			BinaryMachineTagAddress{ value: tag },
			BinaryMachineFunctionAddress{ value: function },
		]
	}
	assert store.get_memory(memory) != none && store.get_tag(tag) != none && store.get_function(function) != none
}

fn test_source_qualified_linker_preserves_import_order_tags_and_ignores_description_for_name_identity() {
	mut module_ := &Module{
		binary_import_entries: [
			source_linker_import('left', 'same', BinaryImportTypeIndex{ value: 0 }),
			source_linker_import('env', 'tag', BinaryTagType{ type_index: 0 }),
			source_linker_import('right', 'same', BinaryGlobalType{ type_: BinaryValueType{ kind: .i32 } }),
			source_linker_import('left', 'same', BinaryTableType{}),
		]
	}
	mut linker := BinaryMachineLinker.create(module_)
	mut exports := &BinaryMachineQualifiedExports{}
	// Different description still addresses the same source Name key.
	exports.set(BinaryMachineLinkName{ module: 'right', name: 'same', type_: BinaryImportTypeIndex{ value: 19 } }, BinaryMachineGlobalAddress{ value: 31 })
	linker.link_exports(exports)
	exports.set(source_linker_name(module_.binary_import_entries[0]), BinaryMachineFunctionAddress{ value: 7 })
	exports.set(source_linker_name(module_.binary_import_entries[1]), BinaryMachineTagAddress{ value: 5 })
	linker.link_exports(exports)
	result := linker.finish()
	assert result is BinaryMachineLinkedValues
	if result is BinaryMachineLinkedValues {
		assert result.values == [
			BinaryMachineExternValue(BinaryMachineFunctionAddress{ value: 7 }),
			BinaryMachineTagAddress{ value: 5 },
			BinaryMachineGlobalAddress{ value: 31 },
			BinaryMachineFunctionAddress{ value: 7 },
		]
	}
	// Already resolved entries are not replaced by subsequent link calls.
	exports.set(source_linker_name(module_.binary_import_entries[0]), BinaryMachineFunctionAddress{ value: 99 })
	linker.link_exports(exports)
	after := linker.finish()
	assert after == BinaryMachineLinkResult(result)
}

fn test_source_module_linker_ignores_qualifiers_selects_first_export_and_keeps_empty_result() {
	module_ := &Module{
		binary_import_entries: [
			source_linker_import('a', 'shared', BinaryImportTypeIndex{}),
			source_linker_import('b', 'shared', BinaryTagType{}),
		]
	}
	mut instance := BinaryMachineModuleInstance.create()
	instance.contents().exports << BinaryMachineExportInstance.create('shared', BinaryMachineMemoryAddress{ value: 12 })
	instance.contents().exports << BinaryMachineExportInstance.create('shared', BinaryMachineTagAddress{ value: 13 })
	mut linker := BinaryMachineLinker.create(module_)
	linker.link_module(instance)
	result := linker.finish()
	assert result is BinaryMachineLinkedValues
	if result is BinaryMachineLinkedValues {
		assert result.values == [
			BinaryMachineExternValue(BinaryMachineMemoryAddress{ value: 12 }),
			BinaryMachineMemoryAddress{ value: 12 },
		]
	}
	mut empty := BinaryMachineLinker.create(&Module{})
	empty_result := empty.finish()
	assert empty_result is BinaryMachineLinkedValues
	if empty_result is BinaryMachineLinkedValues {
		assert empty_result.values.len == 0
	}
}

fn test_source_linker_retains_finish_errors_repeated_missing_entries_and_independent_error_copy() {
	module_ := &Module{ binary_import_entries: [source_linker_import('env', 'missing', BinaryImportTypeIndex{})] }
	mut linker := BinaryMachineLinker.create(module_)
	mut first := linker.finish()
	assert first is BinaryMachineLinkError
	if mut first is BinaryMachineLinkError {
		assert first.missing_imports == ['missing']
		first.missing_imports[0] = 'changed outside linker'
	}
	second := linker.finish()
	assert second is BinaryMachineLinkError
	if second is BinaryMachineLinkError {
		assert second.missing_imports == ['missing', 'missing']
	}
	mut exports := &BinaryMachineQualifiedExports{}
	exports.set(source_linker_name(module_.binary_import_entries[0]), BinaryMachineFunctionAddress{ value: 0 })
	linker.link_exports(exports)
	// Pinned source does not clear a previous finish error after resolution.
	after := linker.finish()
	assert after == BinaryMachineLinkResult(second)
}

fn test_source_linker_qualified_keys_preserve_embedded_nul_and_unambiguous_module_name_boundary() {
	imports := [source_linker_import('a', 'bc', BinaryImportTypeIndex{}),
		source_linker_import('ab', 'c', BinaryImportTypeIndex{}),
		source_linker_import('a\x00b', 'c', BinaryImportTypeIndex{}),
		source_linker_import('a', '\x00bc', BinaryImportTypeIndex{})]
	mut linker := BinaryMachineLinker.create(&Module{ binary_import_entries: imports })
	mut exports := &BinaryMachineQualifiedExports{}
	for i, import_ in imports {
		exports.set(source_linker_name(import_), BinaryMachineFunctionAddress{ value: u64(i) })
	}
	linker.link_exports(exports)
	result := linker.finish()
	assert result is BinaryMachineLinkedValues
	if result is BinaryMachineLinkedValues {
		for i, value in result.values {
			assert value is BinaryMachineFunctionAddress
			if value is BinaryMachineFunctionAddress {
				assert value.value == u64(i)
			}
		}
	}
}
