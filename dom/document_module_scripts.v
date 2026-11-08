// SPDX-License-Identifier: BSD-2-Clause
module dom

// Module graph evaluation can outlive preparation of its script element. The
// parser's end steps wait for it before dispatching DOMContentLoaded.
pub fn (mut document Document) begin_module_readiness_delay() {
	document.pending_module_readiness_scripts++
}

pub fn (mut document Document) end_module_readiness_delay() {
	assert document.pending_module_readiness_scripts > 0
	document.pending_module_readiness_scripts--
	document.schedule_html_parser_end_check()
}
