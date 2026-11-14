module css

import dom
import os

struct AttributeValueFixture {
mut:
	document &dom.Document
	scope    &dom.Element
	middle   &dom.Element
	target   &dom.Element
	sibling  &dom.Element
}

// html > section.scope > (div.mid > span.inner-1.target) + p.sibling
fn attribute_value_fixture(source string) AttributeValueFixture {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns(dom.namespace_html_uri, 'html') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(root.as_node()) or { panic(err) }
	mut scope := document.create_element_ns(dom.namespace_html_uri, 'section') or { panic(err) }
	scope.set_attribute_value('class', 'scope')
	mut root_node := root.as_node()
	root_node.append_child(scope.as_node()) or { panic(err) }
	mut middle := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	middle.set_attribute_value('class', 'mid')
	mut scope_node := scope.as_node()
	scope_node.append_child(middle.as_node()) or { panic(err) }
	mut target := document.create_element_ns(dom.namespace_html_uri, 'span') or { panic(err) }
	target.set_attribute_value('class', 'inner-1 target')
	mut middle_node := middle.as_node()
	middle_node.append_child(target.as_node()) or { panic(err) }
	mut sibling := document.create_element_ns(dom.namespace_html_uri, 'p') or { panic(err) }
	sibling.set_attribute_value('class', 'sibling')
	scope_node.append_child(sibling.as_node()) or { panic(err) }
	add_document_author_style_sheet(document, '.target,.sibling{color:blue}' + source)
	css_style_computer_for(document)
	document.update_style()
	return AttributeValueFixture{document, scope, middle, target, sibling}
}

fn attribute_value_color(element &dom.Element) string {
	style := computed_properties_for_element(element) or { panic('missing style') }
	return (style.property(.color, .no) or { panic('missing color') }).css_text
}

// The colors after the pending invalidations, checked against a complete
// style pass over the same tree.
fn (mut fixture AttributeValueFixture) colors(label string) string {
	fixture.document.update_style()
	incremental := attribute_value_color(fixture.target) + ' ' + attribute_value_color(fixture.sibling)
	fixture.document.set_needs_full_style_update(true)
	fixture.document.update_style()
	complete := attribute_value_color(fixture.target) + ' ' + attribute_value_color(fixture.sibling)
	assert incremental == complete, label
	return incremental
}

const attribute_value_blue = 'rgb(0, 0, 255)'
const attribute_value_red = 'rgb(255, 0, 0)'

// A class change that flips no attribute selector leaves descendants with a
// class attribute alone, although `[class^=…]>[class^=…]` registers them
// under the attribute's name.
fn test_class_changes_that_flip_no_attribute_selector_keep_descendant_styles() {
	mut fixture := attribute_value_fixture('[class^=pane-]>[class^=inner-]{color:red}a:not([class]){color:green}')
	defer { fixture.document.finalize() }
	precise := os.getenv('VOX_RETAIN_ATTRIBUTE_NAME_INVALIDATION') == ''
	for value in ['scope loaded', 'scope', 'scope a b c', 'x-pane- scope'] {
		before := computed_properties_for_element(fixture.target) or { panic('missing style') }
		skipped_before, applied_before := attribute_value_invalidation_statistics()
		fixture.scope.set_attribute_value('class', value)
		skipped_after, applied_after := attribute_value_invalidation_statistics()
		fixture.document.update_style()
		after := computed_properties_for_element(fixture.target) or { panic('missing style') }
		if precise {
			assert skipped_after == skipped_before + 1, value
			assert applied_after == applied_before, value
			assert voidptr(before) == voidptr(after), value
		}
		assert fixture.colors(value) == '${attribute_value_blue} ${attribute_value_blue}'
	}
	// The same selectors still invalidate when a value starts to match.
	_, applied_before := attribute_value_invalidation_statistics()
	fixture.middle.set_attribute_value('class', 'pane-2 mid')
	_, applied_after := attribute_value_invalidation_statistics()
	if precise { assert applied_after == applied_before + 1 }
	assert fixture.colors('prefix added') == '${attribute_value_red} ${attribute_value_blue}'
	fixture.middle.set_attribute_value('class', 'mid pane-2')
	assert fixture.colors('prefix moved') == '${attribute_value_blue} ${attribute_value_blue}'
	fixture.middle.set_attribute_value('class', 'pane-3')
	assert fixture.colors('prefix again') == '${attribute_value_red} ${attribute_value_blue}'
	fixture.target.set_attribute_value('class', 'target')
	assert fixture.colors('subject prefix removed') == '${attribute_value_blue} ${attribute_value_blue}'
	fixture.target.set_attribute_value('class', 'inner-9 target')
	assert fixture.colors('subject prefix restored') == '${attribute_value_red} ${attribute_value_blue}'
	fixture.middle.remove_attribute('class')
	assert fixture.colors('attribute removed') == '${attribute_value_blue} ${attribute_value_blue}'
}

struct AttributeValueStep {
	owner string
	name  string
	value string
	// 'remove' removes the attribute.
	red   string
}

// Every match type, through descendant, child, sibling, :not(), :is() and
// :has() positions: each step paints like a complete style pass, and flips
// exactly when its selector does.
fn test_value_tests_follow_every_attribute_match_type() {
	cases := {
		'.scope[class~=on] .target{color:red}':                         [
			AttributeValueStep{'scope', 'class', 'scope on', 'target'},
			AttributeValueStep{'scope', 'class', 'scope only', ''},
			AttributeValueStep{'scope', 'class', 'on scope', 'target'},
			AttributeValueStep{'scope', 'class', 'scope', ''},
		]
		'[class*=wide] .target{color:red}':                             [
			AttributeValueStep{'middle', 'class', 'mid', ''},
			AttributeValueStep{'middle', 'class', 'mid x-wide-y', 'target'},
			AttributeValueStep{'middle', 'class', 'mid x-wide-z', 'target'},
			AttributeValueStep{'middle', 'class', 'mid narrow', ''},
		]
		'[class$=-open]+.sibling{color:red}':                           [
			AttributeValueStep{'middle', 'class', 'mid is-open', 'sibling'},
			AttributeValueStep{'middle', 'class', 'mid is-open ', ''},
			AttributeValueStep{'middle', 'class', 'is-open', 'sibling'},
			AttributeValueStep{'middle', 'class', 'remove', ''},
		]
		'.scope:has(>[class|=tab]) .sibling{color:red}':                [
			AttributeValueStep{'middle', 'class', 'tab', 'sibling'},
			AttributeValueStep{'middle', 'class', 'tab-2 mid', 'sibling'},
			AttributeValueStep{'middle', 'class', 'tabs', ''},
			AttributeValueStep{'middle', 'class', 'mid tab', ''},
		]
		'.scope :not([class="mid"])>.target{color:red}':                [
			AttributeValueStep{'middle', 'class', 'mid ', 'target'},
			AttributeValueStep{'middle', 'class', 'mid', ''},
			AttributeValueStep{'middle', 'class', 'remove', 'target'},
			AttributeValueStep{'middle', 'class', 'mid', ''},
		]
		':is([data-mode|=dark],[data-mode=night i]) .target{color:red}': [
			AttributeValueStep{'scope', 'data-mode', 'light', ''},
			AttributeValueStep{'scope', 'data-mode', 'dark-dimmed', 'target'},
			AttributeValueStep{'scope', 'data-mode', 'NIGHT', 'target'},
			AttributeValueStep{'scope', 'data-mode', 'nightly', ''},
			AttributeValueStep{'scope', 'data-mode', 'dark', 'target'},
			AttributeValueStep{'scope', 'data-mode', 'remove', ''},
		]
		'[aria-label]~.sibling{color:red}':                             [
			AttributeValueStep{'middle', 'aria-label', '', 'sibling'},
			AttributeValueStep{'middle', 'aria-label', 'name', 'sibling'},
			AttributeValueStep{'middle', 'aria-label', 'remove', ''},
			AttributeValueStep{'middle', 'aria-label', 'again', 'sibling'},
		]
		'.target[data-state=open]{color:red}':                          [
			AttributeValueStep{'target', 'data-state', 'open', 'target'},
			AttributeValueStep{'target', 'data-state', 'opening', ''},
			AttributeValueStep{'target', 'data-state', 'open', 'target'},
			AttributeValueStep{'target', 'data-state', 'closed', ''},
		]
	}
	for rule, steps in cases {
		mut fixture := attribute_value_fixture(rule)
		defer { fixture.document.finalize() }
		for step in steps {
			mut owner := match step.owner {
				'scope' { fixture.scope }
				'middle' { fixture.middle }
				else { fixture.target }
			}
			if step.value == 'remove' {
				owner.remove_attribute(step.name)
			} else {
				owner.set_attribute_value(step.name, step.value)
			}
			target := if step.red == 'target' { attribute_value_red } else { attribute_value_blue }
			sibling := if step.red == 'sibling' { attribute_value_red } else { attribute_value_blue }
			assert fixture.colors('${rule} ${step.value}') == '${target} ${sibling}', '${rule} ${step.value}'
		}
	}
}

// Data and ARIA values that flip no selector invalidate nothing; attr()
// still follows the element's own attribute.
fn test_metadata_values_that_flip_no_selector_are_skipped() {
	mut fixture := attribute_value_fixture('[data-mode=dark] [class^=inner-]{color:red}.sibling{color:attr(data-mode type(<color>), blue)}')
	defer { fixture.document.finalize() }
	precise := os.getenv('VOX_RETAIN_ATTRIBUTE_NAME_INVALIDATION') == ''
	for value in ['light', 'dim', 'darker'] {
		skipped_before, _ := attribute_value_invalidation_statistics()
		fixture.scope.set_attribute_value('data-mode', value)
		skipped_after, _ := attribute_value_invalidation_statistics()
		if precise { assert skipped_after == skipped_before + 1, value }
		assert fixture.colors(value) == '${attribute_value_blue} ${attribute_value_blue}'
	}
	fixture.scope.set_attribute_value('data-mode', 'dark')
	assert fixture.colors('dark') == '${attribute_value_red} ${attribute_value_blue}'
	fixture.sibling.set_attribute_value('data-mode', 'red')
	assert fixture.colors('attr') == '${attribute_value_red} ${attribute_value_red}'
	fixture.sibling.set_attribute_value('data-mode', 'green')
	assert fixture.colors('attr again') == '${attribute_value_red} rgb(0, 128, 0)'
}

// Other attributes, foreign elements and names with more distinct tests than
// the limit keep the plan registered for the attribute's name.
fn test_other_attributes_and_long_test_lists_keep_name_invalidation() {
	mut rules := '[title=x] .target{color:red}'
	for index in 0 .. attribute_value_test_limit + 4 {
		rules += '[data-key="k${index}"] .target{color:red}'
	}
	mut fixture := attribute_value_fixture(rules)
	defer { fixture.document.finalize() }
	skipped_before, applied_before := attribute_value_invalidation_statistics()
	fixture.scope.set_attribute_value('title', 'y')
	assert fixture.colors('title y') == '${attribute_value_blue} ${attribute_value_blue}'
	fixture.scope.set_attribute_value('title', 'x')
	assert fixture.colors('title x') == '${attribute_value_red} ${attribute_value_blue}'
	fixture.scope.remove_attribute('title')
	skipped_middle, applied_middle := attribute_value_invalidation_statistics()
	assert skipped_middle == skipped_before && applied_middle == applied_before
	fixture.scope.set_attribute_value('data-key', 'none')
	assert fixture.colors('key none') == '${attribute_value_blue} ${attribute_value_blue}'
	fixture.scope.set_attribute_value('data-key', 'k${attribute_value_test_limit + 2}')
	assert fixture.colors('key last') == '${attribute_value_red} ${attribute_value_blue}'
	skipped_after, applied_after := attribute_value_invalidation_statistics()
	if os.getenv('VOX_RETAIN_ATTRIBUTE_NAME_INVALIDATION') == '' {
		assert skipped_after == skipped_middle
		assert applied_after == applied_middle + 2
	}
}

fn test_value_tests_are_collected_once_per_distinct_selector() {
	mut insights := SelectorInsights{}
	for source in ['[class^=a] [class^=a]', ':not([class^=a]):is([class^="a"],[class^=b])',
		'[CLASS^=a]', '::slotted([class~=c])'] {
		selectors := parse_selector_with_parser(source, map[string]bool{}) or { panic(source) }
		for selector in selectors.selectors {
			StyleScope.collect_selector_insights(selector, mut insights)
		}
	}
	tests := insights.attribute_value_tests['class'] or { panic('missing class tests') }
	assert !tests.imprecise
	// `a` in two name spellings, `b` and the slotted word.
	assert tests.tests.len == 4
	assert insights.attribute_value_tests.len == 1
}
