module css

import dom
import platform

fn kind_storage_rule(source string) &CSSRule {
	rules := parse_css_stylesheet_contents_with_parser(source, map[string]bool{})
	assert rules.len == 1
	return rules[0]
}

fn test_common_rules_share_empty_kind_defaults_without_allocating_payloads() {
	mut style := CSSRule.create(.style)
	mut media := CSSRule.create(.media)
	assert style.kind_data_ == unsafe { nil }
	assert media.kind_data_ == unsafe { nil }
	assert voidptr(style.kind_data()) == voidptr(media.kind_data())
	assert style.scope_start() == none
	assert style.scope_end() == none
	assert style.property_rule_initial_style_value() == none
	assert style.function_rule_name() == ''
	assert sizeof(CSSRule) <= 384
	// An invalidation that has no kind-specific cache must keep the empty handle.
	style.clear_caches()
	media.clear_caches()
	assert style.kind_data_ == unsafe { nil }
	assert media.kind_data_ == unsafe { nil }
	$if prealloc {
		style.clear_caches()
		before := platform.thread_arena_usage().used
		for _ in 0 .. 64 {
			style.clear_caches()
			media.clear_caches()
			_ = style.kind_data()
		}
		assert platform.thread_arena_usage().used == before
	}
}

fn test_keyframes_kind_mutation_preserves_by_value_snapshots() {
	mut rule := kind_storage_rule('@keyframes before { from { opacity: 0 } }')
	snapshot := *rule
	original_payload := voidptr(snapshot.kind_data())
	children := rule.css_rules() or { panic('missing keyframes') }
	rule.set_keyframes_name('after')
	assert snapshot.keyframes_name() == 'before'
	assert rule.keyframes_name() == 'after'
	assert voidptr(rule.kind_data()) != original_payload
	assert voidptr(rule.css_rules() or { panic('missing children') }) == voidptr(children)
	assert snapshot.css_text().contains('@keyframes "before"')
	assert rule.css_text().contains('@keyframes "after"')
	payload := voidptr(rule.kind_data())
	rule.set_keyframes_name('after')
	assert voidptr(rule.kind_data()) == payload
}

fn test_page_kind_mutation_preserves_selector_snapshot_and_descriptor_identity() {
	mut page := kind_storage_rule('@page :first { margin: 1cm; @top-left { content: "page"; } }')
	snapshot := *page
	descriptors := page.page_style() or { panic('missing page descriptors') }
	page.set_page_selector_text('chapter:left')
	assert snapshot.page_selector_text() == ':first'
	assert page.page_selector_text() == 'chapter:left'
	assert voidptr(page.page_style() or { panic('missing page style') }) == voidptr(descriptors)
	assert voidptr(descriptors.base.parent_rule or { panic('missing parent') }) == voidptr(page)
	payload := voidptr(page.kind_data())
	page.set_page_selector_text('> invalid')
	assert voidptr(page.kind_data()) == payload
	assert page.page_selector_text() == 'chapter:left'
}

fn test_scope_kind_cache_copy_and_invalidation_preserve_previous_bounds() {
	mut rule := kind_storage_rule('@scope (.root) to (.limit) { .child {} }')
	_ = rule.scope_start_selectors_for_matching() or { panic('missing scope start') }
	_ = rule.scope_end_selectors_for_matching() or { panic('missing scope end') }
	snapshot := *rule
	assert snapshot.kind_data().cached_scope_start_selectors != none
	assert snapshot.kind_data().cached_scope_end_selectors != none
	rule.clear_caches()
	assert rule.kind_data().cached_scope_start_selectors == none
	assert rule.kind_data().cached_scope_end_selectors == none
	cached_start := snapshot.kind_data().cached_scope_start_selectors or { panic('lost saved start') }
	cached_end := snapshot.kind_data().cached_scope_end_selectors or { panic('lost saved end') }
	assert serialize_a_group_of_selectors(cached_start) == '.root'
	assert serialize_a_group_of_selectors(cached_end) == ':scope .limit'
	assert (rule.scope_start() or { '' }) == '.root'
	assert (rule.scope_end() or { '' }) == '.limit'
	payload := voidptr(rule.kind_data())
	rule.clear_caches()
	assert voidptr(rule.kind_data()) == payload
}

fn test_import_kind_copy_keeps_loaded_sheet_and_loading_state_independent() {
	mut import_rule := kind_storage_rule('@import url(child.css) layer(example) scope(.root);')
	snapshot := *import_rule
	mut child := parse_css_stylesheet_with_parser('div { color: red; }', none)
	import_rule.set_style_sheet(child)
	assert snapshot.loaded_style_sheet_for_bindings() == none
	assert snapshot.kind_data().loading_state == .unloaded
	assert voidptr(import_rule.loaded_style_sheet_for_bindings() or { panic('missing loaded sheet') }) == voidptr(child)
	assert import_rule.kind_data().loading_state == .loaded
	assert voidptr(child.owner_rule or { panic('missing sheet owner') }) == voidptr(import_rule)
	assert import_rule.href() == snapshot.href()
	assert (import_rule.layer_name() or { '' }) == 'example'
	assert import_rule.has_scope()
	assert serialize_a_group_of_selectors(import_rule.import_scope_start_selectors() or { panic('missing import scope') }) == '.root'
	payload := voidptr(import_rule.kind_data())
	import_rule.set_style_sheet(child)
	assert voidptr(import_rule.kind_data()) == payload
	import_rule.set_loading_state(.error)
	assert snapshot.kind_data().loading_state == .unloaded
	assert import_rule.kind_data().loading_state == .error
}

fn test_import_unchanged_loading_state_still_notifies_parent_owner() {
	mut ancestor := CSSRule.create(.import_rule)
	mut parent := parse_css_stylesheet_with_parser('', none)
	parent.set_owner_css_rule(ancestor)
	mut child := CSSRule.create(.import_rule)
	child.set_parent_style_sheet(parent)
	child.set_loading_state(.loaded)
	assert ancestor.kind_data().loading_state == .loaded
	ancestor.set_loading_state(.loading)
	child.set_loading_state(.loaded)
	assert ancestor.kind_data().loading_state == .loaded
}

fn test_kind_payload_constructors_keep_namespace_layers_properties_and_wrappers() {
	namespace := CSSRule.create_namespace('s', 'urn:svg')
	assert namespace.namespace_rule_prefix() == 's'
	assert namespace.namespace_rule_namespace_uri() == 'urn:svg'
	assert namespace.css_text() == '@namespace s url("urn:svg");'
	layer := CSSRule.create_layer_statement(['first', 'second'])
	mut names := layer.layer_statement_name_list()
	names[0] = 'changed'
	assert layer.css_text() == '@layer first, second;'
	property := kind_storage_rule('@property --size { syntax: "<length>"; inherits: false; initial-value: 2px; }')
	assert property.property_rule_name() == '--size'
	assert property.property_rule_syntax() == '<length>'
	assert !property.property_rule_inherits()
	assert (property.property_rule_initial_value() or { '' }) == '2px'
	assert property.property_rule_initial_style_value() != none
	face := kind_storage_rule('@font-face { font-family: "Probe"; src: url(probe.woff2); }')
	assert face.font_face_rule_ref() != none
	assert face.css_text().contains('Probe')
	counter := kind_storage_rule('@counter-style probe { system: cyclic; symbols: "x"; }')
	assert counter.counter_style_rule_value() != none
	assert counter.css_text().contains('@counter-style probe')
}

fn test_kind_mutation_and_lazy_scope_cache_survive_document_scratch_release() {
	$if prealloc {
		mut document := dom.Document.create(dom.url_about_blank())
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		mut scope := kind_storage_rule('@scope (.root) to (.limit) {}')
		mut page := kind_storage_rule('@page :first {}')
		mut keyframes := kind_storage_rule('@keyframes before {}')
		mut import_rule := CSSRule.create(.import_rule)
		scratch := platform.begin_thread_scratch('CSS rule kind publication test')
		_ = scope.scope_start_selectors_for_matching() or { panic('missing start') }
		_ = scope.scope_end_selectors_for_matching() or { panic('missing end') }
		page.set_page_selector_text('chapter:right')
		keyframes.set_keyframes_name(['scratch', 'name'].join('-'))
		import_rule.set_loading_state(.error)
		scratch.finish()
		assert import_rule.kind_data().loading_state == .error
		assert page.page_selector_text() == 'chapter:right'
		assert keyframes.keyframes_name() == 'scratch-name'
		start := scope.kind_data().cached_scope_start_selectors or { panic('lost start') }
		end := scope.kind_data().cached_scope_end_selectors or { panic('lost end') }
		assert serialize_a_group_of_selectors(start) == '.root'
		assert serialize_a_group_of_selectors(end) == ':scope .limit'
		owner.finish()
		document.release_native_storage()
	}
}

fn test_process_lifetime_scope_kind_cache_survives_document_arena_release() {
	$if prealloc {
		mut sheet := parse_css_stylesheet_with_parser('@scope (.shared) to (.limit) {}', none)
		sheet.process_lifetime = true
		mut rule := sheet.rules.item(0) or { panic('missing shared scope') }
		mut document := dom.Document.create(dom.url_about_blank())
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		scratch := platform.begin_thread_scratch('CSS shared rule kind publication test')
		_ = rule.scope_start_selectors_for_matching() or { panic('missing shared start') }
		_ = rule.scope_end_selectors_for_matching() or { panic('missing shared end') }
		scratch.finish()
		owner.finish()
		document.release_native_storage()
		start := rule.kind_data().cached_scope_start_selectors or { panic('lost shared start') }
		end := rule.kind_data().cached_scope_end_selectors or { panic('lost shared end') }
		assert serialize_a_group_of_selectors(start) == '.shared'
		assert serialize_a_group_of_selectors(end) == ':scope .limit'
		snapshot := *rule
		rule.clear_caches()
		assert snapshot.kind_data().cached_scope_start_selectors != none
		assert rule.kind_data().cached_scope_start_selectors == none
	}
}
