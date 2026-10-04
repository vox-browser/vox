// HTMLInputElement.cpp and HTMLSelectElement.cpp obtain picker permission from
// the element's actual relevant settings/global, rather than per-control state.
// Source Environments.cpp::relevant_settings_object(DOM::Node const&) reads
// node.document(); relevant_realm(Node) and relevant_global_object(Node) use
// that overload. The JS::Object overload reads the wrapper Realm separately.
module html

import dom

fn picker_relevant_settings(element &dom.Element) &EnvironmentSettingsObject {
	pointer := element.document().relevant_settings_object()
	assert pointer != unsafe { nil }, 'Picker requires actual element global settings'
	return unsafe { &EnvironmentSettingsObject(pointer) }
}

fn picker_relevant_window(element &dom.Element) ?&dom.Window {
	global := picker_relevant_settings(element).global_object()
	if global.data.kind != .window {
		return none
	}
	return unsafe { &dom.Window(global) }
}

fn picker_origin_is_same_as_top_level(element &dom.Element) bool {
	settings := picker_relevant_settings(element)
	top_origin := settings.environment().top_level_origin or {
		panic('Source picker requires the relevant settings top-level origin')
	}
	return settings.origin().is_same_origin(top_origin)
}
