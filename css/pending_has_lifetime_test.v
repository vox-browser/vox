module css

import dom

#include "pending_has_lifetime_test.h"

$if gcboehm ? {
	#flag -DVOX_CSS_PENDING_HAS_LIFETIME_GC
	fn C.vox_pending_has_watch_owner(index u32, owner voidptr)
	fn C.vox_pending_has_owners_alive() u32
	fn C.vox_pending_has_collect(depth u32)
	fn C.vox_pending_has_run_worker(work fn ())
}

__global pending_has_lifetime_scope &StyleScope

fn test_pending_has_cleared_generation_preserves_drained_records_and_restarts_queue_order() {
	document := dom.Document.create(dom.url_about_blank())
	first := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or { panic(err) }
	second := document.create_element_ns('http://www.w3.org/1999/xhtml', 'aside') or { panic(err) }
	mut scope := StyleScope.new(document.as_node())
	scope.record_pending_has_invalidation_mutation_properties(first.as_node(), [InvalidationProperty.class('old')])
	scope.record_pending_has_invalidation_mutation_properties(second.as_node(), [InvalidationProperty.id('second')])
	nodes := scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.clone()
	features := scope.pending_has_invalidation_features.clone()
	scope.clear_pending_has_invalidations()
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 0
	assert scope.pending_has_invalidation_features.len == 0
	scope.record_pending_has_invalidation_mutation_properties(second.as_node(), [InvalidationProperty.class('new')])
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 1
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has[0] == second.as_node()
	assert nodes.len == 2 && nodes[0] == first.as_node() && nodes[1] == second.as_node()
	old_first := features[first.as_node().unique_id().value()] or { panic('missing first drained record') }
	old_second := features[second.as_node().unique_id().value()] or { panic('missing second drained record') }
	current := scope.pending_has_invalidation_features[second.as_node().unique_id().value()] or { panic('missing new record') }
	assert old_first.class_names['old'] && old_second.ids['second']
	assert !old_second.class_names['new'] && current.class_names['new'] && !current.ids['second']
	assert voidptr(current) != voidptr(old_second)
}

fn test_pending_has_drain_keeps_selector_results_across_matching_and_nonmatching_generations() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	add_document_author_style_sheet(document, '.subject { color: blue } .subject:has(.flag) { color: red }')
	mut subject := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or { panic(err) }
	subject.set_attribute_value('class', 'subject')
	mut child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(subject.as_node()) or { panic(err) }
	mut subject_node := subject.as_node()
	subject_node.append_child(child.as_node()) or { panic(err) }
	mut computer := css_style_computer_for(document)
	document.needs_full_style_update = true
	document.update_style()
	mut scope := css_style_scope_for_document(document)
	before := computer.compute_style(dom.AbstractElement.new(subject, none))
	assert (before.property(.color, .no) or { panic('missing initial color') }).css_text == 'rgb(0, 0, 255)'
	for index, class_name in ['flag', 'unrelated'] {
		expected := ['rgb(255, 0, 0)', 'rgb(0, 0, 255)'][index]
		child.set_attribute_value('class', class_name)
		assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len > 0
		scope.invalidate_style_of_elements_affected_by_has()
		assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 0
		assert scope.pending_has_invalidation_features.len == 0
		document.update_style()
		after := computer.compute_style(dom.AbstractElement.new(subject, none))
		assert (after.property(.color, .no) or { panic('missing updated color') }).css_text == expected
	}
}

@[noinline]
fn pending_has_lifetime_queue_only_owner() {
	// Avoid initialize()'s cursor callback and DOM mutation callbacks: their
	// closure contexts have independent lifetimes outside this queue's owner.
	mut document := &dom.Document{}
	document.document_ = document
	document.selection_ = dom.Selection.create(document)
	pending_has_lifetime_scope.record_conservative_pending_has_invalidation(document.as_node(), true)
	features := pending_has_lifetime_scope.pending_has_invalidation_features[document.as_node().unique_id().value()] or { panic('missing owner features') }
	$if gcboehm ? {
		C.vox_pending_has_watch_owner(0, voidptr(document))
		C.vox_pending_has_watch_owner(1, voidptr(features))
	}
	document.finalize()
}

fn pending_has_lifetime_clear_owners() {
	pending_has_lifetime_scope.clear_pending_has_invalidations()
}

fn test_pending_has_clear_releases_queued_document_and_feature_ownership() {
	anchor := dom.Document.create(dom.url_about_blank())
	pending_has_lifetime_scope = StyleScope.new(anchor.as_node())
	$if gcboehm ? {
		C.vox_pending_has_run_worker(pending_has_lifetime_queue_only_owner)
	} $else {
		pending_has_lifetime_queue_only_owner()
	}
	assert pending_has_lifetime_scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 1
	assert pending_has_lifetime_scope.pending_has_invalidation_features.len == 1
	$if gcboehm ? {
		C.vox_pending_has_collect(8)
		assert C.vox_pending_has_owners_alive() == 3
	}
	$if gcboehm ? {
		C.vox_pending_has_run_worker(pending_has_lifetime_clear_owners)
	} $else {
		pending_has_lifetime_clear_owners()
	}
	assert pending_has_lifetime_scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 0
	assert pending_has_lifetime_scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.cap == 0
	assert pending_has_lifetime_scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.data == unsafe { nil }
	assert pending_has_lifetime_scope.pending_has_invalidation_features.len == 0
	$if gcboehm ? {
		C.vox_pending_has_collect(8)
		C.vox_pending_has_collect(8)
		assert C.vox_pending_has_owners_alive() == 0
	}
	pending_has_lifetime_scope = unsafe { nil }
}
