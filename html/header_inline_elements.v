// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Class-scope implementations from the simple HTML element headers. Keeping
// these explicit preserves the upstream virtual/default-role surface even
// though V represents the elements as DOM-backed concrete structs.
module html

import aria
import dom

pub fn html_data_element_default_role(_ &dom.HTMLDataElement) ?aria.Role { return .generic }
pub fn html_data_list_element_default_role(_ &dom.HTMLDataListElement) ?aria.Role { return .listbox }
pub fn html_details_element_default_role(_ &dom.HTMLDetailsElement) ?aria.Role { return .group }
pub fn html_div_element_default_role(_ &dom.HTMLDivElement) ?aria.Role { return .generic }
pub fn html_form_element_default_role(_ &dom.HTMLFormElement) ?aria.Role { return .form }
pub fn html_hr_element_default_role(_ &dom.HTMLHRElement) ?aria.Role { return .separator }
pub fn html_heading_element_default_role(_ &dom.HTMLHeadingElement) ?aria.Role { return .heading }
pub fn html_html_element_default_role(_ &dom.HTMLHtmlElement) ?aria.Role { return .document }
pub fn html_menu_element_default_role(_ &dom.HTMLMenuElement) ?aria.Role { return .list }
pub fn html_meter_element_default_role(_ &dom.HTMLMeterElement) ?aria.Role { return .meter }
pub fn html_olist_element_default_role(_ &dom.HTMLOListElement) ?aria.Role { return .list }
pub fn html_opt_group_element_default_role(_ &dom.HTMLOptGroupElement) ?aria.Role { return .group }
pub fn html_paragraph_element_default_role(_ &dom.HTMLParagraphElement) ?aria.Role { return .paragraph }
pub fn html_pre_element_default_role(_ &dom.HTMLPreElement) ?aria.Role { return .generic }
pub fn html_progress_element_default_role(_ &dom.HTMLProgressElement) ?aria.Role { return .progressbar }
pub fn html_selected_content_element_default_role(_ &dom.HTMLSelectedContentElement) ?aria.Role { return .generic }
pub fn html_span_element_default_role(_ &dom.HTMLSpanElement) ?aria.Role { return .generic }
pub fn html_summary_element_default_role(_ &dom.HTMLSummaryElement) ?aria.Role { return .button }
pub fn html_table_caption_element_default_role(_ &dom.HTMLTableCaptionElement) ?aria.Role { return .caption }
pub fn html_table_element_default_role(_ &dom.HTMLTableElement) ?aria.Role { return .table }
pub fn html_table_row_element_default_role(_ &dom.HTMLTableRowElement) ?aria.Role { return .row }
pub fn html_table_section_element_default_role(_ &dom.HTMLTableSectionElement) ?aria.Role { return .rowgroup }
pub fn html_time_element_default_role(_ &dom.HTMLTimeElement) ?aria.Role { return .time }
pub fn html_ulist_element_default_role(_ &dom.HTMLUListElement) ?aria.Role { return .list }

pub fn html_br_element_is_html_br_element(_ &dom.HTMLBRElement) bool { return true }
pub fn html_base_element_is_html_base_element(_ &dom.HTMLBaseElement) bool { return true }
pub fn html_div_element_is_html_div_element(_ &dom.HTMLDivElement) bool { return true }
pub fn html_embed_element_is_html_embed_element(_ &dom.HTMLEmbedElement) bool { return true }
pub fn html_form_element_is_html_form_element(_ &dom.HTMLFormElement) bool { return true }
pub fn html_head_element_is_html_head_element(_ &dom.HTMLHeadElement) bool { return true }
pub fn html_heading_element_is_html_heading_element(_ &dom.HTMLHeadingElement) bool { return true }
pub fn html_html_element_is_html_html_element(_ &dom.HTMLHtmlElement) bool { return true }
pub fn html_li_element_is_html_li_element(_ &dom.HTMLLIElement) bool { return true }
pub fn html_link_element_is_html_link_element(_ &dom.HTMLLinkElement) bool { return true }
pub fn html_menu_element_is_html_menu_element(_ &dom.HTMLMenuElement) bool { return true }
pub fn html_olist_element_is_html_olist_element(_ &dom.HTMLOListElement) bool { return true }
pub fn html_opt_group_element_is_html_optgroup_element(_ &dom.HTMLOptGroupElement) bool { return true }
pub fn html_option_element_is_html_option_element(_ &dom.HTMLOptionElement) bool { return true }
pub fn html_progress_element_is_html_progress_element(_ &dom.HTMLProgressElement) bool { return true }
pub fn html_script_element_is_html_script_element(_ &dom.HTMLScriptElement) bool { return true }
pub fn html_span_element_is_html_span_element(_ &dom.HTMLSpanElement) bool { return true }
pub fn html_table_cell_element_is_html_table_cell_element(_ &dom.HTMLTableCellElement) bool { return true }
pub fn html_table_element_is_html_table_element(_ &dom.HTMLTableElement) bool { return true }
pub fn html_table_row_element_is_html_table_row_element(_ &dom.HTMLTableRowElement) bool { return true }
pub fn html_table_section_element_is_html_table_section_element(_ &dom.HTMLTableSectionElement) bool { return true }
pub fn html_template_element_is_html_template_element(_ &dom.HTMLTemplateElement) bool { return true }
pub fn html_title_element_is_html_title_element(_ &dom.HTMLTitleElement) bool { return true }
pub fn html_ulist_element_is_html_ulist_element(_ &dom.HTMLUListElement) bool { return true }

fn header_inline_dom_element[T](element &T) &dom.Element {
	return unsafe { &dom.Element(element) }
}

pub fn html_anchor_element_extract_an_origin(element &dom.HTMLAnchorElement) ?dom.Origin {
	return html_hyperlink_element_utils_extract_an_origin(header_inline_dom_element(element))
}
pub fn html_anchor_element_rel(element &dom.HTMLAnchorElement) string { return header_inline_dom_element(element).get_attribute_value('rel') }
pub fn html_anchor_element_target(element &dom.HTMLAnchorElement) string { return header_inline_dom_element(element).get_attribute_value('target') }
pub fn html_anchor_element_download(element &dom.HTMLAnchorElement) string { return header_inline_dom_element(element).get_attribute_value('download') }
pub fn html_anchor_element_is_focusable(element &dom.HTMLAnchorElement) bool { return header_inline_dom_element(element).has_attribute('href') }
pub fn html_anchor_element_is_html_anchor_element(_ &dom.HTMLAnchorElement) bool { return true }
pub fn html_anchor_element_hyperlink_element_utils_element(element &dom.HTMLAnchorElement) &dom.Element { return header_inline_dom_element(element) }

pub fn html_area_element_is_html_area_element(_ &dom.HTMLAreaElement) bool { return true }
pub fn html_area_element_extract_an_origin(element &dom.HTMLAreaElement) ?dom.Origin { return html_hyperlink_element_utils_extract_an_origin(header_inline_dom_element(element)) }
pub fn html_area_element_hyperlink_element_utils_element(element &dom.HTMLAreaElement) &dom.Element { return header_inline_dom_element(element) }

pub fn html_body_element_is_html_body_element(_ &dom.HTMLBodyElement) bool { return true }
pub fn html_body_element_default_role(_ &dom.HTMLBodyElement) ?aria.Role { return .generic }

pub fn html_button_element_is_listed(_ &dom.HTMLButtonElement) bool { return true }
pub fn html_button_element_is_submittable(_ &dom.HTMLButtonElement) bool { return true }
pub fn html_button_element_is_autocapitalize_and_autocorrect_inheriting(_ &dom.HTMLButtonElement) bool { return true }
pub fn html_button_element_is_button(_ &dom.HTMLButtonElement) bool { return true }
pub fn html_button_element_is_labelable(_ &dom.HTMLButtonElement) bool { return true }
pub fn html_button_element_default_role(_ &dom.HTMLButtonElement) ?aria.Role { return .button }
pub fn html_button_element_uses_button_layout(_ &dom.HTMLButtonElement) bool { return true }
pub fn html_button_element_is_html_button_element(_ &dom.HTMLButtonElement) bool { return true }
pub fn html_button_element_set_command_for_element(element &dom.HTMLButtonElement, value ?&dom.Element) {
	mut mutable_element := unsafe { &dom.HTMLButtonElement(element) }
	mutable_element.command_for_element_ = value
}

pub fn html_element_title(element &dom.HTMLElement) ?string { return header_inline_dom_element(element).get_attribute('title') }
pub fn html_element_content_editable_state(element &dom.HTMLElement) string { return html_element_content_editable(element) }
pub fn html_element_is_labelable(_ &dom.HTMLElement) bool { return false }
pub fn html_element_is_inert(element &dom.HTMLElement) bool { return element.inert() }
pub fn html_element_is_valid_command(_ &dom.HTMLElement, _ string) bool { return false }
pub fn html_element_command_steps(_ &dom.HTMLElement, _ &dom.Element, _ string) {}
pub fn html_element_uses_button_layout(_ &dom.HTMLElement) bool { return false }
pub fn html_element_is_html_element(_ &dom.HTMLElement) bool { return true }
pub fn html_element_global_event_handlers_to_event_target(element &dom.HTMLElement, _ string) &dom.EventTarget {
	return unsafe { &dom.EventTarget(element) }
}

pub fn html_field_set_element_type(_ &dom.HTMLFieldSetElement) string { return 'fieldset' }
pub fn html_field_set_element_is_listed(_ &dom.HTMLFieldSetElement) bool { return true }
pub fn html_field_set_element_is_autocapitalize_and_autocorrect_inheriting(_ &dom.HTMLFieldSetElement) bool { return true }
pub fn html_field_set_element_default_role(_ &dom.HTMLFieldSetElement) ?aria.Role { return .group }
pub fn html_field_set_element_is_html_fieldset_element(_ &dom.HTMLFieldSetElement) bool { return true }

pub fn html_frame_set_element_is_html_frameset_element(_ &dom.HTMLFrameSetElement) bool { return true }

pub fn html_heading_element_aria_level(element &dom.HTMLHeadingElement) ?u32 {
	return match header_inline_dom_element(element).local_name() {
		'h1' { u32(1) }
		'h2' { u32(2) }
		'h3' { u32(3) }
		'h4' { u32(4) }
		'h5' { u32(5) }
		'h6' { u32(6) }
		else { none }
	}
}

pub fn html_iframe_element_is_focusable(_ &dom.HTMLIFrameElement) bool { return true }
pub fn html_iframe_element_is_html_iframe_element(_ &dom.HTMLIFrameElement) bool { return true }
pub fn html_iframe_element_supports_dimension_attributes(_ &dom.HTMLIFrameElement) bool { return true }

pub fn html_image_element_to_html_element(element &dom.HTMLImageElement) &dom.Element { return header_inline_dom_element(element) }
pub fn html_image_element_is_html_image_element(_ &dom.HTMLImageElement) bool { return true }
pub fn html_image_element_supports_dimension_attributes(_ &dom.HTMLImageElement) bool { return true }

pub fn html_li_element_default_role(element &dom.HTMLLIElement) ?aria.Role {
	return if header_inline_dom_element(element).local_name() == 'li' { aria.Role.listitem } else { none }
}

pub fn html_output_element_type(_ &dom.HTMLOutputElement) string { return 'output' }
pub fn html_output_element_is_listed(_ &dom.HTMLOutputElement) bool { return true }
pub fn html_output_element_is_resettable(_ &dom.HTMLOutputElement) bool { return true }
pub fn html_output_element_is_autocapitalize_and_autocorrect_inheriting(_ &dom.HTMLOutputElement) bool { return true }
pub fn html_output_element_is_labelable(_ &dom.HTMLOutputElement) bool { return true }
pub fn html_output_element_default_role(_ &dom.HTMLOutputElement) ?aria.Role { return .status }

pub fn html_slot_element_is_html_slot_element(_ &dom.HTMLSlotElement) bool { return true }
pub fn html_style_element_is_html_style_element(_ &dom.HTMLStyleElement) bool { return true }
pub fn html_style_element_as_element(element &dom.HTMLStyleElement) &dom.Element { return header_inline_dom_element(element) }

pub fn html_text_area_element_type(_ &dom.HTMLTextAreaElement) string { return 'textarea' }
pub fn html_text_area_element_is_listed(_ &dom.HTMLTextAreaElement) bool { return true }
pub fn html_text_area_element_is_submittable(_ &dom.HTMLTextAreaElement) bool { return true }
pub fn html_text_area_element_is_resettable(_ &dom.HTMLTextAreaElement) bool { return true }
pub fn html_text_area_element_is_autocapitalize_and_autocorrect_inheriting(_ &dom.HTMLTextAreaElement) bool { return true }
pub fn html_text_area_element_is_labelable(_ &dom.HTMLTextAreaElement) bool { return true }
pub fn html_text_area_element_default_role(_ &dom.HTMLTextAreaElement) ?aria.Role { return .textbox }
pub fn html_text_area_element_is_html_textarea_element(_ &dom.HTMLTextAreaElement) bool { return true }
