// DOM/Node.cpp::is_scripting_disabled(), using the actual current Document
// settings through the DOM/HTML module-cycle boundary.
module dom

fn (node &Node) relevant_settings_scripting_enabled() bool {
	// Environments.cpp::relevant_settings_object(DOM::Node const&) reads
	// the current node Document, including after adoption.
	document := node.document()
	hook := document.lifecycle_hook_ or { return true }
	if hook.settings_scripting_enabled == unsafe { nil } { return true }
	settings := document.relevant_settings_object()
	if settings == unsafe { nil } { return true }
	return hook.settings_scripting_enabled(settings)
}

pub fn (page &Page) has_scripting_enabled_owner() bool {
	return page.target != unsafe { nil } && page.is_scripting_enabled_callback != unsafe { nil }
}

pub fn (page &Page) is_scripting_enabled() bool {
	if page.has_scripting_enabled_owner() { return page.is_scripting_enabled_callback(page.target) }
	return true
}
