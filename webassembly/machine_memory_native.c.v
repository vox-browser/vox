// SPDX-License-Identifier: BSD-2-Clause
module webassembly

#include <errno.h>
#include <string.h>

fn C.strerror(int) &char

// LibCore Error::from_errno uses the host errno and its actual diagnostic.
fn machine_memory_allocation_error() IError {
	return error_with_code(unsafe { C.strerror(C.ENOMEM).vstring() }, C.ENOMEM)
}
