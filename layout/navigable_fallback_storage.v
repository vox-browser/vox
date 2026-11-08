module layout

import dom
import html
import platform

// Standalone layout has no HTML navigable owning its about:blank/srcdoc
// adapter. Native parents give that fallback an independent payload and close
// its publisher at their early retirement boundary, like hosted documents.
fn create_navigable_fallback_document(parent &dom.Document, source string) &dom.Document {
	if parent.native_storage() == unsafe { nil } { return html.parse_document(source) }
	persistent := platform.enter_persistent()
	mut document := dom.Document.create(dom.url_about_blank())
	platform.leave_persistent(persistent)
	document.enable_native_storage()
	enable_native_paint_tree_storage(document)
	mut owner := document.native_storage()
	mut allocations := owner.enter_nested()
	document.set_document_type(.html)
	_ = html.CustomElementRegistry.create(document)
	document.set_allow_declarative_shadow_roots(true)
	html.parse_html_from_a_string(document, source.clone())
	allocations.finish()
	// The callback captures only the persistent child header. It remains safe
	// if a source replacement retires that child before the parent closes.
	registration := platform.enter_persistent()
	mut host := unsafe { &dom.Document(parent) }
	host.add_native_storage_cleanup(fn [document] () {
		retire_native_navigable_fallback_document(document)
	})
	platform.leave_persistent(registration)
	return document
}

fn retire_native_navigable_fallback_document(document &dom.Document) {
	mut retiring := unsafe { &dom.Document(document) }
	if retiring.native_storage() == unsafe { nil } { return }
	handle := retiring.layout_engine_handle()
	if navigable := retiring.navigable() {
		mut owner := unsafe { &dom.Navigable(navigable) }
		owner.remove_from_all_navigables()
	}
	if !retiring.has_been_destroyed() { retiring.destroy_a_document_and_its_descendants() }
	retire_native_document_layout(handle)
	retiring.layout_engine_handle_ = unsafe { nil }
	retiring.cached_display_list_ = unsafe { nil }
	retiring.finalize()
	retiring.release_native_storage()
}
