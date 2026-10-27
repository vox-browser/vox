// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// AbstractMachine.cpp::ModuleInstance::compiled_fn_table (516-557).
module webassembly

pub fn (mut instance BinaryMachineModuleInstance) compiled_fn_table(store &BinaryMachineStore) &BinaryMachineCompiledFunctionTable {
	if instance.compiled_fn_table_built_ { return &instance.compiled_fn_table_ }
	count := instance.functions().len
	if count == 0 {
		instance.compiled_fn_table_built_ = true
		return &instance.compiled_fn_table_
	}
	mut table := &instance.compiled_fn_table_
	// AK::Vector resize_with_default_value_and_keep_capacity preserves existing
	// entries. Only new entries receive the source zero/null default.
	table.entries.ensure_cap(count)
	table.entries.trim(count)
	for table.entries.len < count { table.entries << BinaryMachineCompiledFunctionEntry{} }
	mut all_ready := true
	for index, address in instance.functions() {
		function := store.unsafe_get_function(address)
		if function is BinaryMachineWasmFunction {
			if source := function.module_ref() {
				if !source.has_attempted_cranelift_compilation() { all_ready = false }
			}
			compiled := &function.code().body.compiled_instructions
			native := binary_cranelift_entry_acquire(compiled)
			if native == 0 { continue }
			table.entries[index] = BinaryMachineCompiledFunctionEntry{
				handler_ptr:          native
				dispatches_ptr:       uint(compiled.dispatches.data)
				src_dst_ptr:          uint(compiled.src_dst_mappings.data)
				first_instruction:    compiled.dispatches[0].instruction
				expression:           &function.code().body
				module:               function.module()
				total_local_count:    u32(function.code().total_local_count()) + compiled.cranelift_inlined_locals
				arity:                u32(function.type_().results.len)
				max_call_record_size: u32(compiled.max_call_rec_size)
			}
		}
	}
	instance.compiled_fn_table_built_ = all_ready
	return table
}
