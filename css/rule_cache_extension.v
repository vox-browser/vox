module css

import dom
import os

// Appending a style sheet used to rebuild every rule cache of the document:
// each selector of every author, user and user-agent sheet was indexed and its
// invalidation sets built again. Pages that add sheets after the first style
// pass (GitHub inserts two more after about 7,000 rules) paid that each time.
//
// Every structure the build fills is append-only: rule buckets, the
// pseudo-subject index, disjunctive subject masks, keyframes, invalidation
// plans and selector insights. A build that adds the new sheets' rules after
// those of the sheets before them therefore produces the same caches as a
// complete one. The appending invalidation still clears the scope's caches,
// so readers that consult them without building see none in between, and
// keeps the published cache aside. The next build extends that cache when the
// author sheets it holds are an unchanged prefix of the current ones and no
// other invalidation happened since; otherwise it builds everything again.
const disable_rule_cache_extension = os.getenv('VOX_DISABLE_RULE_CACHE_EXTENSION') != ''
const rule_cache_extension_diagnostics = os.getenv('VOX_RULE_CACHE_EXTENSION_DIAGNOSTICS') != ''

__global rule_cache_extensions u64

@[heap]
struct ExtendableRuleCache {
	cache         &StyleCache = unsafe { nil }
	author_sheets []&CSSStyleSheet
	font_policy   dom.FontRenderingPolicy
	quirks        bool
	// The document's author sheets end with its view-transition sheet, which
	// is empty outside a transition. Sheets in tree order precede it.
	trailing_empty bool
}

fn rule_cache_sheet_is_empty(sheet &CSSStyleSheet) bool {
	return sheet.rules.length() == 0
}

// Rule caches extended with appended sheets in this process (tests and diagnostics).
pub fn rule_cache_extension_count() u64 {
	return rule_cache_extensions
}

fn invalidate_css_style_scope_for_appended_sheet(node &dom.Node) {
	mut scope := css_style_scope_for_node(node)
	scope.invalidate_rule_cache_for_appended_sheet()
}

// A sheet was inserted into the scope's sheet list. Invalidates like
// invalidate_rule_cache(), keeping the document's built cache for extension.
pub fn (mut scope StyleScope) invalidate_rule_cache_for_appended_sheet() {
	mut extendable := scope.extendable_rule_cache_
	if !disable_rule_cache_extension && extendable == unsafe { nil } {
		if cache := scope.rule_cache {
			if node := scope.node {
				if node.as_shadow_root() == none && scope.adopted_user_agent_only_shadow_cache_ == unsafe { nil } {
					if document := scope.document() {
						sheets := scope.rule_cache_author_sheets_
						extendable = &ExtendableRuleCache{
							cache:          cache
							author_sheets:  sheets
							font_policy:    scope.rule_cache_font_policy_
							quirks:         document.in_quirks_mode()
							trailing_empty: sheets.len > 0 && rule_cache_sheet_is_empty(sheets.last())
						}
					}
				}
			}
		}
	}
	scope.invalidate_rule_cache()
	scope.extendable_rule_cache_ = extendable
}

// Whether `rules` can join the caches after the existing sheets. Layer
// declarations and imports can change the order of named layers, which the
// whole cache depends on.
fn rule_cache_rules_append_cleanly(rules &CSSRuleList) bool {
	for rule in rules.rules {
		if rule.type_ in [.layer_block, .layer_statement, .import_rule] { return false }
		if children := rule.css_rules() {
			if !rule_cache_rules_append_cleanly(children) { return false }
		}
	}
	return true
}

// The current author sheets and those of them to add, or none when the kept
// cache cannot be extended to them.
struct RuleCacheExtensionSheets {
	all      []&CSSStyleSheet
	appended []&CSSStyleSheet
	first    int
}

fn (scope &StyleScope) extension_sheets(saved &ExtendableRuleCache) ?RuleCacheExtensionSheets {
	document := scope.document() or { return none }
	if saved.font_policy != document.font_rendering_policy() || saved.quirks != document.in_quirks_mode() {
		return none
	}
	sheets := scope.stylesheets_for_cascade_origin(.author)
	mut previous := saved.author_sheets.clone()
	mut current := sheets.clone()
	// An empty last sheet that stays last and empty contributes no rules, so
	// the sheets inserted before it extend the cache as appended ones.
	if saved.trailing_empty && previous.len > 0 && current.len > 0
		&& voidptr(previous.last()) == voidptr(current.last()) && rule_cache_sheet_is_empty(current.last()) {
		previous.delete_last()
		current.delete_last()
	}
	if current.len < previous.len { return none }
	for index, sheet in previous {
		if voidptr(current[index]) != voidptr(sheet) { return none }
	}
	appended := current[previous.len..].clone()
	for sheet in appended {
		if !rule_cache_rules_append_cleanly(sheet.rules) { return none }
	}
	return RuleCacheExtensionSheets{
		all:      sheets
		appended: appended
		first:    previous.len
	}
}

// Restores the cache kept by invalidate_rule_cache_for_appended_sheet() and
// adds the sheets appended since. False when a complete build is needed.
fn (mut scope StyleScope) extend_rule_cache() bool {
	saved := scope.extendable_rule_cache_
	if saved == unsafe { nil } { return false }
	scope.extendable_rule_cache_ = unsafe { nil }
	extension := scope.extension_sheets(saved) or {
		if rule_cache_extension_diagnostics {
			eprintln('VOX_RULE_CACHE_EXTENSION rejected author_sheets=${saved.author_sheets.len}')
		}
		return false
	}
	sheets := extension.all
	appended := extension.appended
	previous := saved.cache
	scope.rule_cache_font_policy_ = saved.font_policy
	scope.qualified_layer_names_in_order = previous.qualified_layer_names_in_order.clone()
	scope.selector_insights = previous.selector_insights
	scope.pseudo_class_rule_cache = previous.pseudo_class_rule_cache.clone()
	scope.style_invalidation_data = previous.style_invalidation_data
	scope.author_rule_cache = previous.author_rule_cache
	scope.user_rule_cache = previous.user_rule_cache
	scope.user_agent_rule_cache = previous.user_agent_rule_cache
	scope.has_size_container_queries = previous.has_size_container_queries
	scope.build_user_style_sheet_if_needed()
	scope.cache_rules_of_sheets(.author, previous.selector_insights, appended, uint(extension.first))
	mut cache := &StyleCache{
		function_rules_by_name:         previous.function_rules_by_name.clone()
		qualified_layer_names_in_order: previous.qualified_layer_names_in_order.clone()
		selector_insights:              previous.selector_insights
		pseudo_class_rule_cache:        scope.pseudo_class_rule_cache.clone()
		style_invalidation_data:        previous.style_invalidation_data
		author_rule_cache:              previous.author_rule_cache
		user_rule_cache:                previous.user_rule_cache
		user_agent_rule_cache:          previous.user_agent_rule_cache
		has_size_container_queries:     scope.has_size_container_queries
	}
	for sheet in appended {
		context := CachedFunctionRuleContext{cache: cache, origin: .author}
		sheet.for_each_effective_rule_with_context(.preorder, voidptr(&context), cache_function_rule)
	}
	scope.rule_cache = cache
	scope.rule_cache_author_sheets_ = sheets
	rule_cache_extensions++
	if rule_cache_extension_diagnostics {
		eprintln('VOX_RULE_CACHE_EXTENSION extended author_sheets=${saved.author_sheets.len}->${sheets.len}')
	}
	return true
}
