// HTML/Scripting/Environments.cpp scripting preference and sandbox checks.
module html

import url as liburl

pub fn is_scripting_enabled_for_settings(settings &EnvironmentSettingsObject) bool {
	window := settings.window_ or {
		// Pinned source worker behavior is still its explicit FIXME.
		return true
	}
	document := window.associated_document()
	if !document.is_scripting_enabled_by_embedder() { return false }
	if document.has_page() && document.page().has_scripting_enabled_owner() {
		if !document.page().is_scripting_enabled() {
			parsed := liburl.parse(document.url.serialize()) or { return false }
			if !liburl.is_webui_url(&parsed) { return false }
		}
	} else if !settings.realm().scripting_enabled {
		// Explicit pre-existing standalone Window/realm adapter with no Page
		// preference owner. Actual Page-backed settings use the source above.
		return false
	}
	return document.active_sandboxing_flag_bits() & u32(SandboxingFlag.sandboxed_scripts) == 0
}

pub fn is_scripting_disabled_for_settings(settings &EnvironmentSettingsObject) bool {
	return !is_scripting_enabled_for_settings(settings)
}
