// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import libjs
import platform

// The ordinary-value subset of structured clone shared with the History
// adapter. Other internal-slot families still fail explicitly with DataCloneError.
pub fn (mut host Host) clone_ordinary_value(value libjs.Value) !libjs.Value {
	mut vm := host.vm
	host.require_open(mut vm)!
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	mut projection := HistoryClone{host: &host}
	projected := projection.project(mut vm, value, 0) or { return host.dom_error(mut vm, err) }
	serialized := html.structured_serialize(projected) or { return host.dom_error(mut vm, err) }
	native := html.structured_deserialize(serialized) or { return host.dom_error(mut vm, err) }
	return projection.reconstruct(mut vm, native, 0) or { return host.dom_error(mut vm, err) }
}
