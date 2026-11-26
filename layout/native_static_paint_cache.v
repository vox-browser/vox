module layout

import dom

// The native shell gives each paint projection and its readers an explicit
// lifetime. A second copy of its boxes and line payloads in template storage
// would live for the document, including after a script replaces the layout.
fn keeps_paint_projection_templates(document &dom.Document) bool {
	$if prealloc {
		if document.native_storage() != unsafe { nil }
			&& (document.recycle_native_paint_trees || !document.as_node().is_scripting_enabled()) {
			return false
		}
	}
	return true
}
