module dump

import css
import dom
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
	selector_value := css.Selector{
		text: 'div > .item'
	}
	rule_list := css.CSSRuleList.create_empty()
	rule_value := css.CSSRule.create_style(css.SelectorList{ selectors: [
		selector_value,
	] }, properties, rule_list)
	sheet_value := css.CSSStyleSheet.create(css.CSSRuleList.create([rule_value]),
		css.MediaList.create_empty(), none)
	assert selector(selector_value, 0).contains('ImmediateChild')
	assert style_properties(properties, 0).contains("color: 'red' !important")
	assert rule(rule_value, 0).contains('CSSStyleRule')
	assert sheet(sheet_value, 0).contains('1 rule(s)')
}
