// SPDX-License-Identifier: BSD-2-Clause
module libjs

pub struct NativePendingExecutableDiagnostic {
pub:
	key          string
	filename     string
	name         string
	scope        string
	instructions int
	constants    int
}

// Read bounded source identities without executing JavaScript, compiling code,
// or serializing the VM/AST/DOM ownership graph.
pub fn (vm &VM) pending_native_code_cache_diagnostics(limit int) []NativePendingExecutableDiagnostic {
	if limit <= 0 { return [] }
	tier := vm.native_tier or { return [] }
	cache := tier.persistent or { return [] }
	mut result := []NativePendingExecutableDiagnostic{}
	for key in cache.pending.keys().sorted() {
		if result.len >= limit { break }
		executable := cache.pending[key] or { continue }
		result << NativePendingExecutableDiagnostic{
			key:          key
			filename:     if code := executable.source_code { code.filename.str() } else { '' }
			name:         executable.name.str()
			scope:        executable.native_cache_scope
			instructions: executable.instructions.len
			constants:    executable.constants.len
		}
	}
	return result
}
