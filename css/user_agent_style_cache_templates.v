module css

import platform

// UA-only documents and shadow roots use the same read-only selector indexes.
// Keep bounded process templates over process-owned sheets, and give every
// document its own StyleCache wrapper and environment/adoption bookkeeping.
struct UserAgentStyleCacheTemplate {
	sheets []UserAgentOnlyShadowSheetInput
	rules  []&CSSRule
	cache  &StyleCache
}

const user_agent_style_cache_template_limit = 8

__global (
	user_agent_style_cache_templates_         []UserAgentStyleCacheTemplate
	user_agent_style_cache_template_building_ bool
)

fn user_agent_template_inputs_match(first []UserAgentOnlyShadowSheetInput,
	second []UserAgentOnlyShadowSheetInput) bool {
	if first.len != second.len { return false }
	for index, input in first {
		other := second[index]
		if voidptr(input.sheet) != voidptr(other.sheet) || input.revision != other.revision
			|| input.media_matches != other.media_matches {
			return false
		}
	}
	return true
}

fn user_agent_template_inputs_are_current(inputs []UserAgentOnlyShadowSheetInput) bool {
	for input in inputs {
		if input.sheet.shared_style_cache_revision_ != input.revision
			|| input.sheet.base.media.matches() != input.media_matches {
			return false
		}
	}
	return true
}

fn (mut scope StyleScope) adopt_user_agent_style_template(payload &StyleCache) &StyleCache {
	// The inner graphs are immutable after publication; the wrapper remains
	// distinct for this document and for each environment refresh.
	cache := &StyleCache{ ...payload }
	scope.adopt_style_cache(cache)
	return cache
}

fn (mut scope StyleScope) user_agent_style_cache_template(inputs []UserAgentOnlyShadowSheetInput,
	rules []&CSSRule) ?&StyleCache {
	// Worker style computers keep their ordinary path. No lock may surround a
	// build which can yield to a native/cooperative callback on the UI thread.
	if !platform.arena_thread_is_current() { return none }
	for input in inputs { if !input.sheet.process_lifetime { return none } }
	for entry in user_agent_style_cache_templates_ {
		if user_agent_template_inputs_match(entry.sheets, inputs)
			&& same_effective_user_agent_rules(entry.rules, rules) {
			return scope.adopt_user_agent_style_template(entry.cache)
		}
	}
	if user_agent_style_cache_templates_.len >= user_agent_style_cache_template_limit
		|| user_agent_style_cache_template_building_ {
		return none
	}
	user_agent_style_cache_template_building_ = true
	defer { user_agent_style_cache_template_building_ = false }
	persistent := platform.enter_persistent()
	payload := scope.populate_new_rule_cache()
	// A callback may have changed UA input while lazy declarations parsed.
	// Only publish a template after rechecking both revisions and rule order.
	if user_agent_template_inputs_are_current(inputs)
		&& same_effective_user_agent_rules(rules, effective_user_agent_rules(scope.stylesheets_for_cascade_origin(.user_agent))) {
		user_agent_style_cache_templates_ << UserAgentStyleCacheTemplate{
			sheets: inputs.clone()
			rules:  rules.clone()
			cache:  payload
		}
	}
	platform.leave_persistent(persistent)
	return scope.adopt_user_agent_style_template(payload)
}
