module css

import dom

#include "computed_property_store_test.h"

$if gcboehm ? {
	fn C.vox_property_store_watch(index u32, owner voidptr)
	fn C.vox_property_store_collect(depth u32)
	fn C.vox_property_store_worker(work fn ())
	fn C.vox_property_store_alive() u32
	__global retired_scope_document_ &dom.Document
}

fn retired_scope_document() &dom.Document {
	mut document := dom.Document.create(dom.URL{value: 'https://scope-retirement.test/'})
	mut node := document.as_node()
	target := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	node.append_child(target.as_node()) or { panic(err) }
	add_document_author_style_sheet(document, '@layer base { div { color: rgb(12 34 56) } }')
	return document
}

fn retired_scope_color(document &dom.Document, target &dom.Element) string {
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(target, none))
	return (computed.property(.color, .no) or { panic('missing color') }).css_text
}

fn test_retired_scope_rebuilds_from_original_cssom_and_observes_later_mutations() {
	mut document := retired_scope_document()
	defer { document.finalize() }
	target := document.document_element()?
	assert retired_scope_color(document, target) == 'rgb(12, 34, 56)'
	mut scope := css_style_scope_for_document(document)
	sheet := scope.stylesheets_for_cascade_origin(.author)[0]
	assert scope.rule_cache != none
	assert discard_native_document_computed_styles(document)
	assert scope.rule_cache == none
	assert scope.author_rule_cache == none
	assert scope.selector_insights == none
	assert scope.stylesheets_for_cascade_origin(.author)[0] == sheet
	assert retired_scope_color(document, target) == 'rgb(12, 34, 56)'
	mut mutable_sheet := unsafe { &CSSStyleSheet(sheet) }
	mutable_sheet.insert_rule('div { color: rgb(65 43 21) }', u32(sheet.rules.length()))!
	assert retired_scope_color(document, target) == 'rgb(65, 43, 21)'
}

fn test_retirement_releases_disconnected_shadow_cache_owners_and_rebuilds_shared_ua_cache() {
	mut document := retired_scope_document()
	defer { document.finalize() }
	mut host := document.create_element_ns(dom.namespace_html_uri, 'div')!
	shadow := host.attach_shadow(dom.ShadowRootInit{mode: .closed})!
	child := document.create_element_ns(dom.namespace_html_uri, 'span')!
	mut root := unsafe { &dom.Node(shadow) }
	root.append_child(child.as_node())!
	scope := css_style_scope_for_shadow_root(shadow)
	scope.build_rule_cache_if_needed()
	before := scope.rule_cache?
	assert scope.adopted_user_agent_only_shadow_cache_ != unsafe { nil }
	document_scope := css_style_scope_for_document(document)
	assert document_scope.user_agent_only_shadow_cache_ != unsafe { nil }
	assert discard_native_document_computed_styles(document)
	assert scope.rule_cache == none
	assert document_scope.user_agent_only_shadow_cache_ == unsafe { nil }
	scope.build_rule_cache_if_needed()
	assert scope.rule_cache? != before
	assert scope.adopted_user_agent_only_shadow_cache_ != unsafe { nil }
}

@[noinline]
fn prepare_retired_scope_collection() {
	$if gcboehm ? {
		mut document := retired_scope_document()
		scope := css_style_scope_for_document(document)
		scope.build_rule_cache_if_needed()
		C.vox_property_store_watch(0, scope.rule_cache or { panic('cache') })
		C.vox_property_store_watch(1, scope.author_rule_cache or { panic('author cache') })
		retired_scope_document_ = document
	}
}

fn release_retired_scope_collection() {
	$if gcboehm ? { assert discard_native_document_computed_styles(retired_scope_document_) }
}

fn test_retired_document_retains_cssom_while_derived_rule_caches_become_collectible() {
	$if gcboehm ? {
		C.vox_property_store_worker(prepare_retired_scope_collection)
		C.vox_property_store_collect(8)
		assert C.vox_property_store_alive() == 3
		C.vox_property_store_worker(release_retired_scope_collection)
		C.vox_property_store_collect(8)
		C.vox_property_store_collect(8)
		assert C.vox_property_store_alive() == 0
		assert retired_scope_color(retired_scope_document_, retired_scope_document_.document_element()?) == 'rgb(12, 34, 56)'
		retired_scope_document_.finalize()
	} $else {
		mut document := retired_scope_document()
		assert discard_native_document_computed_styles(document)
		assert retired_scope_color(document, document.document_element()?) == 'rgb(12, 34, 56)'
		document.finalize()
	}
}
