// ViewTransition.cpp's retained CSSOM rules in Document's dynamic stylesheet.
module css

import dom

fn insert_view_transition_rule(target voidptr, text string) voidptr {
	mut sheet := unsafe { &CSSStyleSheet(target) }
	index := sheet.insert_rule(text, u32(sheet.rules.length())) or { panic(err) }
	rule := sheet.rules.item(uint(index)) or { panic('Inserted view-transition rule is missing') }
	return voidptr(rule)
}

fn remove_view_transition_rule(target voidptr, owned voidptr) {
	mut sheet := unsafe { &CSSStyleSheet(target) }
	for index, rule in sheet.rules.rules {
		if voidptr(rule) == owned {
			sheet.delete_rule(u32(index)) or { panic(err) }
			break
		}
	}
}

fn set_view_transition_selector(target voidptr, selector string) {
	mut rule := unsafe { &CSSRule(target) }
	rule.set_selector_text(selector)
}

pub fn dynamic_view_transition_style_sheet_for_document(document &dom.Document) &CSSStyleSheet {
	if bridge := document.document_dynamic_view_transition_style_sheet() {
		if bridge.css_handle != unsafe { nil } {
			return unsafe { &CSSStyleSheet(bridge.css_handle) }
		}
	}
	mut sheet := CSSStyleSheet.create(CSSRuleList.create_empty(), MediaList.create_empty(), none)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.dynamic_view_transition_style_sheet = &dom.CSSStyleSheet{
		css_handle:                            voidptr(sheet)
		insert_view_transition_rule_callback:  insert_view_transition_rule
		remove_view_transition_rule_callback:  remove_view_transition_rule
		set_view_transition_selector_callback: set_view_transition_selector
	}
	// Ownership synchronizes the document's font sheets, which enumerates this
	// sheet again. Publish its identity before entering that source boundary.
	sheet.add_owning_document_or_shadow_root(unsafe { &dom.Node(document) })
	return sheet
}
