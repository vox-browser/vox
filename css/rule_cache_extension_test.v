module css

import dom

fn extension_document() (&dom.Document, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	mut html := document.create_element('html') or { panic(err) }
	mut head := document.create_element('head') or { panic(err) }
	mut body := document.create_element('body') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(html.as_node()) or { panic(err) }
	mut html_node := html.as_node()
	html_node.append_child(head.as_node()) or { panic(err) }
	html_node.append_child(body.as_node()) or { panic(err) }
	return document, head
}

fn extension_style(document &dom.Document, text string) &dom.Element {
	mut owner := document.create_element('style') or { panic(err) }
	mut owner_node := owner.as_node()
	owner_node.append_child(document.create_text_node(text).as_node()) or { panic(err) }
	return owner
}

fn extension_add_sheet(document &dom.Document, head &dom.Element, text string) &dom.Element {
	owner := extension_style(document, text)
	mut head_node := head.as_node()
	head_node.append_child(owner.as_node()) or { panic(err) }
	return owner
}

fn extension_author_sheets(scope &StyleScope) int {
	return scope.stylesheets_for_cascade_origin(.author).len
}

fn extension_rules(label string, rules []&MatchingRule, mut out []string) {
	mut parts := []string{}
	for rule in rules {
		identity := if owner := rule.rule { u64(voidptr(owner)) } else { u64(0) }
		parts << '${identity}:${rule.style_sheet_index}:${rule.rule_index}:${rule.specificity}:${rule.pseudo_element}:${rule.contains_pseudo_element}'
	}
	out << '${label}=[${parts.join(' ')}]'
}

fn extension_bucket_map(label string, buckets map[string][]&MatchingRule, mut out []string) {
	mut keys := buckets.keys()
	keys.sort()
	for key in keys {
		extension_rules('${label}.${key}', buckets[key], mut out)
	}
}

fn extension_rule_cache(label string, cache &RuleCache, mut out []string) {
	extension_bucket_map('${label}.id', cache.rules_by_id, mut out)
	extension_bucket_map('${label}.class', cache.rules_by_class, mut out)
	extension_bucket_map('${label}.tag', cache.rules_by_tag_name, mut out)
	extension_bucket_map('${label}.attribute', cache.rules_by_attribute_name, mut out)
	for pseudo, rules in cache.rules_by_pseudo_element {
		extension_rules('${label}.pseudo.${pseudo}', rules, mut out)
	}
	extension_rules('${label}.root', cache.root_rules, mut out)
	extension_rules('${label}.slotted', cache.slotted_rules, mut out)
	extension_rules('${label}.part', cache.part_rules, mut out)
	extension_rules('${label}.other', cache.other_rules, mut out)
	mut keyframes := cache.rules_by_animation_keyframes.keys()
	keyframes.sort()
	out << '${label}.keyframes=${keyframes}'
	if cache.disjunctive_subject_masks_ != unsafe { nil } {
		masks := cache.disjunctive_subject_masks_
		out << '${label}.masks=${masks.bits}:${masks.rules.len}'
	}
	for pseudo, index in cache.pseudo_subject_rules_ {
		extension_rule_cache('${label}.subject.${pseudo}', index, mut out)
	}
}

fn extension_snapshot(scope &StyleScope) []string {
	mut out := []string{}
	cache := scope.rule_cache or { panic('no rule cache') }
	for label, caches in {
		'author': cache.author_rule_cache
		'user':   cache.user_rule_cache
		'ua':     cache.user_agent_rule_cache
	} {
		extension_rule_cache('${label}.main', caches.main, mut out)
		mut layers := caches.by_layer.keys()
		layers.sort()
		for layer in layers {
			extension_rule_cache('${label}.layer.${layer}', caches.by_layer[layer] or { panic('layer') }, mut out)
		}
	}
	for pseudo_class, pseudo_cache in cache.pseudo_class_rule_cache {
		extension_rule_cache('pseudo_class.${pseudo_class}', pseudo_cache, mut out)
	}
	data := cache.style_invalidation_data
	mut plan_keys := data.invalidation_plans.keys()
	plan_keys.sort()
	for key in plan_keys {
		plan := data.invalidation_plans[key] or { panic('plan') }
		out << 'plan.${key}=${plan.invalidate_self}:${plan.invalidate_whole_subtree}:${plan.descendant_rules.len}:${plan.sibling_rules.len}'
	}
	out << 'has.classes=${data.class_names_used_in_has_selectors.keys().len}:${data.has_selectors_sensitive_to_featureless_subtree_changes}'
	insights := cache.selector_insights
	mut attributes := insights.attribute_value_tests.keys()
	attributes.sort()
	out << 'insights=${insights.has_has_selectors}:${insights.has_local_link_selectors}:${attributes}'
	mut functions := cache.function_rules_by_name.keys()
	functions.sort()
	for name in functions {
		out << 'function.${name}=${cache.function_rules_by_name[name].len}'
	}
	out << 'layers=${cache.qualified_layer_names_in_order}'
	out << 'size_queries=${cache.has_size_container_queries}'
	return out
}

fn extension_complete_build(mut scope StyleScope) []string {
	scope.invalidate_rule_cache()
	scope.build_rule_cache_if_needed()
	return extension_snapshot(scope)
}

fn test_appended_sheets_extend_the_rule_cache_like_a_complete_build() {
	mut document, head := extension_document()
	defer { document.finalize() }
	extension_add_sheet(document, head, '.a{color:red} #x{margin:1px} div > p{padding:2px} @media (min-width:1px){.m{color:blue}} @keyframes k{from{opacity:0}} .h:has(.i){color:green} [data-v="1"]{color:red} :is(.p,.q){color:red} @function --f(){result:1px}')
	mut scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	// The tree-order sheet precedes the document's empty view-transition sheet.
	assert extension_author_sheets(scope) == 2
	before := rule_cache_extension_count()

	extension_add_sheet(document, head, '.a{color:green} .b::before{content:"x"} p:hover{color:red} @container (min-width:1px){.c{color:red}} @keyframes k{to{opacity:1}} [data-w]{color:red} :is(.r,.s) span{color:red}')
	extension_add_sheet(document, head, '@function --g(){result:2px} li:first-child{margin:0} .h:has(> .j){color:blue}')
	scope.build_rule_cache_if_needed()
	assert rule_cache_extension_count() == before + 1
	extended := extension_snapshot(scope)
	assert extended == extension_complete_build(mut scope)
	assert extended.any(it.starts_with('author.main.class.a=') && it.count(' ') == 1)
	assert extended.contains('size_queries=true')
}

fn test_layers_insertions_and_other_invalidations_build_completely() {
	mut document, head := extension_document()
	defer { document.finalize() }
	first := extension_add_sheet(document, head, '.a{color:red}')
	mut scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	before := rule_cache_extension_count()

	// Layer order belongs to the whole cache.
	extension_add_sheet(document, head, '@layer base{.l{color:red}}')
	scope.build_rule_cache_if_needed()
	assert rule_cache_extension_count() == before
	assert extension_snapshot(scope) == extension_complete_build(mut scope)

	// A sheet before the existing ones changes their cascade positions.
	earlier := extension_style(document, '.e{color:red}')
	mut head_node := head.as_node()
	head_node.insert_before(earlier.as_node(), first.as_node(), false)
	assert extension_author_sheets(scope) == 4
	scope.build_rule_cache_if_needed()
	assert rule_cache_extension_count() == before
	assert extension_snapshot(scope) == extension_complete_build(mut scope)

	// Any other invalidation after an append discards the kept cache.
	extension_add_sheet(document, head, '.z{color:red}')
	scope.invalidate_rule_cache()
	scope.build_rule_cache_if_needed()
	assert rule_cache_extension_count() == before
	assert extension_snapshot(scope) == extension_complete_build(mut scope)

	// Two appends before the next build extend once.
	extension_add_sheet(document, head, '.y{color:red}')
	extension_add_sheet(document, head, '.x{color:red}')
	scope.build_rule_cache_if_needed()
	assert rule_cache_extension_count() == before + 1
	assert extension_snapshot(scope) == extension_complete_build(mut scope)
}
