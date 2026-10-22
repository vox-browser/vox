module layout

import dom
import platform

// Isolated image documents can be created while the host's paint projection
// is entered. Their identity outlives that projection and their payload has an
// independent owner, retired with the embedding document's final reader.
fn create_svg_image_document(image_url dom.URL, owner &platform.RetainedArena) &dom.Document {
	persistent := platform.enter_persistent()
	mut document := dom.Document.create(dom.URL{ value: image_url.serialize().clone() })
	platform.leave_persistent(persistent)
	$if prealloc {
		if owner != unsafe { nil } { document.enable_native_storage() }
	}
	return document
}

fn retain_svg_image_document_until_owner_retires(document &dom.Document, storage &platform.RetainedArena) {
	$if prealloc {
		mut owner := unsafe { &platform.RetainedArena(storage) }
		if document.native_storage() == unsafe { nil } || owner == unsafe { nil } { return }
		persistent := platform.enter_persistent()
		owner.add_cleanup(fn [document] () {
			retire_svg_image_document(document)
		})
		platform.leave_persistent(persistent)
	}
}

fn retire_svg_image_document(document &dom.Document) {
	mut image := unsafe { &dom.Document(document) }
	// Static pictures can retire early. The persistent Document header remains
	// callable by the host's later cleanup, but its old layout payload does not.
	if image.native_storage() == unsafe { nil } { return }
	retire_native_document_layout(image.layout_engine_handle())
	image.layout_engine_handle_ = unsafe { nil }
	image.cached_display_list_ = unsafe { nil }
	image.clear_layout_and_paintable_nodes_for_inactive_document()
	image.tear_down_layout_tree()
	if navigable := image.navigable() {
		persistent := platform.enter_persistent()
		mut retiring := unsafe { &dom.Navigable(navigable) }
		retiring.remove_from_all_navigables()
		platform.leave_persistent(persistent)
	}
	image.finalize()
	image.release_native_storage()
}
