// SPDX-License-Identifier: BSD-2-Clause
module libjs

import crypto.sha256

// Normalize only the entry's symbol index by generating it as the sole function.
// Hash the exact C, including helper definitions, operand slots and property
// plans. Constants, environments and exception tables remain with the current
// executable and are read through its live invocation/slow callback. A batch's
// vox_native_N has the same body as this canonical vox_native_0; the record
// retains N and the verified library digest, as in the source-bound cache.
fn native_generated_code_identity(executable &Executable) !string {
	$if prealloc {
		scope := unsafe { prealloc_scope_begin() }
		defer { unsafe { prealloc_scope_free_after(scope) } }
		identity := native_generated_code_identity_in_workspace(executable) or {
			unsafe { prealloc_scope_leave(scope) }
			return error_with_code(err.msg().clone(), err.code())
		}
		unsafe { prealloc_scope_leave(scope) }
		return identity.clone()
	}
	return native_generated_code_identity_in_workspace(executable)
}

fn native_generated_code_identity_in_workspace(executable &Executable) !string {
	source, _ := native_source([executable])!
	return sha256.hexhash('native-generated-function-v1:' + source)
}
