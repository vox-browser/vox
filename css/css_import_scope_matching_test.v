module css

import dom

fn attach_import_scope_test_sheet(document &dom.Document, parent_source string, imported_source string) (&CSSStyleSheet, &CSSRule) {
	mut parent_sheet := parse_css_stylesheet_with_parser(parent_source, none)
	parent_sheet.add_owning_document_or_shadow_root(unsafe { &dom.Node(document) })
	mut import_rule := parent_sheet.rules.item(0) or { panic('missing import rule') }
	mut imported_sheet := parse_css_stylesheet_with_parser(imported_source, none)
	import_rule.set_style_sheet(imported_sheet)
	holder := css_author_style_sheets_for(document)
	unsafe {
		holder.sheets << parent_sheet
	}
	mut scope := css_style_scope_for_document(document)
	scope.invalidate_rule_cache()
	return parent_sheet, import_rule
}

fn import_scope_test_element(document &dom.Document, class_name string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	element.set_attribute_value('class', class_name)
	return element
}

fn import_scope_test_color(document &dom.Document, element &dom.Element) string {
	computed := css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	return (computed.property(.color, .no) or { panic('computed color missing') }).css_text
}

fn test_imported_rules_obey_import_scope_root_and_limit() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut html := import_scope_test_element(document, '')
	mut outer := import_scope_test_element(document, 'outer')
	inside := import_scope_test_element(document, 'target')
	mut limit := import_scope_test_element(document, 'limit')
	inside_limit := import_scope_test_element(document, 'target')
	outside := import_scope_test_element(document, 'target')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html.as_node()) or { panic(err) }
	mut html_node := html.as_node()
	html_node.append_child(outer.as_node()) or { panic(err) }
	mut outer_node := outer.as_node()
	outer_node.append_child(inside.as_node()) or { panic(err) }
	outer_node.append_child(limit.as_node()) or { panic(err) }
	mut limit_node := limit.as_node()
	limit_node.append_child(inside_limit.as_node()) or { panic(err) }
	html_node.append_child(outside.as_node()) or { panic(err) }
	attach_import_scope_test_sheet(document, '@import url(imported.css) scope((.outer) to (.limit)); .target { color: blue }', '.target { color: red }')

	assert import_scope_test_color(document, inside) == 'rgb(255, 0, 0)'
	assert import_scope_test_color(document, inside_limit) == 'rgb(0, 0, 255)'
	assert import_scope_test_color(document, outside) == 'rgb(0, 0, 255)'
}

fn test_unscoped_nested_import_inherits_outer_import_scope() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut html := import_scope_test_element(document, '')
	mut outer := import_scope_test_element(document, 'outer')
	inside := import_scope_test_element(document, 'target')
	outside := import_scope_test_element(document, 'target')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html.as_node()) or { panic(err) }
	mut html_node := html.as_node()
	html_node.append_child(outer.as_node()) or { panic(err) }
	mut outer_node := outer.as_node()
	outer_node.append_child(inside.as_node()) or { panic(err) }
	html_node.append_child(outside.as_node()) or { panic(err) }
	parent_sheet, _ := attach_import_scope_test_sheet(document, '@import url(middle.css) scope(.outer); .target { color: blue }', '@import url(inner.css);')
	outer_import := parent_sheet.rules.item(0) or { panic('missing outer import') }
	mut middle_sheet := outer_import.loaded_style_sheet_for_bindings() or { panic('missing middle sheet') }
	mut inner_import := middle_sheet.rules.item(0) or { panic('missing inner import') }
	inner_sheet := parse_css_stylesheet_with_parser('.target { color: red }', none)
	inner_import.set_style_sheet(inner_sheet)
	mut scope := css_style_scope_for_document(document)
	scope.invalidate_rule_cache()

	assert import_scope_test_color(document, inside) == 'rgb(255, 0, 0)'
	assert import_scope_test_color(document, outside) == 'rgb(0, 0, 255)'
}
