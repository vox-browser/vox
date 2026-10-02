module css

import dom

fn function_scope_document(source string) !(&dom.Document, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut document_node := document.as_node()
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(target.as_node())!
	add_document_author_style_sheet(document, source)
	_ = css_style_computer_for(document)
	return document, target
}

fn function_scope_call(target &dom.Element, name string) string {
	mut contexts := GuardedSubstitutionContexts{}
	tokens := replace_a_dashed_function(dom.AbstractElement.new(target, none), mut contexts, name, [])
	return serialize_a_series_of_component_values(tokens).trim_space()
}

fn test_function_lookup_uses_layer_order_and_same_layer_last_definition() {
	document, target := function_scope_document('
		@layer lower, higher;
		@layer higher { @function --rank() { result: high; } }
		@layer lower { @function --rank() { result: low; } }
		@layer higher { @function --same() { result: old; } @function --same() { result: new; } }
		@function --outer() { result: outer; }
		@layer higher { @function --outer() { result: layered; } }
		@media not all { @function --rank() { result: inactive; } }
	')!
	assert function_scope_call(target, '--rank') == 'high'
	assert function_scope_call(target, '--same') == 'new'
	assert function_scope_call(target, '--outer') == 'outer'
	mut scope := css_style_scope_for_document(document)
	definition := scope.get_function_definition('--rank') or { panic('missing rank') }
	assert voidptr(definition.scope) == voidptr(scope)
	mut sheet := scope.stylesheets_for_cascade_origin(.author)[0]
	sheet.insert_rule('@layer higher { @function --rank() { result: replacement; } }', u32(sheet.css_rules().length()))!
	assert function_scope_call(target, '--rank') == 'replacement'
}

fn test_function_lookup_searches_origins_only_on_document_scope() {
	document, mut host := function_scope_document('@function --shared() { result: author; }')!
	mut scope := css_style_scope_for_document(document)
	scope.user_style_source = '@function --shared() { result: user; } @function --user() { result: user; }'
	scope.invalidate_rule_cache()
	assert function_scope_call(host, '--shared') == 'author'
	assert function_scope_call(host, '--user') == 'user'
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	mut inside := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut shadow_node := shadow.as_node()
	shadow_node.append_child(inside.as_node())!
	mut shadow_scope := css_style_scope_for_shadow_root(shadow)
	shadow_scope.user_style_source = '@function --user() { result: shadow-user; }'
	assert function_scope_call(inside, '--user') == 'user'
	// The UA cache entry is an actual parsed rule, installed as a rule-cache
	// fixture because platform UA stylesheet sources expose no @function.
	scope.build_rule_cache_if_needed()
	mut cache := scope.rule_cache or { panic('cache') }
	ua_sheet := parse_css_stylesheet_with_parser('@function --ua() { result: ua; }', none)
	rule := ua_sheet.css_rules().item(0) or { panic('ua rule') }
	cache.function_rules_by_name['--ua'] = [CachedFunctionDefinition{ function: rule, cascade_origin: .user_agent }]
	assert function_scope_call(host, '--ua') == 'ua'
	assert function_scope_call(inside, '--ua') == 'ua'
}

fn test_function_lookup_inherits_shadow_scopes_and_preserves_definition_scope_for_nested_calls() {
	document, mut host := function_scope_document('
		@function --value() { result: document; }
		@function --document-call() { result: --value(); }
	')!
	mut shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	mut nested_host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut shadow_node := shadow.as_node()
	shadow_node.append_child(nested_host.as_node())!
	add_shadow_root_author_style_sheet(shadow, '
		@function --value() { result: shadow; }
		@function --shadow-call() { result: --value(); }
	')
	nested := nested_host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	mut inside := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut nested_node := nested.as_node()
	nested_node.append_child(inside.as_node())!
	add_shadow_root_author_style_sheet(nested, '@function --value() { result: nested; }')
	assert function_scope_call(inside, '--value') == 'nested'
	assert function_scope_call(inside, '--shadow-call') == 'shadow'
	assert function_scope_call(inside, '--document-call') == 'document'
	mut parent := host.as_node().parent() or { panic('parent') }
	parent.remove_child(host.as_node())!
	assert css_style_scope_for_shadow_root(nested).get_function_definition('--document-call') == none
	assert function_scope_call(inside, '--shadow-call') == 'shadow'
	// Source uses_document_style_sheets jumps directly to the document's scope,
	// including when the enclosing shadow host is disconnected.
	shadow.set_uses_document_style_sheets(true)
	assert function_scope_call(inside, '--document-call') == 'document'
}
