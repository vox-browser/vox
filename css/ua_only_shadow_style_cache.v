module css

import dom

// Empty shadow scopes share the same immutable UA selector/invalidation input.
// Keep only one entry per owning document, while adopters retain their input
// snapshot until their normal cache invalidation. Counter styles and pending
// per-scope invalidations stay on each StyleScope.
struct UserAgentOnlyShadowSheetInput {
	sheet         &CSSStyleSheet
	revision      u64
	media_matches bool
}

struct UserAgentOnlyShadowImportInput {
	rule         &CSSRule
	loaded_sheet voidptr
}

struct UserAgentOnlyShadowConditionInput {
	rule    &CSSRule
	matches bool
}

@[heap]
struct UserAgentOnlyShadowStyleCache {
	document            &dom.Document
	sheets              []UserAgentOnlyShadowSheetInput
	imports             []UserAgentOnlyShadowImportInput
	conditions          []UserAgentOnlyShadowConditionInput
	effective_rules     []&CSSRule
	environment_version u64
	viewport_width      f64
	viewport_height     f64
	color_scheme        string
	scripting_enabled   bool
	device_scale        f64
	cache               &StyleCache
}

fn (entry &UserAgentOnlyShadowStyleCache) environment_matches(scope &StyleScope) bool {
	node := scope.node or { return false }
	if node.as_shadow_root() == none { return false }
	document := node.document()
	if voidptr(document) != voidptr(entry.document) || document.in_quirks_mode()
		|| document.style_environment_version() != entry.environment_version {
		return false
	}
	viewport := document.viewport_rect()
	if viewport.width != entry.viewport_width || viewport.height != entry.viewport_height
		|| document.preferred_color_scheme() != entry.color_scheme
		|| document.device_pixels_per_css_pixel() != entry.device_scale
		|| unsafe { &dom.Node(document) }.is_scripting_enabled() != entry.scripting_enabled {
		return false
	}
	for input in entry.sheets {
		if input.sheet.shared_style_cache_revision_ != input.revision
			|| input.sheet.base.media.matches() != input.media_matches {
			return false
		}
	}
	for input in entry.imports {
		mut current := voidptr(0)
		if loaded := input.rule.loaded_style_sheet { current = voidptr(loaded) }
		if current != input.loaded_sheet { return false }
	}
	for input in entry.conditions {
		if input.rule.condition_matches() != input.matches { return false }
	}
	return true
}

fn same_effective_user_agent_rules(left []&CSSRule, right []&CSSRule) bool {
	if left.len != right.len { return false }
	for index, rule in left { if voidptr(rule) != voidptr(right[index]) { return false } }
	return true
}

fn collect_user_agent_sheet_inputs(sheet &CSSStyleSheet, mut sheets []UserAgentOnlyShadowSheetInput, mut imports []UserAgentOnlyShadowImportInput) {
	for input in sheets { if voidptr(input.sheet) == voidptr(sheet) { return } }
	sheets << UserAgentOnlyShadowSheetInput{ sheet: sheet, revision: sheet.shared_style_cache_revision_, media_matches: sheet.base.media.matches() }
	for rule in sheet.import_rules {
		mut loaded_pointer := voidptr(0)
		if loaded := rule.loaded_style_sheet { loaded_pointer = voidptr(loaded) }
		imports << UserAgentOnlyShadowImportInput{ rule: rule, loaded_sheet: loaded_pointer }
		if loaded := rule.loaded_style_sheet {
			collect_user_agent_sheet_inputs(loaded, mut sheets, mut imports)
		}
	}
}

fn effective_user_agent_rules(sheets []&CSSStyleSheet) []&CSSRule {
	mut result := []&CSSRule{}
	result_ptr := &result
	for sheet in sheets {
		sheet.for_each_effective_rule(.preorder, fn [result_ptr] (rule &CSSRule) {
			unsafe {
				mut rules := *result_ptr
				rules << rule
				*result_ptr = rules
			}
		})
	}
	return result
}

fn (mut scope StyleScope) shared_user_agent_only_shadow_style_cache() ?&StyleCache {
	node := scope.node or { return none }
	if node.as_shadow_root() == none { return none }
	document := node.document()
	if document.in_quirks_mode() { return none }
	if scope.stylesheets_for_cascade_origin(.author).len != 0
		|| scope.stylesheets_for_cascade_origin(.user).len != 0 {
		return none
	}
	sheets := scope.stylesheets_for_cascade_origin(.user_agent)
	// Documents using Chromium's rendering policy add its form-control font
	// sheet; without it here every UA shadow root built its own UA rule cache.
	chromium := document.font_rendering_policy() == .chromium
	if sheets.len != if chromium { 4 } else { 3 } { return none }
	expected := [user_agent_default_stylesheet, user_agent_mathml_stylesheet,
		user_agent_svg_stylesheet]!
	for index in 0 .. 3 { if voidptr(sheets[index]) != voidptr(expected[index]) { return none } }
	if chromium && voidptr(sheets[3]) != voidptr(chromium_control_font_style_sheet()) { return none }
	rules := effective_user_agent_rules(sheets)
	mut document_scope := css_style_scope_for_document(document)
	previous := document_scope.user_agent_only_shadow_cache_
	if previous != unsafe { nil } && previous.environment_matches(scope)
		&& same_effective_user_agent_rules(previous.effective_rules, rules) {
		scope.adopted_user_agent_only_shadow_cache_ = previous
		return previous.cache
	}
	viewport := document.viewport_rect()
	mut sheet_inputs := []UserAgentOnlyShadowSheetInput{}
	mut import_inputs := []UserAgentOnlyShadowImportInput{}
	for sheet in sheets {
		collect_user_agent_sheet_inputs(sheet, mut sheet_inputs, mut import_inputs)
	}
	mut conditions := []UserAgentOnlyShadowConditionInput{}
	for rule in rules {
		if rule.type_ in [.media, .supports] {
			conditions << UserAgentOnlyShadowConditionInput{ rule: rule, matches: rule.condition_matches() }
		}
	}
	environment_version := document.style_environment_version()
	color_scheme := document.preferred_color_scheme()
	scripting_enabled := unsafe { &dom.Node(document) }.is_scripting_enabled()
	device_scale := document.device_pixels_per_css_pixel()
	cache := scope.populate_new_rule_cache()
	entry := &UserAgentOnlyShadowStyleCache{
		document:            document
		sheets:              sheet_inputs
		imports:             import_inputs
		conditions:          conditions
		effective_rules:     rules
		environment_version: environment_version
		viewport_width:      viewport.width
		viewport_height:     viewport.height
		color_scheme:        color_scheme
		scripting_enabled:   scripting_enabled
		device_scale:        device_scale
		cache:               cache
	}
	document_scope.user_agent_only_shadow_cache_ = entry
	scope.adopted_user_agent_only_shadow_cache_ = entry
	return cache
}
