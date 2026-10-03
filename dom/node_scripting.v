// DOM/Node.cpp::is_scripting_disabled(), retaining the actual relevant settings
// across node adoption through the DOM/HTML module-cycle boundary.
module dom

pub struct NodeScriptingEnvironment {
pub:
	settings voidptr
	enabled  DocumentSettingsScriptingEnabledCallback
}

fn (document &Document) node_scripting_environment() ?NodeScriptingEnvironment {
	hook := document.lifecycle_hook_ or { return none }
	if hook.settings_scripting_enabled == unsafe { nil } { return none }
	settings := document.relevant_settings_object()
	if settings == unsafe { nil } { return none }
	return NodeScriptingEnvironment{ settings: settings, enabled: hook.settings_scripting_enabled }
}

fn (mut node Node) initialize_relevant_scripting_environment() {
	if node.relevant_scripting_environment_ != none { return }
	if node.relevant_scripting_document_ == unsafe { nil } {
		node.relevant_scripting_document_ = node.document()
	}
	if node.relevant_scripting_document_ != unsafe { nil } {
		node.relevant_scripting_environment_ = node.relevant_scripting_document_.node_scripting_environment()
		if node.relevant_scripting_environment_ != none {
			// The actual settings own their Realm/global. A native node does not
			// retain an additional obsolete creation Document after adoption.
			node.relevant_scripting_document_ = unsafe { nil }
		}
	}
}

fn (node &Node) relevant_settings_scripting_enabled() bool {
	mut mutable_node := unsafe { &Node(node) }
	mutable_node.initialize_relevant_scripting_environment()
	if environment := node.relevant_scripting_environment_ {
		return environment.enabled(environment.settings)
	}
	// DOM-only and late-Window standalone adapters have no settings predicate.
	return true
}

pub fn (page &Page) has_scripting_enabled_owner() bool {
	return page.target != unsafe { nil } && page.is_scripting_enabled_callback != unsafe { nil }
}

pub fn (page &Page) is_scripting_enabled() bool {
	if page.has_scripting_enabled_owner() { return page.is_scripting_enabled_callback(page.target) }
	return true
}
