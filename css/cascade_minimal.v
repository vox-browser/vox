module css

import dom

// Compact cascade query helpers built on generated property metadata, the typed declaration parser,
// and the property database. The full author/user/UA cascade and style computation live in
// style_computer.v, computed_interpolation.v, and style_scope_cache.v; these helpers intentionally
// expose the smaller rule-list/inline-style calculation used by focused callers and tests.

// https://drafts.csswg.org/css-cascade/#inherited-property — does this longhand inherit by default?
pub fn is_inherited_property(property_id PropertyID) bool {
	return string_from_property_id(property_id) in inherited_properties
}

// The property's initial value, as a source string (from Properties.json), or '' if none.
pub fn property_initial_value_string(property_id PropertyID) string {
	return property_initial_values[string_from_property_id(property_id)] or { '' }
}

// A single longhand value taken from a declaration (directly or via an expanded shorthand).
struct LonghandDeclaration {
	value     string
	important bool
}

// Expand a shorthand's value text into a longhand-name -> value map, using the CSS value-logic
// typed expansion (e.g. 'margin: 1px 2px' -> margin-top/bottom '1px', margin-left/right '2px').
fn expand_shorthand_value(shorthand_id PropertyID, value_text string) map[string]string {
	mut result := map[string]string{}
	typed := parse_css_value_logic(shorthand_id, value_text) or { return result }
	result_ptr := &result
	for_each_typed_property_expanding_shorthands(shorthand_id, typed, fn [result_ptr] (longhand_id PropertyID, longhand_value StyleValue) {
		unsafe {
			mut m := *result_ptr
			m[string_from_property_id(longhand_id)] = longhand_value.to_string()
			*result_ptr = m
		}
	})
	return result
}

// The declaration's value for the longhand `property_name`: a direct declaration if present,
// otherwise a value produced by expanding any shorthand the declaration sets.
// FIXME: source order between a shorthand and an overlapping longhand within one block is not
// tracked (a direct longhand always wins here).
fn declaration_longhand(declaration &CSSStyleProperties, property_name string) ?LonghandDeclaration {
	direct := declaration.get_property_value(property_name)
	if direct.len > 0 {
		return LonghandDeclaration{
			value:     direct
			important: declaration.property_priority(property_name) == 'important'
		}
	}
	for i in 0 .. declaration.length() {
		shorthand_name := declaration.item(usize(i))
		shorthand_id := property_id_from_string(shorthand_name) or { continue }
		if !property_is_shorthand(shorthand_id) {
			continue
		}
		expanded := expand_shorthand_value(shorthand_id,
			declaration.get_property_value(shorthand_name))
		if value := expanded[property_name] {
			return LonghandDeclaration{
				value:     value
				important: declaration.property_priority(shorthand_name) == 'important'
			}
		}
	}
	return none
}

// The element's inline style declaration block, if it has a non-empty style attribute.
fn inline_declaration_block(element &dom.Element) ?&CSSStyleProperties {
	style_text := element.get_attribute('style') or { return none }
	if style_text.len == 0 {
		return none
	}
	return parse_css_property_declaration_block_with_parser(style_text)
}

// The element's declared value for `property_name` from its inline style attribute, if present
// (expanding shorthands).
fn inline_declared_value(element &dom.Element, property_name string) ?string {
	block := inline_declaration_block(element) or { return none }
	longhand := declaration_longhand(block, property_name) or { return none }
	return longhand.value
}

// Resolve the cascaded/specified value of `property_id` for `element`:
//   1. an inline declaration on the element, otherwise
//   2. (if the property inherits) the nearest ancestor's inline declaration for it, otherwise
//   3. the property's initial value.
// This compact helper only accepts inline declarations. Call StyleComputer.compute_style() for the
// complete origin/layer/specificity cascade over active stylesheets.
pub fn cascaded_value_for(element &dom.Element, property_id PropertyID) string {
	name := string_from_property_id(property_id)
	if value := inline_declared_value(element, name) {
		return value
	}
	if is_inherited_property(property_id) {
		mut ancestor := element.as_node().parent_element()
		for {
			current := ancestor or { break }
			if value := inline_declared_value(current, name) {
				return value
			}
			ancestor = current.as_node().parent_element()
		}
	}
	return property_initial_value_string(property_id)
}

// A single declaration competing in the cascade for one property. (CascadeOrigin is the existing
// css enum: user_agent / user / author / transition / animation.)
struct CascadeMatch {
	origin      CascadeOrigin
	important   bool
	specificity u32
	order       int
	value       string
}

// The cascade tier of a declaration (higher wins), per https://drafts.csswg.org/css-cascade/#cascade-sort
// origin+importance order (ignoring user/transition/animation origins): UA !important > author
// !important > author normal > UA normal.
fn (m CascadeMatch) tier() int {
	if m.important {
		return if m.origin == .user_agent { 3 } else { 2 }
	}
	return if m.origin == .author { 1 } else { 0 }
}

// https://drafts.csswg.org/css-cascade/#cascade-sort: origin/importance tier, then specificity,
// then source order.
fn cascade_match_beats(a CascadeMatch, b CascadeMatch) bool {
	if a.tier() != b.tier() {
		return a.tier() > b.tier()
	}
	if a.specificity != b.specificity {
		return a.specificity > b.specificity
	}
	return a.order >= b.order
}

// The specified value of `property_name` on `element`: the winner of the cascade among the inline
// declaration and every matching author rule in `rules`, ordered by !important, then specificity,
// then source order. Shorthands are expanded, so e.g. 'margin: 0' contributes to 'margin-top'.
// (Inline style is given a specificity higher than any selector, per spec.)
// CascadeMatches from every rule in `rules` (with the given `origin`) that matches `element` and
// contributes `property_name`, numbering source order from `start_order`.
fn rule_matches_for(element &dom.Element, property_name string, rules []&CSSRule, origin CascadeOrigin, start_order int) []CascadeMatch {
	mut result := []CascadeMatch{}
	mut order := start_order
	for rule in rules {
		order++
		declaration := rule.style() or { continue }
		longhand := declaration_longhand(declaration, property_name) or { continue }
		// Highest specificity among this rule's selectors that match the element.
		mut rule_mut := rule
		mut best_specificity := ?u32(none)
		for selector in rule_mut.absolutized_selectors().selectors {
			if selector_matches(selector, element) {
				specificity := selector.specificity()
				if current_best := best_specificity {
					if specificity > current_best {
						best_specificity = specificity
					}
				} else {
					best_specificity = specificity
				}
			}
		}
		if specificity := best_specificity {
			result << CascadeMatch{
				origin:      origin
				important:   longhand.important
				specificity: specificity
				order:       order
				value:       longhand.value
			}
		}
	}
	return result
}

fn specified_value_on(element &dom.Element, property_name string, author_rules []&CSSRule, ua_rules []&CSSRule) ?string {
	mut matches := []CascadeMatch{}
	// UA origin first (lowest source order), then author rules.
	matches << rule_matches_for(element, property_name, ua_rules, .user_agent, 0)
	matches << rule_matches_for(element, property_name, author_rules, .author, ua_rules.len)

	// Inline style is an author-origin declaration with a specificity higher than any selector.
	if block := inline_declaration_block(element) {
		if longhand := declaration_longhand(block, property_name) {
			matches << CascadeMatch{
				origin:      .author
				important:   longhand.important
				specificity: u32(0xffffffff)
				order:       0x7fffffff
				value:       longhand.value
			}
		}
	}

	if matches.len == 0 {
		return none
	}
	mut winner := matches[0]
	for match_candidate in matches[1..] {
		if cascade_match_beats(match_candidate, winner) {
			winner = match_candidate
		}
	}
	return winner.value
}

// Resolve `property_id` for `element` given `author_rules` and `ua_rules`: the winning specified
// value (cascade of UA + author + inline), else inheritance, else the initial value. The CSS-wide
// keywords in a specified value are resolved here: `initial`, `inherit`, and `unset` (and `revert`,
// approximated as `unset`).
fn cascaded_value_impl(element &dom.Element, property_id PropertyID, author_rules []&CSSRule, ua_rules []&CSSRule) string {
	name := string_from_property_id(property_id)
	if value := specified_value_on(element, name, author_rules, ua_rules) {
		// Substitute any var() references before interpreting the value.
		resolved := substitute_var(element, value, author_rules, ua_rules)
		return match resolved {
			'initial' {
				property_initial_value_string(property_id)
			}
			'inherit' {
				inherited_value(element, property_id, author_rules, ua_rules)
			}
			'unset', 'revert' {
				// `unset` acts as `inherit` for inherited properties and `initial` otherwise. `revert`
				// is approximated as `unset` here. FIXME: `revert` should roll back to the UA cascade.
				if is_inherited_property(property_id) {
					inherited_value(element, property_id, author_rules, ua_rules)
				} else {
					property_initial_value_string(property_id)
				}
			}
			else {
				resolved
			}
		}
	}
	if is_inherited_property(property_id) {
		return inherited_value(element, property_id, author_rules, ua_rules)
	}
	return property_initial_value_string(property_id)
}

// The declared value of a custom property (`--name`) on `element`, resolved through the cascade and
// inheritance (all custom properties inherit). Returns none when the property is defined nowhere up
// the tree. The value is returned RAW; any var() it contains is substituted by the caller.
fn custom_property_value(element &dom.Element, name string, author_rules []&CSSRule, ua_rules []&CSSRule) ?string {
	if value := specified_value_on(element, name, author_rules, ua_rules) {
		return value
	}
	parent := element.as_node().parent_element() or { return none }
	return custom_property_value(parent, name, author_rules, ua_rules)
}

// Substitute every var(--name[, fallback]) reference in `value` with the custom property's value (or
// its fallback when the property is undefined), for `element`. Substitution re-scans so a custom
// property whose value itself uses var() is resolved. A recursion cap guards against cyclic vars.
// FIXME: an undefined var() with no fallback substitutes to the empty string rather than making the
// whole declaration invalid (which should fall back to the inherited/initial value).
fn substitute_var(element &dom.Element, value string, author_rules []&CSSRule, ua_rules []&CSSRule) string {
	return substitute_var_impl(element, value, author_rules, ua_rules, 0)
}

fn substitute_var_impl(element &dom.Element, value string, author_rules []&CSSRule, ua_rules []&CSSRule, depth int) string {
	if depth > 32 || !value.contains('var(') {
		return value
	}
	start := value.index('var(') or { return value }
	// Find the ')' matching the '(' at start+3.
	mut inner_depth := 0
	mut end := -1
	for i := start + 3; i < value.len; i++ {
		c := value[i]
		if c == `(` {
			inner_depth++
		} else if c == `)` {
			inner_depth--
			if inner_depth == 0 {
				end = i
				break
			}
		}
	}
	if end < 0 {
		return value // malformed var()
	}
	inner := value[start + 4..end]
	parts := split_first_top_level_comma(inner)
	var_name := parts[0].trim_space()
	replacement := custom_property_value(element, var_name, author_rules, ua_rules) or {
		// Undefined: use the fallback (itself possibly containing var()), else the empty string.
		if parts.len > 1 { parts[1].trim_space() } else { '' }
	}
	rebuilt := value[..start] + replacement + value[end + 1..]
	return substitute_var_impl(element, rebuilt, author_rules, ua_rules, depth + 1)
}

// Split `s` at its first top-level comma (commas inside parentheses are ignored), returning either
// [before, after] or [s] when there is no top-level comma.
fn split_first_top_level_comma(s string) []string {
	mut depth := 0
	for i := 0; i < s.len; i++ {
		c := s[i]
		if c == `(` {
			depth++
		} else if c == `)` && depth > 0 {
			depth--
		} else if c == `,` && depth == 0 {
			return [s[..i], s[i + 1..]]
		}
	}
	return [s]
}

// The value `element` inherits for `property_id`: its parent element's fully-resolved cascaded value
// (so keywords declared up the chain are already resolved), or the property's initial value when
// there is no parent element (the root).
fn inherited_value(element &dom.Element, property_id PropertyID, author_rules []&CSSRule, ua_rules []&CSSRule) string {
	parent := element.as_node().parent_element() or {
		return property_initial_value_string(property_id)
	}
	return cascaded_value_impl(parent, property_id, author_rules, ua_rules)
}

// Like cascaded_value_for, but also considers a list of author style `rules` (e.g. from
// parse_css_stylesheet_contents_with_parser): inline > matching author rules > inheritance > initial.
pub fn cascaded_value_with_stylesheet(element &dom.Element, property_id PropertyID, rules []&CSSRule) string {
	return cascaded_value_impl(element, property_id, rules, []&CSSRule{})
}

// The full minimal cascade INCLUDING the user-agent stylesheet as the lowest origin, so unstyled
// elements get their UA defaults (e.g. div -> display: block, head -> display: none). Order:
// UA/author/importance tier -> specificity -> source order, then inheritance, then initial.
pub fn cascaded_value_with_ua(element &dom.Element, property_id PropertyID, author_rules []&CSSRule) string {
	return cascaded_value_impl(element, property_id, author_rules, user_agent_rules())
}

// Whether `property_id` is explicitly declared for `element` by any UA, author, or inline declaration
// (shorthands expanded), as opposed to falling back to inheritance or the initial value. Lets the
// layout decide whether a physical box edge that was never set should defer to its CSS logical
// equivalent (e.g. an unset `margin-top` deferring to a declared `margin-block-start`).
pub fn is_property_specified(element &dom.Element, property_id PropertyID, author_rules []&CSSRule) bool {
	name := string_from_property_id(property_id)
	if _ := specified_value_on(element, name, author_rules, user_agent_rules()) {
		return true
	}
	return false
}
