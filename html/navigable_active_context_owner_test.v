module html

import dom
import os
import page

fn navigable_active_context_fixture(address string) !(&dom.Document, &WindowModel, &NavigableModel, &dom.Navigable) {
	owner := page.Page.create(1)!
	url := dom.URL{address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	window := unsafe { &WindowModel(document.get_window() or { return error('missing actual Window') }) }
	native := document.navigable() or { return error('missing actual native Navigable') }
	model := navigable_model_for_host(native) or { return error('missing actual local model') }
	return document, window, model, native
}

fn test_active_context_owner_is_actual_native_constructor_identity_and_survives_navigation_replacement() {
	mut original, window, model, native := navigable_active_context_fixture('https://active-context-owner.example/original')!
	context := window.browsing_context()
	native_context := original.get_browsing_context()?
	proxy := context.window_proxy()?
	assert voidptr(browsing_context_model_for_native(native_context)) == voidptr(context)
	assert voidptr(model.active_browsing_context()?) == voidptr(context)
	assert voidptr(model.active_window_proxy()?) == voidptr(proxy)
	assert voidptr(model.active_window()?) == voidptr(window)
	url := dom.URL{'https://active-context-owner.example/replacement'}
	mut replacement := create_navigation_document_for_page(url, url.origin(), original, original.page())!
	defer {
		original.finalize()
		replacement.finalize()
	}
	replacement_window := unsafe { &WindowModel(replacement.get_window()?) }
	assert voidptr(replacement.navigable()?) == voidptr(native)
	assert voidptr(replacement.get_browsing_context()?) == voidptr(native_context)
	assert voidptr(model.active_browsing_context()?) == voidptr(context)
	assert voidptr(model.active_window_proxy()?) == voidptr(proxy)
	assert voidptr(model.active_window()?) == voidptr(replacement_window)
	assert voidptr(model.active_window()?) != voidptr(window)
}

fn test_active_context_getters_follow_actual_document_context_reassociation_without_cached_context_fallback() {
	mut document, window, model, native := navigable_active_context_fixture('https://active-context-owner.example/reassociated')!
	mut other, other_window, _, _ := navigable_active_context_fixture('https://active-context-owner.example/other-context')!
	defer {
		document.finalize()
		other.finalize()
	}
	original_context := window.browsing_context()
	original_native_context := document.get_browsing_context()?
	other_context := other_window.browsing_context()
	other_native_context := other.get_browsing_context()?
	logical_parent := native.parent()
	document.set_browsing_context(other_native_context)
	assert voidptr(model.context_?) == voidptr(original_context)
	assert voidptr(model.active_browsing_context()?) == voidptr(other_context)
	assert voidptr(model.active_window_proxy()?) == voidptr(other_context.window_proxy()?)
	assert voidptr(model.active_window()?) == voidptr(other_window)
	assert native.parent() == logical_parent
	document.set_browsing_context(original_native_context)
	assert voidptr(model.active_browsing_context()?) == voidptr(original_context)
	assert voidptr(model.active_window()?) == voidptr(window)
}

fn test_native_context_identity_is_independent_of_temporary_window_document_and_proxy_window_association() {
	mut document, mut window, model, _ := navigable_active_context_fixture('https://active-context-owner.example/context')!
	mut other, other_window, _, _ := navigable_active_context_fixture('https://active-context-owner.example/other-window')!
	defer {
		document.finalize()
		other.finalize()
	}
	context := window.browsing_context()
	proxy := context.window_proxy()?
	native_context := document.get_browsing_context()?
	window.set_associated_document(other)
	assert voidptr(model.active_browsing_context()?) == voidptr(context)
	assert voidptr(model.active_window()?) == voidptr(window)
	window.set_associated_document(document)
	native_context.window_proxy().set_window(unsafe { &dom.Window(other_window) })
	assert voidptr(proxy.associated_browsing_context()) == voidptr(other_window.browsing_context())
	assert voidptr(browsing_context_model_for_native(native_context)) == voidptr(context)
	assert voidptr(model.active_browsing_context()?) == voidptr(context)
	assert voidptr(model.active_window_proxy()?) == voidptr(proxy)
	assert voidptr(model.active_window()?) == voidptr(other_window)
	native_context.window_proxy().set_window(unsafe { &dom.Window(window) })
	assert voidptr(model.active_window()?) == voidptr(window)
}

fn test_initialized_active_context_getters_return_none_for_destroyed_document_or_missing_actual_context() {
	mut document, window, model, mut native := navigable_active_context_fixture('https://active-context-owner.example/null-current')!
	defer { document.finalize() }
	context := window.browsing_context()
	native_context := document.get_browsing_context()?
	document.destroy()
	assert model.active_document() == none && document.get_browsing_context() == none
	assert model.active_browsing_context() == none && model.active_window_proxy() == none && model.active_window() == none
	assert voidptr(model.context_?) == voidptr(context)
	assert context.active_window() != none
	// Select the actual retained Document through the native setter. Its null
	// browsing-context slot must still prevent a cached context/Window fallback.
	native.set_active_document(document)
	assert voidptr(model.active_document()?) == voidptr(document)
	assert model.active_browsing_context() == none && model.active_window_proxy() == none && model.active_window() == none
	assert voidptr(browsing_context_model_for_native(native_context)) == voidptr(context)
	native.set_active_document(none)
}

fn test_retained_native_context_identity_survives_local_model_registry_removal() {
	mut document, window, mut model, native := navigable_active_context_fixture('https://active-context-owner.example/removed-model')!
	defer { document.finalize() }
	context := window.browsing_context()
	native_context := document.get_browsing_context()?
	model.remove_from_all_navigables()
	assert navigable_model_for_host(native) == none && native.active_document() == none
	assert model.active_browsing_context() == none && model.active_window_proxy() == none && model.active_window() == none
	assert voidptr(browsing_context_model_for_native(native_context)) == voidptr(context)
	assert voidptr(context.page()?) == voidptr(document.page())
}

fn test_actual_native_context_rejects_a_second_constructor_owner_in_every_build_mode() {
	if os.getenv('VOX2_NATIVE_CONTEXT_IDENTITY_CONFLICT') == '1' {
		mut document, _, _, _ := navigable_active_context_fixture('https://active-context-owner.example/identity-conflict')!
		defer { document.finalize() }
		// This constructor would give an already-owned native BrowsingContext a
		// distinct typed identity. The bridge must reject it even under -prod.
		_ = WindowModel.create_top_level(document, none, 'foreign-owner')!
		assert false, 'actual native identity was overwritten'
		return
	}
	mut environment := os.environ()
	environment['VOX2_NATIVE_CONTEXT_IDENTITY_CONFLICT'] = '1'
	mut process := os.new_process(os.executable())
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Native BrowsingContext belongs to another actual HTML model identity'), output
	process.close()
}
