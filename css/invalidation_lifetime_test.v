module css

import dom

#include "invalidation_lifetime_test.h"

$if gcboehm ? {
	fn C.vox_invalidation_watch_owner(owner voidptr)
	fn C.vox_invalidation_owner_alive() int
	fn C.vox_invalidation_collect(depth u32)
	fn C.vox_invalidation_run_worker(work fn ())
}

fn invalidation_watch_document(document &dom.Document) {
	$if gcboehm ? { C.vox_invalidation_watch_owner(voidptr(document)) }
}

@[noinline]
fn invalidation_create_keyframes_owner() {
	mut document := dom.Document.create(dom.url_about_blank())
	invalidation_watch_document(document)
	sheet :=
		parse_css_stylesheet_with_parser('@media all { @keyframes unused { from { opacity: 0 } } }', none)
	invalidate_root_for_keyframes_rules_in_sheet(document.as_node(), sheet)
	document.finalize()
}

@[noinline]
fn invalidation_create_matching_rule_owner() {
	mut document := dom.Document.create(dom.url_about_blank())
	invalidation_watch_document(document)
	mut sheet := parse_css_stylesheet_with_parser('div::before { content: "x" }', none)
	sheet.add_owning_document_or_shadow_root(document.as_node())
	result := &StyleSheetInvalidationSet{
		pseudo_element_rules: [
			StyleSheetPseudoElementInvalidationRule{
				style_sheet_for_rule: sheet
			},
		]
	}
	invalidate_elements_matching_style_sheet_invalidation(document.as_node(), result, none, none)
	document.finalize()
}

fn invalidation_empty_shadow(document &dom.Document) &dom.ShadowRoot {
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	return host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
}

@[noinline]
fn invalidation_create_slot_owner() {
	mut document := dom.Document.create(dom.url_about_blank())
	invalidation_watch_document(document)
	shadow := invalidation_empty_shadow(document)
	invalidate_assigned_elements_for_dirty_style_sheet_slots(shadow)
	document.finalize()
}

@[noinline]
fn invalidation_create_shadow_sheet_owner() {
	mut document := dom.Document.create(dom.url_about_blank())
	invalidation_watch_document(document)
	shadow := invalidation_empty_shadow(document)
	sheet :=
		parse_css_stylesheet_with_parser(':host { color: red } ::slotted(span) { color: blue }', none)
	effects := determine_shadow_root_style_sheet_effects_for_sheet(sheet, shadow)
	assert effects.may_match_shadow_host
	assert effects.may_match_light_dom_under_shadow_host
	document.finalize()
}

@[noinline]
fn invalidation_create_shadow_scope_owner() {
	mut document := dom.Document.create(dom.url_about_blank())
	invalidation_watch_document(document)
	shadow := invalidation_empty_shadow(document)
	effects := determine_shadow_root_style_sheet_effects(shadow)
	assert !effects.may_match_shadow_host
	document.finalize()
}

fn invalidation_assert_worker_collectible(work fn ()) {
	$if gcboehm ? {
		C.vox_invalidation_run_worker(work)
		C.vox_invalidation_collect(8)
		C.vox_invalidation_collect(8)
		assert C.vox_invalidation_owner_alive() == 0
	} $else {
		work()
	}
}

fn test_keyframes_sheet_invalidation_releases_document_after_walk() {
	invalidation_assert_worker_collectible(invalidation_create_keyframes_owner)
}

fn test_matching_rule_invalidation_releases_dom_owned_sheet_after_walk() {
	invalidation_assert_worker_collectible(invalidation_create_matching_rule_owner)
}

fn test_slot_invalidation_releases_shadow_owner_after_walk() {
	invalidation_assert_worker_collectible(invalidation_create_slot_owner)
}

fn test_shadow_rule_effects_release_document_after_walk() {
	invalidation_assert_worker_collectible(invalidation_create_shadow_sheet_owner)
}

fn test_shadow_scope_effects_release_document_after_walk() {
	invalidation_assert_worker_collectible(invalidation_create_shadow_scope_owner)
}
