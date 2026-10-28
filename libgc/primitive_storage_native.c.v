// SPDX-License-Identifier: BSD-2-Clause
module libgc

#include "@DIR/primitive_storage_host.h"

fn C.vox_gc_storage_page_size() uint
fn C.vox_gc_storage_errno() int
fn C.vox_gc_storage_error(int) &char
fn C.vox_gc_reserve_address_space(uint) voidptr
fn C.vox_gc_commit_memory(voidptr, uint) voidptr
fn C.vox_gc_decommit_memory(voidptr, uint) voidptr
fn C.vox_gc_release_address_space(voidptr, uint) int
fn C.vox_gc_set_primitive_storage_cage_base(voidptr)
fn C.vox_gc_get_primitive_storage_cage_base() uint

pub fn primitive_storage_cage_base() uint { return C.vox_gc_get_primitive_storage_cage_base() }

fn storage_page_size() uint { return C.vox_gc_storage_page_size() }

fn storage_errno_error(code int) IError {
	return error_with_code(unsafe { C.vox_gc_storage_error(code).vstring() }, code)
}

fn storage_syscall_error(name string) IError {
	code := C.vox_gc_storage_errno()
	return error_with_code(name + ': ' + unsafe { C.vox_gc_storage_error(code).vstring() }, code)
}

fn reserve_storage_address_space(size uint) !&u8 {
	pointer := C.vox_gc_reserve_address_space(size)
	if uint(pointer) == uint(-1) { return storage_syscall_error('mmap') }
	return unsafe { &u8(pointer) }
}

fn commit_storage_memory(address &u8, size uint) ! {
	if uint(C.vox_gc_commit_memory(address, size)) == uint(-1) {
		return storage_syscall_error('mmap')
	}
}

fn decommit_storage_memory(address &u8, size uint) ! {
	if size == 0 { return }
	pointer := C.vox_gc_decommit_memory(address, size)
	if uint(pointer) == uint(-1) { return storage_syscall_error('mmap') }
	assert pointer == voidptr(address)
}

$if test {
	fn release_storage_address_space(address &u8, size uint) ! {
		if C.vox_gc_release_address_space(address, size) < 0 { return storage_syscall_error('munmap') }
	}
}
