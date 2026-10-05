module html

import dom
import page

fn cross_site_ancestor_document(address string) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{value: address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	native := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(native) }
}

fn cross_site_ancestor_logical_parent(document &dom.Document, parent &dom.Document) {
	mut navigable := document.navigable() or { panic('missing actual child navigable') }
	navigable.parent_ = parent.navigable() or { panic('missing actual parent navigable') }
	navigable.is_top_level_traversable_ = false
}

fn test_cross_site_ancestor_uses_logical_parent_over_cached_context_and_container_document() {
	mut foreign, foreign_window := cross_site_ancestor_document('https://foreign-cross-site.example/')!
	mut local, local_window := cross_site_ancestor_document('https://local-cross-site.example/top')!
	mut child, child_window := cross_site_ancestor_document('https://local-cross-site.example/child')!
	defer {
		foreign.finalize()
		local.finalize()
		child.finalize()
	}
	settings := child_window.environment_settings_.settings
	assert !settings.has_cross_site_ancestor()
	cross_site_ancestor_logical_parent(child, foreign)
	mut navigable := child.navigable()?
	navigable.container_document_ = local
	assert child_window.browsing_context().parent() == none
	assert settings.has_cross_site_ancestor()
	assert settings.serialize().has_cross_site_ancestor
	assert navigable.active_document_has_cross_site_ancestor()
	assert !foreign.navigable()?.active_document_has_cross_site_ancestor()

	// The actual logical parent changes independently of cached local owners.
	cross_site_ancestor_logical_parent(child, local)
	mut context := child_window.browsing_context()
	context.parent_ = foreign_window.browsing_context()
	navigable.container_document_ = foreign
	assert settings.has_cross_site_ancestor() == false
	assert settings.serialize().has_cross_site_ancestor == false
	assert navigable.active_document_has_cross_site_ancestor() == false
	assert local_window.environment_settings_.has_cross_site_ancestor() == false
}

fn test_cross_site_ancestor_recurses_through_parent_active_settings_and_worker_serialization() {
	mut top, _ := cross_site_ancestor_document('https://top-cross-site.example/')!
	mut parent, parent_window := cross_site_ancestor_document('https://repeated-cross-site.example/parent')!
	mut leaf, leaf_window := cross_site_ancestor_document('https://repeated-cross-site.example/leaf')!
	defer {
		top.finalize()
		parent.finalize()
		leaf.finalize()
	}
	cross_site_ancestor_logical_parent(parent, top)
	cross_site_ancestor_logical_parent(leaf, parent)
	assert parent.origin().is_same_site(leaf.origin())
	assert leaf_window.browsing_context().parent() == none
	assert parent_window.environment_settings_.has_cross_site_ancestor()
	assert parent.navigable()?.active_document_has_cross_site_ancestor()
	assert leaf_window.environment_settings_.has_cross_site_ancestor()
	outside := leaf_window.environment_settings_.settings.serialize()
	assert outside.has_cross_site_ancestor
	mut realm := &ScriptingRealm{}
	scope := WorkerGlobalScope.create(dom.URL{value: 'https://repeated-cross-site.example/worker.js'}, .classic, '', realm)
	worker := WorkerEnvironmentSettingsObject.setup(scope, mut realm, outside, 1)
	assert worker.has_cross_site_ancestor()

	// Retain Source short-circuit recursion through the parent's current state.
	mut parent_navigable := parent.navigable()?
	parent_navigable.parent_ = none
	parent_navigable.is_top_level_traversable_ = true
	assert !parent.navigable()?.active_document_has_cross_site_ancestor()
	assert !leaf_window.environment_settings_.has_cross_site_ancestor()
	assert outside.has_cross_site_ancestor
	assert worker.has_cross_site_ancestor()
}

fn test_cross_site_ancestor_reads_window_actual_associated_document_and_restores_after_temporary_swap() {
	mut original, mut window := cross_site_ancestor_document('https://original-cross-site.example/')!
	mut parent, _ := cross_site_ancestor_document('https://parent-cross-site.example/')!
	mut replacement, _ := cross_site_ancestor_document('https://replacement-cross-site.example/')!
	defer {
		original.finalize()
		parent.finalize()
		replacement.finalize()
	}
	cross_site_ancestor_logical_parent(replacement, parent)
	settings := window.environment_settings_.settings
	assert !settings.has_cross_site_ancestor()
	context := window.browsing_context()
	window.set_associated_document(replacement)
	assert window.browsing_context() == context && context.parent() == none
	assert settings.has_cross_site_ancestor()
	assert original.navigable()?.active_document_has_cross_site_ancestor()
	assert settings.serialize().has_cross_site_ancestor
	window.set_associated_document(original)
	assert !settings.has_cross_site_ancestor()
	assert !original.navigable()?.active_document_has_cross_site_ancestor()
}
