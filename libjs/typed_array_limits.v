// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Bulk byte copies perform native work without indexed JS operations. Charge
// them before the copy while leaving the existing coercion/witness order intact.
fn typed_array_charge_byte_work(mut vm VM, count uint) ! {
	for consumed := uint(0); consumed < count; consumed += 1024 { vm.consume_execution_budget()! }
}
