module css

import dom

__global remote_import_test_calls []string

fn remote_import_test_load(_ &dom.Document, address string) ?ImportedStyleSheetSource {
	remote_import_test_calls << address
	return match address {
		'https://imports.test/fonts.css' {
			ImportedStyleSheetSource{
				css_text:     '@import "nested.css"; @font-face {font-family: Imported;src:url(font.woff2)} .target{color:red}'
				response_url: 'https://cdn.imports.test/assets/fonts.css'
			}
		}
		'https://cdn.imports.test/assets/nested.css' {
			ImportedStyleSheetSource{
				css_text:     '@import "https://imports.test/fonts.css"; .nested{color:green}'
				response_url: address
			}
		}
		'https://imports.test/redirect-cycle.css' {
			ImportedStyleSheetSource{
				css_text:     '@import "https://imports.test/redirect-cycle.css";'
				response_url: 'https://cdn.imports.test/cycle.css'
			}
		}
		else { none }
	}
}

fn test_remote_import_keeps_response_base_nested_rules_and_font_registration() {
	remote_import_test_calls = []
	install_remote_style_sheet_loader(remote_import_test_load)
	defer { install_remote_style_sheet_loader(none) }
	mut document := dom.Document.create(dom.URL{ value: 'https://imports.test/' })
	mut sheet := parse_css_style_sheet_for_owner_node(document,
		'@import "fonts.css" layer(theme); .target{color:blue}', document.url.serialize())
	assert remote_import_test_calls == ['https://imports.test/fonts.css',
		'https://cdn.imports.test/assets/nested.css']
	import_rule := sheet.import_rules[0]
	imported := import_rule.loaded_style_sheet_for_bindings() or { panic('missing remote sheet') }
	assert (imported.base.location or { panic('missing response location') }) == 'https://cdn.imports.test/assets/fonts.css'
	assert voidptr(imported.base.parent_style_sheet?) == voidptr(sheet)
	nested := imported.import_rules[0].loaded_style_sheet_for_bindings() or { panic('missing nested sheet') }
	assert nested.import_rules[0].loaded_style_sheet_for_bindings() == none
	sheet.add_owning_document_or_shadow_root(document.as_node())
	fonts := css_style_computer_for(document).font_face_set_.set_entries()
	assert fonts.len == 1
	assert fonts[0].family() == 'Imported'
	parsed := fonts[0].parsed_font_face()
	assert resolve_font_face_source_url(parsed.sources()[0].url?, parsed.parent_rule_ref()) == 'https://cdn.imports.test/assets/font.woff2'
	sheet.remove_owning_document_or_shadow_root(document.as_node())
	assert css_style_computer_for(document).font_face_set_.set_entries().len == 0
}

fn test_remote_import_skips_failed_conditions_and_fetch_errors_without_losing_other_rules() {
	remote_import_test_calls = []
	install_remote_style_sheet_loader(remote_import_test_load)
	defer { install_remote_style_sheet_loader(none) }
	document := dom.Document.create(dom.URL{ value: 'https://imports.test/' })
	sheet := parse_css_style_sheet_for_owner_node(document,
		'@import "fonts.css" supports(display:invalid-display); @import "fonts.css" not all; @import "missing.css"; p{color:red}', document.url.serialize())
	assert remote_import_test_calls == ['https://imports.test/missing.css']
	assert sheet.css_rules().length() == 4
	assert sheet.import_rules.all(it.loaded_style_sheet_for_bindings() == none)
}

fn test_remote_import_redirect_cycle_stops_before_a_repeated_request() {
	remote_import_test_calls = []
	install_remote_style_sheet_loader(remote_import_test_load)
	defer { install_remote_style_sheet_loader(none) }
	document := dom.Document.create(dom.URL{ value: 'https://imports.test/' })
	sheet := parse_css_style_sheet_for_owner_node(document,
		'@import "redirect-cycle.css";', document.url.serialize())
	assert remote_import_test_calls == ['https://imports.test/redirect-cycle.css']
	imported := sheet.import_rules[0].loaded_style_sheet_for_bindings() or { panic('missing redirected sheet') }
	assert imported.import_rules[0].loaded_style_sheet_for_bindings() == none
}
