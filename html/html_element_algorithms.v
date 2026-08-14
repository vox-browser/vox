// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the dependency-complete element algorithms in HTMLElement.cpp,
// HTMLTitleElement.cpp, HTMLLIElement.cpp, and HTMLOListElement.cpp.
module html

import dom

pub enum AutocapitalizationHint {
	default_
	none_
	sentences
	words
	characters
}

pub type HiddenValue = bool | f64 | string

fn dom_element_from_html_element(element &dom.HTMLElement) &dom.Element {
	return unsafe { &dom.Element(element) }
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-translate
pub fn html_element_translate(element &dom.HTMLElement) bool {
	return dom_element_from_html_element(element).translation_mode() == .translate_enabled
}

pub fn set_html_element_translate(element &dom.HTMLElement, new_value bool) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('translate', if new_value { 'yes' } else { 'no' })
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-dir
pub fn html_element_dir(element &dom.HTMLElement) string {
	value :=
		ascii_lowercase_string(dom_element_from_html_element(element).get_attribute_value('dir'))
	return if value in ['ltr', 'rtl', 'auto'] { value } else { '' }
}

pub fn set_html_element_dir(element &dom.HTMLElement, value string) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('dir', value)
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-iscontenteditable
pub fn html_element_is_content_editable(element &dom.HTMLElement) bool {
	return dom_element_from_html_element(element).as_node().is_editable_or_editing_host()
}

pub fn html_element_content_editable(element &dom.HTMLElement) string {
	value := element.get_attribute('contenteditable') or { return 'inherit' }
	return match ascii_lowercase_string(value) {
		'', 'true' { 'true' }
		'false' { 'false' }
		'plaintext-only' { 'plaintext-only' }
		else { 'inherit' }
	}
}

pub fn set_html_element_content_editable(element &dom.HTMLElement, value string) ! {
	mut dom_element := unsafe { &dom.Element(element) }
	match ascii_lowercase_string(value) {
		'inherit' {
			dom_element.remove_attribute('contenteditable')
		}
		'true' {
			dom_element.set_attribute_value('contenteditable', 'true')
		}
		'plaintext-only' {
			dom_element.set_attribute_value('contenteditable', 'plaintext-only')
		}
		'false' {
			dom_element.set_attribute_value('contenteditable', 'false')
		}
		else {
			return error("SyntaxError: Invalid contentEditable value, must be 'true', 'false', 'plaintext-only' or 'inherit'")
		}
	}
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-hidden
pub fn html_element_hidden(element &dom.HTMLElement) HiddenValue {
	if hidden := element.get_attribute('hidden') {
		if ascii_lowercase_string(hidden) == 'until-found' {
			return HiddenValue('until-found')
		}
		return HiddenValue(true)
	}
	return HiddenValue(false)
}

pub fn set_html_element_hidden(element &dom.HTMLElement, value HiddenValue) {
	mut dom_element := unsafe { &dom.Element(element) }
	match value {
		string {
			if ascii_lowercase_string(value) == 'until-found' {
				dom_element.set_attribute_value('hidden', 'until-found')
				return
			}
			if value == '' || ascii_lowercase_string(value) in ['null', 'undefined'] {
				dom_element.remove_attribute('hidden')
				return
			}
		}
		bool {
			if !value {
				dom_element.remove_attribute('hidden')
				return
			}
		}
		f64 {
			if value == 0 || value != value {
				dom_element.remove_attribute('hidden')
				return
			}
		}
	}
	dom_element.set_attribute_value('hidden', '')
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-accesskeylabel
pub fn html_element_access_key_label(element &dom.HTMLElement) string {
	access_key := element.get_attribute('accesskey') or { return '' }
	if access_key.runes().len != 1 {
		return ''
	}
	return access_key
}

// https://html.spec.whatwg.org/multipage/dnd.html#dom-draggable
pub fn html_element_draggable(element &dom.HTMLElement) bool {
	dom_element := dom_element_from_html_element(element)
	if attribute := dom_element.get_attribute('draggable') {
		if ascii_lowercase_string(attribute) == 'true' {
			return true
		}
		if ascii_lowercase_string(attribute) == 'false' {
			return false
		}
	}
	if dom_element.local_name() == 'img' {
		return true
	}
	if dom_element.local_name() == 'object'
		&& ascii_lowercase_string(dom_element.get_attribute_value('type')) == 'image' {
		return true
	}
	return dom_element.local_name() == 'a' && dom_element.has_attribute('href')
}

pub fn set_html_element_draggable(element &dom.HTMLElement, value bool) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('draggable', if value { 'true' } else { 'false' })
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-writingsuggestions
pub fn html_element_writing_suggestions(element &dom.HTMLElement) string {
	dom_element := dom_element_from_html_element(element)
	if value := dom_element.get_attribute('writingsuggestions') {
		return if ascii_lowercase_string(value) == 'false' { 'false' } else { 'true' }
	}
	if parent := dom_element.as_node().parent_element() {
		if parent.is_html_element()
			&& html_element_writing_suggestions(unsafe { &dom.HTMLElement(parent) }) == 'false' {
			return 'false'
		}
	}
	return 'true'
}

pub fn set_html_element_writing_suggestions(element &dom.HTMLElement, value string) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('writingsuggestions', value)
}

// https://html.spec.whatwg.org/multipage/interaction.html#own-autocapitalization-hint
//
// Form-associated-element ownership lives outside the translated DOM core. The
// caller supplies the form owner only when `element` is an autocapitalize-and-
// autocorrect inheriting element with a non-null form owner.
pub fn html_element_own_autocapitalization_hint(element &dom.HTMLElement, form_owner ?&dom.HTMLElement) AutocapitalizationHint {
	if attribute := element.get_attribute('autocapitalize') {
		if attribute != '' {
			return match ascii_lowercase_string(attribute) {
				'off', 'none' { .none_ }
				'words' { .words }
				'characters' { .characters }
				else { .sentences }
			}
		}
	}
	if owner := form_owner {
		return html_element_own_autocapitalization_hint(owner, none)
	}
	return .default_
}

pub fn html_element_autocapitalize(element &dom.HTMLElement, form_owner ?&dom.HTMLElement) string {
	return match html_element_own_autocapitalization_hint(element, form_owner) {
		.default_ { '' }
		.none_ { 'none' }
		.sentences { 'sentences' }
		.words { 'words' }
		.characters { 'characters' }
	}
}

pub fn set_html_element_autocapitalize(element &dom.HTMLElement, value string) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('autocapitalize', value)
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-autocorrect
pub fn html_element_autocorrect(element &dom.HTMLElement, form_owner ?&dom.HTMLElement) bool {
	dom_element := dom_element_from_html_element(element)
	if dom_element.local_name() == 'input' {
		type_ := ascii_lowercase_string(dom_element.get_attribute_value('type'))
		if type_ in ['url', 'email', 'password'] {
			return false
		}
	}
	if value := dom_element.get_attribute('autocorrect') {
		return ascii_lowercase_string(value) != 'off'
	}
	if owner := form_owner {
		if value := owner.get_attribute('autocorrect') {
			return ascii_lowercase_string(value) != 'off'
		}
	}
	return true
}

pub fn set_html_element_autocorrect(element &dom.HTMLElement, value bool) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('autocorrect', if value { 'on' } else { 'off' })
}

// https://html.spec.whatwg.org/multipage/semantics.html#dom-title-text
pub fn html_title_element_text(element &dom.HTMLTitleElement) string {
	return unsafe { &dom.Element(element) }.as_node().child_text_content()
}

pub fn set_html_title_element_text(element &dom.HTMLTitleElement, value string) {
	mut node := unsafe { &dom.Element(element) }.as_node()
	node.string_replace_all(value)
}

// https://html.spec.whatwg.org/multipage/grouping-content.html#dom-li-value
pub fn html_li_element_value(element &dom.HTMLLIElement) i32 {
	dom_element := unsafe { &dom.Element(element) }
	return parse_integer(dom_element.get_attribute_value('value')) or { i32(0) }
}

pub fn set_html_li_element_value(element &dom.HTMLLIElement, value i32) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('value', value.str())
}

// https://html.spec.whatwg.org/multipage/grouping-content.html#dom-ol-start
pub fn html_olist_element_start(element &dom.HTMLOListElement) i32 {
	dom_element := unsafe { &dom.Element(element) }
	return parse_integer(dom_element.get_attribute('start') or { '1' }) or { i32(1) }
}

pub fn set_html_olist_element_start(element &dom.HTMLOListElement, value i32) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('start', value.str())
}

pub fn html_olist_element_starting_value(element &dom.HTMLOListElement) i32 {
	dom_element := unsafe { &dom.Element(element) }
	if start := dom_element.get_attribute('start') {
		if parsed := parse_integer(start) {
			return parsed
		}
	}
	if dom_element.has_attribute('reversed') {
		return i32(dom_element.number_of_owned_list_items())
	}
	return 1
}

// https://html.spec.whatwg.org/multipage/sections.html#get-an-element's-computed-heading-level
pub fn html_heading_element_computed_heading_level(element &dom.HTMLHeadingElement) u32 {
	dom_element := unsafe { &dom.Element(element) }
	mut level := match dom_element.local_name() {
		'h1' { u32(1) }
		'h2' { u32(2) }
		'h3' { u32(3) }
		'h4' { u32(4) }
		'h5' { u32(5) }
		'h6' { u32(6) }
		else { panic('HTMLHeadingElement must have an h1-h6 local name') }
	}
	mut inclusive_ancestor := ?&dom.Node(dom_element.as_node())
	for inclusive_ancestor != none {
		ancestor := inclusive_ancestor or { break }
		if ancestor_element := ancestor.as_element() {
			if ancestor_element.is_html_element() {
				if value := ancestor_element.get_attribute('headingoffset') {
					if offset := parse_non_negative_integer(value) {
						level += offset
					}
				}
				if ancestor_element.has_attribute('headingreset') {
					break
				}
			}
		}
		inclusive_ancestor = ancestor.flat_tree_parent()
	}
	return if level > 9 { u32(9) } else { level }
}
