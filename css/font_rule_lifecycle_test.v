module css

import dom

fn test_inserted_font_face_rule_connects_and_disconnects_with_document_fonts() {
	mut document := dom.Document.create(dom.url_about_blank())
	document_node := unsafe { &dom.Node(document) }
	mut sheet := css_style_sheet_construct(none, document)!
	mut adopted := create_adopted_style_sheets_list(document_node)
	adopted.append(sheet)!
	font_face_set := css_style_computer_for(document).font_face_set_

	sheet.insert_rule('@font-face { font-family: Dynamic; src: url(dynamic.woff2); }', 0)!
	inserted := sheet.css_rules().item(0) or { panic('missing inserted font rule') }
	font_rule := inserted.font_face_rule_ref() or { panic('inserted rule is not @font-face') }
	connected := font_rule.css_connected_font_face_ref() or { panic('inserted font was not connected') }
	assert inserted.parent_style_sheet? == sheet
	assert font_face_set.set_entries().len == 1
	assert font_face_set.set_entries()[0] == connected

	sheet.delete_rule(0)!
	assert font_rule.css_connected_font_face_ref() == none
	assert !connected.is_css_connected()
	assert font_face_set.set_entries().len == 0
}

fn test_nested_font_face_rule_tracks_group_insertion_and_removal() {
	mut document := dom.Document.create(dom.url_about_blank())
	document_node := unsafe { &dom.Node(document) }
	mut sheet := css_style_sheet_construct(none, document)!
	sheet.replace_sync('@media all { }')!
	mut adopted := create_adopted_style_sheets_list(document_node)
	adopted.append(sheet)!
	mut media_rule := sheet.css_rules().item(0) or { panic('missing media rule') }
	font_face_set := css_style_computer_for(document).font_face_set_

	media_rule.insert_rule('@font-face { font-family: Nested; src: url(nested.woff2); }', 0)!
	children := media_rule.rules or { panic('media rule has no child list') }
	inserted := children.item(0) or { panic('missing nested font rule') }
	font_rule := inserted.font_face_rule_ref() or { panic('nested rule is not @font-face') }
	connected := font_rule.css_connected_font_face_ref() or { panic('nested font was not connected') }
	assert inserted.parent_rule? == media_rule
	assert inserted.parent_style_sheet? == sheet
	assert font_face_set.set_entries().len == 1

	media_rule.delete_rule(0)!
	assert font_rule.css_connected_font_face_ref() == none
	assert !connected.is_css_connected()
	assert font_face_set.set_entries().len == 0
}

fn test_style_sheet_replacement_disconnects_old_nested_font_faces() {
	mut document := dom.Document.create(dom.url_about_blank())
	document_node := unsafe { &dom.Node(document) }
	mut sheet := css_style_sheet_construct(none, document)!
	mut adopted := create_adopted_style_sheets_list(document_node)
	adopted.append(sheet)!
	font_face_set := css_style_computer_for(document).font_face_set_

	sheet.replace_sync('@media all { @font-face { font-family: Old; src: url(old.woff2); } }')!
	old_group := sheet.css_rules().item(0) or { panic('missing old media rule') }
	old_children := old_group.rules or { panic('old media rule has no child list') }
	old_wrapper := old_children.item(0) or { panic('missing old font rule') }
	old_rule := old_wrapper.font_face_rule_ref() or { panic('old nested rule is not @font-face') }
	old_face := old_rule.css_connected_font_face_ref() or { panic('old font was not connected') }
	assert font_face_set.set_entries().len == 1

	sheet.replace_sync('@font-face { font-family: New; src: url(new.woff2); }')!
	new_wrapper := sheet.css_rules().item(0) or { panic('missing new font rule') }
	new_rule := new_wrapper.font_face_rule_ref() or { panic('new rule is not @font-face') }
	new_face := new_rule.css_connected_font_face_ref() or { panic('new font was not connected') }
	assert old_rule.css_connected_font_face_ref() == none
	assert !old_face.is_css_connected()
	assert font_face_set.set_entries().len == 1
	assert font_face_set.set_entries()[0] == new_face
}

fn test_ineffective_nested_font_face_stays_disconnected() {
	mut document := dom.Document.create(dom.url_about_blank())
	document_node := unsafe { &dom.Node(document) }
	mut sheet := css_style_sheet_construct(none, document)!
	sheet.replace_sync('@media not all { @font-face { font-family: Hidden; src: url(hidden.woff2); } }')!
	mut adopted := create_adopted_style_sheets_list(document_node)
	adopted.append(sheet)!

	group := sheet.css_rules().item(0) or { panic('missing conditional group') }
	children := group.rules or { panic('conditional group has no children') }
	font_wrapper := children.item(0) or { panic('missing conditional font rule') }
	font_rule := font_wrapper.font_face_rule_ref() or { panic('conditional rule is not @font-face') }
	assert font_rule.css_connected_font_face_ref() == none
	assert css_style_computer_for(document).font_face_set_.set_entries().len == 0
}

fn test_nested_media_mutation_resynchronizes_connected_font_faces() {
	mut document := dom.Document.create(dom.url_about_blank())
	document_node := unsafe { &dom.Node(document) }
	mut sheet := css_style_sheet_construct(none, document)!
	sheet.replace_sync('@media all { @font-face { font-family: Conditional; src: url(conditional.woff2); } }')!
	mut adopted := create_adopted_style_sheets_list(document_node)
	adopted.append(sheet)!
	group := sheet.css_rules().item(0) or { panic('missing media group') }
	children := group.rules or { panic('media group has no children') }
	font_wrapper := children.item(0) or { panic('missing media font rule') }
	font_rule := font_wrapper.font_face_rule_ref() or { panic('media child is not @font-face') }
	first_face := font_rule.css_connected_font_face_ref() or { panic('matching media font was not connected') }
	font_face_set := css_style_computer_for(document).font_face_set_
	assert font_face_set.set_entries().len == 1

	mut media := group.media or { panic('media group has no MediaList') }
	media.set_media_text('not all')
	assert font_rule.css_connected_font_face_ref() == none
	assert !first_face.is_css_connected()
	assert font_face_set.set_entries().len == 0

	media.set_media_text('all')
	second_face := font_rule.css_connected_font_face_ref() or { panic('reactivated media font was not connected') }
	assert second_face != first_face
	assert font_face_set.set_entries().len == 1
}

fn test_dynamic_font_insertion_preserves_style_sheet_order() {
	mut document := dom.Document.create(dom.url_about_blank())
	document_node := unsafe { &dom.Node(document) }
	mut first_sheet := css_style_sheet_construct(none, document)!
	mut second_sheet := css_style_sheet_construct(none, document)!
	second_sheet.replace_sync('@font-face { font-family: Later; src: url(later.woff2); }')!
	mut adopted := create_adopted_style_sheets_list(document_node)
	adopted.append(first_sheet)!
	adopted.append(second_sheet)!
	font_face_set := css_style_computer_for(document).font_face_set_
	later_rule := second_sheet.css_rules().item(0) or { panic('missing later font rule') }
	later_face := (later_rule.font_face_rule_ref() or { panic('later rule is not @font-face') }).css_connected_font_face_ref() or {
		panic('later font was not connected')
	}
	assert font_face_set.set_entries().len == 1
	assert font_face_set.set_entries()[0] == later_face

	first_sheet.insert_rule('@font-face { font-family: Earlier; src: url(earlier.woff2); }', 0)!
	earlier_rule := first_sheet.css_rules().item(0) or { panic('missing earlier font rule') }
	earlier_face := (earlier_rule.font_face_rule_ref() or { panic('earlier rule is not @font-face') }).css_connected_font_face_ref() or {
		panic('earlier font was not connected')
	}
	assert font_face_set.set_entries().len == 2
	assert font_face_set.set_entries()[0] == earlier_face
	assert font_face_set.set_entries()[1] == later_face
}

fn test_css_connected_fonts_precede_manually_added_faces() {
	mut document := dom.Document.create(dom.url_about_blank())
	document_node := unsafe { &dom.Node(document) }
	style_computer := css_style_computer_for(document)
	mut font_face_set := unsafe { &FontFaceSet(style_computer.font_face_set_) }
	manual_face := FontFaceObject.construct_impl('Manual', FontFaceSource.from_string('url(manual.woff2)'), FontFaceDescriptors{})
	font_face_set.add(manual_face)!

	mut sheet := css_style_sheet_construct(none, document)!
	sheet.replace_sync('@font-face { font-family: Connected; src: url(connected.woff2); }')!
	mut adopted := create_adopted_style_sheets_list(document_node)
	adopted.append(sheet)!
	font_rule := sheet.css_rules().item(0) or { panic('missing connected font rule') }
	connected_face := (font_rule.font_face_rule_ref() or { panic('rule is not @font-face') }).css_connected_font_face_ref() or {
		panic('stylesheet font was not connected')
	}

	assert font_face_set.set_entries().len == 2
	assert font_face_set.set_entries()[0] == connected_face
	assert font_face_set.set_entries()[1] == manual_face
}
