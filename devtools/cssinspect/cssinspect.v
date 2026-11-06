// Package cssinspect reads and edits the styles an element's Styles and
// Computed tabs show. It keeps the engine's CSS module out of devtools/.
module cssinspect

import css
import devtools
import dom

// snapshot lists the inline style and the rules matching `element`, highest
// cascade precedence first. Resolved values are read only with `computed`,
// and only when the caller knows layout is current: reading them must not
// run layout behind the browser's back.
pub fn snapshot(element &dom.Element, computed bool) devtools.StyleSnapshot {
	node := element.as_node()
	mut result := devtools.StyleSnapshot{
		node: devtools.node_id(node)
	}
	result.rules << devtools.StyleRule{
		selector:     'element.style'
		origin:       .inline
		declarations: devtools.parse_declarations(element.get_attribute('style') or { '' })
	}
	abstract := dom.AbstractElement.new(element, none)
	computer := css.css_style_computer_for(node.document())
	scope := css.style_scope_for_abstract_element(abstract)
	mut attempted := css.PseudoClassBitmap{}
	mut matched_pseudo_element := false
	set := computer.build_matching_rule_set(abstract, mut attempted, &matched_pseudo_element,
		.normal, scope)
	mut seen := map[voidptr]bool{}
	// Unlayered author rules follow the layers in precedence.
	for index := set.author_rules.len - 1; index >= 0; index-- {
		append_rules(mut result.rules, set.author_rules[index].rules, .author, mut seen)
	}
	append_rules(mut result.rules, set.user_rules, .user, mut seen)
	append_rules(mut result.rules, set.user_agent_rules, .user_agent, mut seen)
	devtools.mark_overridden(mut result.rules)
	if computed {
		result.computed, result.box = resolved_values(abstract)
	}
	return result
}

// Matched lists are in ascending precedence; the panel shows them descending.
fn append_rules(mut rules []devtools.StyleRule, matched []css.ScopedMatchingRule, origin devtools.StyleOrigin, mut seen map[voidptr]bool) {
	for index := matched.len - 1; index >= 0; index-- {
		matching := matched[index].rule
		if matching == unsafe { nil } || matching.contains_pseudo_element {
			continue
		}
		rule := matching.rule or { continue }
		if seen[voidptr(rule)] {
			continue
		}
		seen[voidptr(rule)] = true
		style := rule.style() or { continue }
		rules << devtools.StyleRule{
			selector:     rule.selector_text()
			source:       source_label(matching, origin)
			origin:       origin
			handle:       voidptr(rule)
			declarations: devtools.parse_declarations(style.css_text())
		}
	}
}

fn source_label(matching &css.MatchingRule, origin devtools.StyleOrigin) string {
	match origin {
		.user_agent { return 'user agent stylesheet' }
		.user { return 'user stylesheet' }
		else {}
	}
	sheet := matching.sheet or { return '<style>' }
	if owner := sheet.base.owner_node() {
		if owner.local_name() == 'style' {
			return '<style>'
		}
	}
	href := sheet.href() or { return '<style>' }
	if href == '' {
		return '<style>'
	}
	name := href.all_before('?').all_before('#').all_after_last('/')
	return if name == '' { href } else { name }
}

fn resolved_values(abstract dom.AbstractElement) ([]devtools.ComputedProperty, ?devtools.BoxModel) {
	resolved := css.CSSStyleProperties.create_resolved_style(abstract)
	mut values := map[string]string{}
	mut names := []string{}
	// length() counts only declared properties; resolved styles expose every longhand.
	for index in 0 .. css.number_of_longhand_properties {
		name := resolved.item(uint(index))
		if name == '' || name in values {
			continue
		}
		values[name] = resolved.get_property_value(name)
		names << name
	}
	// Chrome lists vendor-prefixed properties after the standard ones.
	names.sort_with_compare(fn (a &string, b &string) int {
		a_prefixed, b_prefixed := a.starts_with('-'), b.starts_with('-')
		if a_prefixed != b_prefixed {
			return if a_prefixed { 1 } else { -1 }
		}
		return compare_strings(a, b)
	})
	properties := names.map(devtools.ComputedProperty{
		name:  it
		value: values[it]
	})
	if !abstract.element().as_node().is_connected() || (values['display'] or { '' }) == 'none' {
		return properties, none
	}
	edges := fn [values] (prefix string, suffix string) []f64 {
		return ['top', 'right', 'bottom', 'left'].map(devtools.css_pixels(values['${prefix}-${it}${suffix}'] or {
			''
		}))
	}
	return properties, devtools.BoxModel{
		margin:  edges('margin', '')
		border:  edges('border', '-width')
		padding: edges('padding', '')
		width:   devtools.css_pixels(values['width'] or { '' })
		height:  devtools.css_pixels(values['height'] or { '' })
	}
}

// set_rule_property edits a matched author rule through the CSSOM, which
// invalidates the style of documents using its sheet.
pub fn set_rule_property(handle voidptr, name string, value string) ! {
	if handle == unsafe { nil } {
		return error('The rule cannot be edited')
	}
	rule := unsafe { &css.CSSRule(handle) }
	mut style := rule.style() or { return error('The rule has no declarations') }
	parsed, important := devtools.parse_value(value)
	if parsed == '' {
		style.remove_property(name)!
		return
	}
	style.set_property(name, parsed, if important { 'important' } else { '' })!
}

// query_selector_all lists the elements `selector` matches in `document`;
// text that does not parse as a selector matches nothing.
pub fn query_selector_all(document &dom.Document, selector string) []&dom.Node {
	return css.query_selector_all(unsafe { &dom.Node(document) }, selector).map(it.as_node())
}
