module html

import css
import dom

#include "media_rules_lifetime_test.h"

$if gcboehm ? {
	fn C.vox_media_rules_watch(index u32, owner voidptr)
	fn C.vox_media_rules_collect(depth u32)
	fn C.vox_media_rules_run_worker(work fn ())
	fn C.vox_media_rules_owners_alive() u32
}

fn media_rules_lifetime_parse(markup string) (&dom.Document, &HTMLParser) {
	mut document := dom.Document.create(dom.URL{value: 'https://media-owner.test/'})
	document.set_scripting_enabled_by_embedder(false)
	document.set_allow_declarative_shadow_roots(true)
	mut parser := HTMLParser.create_with_scripting_mode(document, markup, .disabled)
	parser.run()
	assert document.readiness() == .complete
	assert document.get_browsing_context() == none
	return document, parser
}

fn media_rules_lifetime_watch(document &dom.Document, parser &HTMLParser) {
	$if gcboehm ? {
		C.vox_media_rules_watch(0, voidptr(document))
		C.vox_media_rules_watch(1, voidptr(parser))
	}
}

fn media_rules_lifetime_evaluate_only() {
	mut document, parser := media_rules_lifetime_parse('<!doctype html><section><p>detached media traversal</p></section>')
	css.install_document_style_hook(document)
	document.evaluate_media_rules()
	media_rules_lifetime_watch(document, parser)
	document.finalize()
}

fn test_media_evaluation_releases_its_parsed_document_and_parser() {
	$if gcboehm ? {
		C.vox_media_rules_run_worker(media_rules_lifetime_evaluate_only)
		C.vox_media_rules_collect(8)
		C.vox_media_rules_collect(8)
		assert C.vox_media_rules_owners_alive() == 0
	} $else {
		media_rules_lifetime_evaluate_only()
	}
}

fn media_rules_lifetime_full_sync() {
	mut document, parser := media_rules_lifetime_parse('<!doctype html><section><p>discovery CSS synchronization</p></section>')
	document.set_viewport_rect(dom.Rect{width: 800, height: 600})
	scope := css.style_scope_for_dom_node(document.as_node())
	initial_sheet_count := scope.stylesheets_for_cascade_origin(.author).len
	// Install the sheet through CSS so this test owns only the stylesheet and
	// media traversals. An inline <style> separately queues its load-event task.
	css.add_document_author_style_sheet(document, '@layer shared { p { color: red } } @media (min-width: 700px) { p { color: blue } }')
	css.sync_document_style_elements(document)
	assert scope.stylesheets_for_cascade_origin(.author).len == initial_sheet_count + 1
	media_rules_lifetime_watch(document, parser)
	document.finalize()
}

fn test_discovery_css_sync_releases_its_css_owned_document_graph() {
	$if gcboehm ? {
		C.vox_media_rules_run_worker(media_rules_lifetime_full_sync)
		C.vox_media_rules_collect(8)
		C.vox_media_rules_collect(8)
		assert C.vox_media_rules_owners_alive() == 0
	} $else {
		media_rules_lifetime_full_sync()
	}
}

fn test_media_traversal_reaches_nested_closed_and_user_agent_shadow_scopes() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_viewport_rect(dom.Rect{width: 500, height: 600})
	css.install_document_style_hook(document)
	mut root := document.create_element_ns(ns_html, 'html') or { panic(err) }
	mut outer_host := document.create_element_ns(ns_html, 'div') or { panic(err) }
	mut unaffected_host := document.create_element_ns(ns_html, 'div') or { panic(err) }
	mut ua_host := document.create_element_ns(ns_html, 'div') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	for host in [outer_host, unaffected_host, ua_host] {
		root_node.append_child(host.as_node()) or { panic(err) }
	}
	outer := outer_host.attach_shadow(dom.ShadowRootInit{mode: .closed}) or { panic(err) }
	mut inner_host := document.create_element_ns(ns_html, 'span') or { panic(err) }
	mut outer_node := outer.as_node()
	outer_node.append_child(inner_host.as_node()) or { panic(err) }
	inner := inner_host.attach_shadow(dom.ShadowRootInit{mode: .closed}) or { panic(err) }
	unaffected := unaffected_host.attach_shadow(dom.ShadowRootInit{mode: .open}) or { panic(err) }
	ua := ua_host.attach_a_user_agent_shadow_root(.named)
	css.add_document_author_style_sheet(document, 'p { color: black }')
	css.add_shadow_root_author_style_sheet(outer, 'span { color: black }')
	css.add_shadow_root_author_style_sheet(inner, '@media (min-width: 600px) { span { color: red } }')
	css.add_shadow_root_author_style_sheet(unaffected, '@media (min-width: 100px) { span { color: blue } }')
	css.add_shadow_root_author_style_sheet(ua, '@media (min-width: 600px) { span { color: green } }')
	document.evaluate_media_rules()
	scopes := [css.style_scope_for_dom_node(document.as_node()),
		css.style_scope_for_dom_node(outer.as_node()), css.style_scope_for_dom_node(inner.as_node()),
		css.style_scope_for_dom_node(unaffected.as_node()), css.style_scope_for_dom_node(ua.as_node())]
	for scope in scopes {
		scope.build_rule_cache_if_needed()
		assert scope.has_valid_rule_cache()
	}
	document.set_viewport_rect(dom.Rect{width: 800, height: 600})
	document.evaluate_media_rules()
	assert scopes[0].has_valid_rule_cache()
	assert scopes[1].has_valid_rule_cache()
	assert !scopes[2].has_valid_rule_cache()
	assert scopes[3].has_valid_rule_cache()
	assert !scopes[4].has_valid_rule_cache()
	for scope in scopes { scope.build_rule_cache_if_needed() }
	document.evaluate_media_rules()
	for scope in scopes { assert scope.has_valid_rule_cache() }
	document.set_viewport_rect(dom.Rect{width: 500, height: 600})
	document.evaluate_media_rules()
	assert !scopes[2].has_valid_rule_cache() && !scopes[4].has_valid_rule_cache()
	assert scopes[0].has_valid_rule_cache() && scopes[1].has_valid_rule_cache() && scopes[3].has_valid_rule_cache()
}
