module dump

import css
import dom
import html
import layout

fn test_dump_dom_tree() {
	document := dom.Document.create(dom.url_about_blank())
	mut root := document.create_element('div') or { panic(err) }
	root.set_attribute_value('id', 'root')
	mut root_node := root.as_node()
	root_node.append_child(document.create_text_node('hello').as_node()) or { panic(err) }
	output := dom_tree(root_node)
	assert output.contains('<div id=root>')
	assert output.contains('  "hello"')
}

fn test_dump_dom_tree_labels_shadow_host_pseudo_elements() {
	document := dom.Document.create(dom.url_about_blank())
	mut host := document.create_element('textarea') or { panic(err) }
	shadow_root := host.attach_a_user_agent_shadow_root(.named)
	mut placeholder := document.create_element('div') or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.append_child(placeholder.as_node()) or { panic(err) }
	placeholder.set_associated_shadow_host_pseudo_element(int(css.PseudoElement.placeholder))
	output := dom_tree(host.as_node())
	assert output.contains('    (pseudo-element: placeholder)\n')
}

fn test_dump_navigation_tree_uses_navigation_entries_and_scroll_positions() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	document.set_origin(document.url.origin())
	document.populate_with_html_head_and_body() or { panic(err) }
	window := html.WindowModel.create_top_level(document, none, 'top') or { panic(err) }
	navigable := html.NavigableModel.navigable_with_active_document(document) or {
		panic('missing navigable')
	}
	mut entry := navigable.active_session_history_entry() or { panic('missing history entry') }
	entry.set_step(7)
	entry.set_scroll_position_data(html.SessionHistoryEntryScrollPositionData{
		viewport_scroll_position: dom.CSSPixelPoint_{ x_: 12.5, y_: 9.25 }
	})
	mut navigation := unsafe { &html.Navigation(window.navigation()) }
	navigation.set_entries_and_events_disabled_override(false)
	navigation.initialize_the_navigation_api_entries_for_a_new_document([entry], entry)
	assert navigation_tree(navigable) == 'step=(7) url=(https://example.test/page) viewport-scroll=(12.5, 9.25)\n'
}

fn test_dump_layout_tree() {
	document := dom.Document.create(dom.url_about_blank())
	root := layout.Node.new(document, none)
	child := layout.Node.new(document, none)
	mut mutable_root := unsafe { &layout.Node(root) }
	mutable_root.append_child(child)
	output := layout_tree(root, false)
	assert output.count('(anonymous)') == 2
	assert output.contains('\n  Node')
}

fn test_dump_css_objects() {
	mut properties := css.CSSStyleProperties.create()
	properties.properties << css.CSSStyleProperty{
		name:      'color'
		value:     'red'
		important: true
	}
	selector_value := css.selector_from_text('div > .item')
	rule_list := css.CSSRuleList.create_empty()
	rule_value := css.CSSRule.create_style(css.SelectorList{
		selectors: [
			selector_value,
		]
	}, properties, rule_list)
	sheet_value := css.CSSStyleSheet.create(css.CSSRuleList.create([rule_value]),
		css.MediaList.create_empty(), none)
	assert selector(selector_value, 0) == 'CSS::Selector: div > .item\n'
	assert serialized_selector(':host > slot', 2) == '    CSS::Selector: :host > slot\n'
	assert style_properties(properties, 0).contains("color: 'red' !important")
	assert rule(rule_value, 0).contains('CSSStyleRule')
	assert sheet(sheet_value, 0).contains('1 rule(s)')
}
