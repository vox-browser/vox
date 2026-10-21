module layout

import dom
import platform

// Isolated image documents can be created while the host's paint projection
// is entered. Their identity outlives that projection and their payload has an
// independent owner, retired with the embedding document's final reader.
fn create_svg_image_document(image_url dom.URL, embedder &dom.Document) &dom.Document {
	persistent := platform.enter_persistent()
	mut document := dom.Document.create(dom.URL{value:image_url.serialize().clone()})
	platform.leave_persistent(persistent)
	$if prealloc {
		if embedder.native_storage() != unsafe { nil } { document.enable_native_storage() }
	}
	return document
}

fn retain_svg_image_document_until_embedder_retires(document &dom.Document, embedder &dom.Document) {
	$if prealloc {
		mut owner := embedder.native_storage()
		if document.native_storage() == unsafe { nil } || owner == unsafe { nil } { return }
		owner.add_cleanup(fn [document] () {
			retire_native_document_layout(document.layout_engine_handle())
			mut image := unsafe { &dom.Document(document) }
			if navigable := image.navigable() {
				persistent := platform.enter_persistent()
				mut retiring := unsafe { &dom.Navigable(navigable) }
				retiring.remove_from_all_navigables()
				platform.leave_persistent(persistent)
			}
			image.finalize()
			image.release_native_storage()
		})
	}
}
