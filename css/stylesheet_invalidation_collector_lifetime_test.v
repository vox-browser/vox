module css

import dom

#include "rule_callback_lifetime_test.h"

$if gcboehm ? {
	fn C.vox_css_rule_lifetime_watch_owner(index u32, owner voidptr)
	fn C.vox_css_rule_lifetime_owners_alive() u32
	fn C.vox_css_rule_lifetime_collect(depth u32)
	fn C.vox_css_rule_lifetime_run_worker(work fn ())
}

@[noinline]
fn invalidation_collector_build_owned_sheet() {
	mut document := dom.Document.create(dom.URL{value: 'https://example.test/added-sheet'})
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	target.set_attribute_value('class', 'target')
	mut root := document.as_node()
	root.append_child(target.as_node()) or { panic(err) }
	mut sheet := parse_css_stylesheet_with_parser('.target {color:red} @media all {div {height:1px}}', none)
	sheet.add_owning_document_or_shadow_root(root)
	// Check the exact collector even when a document's initial full-invalidation
	// shortcut would otherwise omit this work during stylesheet insertion.
	result := build_invalidation_set_for_stylesheet(sheet)
	assert result.invalidation_set.properties().len > 0
	root.set_entire_subtree_needs_style_update(false)
	document.set_needs_full_style_update(false)
	mut scope := css_style_scope_for_document(document)
	mut list := scope.style_sheet_list()
	list.add_a_css_style_sheet(mut sheet)
	assert list.length() == 1
	assert voidptr(list.item(0) or {panic('missing inserted sheet')}) == voidptr(sheet)
	sync_document_style_elements(document)
	$if gcboehm ? {
		C.vox_css_rule_lifetime_watch_owner(0, voidptr(document))
		C.vox_css_rule_lifetime_watch_owner(1, voidptr(sheet))
	}
	document.finalize()
}

fn test_added_stylesheet_invalidation_collector_releases_its_document_graph() {
	$if gcboehm ? {
		C.vox_css_rule_lifetime_run_worker(invalidation_collector_build_owned_sheet)
		C.vox_css_rule_lifetime_collect(8)
		C.vox_css_rule_lifetime_collect(8)
		assert C.vox_css_rule_lifetime_owners_alive() == 0
	} $else {
		invalidation_collector_build_owned_sheet()
	}
}
