// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import platform

fn (collection &Collection) is_supported_property_name(name libjs.Utf16String) bool {
	if collection.host.closed { return false }
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	key := name.str()
	return key != '' && collection.collection.named_item(key) != none
}

fn (collection &Collection) named_property_value(name libjs.Utf16String) libjs.Value {
	if collection.host.closed { return libjs.js_undefined() }
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	mut owner := unsafe { &Host(collection.host) }
	if native := collection.host.form_controls_collections[voidptr(collection.object)] {
		return owner.wrap_form_named_item(native.named_item_or_radio_node_list(name.str()))
	}
	return if element := collection.collection.named_item(name.str()) { owner.wrap_node(element.as_node()) } else { libjs.js_null() }
}

fn (collection &Collection) supported_property_names() []libjs.Utf16String {
	if collection.host.closed { return [] }
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	return collection.collection.supported_property_names().map(libjs.utf16_string(it))
}
