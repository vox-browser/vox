// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Observe an explicitly instrumented native tier without resetting its
// counters or changing its execution policy. Timing runs leave this disabled.
pub fn (vm &VM) native_code_activity() ?NativeCodeActivity {
	tier := vm.native_tier or { return none }
	if !tier.diagnostics { return none }
	return tier.activity
}
