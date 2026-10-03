// LibWasm/Types.h Module::{has_attempted,try_begin,finish,wait}_cranelift_compilation.
module webassembly

#include "@DIR/module_compilation_control_host.h"

$if linux {
	#flag -pthread
}

fn C.vox_wasm_module_compilation_control_create() voidptr
fn C.vox_wasm_module_compilation_has_attempted(voidptr) int
fn C.vox_wasm_module_compilation_try_begin(voidptr) int
fn C.vox_wasm_module_compilation_finish(voidptr)
fn C.vox_wasm_module_compilation_wait(voidptr)
fn C.vox_wasm_module_compilation_control_destroy(voidptr)

// This heap owner keeps the actual native mutex and condition variable at one
// stable address. Module's construction default creates it before publication.
@[heap]
struct BinaryModuleCompilationControl {
mut:
	native voidptr
}

fn BinaryModuleCompilationControl.create() &BinaryModuleCompilationControl {
	return &BinaryModuleCompilationControl{ native: C.vox_wasm_module_compilation_control_create() }
}

pub fn (compiled &Module) has_attempted_cranelift_compilation() bool {
	return C.vox_wasm_module_compilation_has_attempted(compiled.cranelift_compilation_.native) != 0
}

pub fn (compiled &Module) try_begin_cranelift_compilation() bool {
	return C.vox_wasm_module_compilation_try_begin(compiled.cranelift_compilation_.native) != 0
}

pub fn (compiled &Module) finish_cranelift_compilation() {
	C.vox_wasm_module_compilation_finish(compiled.cranelift_compilation_.native)
}

pub fn (compiled &Module) wait_for_cranelift_compilation() {
	C.vox_wasm_module_compilation_wait(compiled.cranelift_compilation_.native)
}

// Source Module destruction destroys its condition variable and mutex. The V
// owner calls this once after all compilation workers/waiters have joined.
// Module's complete weak/ref-counted and native code owner graph remains open.
pub fn (mut compiled Module) destroy_compilation_control() {
	C.vox_wasm_module_compilation_control_destroy(compiled.cranelift_compilation_.native)
	compiled.cranelift_compilation_.native = unsafe { nil }
}
