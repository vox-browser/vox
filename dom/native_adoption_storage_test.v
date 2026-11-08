module dom

import platform

struct NativeAdoptionCleanupProbe {
mut:
	retired int
	released int
}

struct NativeLayoutRetirementProbe {
	document &Document
	payload &Text
	reenter bool
mut:
	calls int
}

fn native_layout_retirement_callback(handle voidptr) {
	mut probe := unsafe { &NativeLayoutRetirementProbe(handle) }
	probe.calls++
	assert probe.document.layout_engine_handle() == unsafe { nil }
	assert probe.document.cached_display_list_ == unsafe { nil }
	assert probe.document.native_storage() != unsafe { nil }
	if probe.reenter {
		mut document := unsafe { &Document(probe.document) }
		document.release_native_storage()
	}
	// Even a reentrant document release cannot free the callback's payload.
	assert probe.payload.data() == 'layout retirement payload'
}

fn install_native_layout_retirement_probe(mut document Document, reenter bool) &NativeLayoutRetirementProbe {
	payload := native_adoption_text(mut document, 'layout retirement payload')
	probe := &NativeLayoutRetirementProbe{document: &document, payload: payload, reenter: reenter}
	document.set_layout_update_hook(DocumentLayoutUpdateHook{
		retire_native_layout: native_layout_retirement_callback
	})
	document.layout_engine_handle_ = voidptr(probe)
	document.cached_display_list_ = &DisplayList{concrete_handle: voidptr(probe)}
	return probe
}

fn native_adoption_document() &Document {
	mut document := Document.create(url_about_blank())
	document.enable_native_storage()
	return document
}

fn native_adoption_text(mut document Document, value string) &Text {
	mut allocations := document.enter_native_storage()
	text := document.create_text_node(value)
	allocations.finish()
	return text
}

fn assert_native_adoption_storage_released(storage &platform.RetainedArena) {
	$if prealloc { assert storage.arena.usage().used == 0 }
}

fn test_adopted_subtree_survives_source_retirement_until_the_last_reader_releases() {
	mut source := native_adoption_document()
	mut destination := native_adoption_document()
	mut source_storage := source.native_storage()
	destination_storage := destination.native_storage()
	mut allocations := source.enter_native_storage()
	parent := source.create_element('div')!
	mut text := source.create_text_node('source payload')
	mut parent_node := parent.as_node()
	parent_node.append_child(text.as_node())!
	allocations.finish()
	destination.adopt_node(parent_node)
	assert voidptr(parent.document()) == voidptr(destination)
	assert voidptr(text.as_node().document()) == voidptr(destination)
	if source_storage != unsafe { nil } { source_storage.retain() }
	source.finalize()
	source.release_native_storage()
	assert text.data() == 'source payload'
	mut edits := destination.enter_native_storage()
	text.set_data('adopted payload')
	edits.finish()
	destination.finalize()
	destination.release_native_storage()
	// A retained reader protects both the original node and its new data.
	assert text.data() == 'adopted payload'
	if source_storage != unsafe { nil } { source_storage.release() }
	assert_native_adoption_storage_released(source_storage)
	assert_native_adoption_storage_released(destination_storage)
}

fn test_reciprocal_native_adoption_reclaims_both_document_arenas() {
	mut first := native_adoption_document()
	mut second := native_adoption_document()
	first_storage := first.native_storage()
	second_storage := second.native_storage()
	first_text := native_adoption_text(mut first, 'first allocation owner')
	second_text := native_adoption_text(mut second, 'second allocation owner')
	second.adopt_node(first_text.as_node())
	first.adopt_node(second_text.as_node())
	for _ in 0 .. 3 {
		first.adopt_node(first_text.as_node())
		second.adopt_node(first_text.as_node())
	}
	first.finalize()
	first.release_native_storage()
	assert first_text.data() == 'first allocation owner'
	assert second_text.data() == 'second allocation owner'
	second.finalize()
	second.release_native_storage()
	assert_native_adoption_storage_released(first_storage)
	assert_native_adoption_storage_released(second_storage)
}

fn test_readoption_carries_the_original_owner_after_its_document_retires() {
	mut source := native_adoption_document()
	mut intermediate := native_adoption_document()
	mut destination := native_adoption_document()
	source_storage := source.native_storage()
	intermediate_storage := intermediate.native_storage()
	destination_storage := destination.native_storage()
	text := native_adoption_text(mut source, 'transitively adopted text')
	intermediate.adopt_node(text.as_node())
	source.finalize()
	source.release_native_storage()
	assert source.native_storage() == unsafe { nil }
	destination.adopt_node(text.as_node())
	intermediate.finalize()
	intermediate.release_native_storage()
	assert voidptr(text.as_node().document()) == voidptr(destination)
	assert text.data() == 'transitively adopted text'
	destination.finalize()
	destination.release_native_storage()
	assert_native_adoption_storage_released(source_storage)
	assert_native_adoption_storage_released(intermediate_storage)
	assert_native_adoption_storage_released(destination_storage)
}

fn test_general_document_finalization_releases_its_implicit_adoption_owner() {
	mut source := native_adoption_document()
	mut destination := Document.create(url_about_blank())
	source_storage := source.native_storage()
	assert destination.native_storage() == unsafe { nil }
	text := native_adoption_text(mut source, 'native text in a general document')
	destination.adopt_node(text.as_node())
	destination_storage := destination.native_storage()
	$if prealloc { assert destination_storage != unsafe { nil } }
	source.finalize()
	source.release_native_storage()
	assert text.data() == 'native text in a general document'
	// General DOM users already finalize; they do not have a native shell.
	destination.finalize()
	assert destination.native_storage() == unsafe { nil }
	assert_native_adoption_storage_released(source_storage)
	assert_native_adoption_storage_released(destination_storage)
	destination.finalize()
}

fn test_explicit_native_enable_takes_over_an_implicit_adoption_owners_retirement() {
	mut source := native_adoption_document()
	mut destination := Document.create(url_about_blank())
	source_storage := source.native_storage()
	text := native_adoption_text(mut source, 'promoted native session')
	destination.adopt_node(text.as_node())
	destination.enable_native_storage()
	destination_storage := destination.native_storage()
	source.finalize()
	source.release_native_storage()
	destination.finalize()
	assert text.data() == 'promoted native session'
	$if prealloc {
		assert destination.native_storage() != unsafe { nil }
		assert source_storage.arena.usage().used > 0
	}
	// The explicit owner keeps the existing shell-controlled release order.
	destination.release_native_storage()
	assert_native_adoption_storage_released(source_storage)
	assert_native_adoption_storage_released(destination_storage)
}

fn test_document_retirement_callbacks_are_reentrant_and_precede_the_final_reader() {
	mut document := native_adoption_document()
	mut storage := document.native_storage()
	text := native_adoption_text(mut document, 'readable in retirement')
	probe := &NativeAdoptionCleanupProbe{}
	if storage != unsafe { nil } {
		storage.retain()
		storage.add_cleanup(fn [probe] () {
			mut observation := unsafe { &NativeAdoptionCleanupProbe(probe) }
			observation.released++
		})
	}
	document.add_native_storage_cleanup(fn [document, text, probe] () {
		assert text.data() == 'readable in retirement'
		mut observation := unsafe { &NativeAdoptionCleanupProbe(probe) }
		observation.retired++
		mut owner := unsafe { &Document(document) }
		owner.release_native_storage()
	})
	document.finalize()
	document.release_native_storage()
	document.release_native_storage()
	assert probe.retired == 1 && probe.released == 0
	assert text.data() == 'readable in retirement'
	if storage != unsafe { nil } {
		storage.release()
		assert probe.released == 1
	}
	assert_native_adoption_storage_released(storage)
}

fn test_retiring_a_parent_releases_a_child_owner_before_their_shared_payload() {
	mut parent := native_adoption_document()
	mut child := native_adoption_document()
	parent_storage := parent.native_storage()
	mut child_storage := child.native_storage()
	text := native_adoption_text(mut child, 'child adopted into parent')
	parent.adopt_node(text.as_node())
	probe := &NativeAdoptionCleanupProbe{}
	child.add_native_storage_cleanup(fn [probe] () {
		mut observation := unsafe { &NativeAdoptionCleanupProbe(probe) }
		observation.retired++
	})
	parent.add_native_storage_cleanup(fn [child, probe] () {
		mut observation := unsafe { &NativeAdoptionCleanupProbe(probe) }
		observation.retired++
		mut owner := unsafe { &Document(child) }
		owner.finalize()
		owner.release_native_storage()
	})
	if child_storage != unsafe { nil } {
		child_storage.add_cleanup(fn [probe, text] () {
			assert probe.retired == 2
			assert text.data() == 'child adopted into parent'
			mut observation := unsafe { &NativeAdoptionCleanupProbe(probe) }
			observation.released++
		})
	}
	parent.finalize()
	parent.release_native_storage()
	parent.release_native_storage()
	child.release_native_storage()
	assert probe.retired == 2
	$if prealloc { assert probe.released == 1 }
	assert_native_adoption_storage_released(parent_storage)
	assert_native_adoption_storage_released(child_storage)
}

fn test_native_deactivation_retires_its_layout_publisher_only_once() {
	$if !prealloc { return }
	mut document := native_adoption_document()
	storage := document.native_storage()
	probe := install_native_layout_retirement_probe(mut document, false)
	document.did_stop_being_active_document_in_navigable()
	assert probe.calls == 1
	assert document.native_storage() != unsafe { nil }
	document.did_stop_being_active_document_in_navigable()
	document.finalize()
	document.release_native_storage()
	assert probe.calls == 1
	assert_native_adoption_storage_released(storage)
}

fn test_suspended_native_layout_retires_only_when_its_document_owner_retires() {
	$if !prealloc { return }
	mut document := native_adoption_document()
	storage := document.native_storage()
	probe := install_native_layout_retirement_probe(mut document, false)
	document.retains_layout_while_inactive = true
	document.did_stop_being_active_document_in_navigable()
	assert probe.calls == 0
	assert document.layout_engine_handle() == voidptr(probe)
	document.finalize()
	document.release_native_storage()
	assert probe.calls == 1
	assert_native_adoption_storage_released(storage)
}

fn test_native_layout_retirement_can_reenter_document_storage_release() {
	$if !prealloc { return }
	mut document := native_adoption_document()
	storage := document.native_storage()
	probe := install_native_layout_retirement_probe(mut document, true)
	document.finalize()
	document.release_native_storage()
	document.release_native_storage()
	assert probe.calls == 1
	assert document.native_storage() == unsafe { nil }
	assert_native_adoption_storage_released(storage)
}

fn test_non_native_deactivation_preserves_the_general_layout_snapshot_contract() {
	mut document := Document.create(url_about_blank())
	probe := install_native_layout_retirement_probe(mut document, false)
	document.did_stop_being_active_document_in_navigable()
	document.finalize()
	document.release_native_storage()
	assert probe.calls == 0
}
