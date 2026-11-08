module main

import dom

fn browser_document_can_load_scripts(document &dom.Document) bool {
	if !document.is_scripting_enabled_by_embedder() { return false }
	if document.has_page() && document.page().has_scripting_enabled_owner() {
		return document.as_node().is_scripting_enabled()
	}
	// Standalone parser/loader adapters need no active browsing context. Actual
	// navigation documents use their Page/settings owner above.
	return true
}
