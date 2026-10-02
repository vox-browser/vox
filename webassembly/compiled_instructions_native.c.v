// Types.h::cranelift_entry_acquire and publish_cranelift_entry.
module webassembly

#include "@DIR/compiled_instructions_host.h"

fn C.vox_wasm_compiled_entry_acquire(&usize) usize
fn C.vox_wasm_compiled_entry_publish(&usize, usize)

pub fn binary_cranelift_entry_acquire(compiled &BinaryCompiledInstructions) usize {
	return C.vox_wasm_compiled_entry_acquire(&compiled.cranelift_entry)
}

pub fn binary_publish_cranelift_entry(mut compiled BinaryCompiledInstructions, entry usize) {
	C.vox_wasm_compiled_entry_publish(&compiled.cranelift_entry, entry)
}
