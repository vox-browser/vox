module html

import dom
import page

@[heap]
struct WindowDocumentDispatchObservation {
mut:
	documents []voidptr
}

fn window_document_identity_fixture(address string, owner &page.Page) !(&dom.Document, &WindowModel) {
	url := dom.URL{value: address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	native := document.get_window() or { return error('missing actual Window') }
	window := unsafe { &WindowModel(native) }
	return document, window
}

fn test_window_document_association_shares_actual_native_slot_page_and_settings_in_both_directions() {
	owner := page.Page.create(1)!
	mut other_owner := page.Page.create(1)!
	other_owner.set_is_scripting_enabled(false)
	mut original, mut window := window_document_identity_fixture('https://window-document.example/original', owner)!
	mut replacement, _ := window_document_identity_fixture('https://other-window-document.example/replacement', other_owner)!
	defer {
		original.finalize()
		replacement.finalize()
	}
	mut native := original.get_window()?
	settings := window.environment_settings_.settings
	window.set_associated_document(replacement)
	assert native.associated_document()? == replacement
	assert window.associated_document() == replacement
	assert settings.responsible_document()? == replacement
	assert settings.api_base_url().to_string() == replacement.base_url().to_string()
	assert settings.origin().is_same_origin(replacement.origin())
	assert window.same_origin(replacement.origin()) && !window.same_origin(original.origin())
	assert window.extract_an_origin()?.is_same_origin(replacement.origin())
	assert voidptr(window.page()) == voidptr(other_owner)
	assert !is_scripting_enabled_for_settings(settings)
	native.set_associated_document(original)
	assert window.associated_document() == original
	assert settings.responsible_document()? == original
	assert window.same_origin(original.origin())
	assert voidptr(window.page()) == voidptr(owner)
	assert is_scripting_enabled_for_settings(settings)
}

fn test_window_document_typed_association_changes_actual_legacy_dispatch_target_and_restores_it() {
	owner := page.Page.create(1)!
	mut original, mut window := window_document_identity_fixture('https://window-document.example/original', owner)!
	mut replacement, _ := window_document_identity_fixture('https://window-document.example/replacement', owner)!
	defer {
		original.finalize()
		replacement.finalize()
	}
	native := original.get_window()?
	state := &WindowDocumentDispatchObservation{}
	target := unsafe { &dom.EventTarget(window) }
	target.add_event_listener_without_options('load', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: native
		handle_event:      fn [window, target, state] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			assert (event.current_target() or { panic('Window current target') }) == target
			assert (current or { panic('Window callback receiver') }) == target
			assert (window.event() or { panic('actual current event') }) == event
			mut observation := unsafe { &WindowDocumentDispatchObservation(state) }
			observation.documents << voidptr(event.target() or { panic('associated Document target') })
			return dom.js_undefined()
		}
	}))
	assert window.dispatch_event(dom.Event.create('load', dom.EventInit{}))
	window.set_associated_document(replacement)
	assert window.dispatch_event(dom.Event.create('load', dom.EventInit{}))
	window.set_associated_document(original)
	assert window.dispatch_event(dom.Event.create('load', dom.EventInit{}))
	assert state.documents == [voidptr(original), voidptr(replacement), voidptr(original)]
	assert window.event() == none
}

fn test_window_document_native_temporary_svg_document_swap_restores_owner_and_active_identity() {
	owner := page.Page.create(1)!
	mut original, mut window := window_document_identity_fixture('https://window-document.example/original', owner)!
	mut native := original.get_window()?
	settings := window.environment_settings_.settings
	mut svg_document := dom.Document.create_with_page_and_relevant_global(original.page(), dom.URL{value: 'https://window-document.example/image.svg'}, native, document_lifecycle_hook(window), dom.DocumentTemporaryExecutionContextHook{
		target: voidptr(window)
		begin:  document_begin_temporary_execution_context
		end:    document_end_temporary_execution_context
	})
	svg_document.set_origin(original.origin())
	svg_document.set_document_type(.xml)
	svg_root := svg_document.create_element_ns('http://www.w3.org/2000/svg', 'svg')!
	mut svg_node := svg_document.as_node()
	svg_node.append_child(svg_root.as_node())!
	defer {
		original.finalize()
		svg_document.finalize()
	}
	mut navigable := original.navigable()?
	previous := navigable.active_document()?
	// ScopedSVGImageDocument's actual Window/Document/navigable association steps.
	svg_document.set_browsing_context(original.get_browsing_context()?)
	svg_document.set_window(native)
	native.set_associated_document(svg_document)
	navigable.set_active_document(svg_document)
	assert window.associated_document() == svg_document
	assert settings.responsible_document()? == svg_document
	assert svg_document.get_window()? == native
	assert svg_document.is_active() && !original.is_active()
	assert voidptr(svg_document.page()) == voidptr(owner) && voidptr(window.page()) == voidptr(owner)
	assert svg_document.relevant_settings_object() == voidptr(settings)
	navigable.set_active_document(previous)
	native.set_associated_document(previous)
	assert window.associated_document() == original
	assert settings.responsible_document()? == original
	assert navigable.active_document()? == original
	assert original.is_active() && !svg_document.is_active()
	assert voidptr(window.page()) == voidptr(owner)
}

fn test_window_document_settings_support_source_global_creation_before_document_association() {
	owner := page.Page.create(1)!
	url := dom.URL{value: 'https://window-document.example/creation'}
	context := BrowsingContextModel.create_for_page(unsafe { &dom.Page(owner) }, none, 'pre-document')
	window := create_window_global_before_document(context, url, url.origin(), url, url.origin())
	settings := window.environment_settings_.settings
	realm := settings.realm()
	assert settings.responsible_document() == none
	assert window.Window.associated_document() == none
	mut document := construct_document_in_global(window, context, url, url.origin())!
	defer { document.finalize() }
	assert settings.responsible_document()? == document
	assert window.associated_document() == document
	assert window.Window.associated_document()? == document
	assert document.get_window()? == unsafe { &dom.Window(window) }
	assert document.relevant_settings_object() == voidptr(settings)
	assert window.environment_settings_.settings.realm() == realm
	assert voidptr(document.page()) == voidptr(owner)
}
