// Types.h::cranelift_entry_acquire and publish_cranelift_entry.
module webassembly

#include "@DIR/compiled_instructions_host.h"

fn C.vox_wasm_compiled_entry_acquire(&uint) uint
fn C.vox_wasm_compiled_entry_publish(&uint, uint)

pub fn binary_cranelift_entry_acquire(compiled &BinaryCompiledInstructions) uint {
	return C.vox_wasm_compiled_entry_acquire(&compiled.cranelift_entry)
}

pub fn binary_publish_cranelift_entry(mut compiled BinaryCompiledInstructions, entry uint) {
	C.vox_wasm_compiled_entry_publish(&compiled.cranelift_entry, entry)
}
