module html

import dom
import page

fn window_closing_document(address string) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{value: address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	native := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(native) }
}

fn test_actual_navigable_closing_state_is_shared_by_native_window_and_typed_local_owner() {
	mut document, window := window_closing_document('https://window-closing-native.example/')!
	defer { document.finalize() }
	mut native := document.navigable()?
	mut model := navigable_model_for_host(native) or { panic('actual local owner') }
	assert !native.is_closing() && !model.is_closing()
	assert !window.Window.closed() && !window.closed()
	model.set_closing(true)
	assert native.is_closing() && model.is_closing()
	assert window.Window.closed() && window.closed()
	assert window.window().get_own_property(document.origin(), 'closed')!.descriptor.value.boolean_data
	native.set_closing(false)
	assert !native.is_closing() && !model.is_closing()
	assert !window.Window.closed() && !window.closed()
	// Removing only a cached context does not change the Source actual owner.
	mut context := window.browsing_context()
	context.remove()
	assert context.has_navigable_been_destroyed()
	assert !window.Window.closed() && !window.closed()
}

fn test_traversable_and_local_navigable_use_one_inherited_native_closing_field() {
	mut document, window := window_closing_document('https://window-closing-inheritance.example/')!
	defer { document.finalize() }
	mut native := document.navigable()?
	mut model := navigable_model_for_host(native) or { panic('actual local owner') }
	mut traversable := TraversableNavigable.create_a_fresh_top_level_traversable(document.url, EmptyDocumentResource{})!
	// Existing host attachment gives the typed subclass its actual native base.
	traversable.set_host_navigable(native)
	assert !traversable.is_closing() && !model.is_closing() && !window.closed()
	traversable.set_closing(true)
	assert traversable.is_closing() && model.is_closing() && native.is_closing()
	assert window.closed()
	model.set_closing(false)
	assert !traversable.is_closing() && !native.is_closing() && !window.closed()
	native.set_closing(true)
	assert traversable.is_closing() && model.is_closing() && window.closed()
	traversable.set_closing(false)
	assert !traversable.is_closing() && !model.is_closing() && !window.closed()
}

fn test_window_closed_reads_current_document_context_and_navigable_after_association_swap() {
	mut original, mut window := window_closing_document('https://window-closing-swap.example/original')!
	mut replacement, replacement_window := window_closing_document('https://window-closing-swap.example/replacement')!
	defer {
		original.finalize()
		replacement.finalize()
	}
	mut original_navigable := original.navigable()?
	mut replacement_navigable := replacement.navigable()?
	original_navigable.set_closing(true)
	assert window.closed()
	window.set_associated_document(replacement)
	assert window.Window.browsing_context()? == replacement.get_browsing_context()?
	assert !window.closed() && !replacement_window.closed()
	replacement_navigable.set_closing(true)
	assert window.closed() && replacement_window.closed()
	replacement_navigable.set_closing(false)
	context := replacement.get_browsing_context()?
	replacement.browsing_context = unsafe { nil }
	assert window.Window.browsing_context() == none
	assert window.closed()
	replacement.set_browsing_context(context)
	assert !window.closed()
	replacement.set_navigable(none)
	assert window.closed()
	replacement.set_navigable(replacement_navigable)
	assert !window.closed()
	window.set_associated_document(original)
	assert window.closed()
	original_navigable.set_closing(false)
	assert !window.closed()
}

fn test_window_closed_before_document_and_existing_close_write_actual_native_state() {
	bare := &dom.Window{}
	assert bare.browsing_context() == none && bare.closed()
	mut document, mut window := window_closing_document('https://window-closing-existing-close.example/')!
	defer { document.finalize() }
	native := document.navigable()?
	assert !native.is_closing() && !window.closed()
	window.close()
	assert native.is_closing() && window.closed()
	assert navigable_model_for_host(native)?.is_closing()
}
