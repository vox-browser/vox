module css

import dom
import os

// Adding a style sheet used to rebuild every rule cache of the document: each
// selector of every author, user and user-agent sheet was indexed and its
// invalidation sets built again. Pages that add sheets after the first style
// pass (GitHub inserts two more among about 7,000 rules) paid that each time.
//
// Every structure the build fills is additive: rule buckets, the pseudo-subject
// index, disjunctive subject masks, invalidation plans and selector insights.
// Matching sorts its candidates by specificity, scope proximity, sheet index
// and rule index, so the position of a rule in a bucket does not matter, only
// the order of the sheet indexes. Complete builds number the author sheets
// with a stride; sheets inserted between kept ones take indexes in the gap.
// Keyframes and function definitions instead depend on processing order, so
// an inserted sheet defining them before a kept sheet with rules keeps the
// complete build. The adding invalidation still clears the scope's caches,
// so readers that consult them without building see none in between, and
// keeps the published cache aside. The next build extends it when the kept
// author sheets are all still present in the same order and no other
// invalidation happened since; otherwise it builds everything again.
const disable_rule_cache_extension = os.getenv('VOX_DISABLE_RULE_CACHE_EXTENSION') != ''
const rule_cache_extension_diagnostics = os.getenv('VOX_RULE_CACHE_EXTENSION_DIAGNOSTICS') != ''

__global rule_cache_extensions u64

// The sheet index distance between consecutive sheets of a complete build.
const rule_cache_sheet_index_stride = uint(4096)

@[heap]
struct ExtendableRuleCache {
	cache         &StyleCache = unsafe { nil }
	author_sheets []&CSSStyleSheet
	sheet_indexes []uint
	font_policy   dom.FontRenderingPolicy
	quirks        bool
	duplicate_groups map[string]&DuplicateSheetGroup
}

fn rule_cache_sheet_is_empty(sheet &CSSStyleSheet) bool {
	return sheet.rules.length() == 0
}

// Starts at one stride, leaving room before the first sheet as well.
fn rule_cache_strided_indexes(count int) []uint {
	return []uint{len: count, init: uint(index + 1) * rule_cache_sheet_index_stride}
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
						extendable = &ExtendableRuleCache{
							cache:         cache
							author_sheets: scope.rule_cache_author_sheets_
							sheet_indexes: scope.rule_cache_author_sheet_indexes_
							font_policy:   scope.rule_cache_font_policy_
							quirks:        document.in_quirks_mode()
							duplicate_groups: scope.rule_cache_duplicate_groups_
						}
					}
				}
			}
		}
	}
	scope.invalidate_rule_cache()
	scope.extendable_rule_cache_ = extendable
}

// What an added sheet contains that the extension must handle. Imported
// sheets load and change on their own schedule; they keep the complete build.
// Layered rules can join: their caches are kept by layer name, and the
// extension orders the names again from every sheet.
struct RuleCacheSheetContents {
mut:
	imports              bool
	order_dependent_defs bool
}

fn rule_cache_scan_rules(rules &CSSRuleList, mut contents RuleCacheSheetContents) {
	for rule in rules.rules {
		if rule.type_ == .import_rule { contents.imports = true }
		if rule.type_ in [.keyframes, .function_rule] { contents.order_dependent_defs = true }
		if children := rule.css_rules() {
			rule_cache_scan_rules(children, mut contents)
		}
	}
}

// The current author sheets with their indexes, and the added ones.
struct RuleCacheExtensionSheets {
	all           []&CSSStyleSheet
	indexes       []uint
	added         []&CSSStyleSheet
	added_indexes []uint
}

fn (scope &StyleScope) extension_sheets(saved &ExtendableRuleCache) !RuleCacheExtensionSheets {
	document := scope.document() or { return error('no document') }
	if saved.font_policy != document.font_rendering_policy() || saved.quirks != document.in_quirks_mode() {
		return error('environment')
	}
	if saved.sheet_indexes.len != saved.author_sheets.len { return error('no indexes') }
	sheets := scope.stylesheets_for_cascade_origin(.author)
	mut indexes := []uint{len: sheets.len}
	mut added := []&CSSStyleSheet{}
	mut added_indexes := []uint{}
	// Every kept sheet must still be there, in order. Each run of added sheets
	// takes evenly spaced indexes between its kept neighbours.
	mut kept := 0
	mut position := 0
	for position < sheets.len {
		if kept < saved.author_sheets.len && voidptr(sheets[position]) == voidptr(saved.author_sheets[kept]) {
			indexes[position] = saved.sheet_indexes[kept]
			kept++
			position++
			continue
		}
		run_start := position
		for position < sheets.len && (kept >= saved.author_sheets.len
			|| voidptr(sheets[position]) != voidptr(saved.author_sheets[kept])) {
			position++
		}
		run := sheets[run_start..position]
		low := if kept > 0 { i64(saved.sheet_indexes[kept - 1]) } else { i64(-1) }
		at_end := kept >= saved.author_sheets.len
		step := if at_end {
			i64(rule_cache_sheet_index_stride)
		} else {
			(i64(saved.sheet_indexes[kept]) - low) / i64(run.len + 1)
		}
		if step < 1 { return error('no index space') }
		mut order_dependent_after := false
		if !at_end {
			for later in saved.author_sheets[kept..] {
				if !rule_cache_sheet_is_empty(later) { order_dependent_after = true; break }
			}
		}
		for offset, sheet in run {
			mut contents := RuleCacheSheetContents{}
			rule_cache_scan_rules(sheet.rules, mut contents)
			if contents.imports { return error('import') }
			if contents.order_dependent_defs && order_dependent_after { return error('keyframes or function') }
			index := low + i64(offset + 1) * step
			if index < 0 || index > i64(max_u32) { return error('no index space') }
			indexes[run_start + offset] = uint(index)
			added << sheet
			added_indexes << uint(index)
		}
	}
	if kept != saved.author_sheets.len { return error('kept sheet missing') }
	return RuleCacheExtensionSheets{
		all:           sheets
		indexes:       indexes
		added:         added
		added_indexes: added_indexes
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
			eprintln('VOX_RULE_CACHE_EXTENSION rejected author_sheets=${saved.author_sheets.len} reason=${err.msg()}')
		}
		return false
	}
	sheets := extension.all
	appended := extension.added
	previous := saved.cache
	scope.rule_cache_font_policy_ = saved.font_policy
	scope.selector_insights = previous.selector_insights
	scope.pseudo_class_rule_cache = previous.pseudo_class_rule_cache.clone()
	scope.style_invalidation_data = previous.style_invalidation_data
	scope.author_rule_cache = previous.author_rule_cache
	scope.user_rule_cache = previous.user_rule_cache
	scope.user_agent_rule_cache = previous.user_agent_rule_cache
	scope.has_size_container_queries = previous.has_size_container_queries
	scope.build_user_style_sheet_if_needed()
	scope.rule_cache_duplicate_groups_ = saved.duplicate_groups
	scope.cache_rules_of_sheets(.author, previous.selector_insights, appended, extension.added_indexes, false)
	scope.build_qualified_layer_names_cache()
	mut cache := &StyleCache{
		function_rules_by_name:         previous.function_rules_by_name.clone()
		qualified_layer_names_in_order: scope.qualified_layer_names_in_order.clone()
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
	scope.rule_cache_author_sheet_indexes_ = extension.indexes
	rule_cache_extensions++
	if rule_cache_extension_diagnostics {
		eprintln('VOX_RULE_CACHE_EXTENSION extended author_sheets=${saved.author_sheets.len}->${sheets.len}')
	}
	return true
}
