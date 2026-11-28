// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs

// Native owners retain actual JS values past the callback that supplied them.
// A later WebIDL conversion may reenter author toString/valueOf methods, so it
// needs the owning realm's HTML callback scope and the usual execution budget.
fn (mut host Host) native_value_string(value libjs.Value) !string {
	mut vm := host.vm
	host.require_open(mut vm)!
	if vm.has_running_execution_context() || (!value.is_object() && !value.is_symbol()) {
		return value.to_primitive_string(mut vm)!.str()
	}
	converted := host.callback_entry(fn [value] (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_string(value.to_primitive_string(mut vm)!)
	})!
	// callback_entry suppresses script for a document that cannot run it.
	// Report that failure instead of replacing the retained value's contents.
	if !converted.is_string() { return error('Document cannot run a retained value conversion') }
	return converted.as_string().str()
}
