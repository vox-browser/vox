module css

import dom

fn test_font_rule_presence_tracks_nested_mutations_and_unloaded_imports() {
	mut sheet := parse_css_stylesheet_with_params(ParsingParams{},
		'@media(width>1px){.card{color:red}}', none)
	assert !sheet.rules.may_contain_font_rules()
	mut children := sheet.rules.rules[0].rules?
	children.insert_a_css_rule_from_text('@font-face{font-family:Presence;src:local("Arial")}', 1, .yes, map[string]bool{})!
	assert sheet.rules.may_contain_font_rules()
	children.remove_a_css_rule(1)!
	assert !sheet.rules.may_contain_font_rules()
	mut imported := parse_css_stylesheet_with_params(ParsingParams{}, '@import "pending.css";', none)
	assert imported.rules.may_contain_font_rules()
	mut conditional := parse_css_stylesheet_with_params(ParsingParams{},
		'@supports(unknown:value){@font-face{font-family:Presence;src:local("Arial")}}', none)
	assert conditional.rules.may_contain_font_rules()
	mut features := parse_css_stylesheet_with_params(ParsingParams{},
		'@font-feature-values Presence{@styleset{alternate:1}}', none)
	assert features.rules.may_contain_font_rules()
}

fn test_font_rule_presence_keeps_last_face_removal_and_font_set_order() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut sheet := parse_css_stylesheet_with_params(ParsingParams{document:document},
		'@font-face{font-family:Presence;src:local("Arial")}', none)
	sheet.add_owning_document_or_shadow_root(document.as_node())
	sheet.load_fonts_for_document(document)
	if !disable_font_rule_presence { assert sheet.font_synchronization_had_rules_ }
	sheet.delete_rule(0)!
	sheet.load_fonts_for_document(document)
	assert !sheet.rules.may_contain_font_rules()
	if !disable_font_rule_presence { assert sheet.font_synchronization_had_rules_ }
	assert css_style_computer_for(document).font_face_set_.set_entries_.len == 0
}

fn test_font_rule_history_preserves_removal_for_every_owning_document() {
	mut first_document := dom.Document.create(dom.url_about_blank())
	mut second_document := dom.Document.create(dom.url_about_blank())
	defer { first_document.finalize(); second_document.finalize() }
	mut sheet := parse_css_stylesheet_with_params(ParsingParams{document:first_document},
		'@font-face{font-family:SharedPresence;src:local("Arial")}', none)
	sheet.add_owning_document_or_shadow_root(first_document.as_node())
	sheet.add_owning_document_or_shadow_root(second_document.as_node())
	sheet.load_fonts_for_document(first_document)
	sheet.load_fonts_for_document(second_document)
	assert css_style_computer_for(first_document).font_face_set_.set_entries_.len == 1
	assert css_style_computer_for(second_document).font_face_set_.set_entries_.len == 1
	sheet.delete_rule(0)!
	sheet.load_fonts_for_document(first_document)
	sheet.load_fonts_for_document(second_document)
	assert css_style_computer_for(first_document).font_face_set_.set_entries_.len == 0
	assert css_style_computer_for(second_document).font_face_set_.set_entries_.len == 0
	if !disable_font_rule_presence { assert sheet.font_synchronization_had_rules_ }
}
