module layout

import dom

// A native static document already owns its current projection and scene.
// Additional templates duplicate their text and box payloads in a longer-lived
// arena. Keep those templates for script-driven pages and standalone callers.
fn keeps_paint_projection_templates(document &dom.Document) bool {
	$if prealloc {
		if document.native_storage() != unsafe { nil }
			&& !document.as_node().is_scripting_enabled() {
			return false
		}
	}
	return true
}
