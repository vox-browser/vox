module css

import dom

fn selector_font_sync_fixture(source string) (&dom.Document, &CSSStyleSheet) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_navigable(&dom.Navigable{active_document_: document})
	document.set_viewport_rect(dom.Rect{width:800,height:600})
	mut style := document.create_element_ns('http://www.w3.org/1999/xhtml', 'style') or { panic(err) }
	mut root := document.as_node()
	root.append_child(style.as_node()) or { panic(err) }
	mut sheet := parse_css_stylesheet_with_parser(source, none)
	sheet.set_owner_node(style)
	sheet.add_owning_document_or_shadow_root(root)
	holder := css_author_style_sheets_for(document)
	unsafe { holder.sheets << sheet }
	sheet.evaluate_media_queries(document)
	sheet.load_fonts_for_document(document)
	return document, sheet
}

fn test_selector_edits_preserve_connected_faces_and_feature_values() {
	document, mut sheet := selector_font_sync_fixture('@font-face {font-family:Stable;src:url(stable.woff2)}
		@font-feature-values Stable { @styleset { display: 3; } }')
	defer { document.finalize() }
	computer := css_style_computer_for(document).font_computer()
	set := css_style_computer_for(document).font_face_set_
	face := set.set_entries()[0]
	assert computer.font_feature_values_rules.len == 1
	generation := computer.environment_generation()
	for text in ['.target {color:red}', '@media all {.target {color:blue}}',
		'@supports (display:block) {@media not all {.target {color:green}}}'] {
		index := u32(sheet.css_rules().length())
		assert sheet.insert_rule(text, index)! == index
		assert set.set_entries().len == 1
		assert voidptr(set.set_entries()[0]) == voidptr(face)
		assert computer.font_feature_values_rules.len == 1
		sheet.delete_rule(index)!
		assert face.is_css_connected()
		assert set.set_entries().len == 1
	}
	if retain_selector_rule_font_sync {
		assert computer.environment_generation() > generation
	} else {
		assert computer.environment_generation() == generation
	}
}

fn test_inline_font_registration_and_removal_still_synchronize() {
	document, mut sheet := selector_font_sync_fixture('')
	defer { document.finalize() }
	set := css_style_computer_for(document).font_face_set_
	sheet.insert_rule('@media all {@font-face {font-family:Dynamic;src:url(dynamic.woff2)}}', 0)!
	group := sheet.css_rules().item(0) or { panic('missing group') }
	font_wrapper := (group.css_rules() or { panic('missing children') }).item(0) or { panic('missing font') }
	font_rule := font_wrapper.font_face_rule_ref() or { panic('missing font rule') }
	face := font_rule.css_connected_font_face_ref() or { panic('font not connected') }
	assert set.set_entries().len == 1
	assert voidptr(set.set_entries()[0]) == voidptr(face)
	sheet.delete_rule(0)!
	assert !face.is_css_connected()
	assert set.set_entries().len == 0
}

fn test_selector_deletion_still_refreshes_existing_media_font_registrations() {
	document, mut sheet := selector_font_sync_fixture('@media (min-width:500px) {
		@font-face {font-family:Conditional;src:url(conditional.woff2)}} .target {color:red}')
	defer { document.finalize() }
	mut owner := unsafe { &dom.Document(document) }
	owner.set_viewport_rect(dom.Rect{width:800,height:600})
	sheet.evaluate_media_queries(document)
	sheet.load_fonts_for_document(document)
	set := css_style_computer_for(document).font_face_set_
	assert set.set_entries().len == 1
	face := set.set_entries()[0]
	owner.set_viewport_rect(dom.Rect{width:300,height:600})
	sheet.delete_rule(1)!
	assert set.set_entries().len == 0
	assert !face.is_css_connected()
}

fn test_failed_selector_edit_preserves_font_registration() {
	document, mut sheet := selector_font_sync_fixture('@font-face {font-family:Stable;src:url(stable.woff2)}')
	defer { document.finalize() }
	set := css_style_computer_for(document).font_face_set_
	face := set.set_entries()[0]
	sheet.delete_rule(10) or {
		assert err.msg().starts_with('IndexSizeError')
		assert set.set_entries().len == 1
		assert voidptr(set.set_entries()[0]) == voidptr(face)
		assert face.is_css_connected()
		return
	}
	assert false
}
