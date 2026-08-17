// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLBaseElement.{h,cpp}, HTMLMetaElement.{h,cpp},
// HTMLStyleElement.{h,cpp}, HTMLBodyElement.{h,cpp}, HTMLSourceElement.{h,cpp},
// HTMLAnchorElement.{h,cpp}, HTMLAreaElement.{h,cpp}, HTMLLabelElement.{h,cpp},
// HTMLFieldSetElement.{h,cpp}, and HTMLOutputElement.{h,cpp}.
module html

import color
import dom

pub type BaseAllowedHook = fn (dom.URL) bool

@[heap]
pub struct HTMLBaseElementModel {
mut:
	fallback_base_url_ dom.URL
	href_              string
	frozen_base_url_   dom.URL
	base_allowed_hook_ ?BaseAllowedHook
}

pub fn HTMLBaseElementModel.create(fallback_base_url dom.URL) &HTMLBaseElementModel {
	return &HTMLBaseElementModel{
		fallback_base_url_: fallback_base_url
		frozen_base_url_:   fallback_base_url
	}
}

pub fn (mut base HTMLBaseElementModel) set_base_allowed_hook(hook ?BaseAllowedHook) {
	base.base_allowed_hook_ = hook
}

pub fn (mut base HTMLBaseElementModel) set_href(value string) {
	base.href_ = value
	base.set_the_frozen_base_url()
}

pub fn (base &HTMLBaseElementModel) href() string {
	url := dom.dom_url_parse(base.href_, base.fallback_base_url_, 'UTF-8') or { return base.href_ }
	return url.serialize()
}

// https://html.spec.whatwg.org/multipage/semantics.html#set-the-frozen-base-url
pub fn (mut base HTMLBaseElementModel) set_the_frozen_base_url() {
	url := dom.dom_url_parse(base.href_, base.fallback_base_url_, 'UTF-8') or {
		base.frozen_base_url_ = base.fallback_base_url_
		return
	}
	if url.scheme() in ['data', 'javascript'] {
		base.frozen_base_url_ = base.fallback_base_url_
		return
	}
	if allowed := base.base_allowed_hook_ {
		if !allowed(url) {
			base.frozen_base_url_ = base.fallback_base_url_
			return
		}
	}
	base.frozen_base_url_ = url
}

pub fn (base &HTMLBaseElementModel) frozen_base_url() dom.URL {
	return base.frozen_base_url_
}

pub enum MetaHttpEquivState {
	encoding_declaration
	refresh
	set_cookie
	x_ua_compatible
	content_language
	content_security_policy
	default_style
}

pub fn meta_http_equiv_state(value string) ?MetaHttpEquivState {
	return match ascii_lowercase_string(value.trim_space()) {
		'content-type' { .encoding_declaration }
		'refresh' { .refresh }
		'set-cookie' { .set_cookie }
		'x-ua-compatible' { .x_ua_compatible }
		'content-language' { .content_language }
		'content-security-policy' { .content_security_policy }
		'default-style' { .default_style }
		else { none }
	}
}

pub struct MetaDocumentState {
pub mut:
	referrer_policy             ReferrerPolicy = .strict_origin_when_cross_origin
	pragma_set_default_language ?string
	theme_color                 ?string
	supported_color_schemes     []string
	refresh_input               ?string
	enforced_meta_csp           []SerializedCSPPolicy
}

@[heap]
pub struct HTMLMetaElementModel {
pub mut:
	document_state &MetaDocumentState
mut:
	name_         ?string
	http_equiv_   ?string
	content_      ?string
	media_        string
	in_document   bool
	child_of_head bool
}

pub fn HTMLMetaElementModel.create(document_state &MetaDocumentState) &HTMLMetaElementModel {
	return &HTMLMetaElementModel{
		document_state: document_state
	}
}

pub fn (mut meta HTMLMetaElementModel) set_name(value ?string) {
	meta.name_ = value
	meta.update_metadata()
}

pub fn (mut meta HTMLMetaElementModel) set_http_equiv(value ?string) {
	meta.http_equiv_ = value
}

pub fn (mut meta HTMLMetaElementModel) set_content(value ?string) {
	meta.content_ = value
	meta.update_metadata()
}

pub fn (mut meta HTMLMetaElementModel) set_media(value string) {
	meta.media_ = value
	meta.update_metadata()
}

fn parse_meta_color_schemes(value string) []string {
	mut result := []string{}
	for token in value.fields() {
		lower := ascii_lowercase_string(token)
		if lower in ['normal', 'light', 'dark', 'only'] && lower !in result {
			result << lower
		}
	}
	return result
}

// https://html.spec.whatwg.org/multipage/semantics.html#meta-referrer
fn (mut meta HTMLMetaElementModel) update_metadata() {
	if !meta.in_document {
		return
	}
	name := ascii_lowercase_string(meta.name_ or { return })
	content := meta.content_ or { return }
	match name {
		'referrer' {
			if content == '' {
				return
			}
			legacy := match ascii_lowercase_string(content) {
				'never' { ReferrerPolicy.no_referrer }
				'default' { ReferrerPolicy.strict_origin_when_cross_origin }
				'always' { ReferrerPolicy.unsafe_url }
				'origin-when-crossorigin' { ReferrerPolicy.origin_when_cross_origin }
				else { referrer_policy_from_string(content) or { return } }
			}
			meta.document_state.referrer_policy = legacy
		}
		'theme-color' {
			meta.document_state.theme_color = if content.trim_space() == '' { none } else { content }
		}
		'color-scheme' {
			meta.document_state.supported_color_schemes = parse_meta_color_schemes(content)
		}
		else {}
	}
}

fn parse_meta_csp(input string) SerializedCSPPolicy {
	mut directives := []SerializedCSPDirective{}
	for serialized_directive in input.split(';') {
		parts := serialized_directive.fields()
		if parts.len == 0 {
			continue
		}
		name := ascii_lowercase_string(parts[0])
		// These directives have no effect in a meta-delivered policy.
		if name in ['report-uri', 'frame-ancestors', 'sandbox'] {
			continue
		}
		directives << SerializedCSPDirective{
			name:  name
			value: parts[1..].clone()
		}
	}
	return SerializedCSPPolicy{
		directives:               directives
		disposition:              .enforce
		source:                   .meta
		pre_parsed_policy_string: input
	}
}

pub fn (mut meta HTMLMetaElementModel) inserted(child_of_head bool) {
	meta.in_document = true
	meta.child_of_head = child_of_head
	meta.update_metadata()
	state := meta_http_equiv_state(meta.http_equiv_ or { return }) or { return }
	content := meta.content_ or { return }
	match state {
		.refresh {
			if content != '' {
				meta.document_state.refresh_input = content
			}
		}
		.content_language {
			if !content.contains(',') {
				candidate := content.trim_space().fields()[0] or { return }
				if candidate != '' {
					meta.document_state.pragma_set_default_language = candidate
				}
			}
		}
		.content_security_policy {
			if child_of_head && content != '' {
				meta.document_state.enforced_meta_csp << parse_meta_csp(content)
			}
		}
		else {}
	}
}

pub fn (mut meta HTMLMetaElementModel) removed() {
	meta.in_document = false
	if ascii_lowercase_string(meta.name_ or { '' }) in ['theme-color', 'color-scheme'] {
		meta.document_state.theme_color = none
		meta.document_state.supported_color_schemes = []
	}
}

pub struct StyleSheetModel {
pub mut:
	text     string
	media    string
	disabled bool
}

pub type StyleParseHook = fn (string) !

@[heap]
pub struct HTMLStyleElementModel {
mut:
	text_       string
	type_       string
	media_      string
	connected_  bool
	sheet_      ?&StyleSheetModel
	parse_hook_ ?StyleParseHook
}

pub fn HTMLStyleElementModel.create() &HTMLStyleElementModel {
	return &HTMLStyleElementModel{}
}

pub fn (mut style HTMLStyleElementModel) set_parse_hook(hook ?StyleParseHook) {
	style.parse_hook_ = hook
}

pub fn (mut style HTMLStyleElementModel) set_text(value string) {
	style.text_ = value
	style.update_a_style_block()
}

pub fn (mut style HTMLStyleElementModel) set_type(value string) {
	style.type_ = value
	style.update_a_style_block()
}

pub fn (mut style HTMLStyleElementModel) set_media(value string) {
	style.media_ = value
	if mut sheet := style.sheet_ {
		sheet.media = value
	}
}

pub fn (mut style HTMLStyleElementModel) inserted() {
	style.connected_ = true
	style.update_a_style_block()
}

pub fn (mut style HTMLStyleElementModel) removed() {
	style.connected_ = false
	style.sheet_ = none
}

pub fn (mut style HTMLStyleElementModel) update_a_style_block() {
	if !style.connected_ || (style.type_ != '' && ascii_lowercase_string(style.type_) != 'text/css') {
		style.sheet_ = none
		return
	}
	if parse_hook := style.parse_hook_ {
		parse_hook(style.text_) or {
			style.sheet_ = none
			return
		}
	}
	style.sheet_ = &StyleSheetModel{
		text:  style.text_
		media: style.media_
	}
}

pub fn (style &HTMLStyleElementModel) sheet() ?&StyleSheetModel {
	return style.sheet_
}

pub fn (style &HTMLStyleElementModel) disabled() bool {
	sheet := style.sheet_ or { return false }
	return sheet.disabled
}

pub fn (mut style HTMLStyleElementModel) set_disabled(value bool) {
	mut sheet := style.sheet_ or { return }
	sheet.disabled = value
}

pub fn (style &HTMLStyleElementModel) contributes_a_script_blocking_style_sheet() bool {
	return false
}

pub struct BodyPresentationalHints {
pub mut:
	background_color ?dom.Color
	color            ?dom.Color
	background_image ?dom.URL
	margin_top       ?f64
	margin_right     ?f64
	margin_bottom    ?f64
	margin_left      ?f64
}

fn legacy_dom_color(value string) ?dom.Color {
	parsed := color.parse_legacy_color_value(value) or { return none }
	return dom.Color{
		r: parsed.red
		g: parsed.green
		b: parsed.blue
		a: parsed.alpha
	}
}

fn first_body_margin(attributes map[string]string, first string, second string, inherited map[string]string, inherited_name string) ?f64 {
	value := if first in attributes {
		attributes[first]
	} else if second in attributes {
		attributes[second]
	} else if inherited_name in inherited {
		inherited[inherited_name]
	} else {
		return none
	}
	parsed := parse_non_negative_integer(value) or { return none }
	return f64(parsed)
}

pub fn html_body_presentational_hints(attributes map[string]string, inherited_frame_attributes map[string]string, base_url dom.URL) BodyPresentationalHints {
	mut hints := BodyPresentationalHints{}
	if 'bgcolor' in attributes {
		hints.background_color = legacy_dom_color(attributes['bgcolor'])
	}
	if 'text' in attributes {
		hints.color = legacy_dom_color(attributes['text'])
	}
	if background := attributes['background'] {
		hints.background_image = dom.dom_url_parse(background, base_url, 'UTF-8')
	}
	hints.margin_top = first_body_margin(attributes, 'marginheight', 'topmargin',
		inherited_frame_attributes, 'marginheight')
	hints.margin_bottom = first_body_margin(attributes, 'marginheight', 'bottommargin',
		inherited_frame_attributes, 'marginheight')
	hints.margin_left = first_body_margin(attributes, 'marginwidth', 'leftmargin',
		inherited_frame_attributes, 'marginwidth')
	hints.margin_right = first_body_margin(attributes, 'marginwidth', 'rightmargin',
		inherited_frame_attributes, 'marginwidth')
	return hints
}

pub fn html_source_element_inserted_into_media(mut media HTMLMediaElement, parent_has_src_attribute bool) ! {
	if !parent_has_src_attribute && media.network_state() == .empty {
		media.select_resource()!
	}
}

fn relation_tokens(value string) []string {
	mut result := []string{}
	for token in value.fields() {
		lower := ascii_lowercase_string(token)
		if lower !in result {
			result << lower
		}
	}
	return result
}

pub struct HyperlinkActivationResult {
pub:
	url              dom.URL
	download         bool
	user_involvement UserNavigationInvolvement
}

pub fn html_anchor_element_rel_list(anchor &dom.HTMLAnchorElement) []string {
	return relation_tokens(unsafe { &dom.Element(anchor) }.get_attribute_value('rel'))
}

pub fn html_area_element_rel_list(area &dom.HTMLAreaElement) []string {
	return relation_tokens(unsafe { &dom.Element(area) }.get_attribute_value('rel'))
}

pub fn html_anchor_element_text(anchor &dom.HTMLAnchorElement) string {
	return unsafe { &dom.Element(anchor) }.as_node().descendant_text_content()
}

pub fn set_html_anchor_element_text(anchor &dom.HTMLAnchorElement, text string) {
	mut node := unsafe { &dom.Element(anchor) }.as_node()
	node.string_replace_all(text)
}

pub fn activate_html_anchor_element(anchor &dom.HTMLAnchorElement, is_image_map_target bool, trusted bool, offset_x f64, offset_y f64, user_involvement UserNavigationInvolvement, platform_control_key bool) ?HyperlinkActivationResult {
	element := unsafe { &dom.Element(anchor) }
	href := element.get_attribute('href') or { return none }
	if href == '' || platform_control_key {
		return none
	}
	mut serialized := dom.dom_url_parse(href, element.document().base_url(), 'UTF-8') or {
		return none
	}.serialize()
	if is_image_map_target {
		x := if trusted && offset_x > 0 { int(offset_x) } else { 0 }
		y := if trusted && offset_y > 0 { int(offset_y) } else { 0 }
		serialized += '?${x},${y}'
	}
	download := element.has_attribute('download')
	return HyperlinkActivationResult{
		url:              dom.URL{
			value: serialized
		}
		download:         download
		user_involvement: if download { .browser_ui } else { user_involvement }
	}
}

fn is_labelable_element(element &dom.Element) bool {
	if element.local_name() == 'input'
		&& ascii_lowercase_string(element.get_attribute_value('type')) == 'hidden' {
		return false
	}
	return element.local_name() in ['button', 'input', 'meter', 'output', 'progress', 'select',
		'textarea']
}

fn find_labelable_element_with_id(node &dom.Node, id string) ?&dom.Element {
	if element := node.as_element() {
		if element.get_attribute_value('id') == id && is_labelable_element(element) {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := find_labelable_element_with_id(child, id) {
			return element
		}
	}
	return none
}

fn find_first_labelable_element(node &dom.Node) ?&dom.Element {
	if element := node.as_element() {
		if is_labelable_element(element) {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := find_first_labelable_element(child) {
			return element
		}
	}
	return none
}

pub fn html_label_element_control(label &dom.HTMLLabelElement) ?&dom.Element {
	element := unsafe { &dom.Element(label) }
	root := element.as_node().root()
	if for_value := element.get_attribute('for') {
		return find_labelable_element_with_id(root, for_value)
	}
	for child in element.as_node().children_as_vector() {
		if control := find_first_labelable_element(child) {
			return control
		}
	}
	return none
}

pub struct FieldSetContext {
pub:
	disabled            bool
	inside_first_legend bool
}

pub fn html_fieldset_element_is_disabled(has_disabled_attribute bool, ancestor_contexts []FieldSetContext) bool {
	if has_disabled_attribute {
		return true
	}
	for context in ancestor_contexts {
		if context.disabled && !context.inside_first_legend {
			return true
		}
	}
	return false
}

fn collect_fieldset_listed_descendants(node &dom.Node) []&dom.Element {
	mut result := []&dom.Element{}
	for child in node.children_as_vector() {
		if element := child.as_element() {
			if element.local_name() in ['button', 'fieldset', 'input', 'object', 'output', 'select',
				'textarea'] {
				result << element
			}
		}
		result << collect_fieldset_listed_descendants(child)
	}
	return result
}

pub fn html_fieldset_element_elements(fieldset &dom.HTMLFieldSetElement) []&dom.Element {
	return collect_fieldset_listed_descendants(unsafe { &dom.Element(fieldset) }.as_node())
}

@[heap]
pub struct HTMLOutputElementModel {
pub:
	element &dom.HTMLOutputElement
mut:
	default_value_override_ ?string
	html_for_               string
}

pub fn HTMLOutputElementModel.create(element &dom.HTMLOutputElement) &HTMLOutputElementModel {
	return &HTMLOutputElementModel{
		element: element
	}
}

pub fn (mut output HTMLOutputElementModel) set_html_for(value string) {
	output.html_for_ = value
}

pub fn (output &HTMLOutputElementModel) html_for() []string {
	return relation_tokens(output.html_for_)
}

pub fn (output &HTMLOutputElementModel) default_value() string {
	return output.default_value_override_ or {
		unsafe { &dom.Element(output.element) }.as_node().descendant_text_content()
	}
}

pub fn (mut output HTMLOutputElementModel) set_default_value(value string) {
	if output.default_value_override_ == none {
		mut node := unsafe { &dom.Element(output.element) }.as_node()
		node.string_replace_all(value)
		return
	}
	output.default_value_override_ = value
}

pub fn (output &HTMLOutputElementModel) value() string {
	return unsafe { &dom.Element(output.element) }.as_node().descendant_text_content()
}

pub fn (mut output HTMLOutputElementModel) set_value(value string) {
	output.default_value_override_ = output.default_value()
	mut node := unsafe { &dom.Element(output.element) }.as_node()
	node.string_replace_all(value)
}

pub fn (mut output HTMLOutputElementModel) reset() {
	mut node := unsafe { &dom.Element(output.element) }.as_node()
	node.string_replace_all(output.default_value())
	output.default_value_override_ = none
}

pub fn (mut output HTMLOutputElementModel) clear() {
	output.default_value_override_ = output.default_value()
	mut node := unsafe { &dom.Element(output.element) }.as_node()
	node.string_replace_all('')
}
