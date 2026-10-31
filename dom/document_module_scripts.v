// SPDX-License-Identifier: BSD-2-Clause
module dom

// The compact embedding loads module graphs after parsing. Its asynchronous
// scripts must share the parser's once-only DOMContentLoaded claim boundary.
pub fn (mut document Document) begin_module_readiness_delay() {
	document.pending_module_readiness_scripts++
}

pub fn (mut document Document) end_module_readiness_delay() {
	assert document.pending_module_readiness_scripts > 0
	document.pending_module_readiness_scripts--
}
