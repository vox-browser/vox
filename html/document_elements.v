// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLBaseElement.{h,cpp}, HTMLMetaElement.{h,cpp},
// HTMLStyleElement.{h,cpp}, HTMLBodyElement.{h,cpp}, HTMLSourceElement.{h,cpp},
// HTMLAnchorElement.{h,cpp}, HTMLAreaElement.{h,cpp}, HTMLLabelElement.{h,cpp},
// HTMLFieldSetElement.{h,cpp}, and HTMLOutputElement.{h,cpp}.
module html

import aria
import color
import dom
import math

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
		frozen_base_url_: fallback_base_url
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

pub fn html_base_element_set_the_frozen_base_url(base &dom.HTMLBaseElement,
	old_base_url dom.URL) {
	mut mutable_base := unsafe { &dom.HTMLBaseElement(base) }
	mutable_base.set_the_frozen_base_url(old_base_url)
}

pub fn html_base_element_inserted(base &dom.HTMLBaseElement) {
	mut mutable_base := unsafe { &dom.HTMLBaseElement(base) }
	mutable_base.inserted()
}

pub fn html_base_element_removed_from(base &dom.HTMLBaseElement, old_parent ?&dom.Node, old_root &dom.Node) {
	mut mutable_base := unsafe { &dom.HTMLBaseElement(base) }
	mutable_base.removed_from_with_context(.yes, old_parent, old_root)
}

pub fn html_base_element_attribute_changed(base &dom.HTMLBaseElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	mut mutable_base := unsafe { &dom.HTMLBaseElement(base) }
	mutable_base.attribute_changed(name, old_value, value, namespace_)
}

pub fn html_base_element_href(base &dom.HTMLBaseElement) string {
	element := unsafe { &dom.Element(base) }
	href := element.get_attribute_value('href')
	url := dom.dom_url_parse(href, element.document().fallback_base_url(), element.document().encoding_or_default()) or { return href }
	return url.serialize()
}

pub fn set_html_base_element_href(base &dom.HTMLBaseElement, href string) {
	mut element := unsafe { &dom.Element(base) }
	element.set_attribute_value('href', href)
}

pub type MetaHttpEquivState = dom.MetaHttpEquivState

pub fn meta_http_equiv_state(value string) ?MetaHttpEquivState {
	return dom.meta_http_equiv_state(value)
}

pub struct MetaDocumentState {
pub mut:
	referrer_policy             ReferrerPolicy = .strict_origin_when_cross_origin
	pragma_set_default_language ?string
	theme_color                 ?string
	supported_color_schemes     []string
	supported_color_schemes_are_only bool
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

fn parse_meta_color_schemes(value string) ([]string, bool) {
	mut result := []string{}
	mut only := false
	for token in value.fields() {
		lower := ascii_lowercase_string(token)
		if lower == 'only' {
			only = true
		} else if lower in ['normal', 'light', 'dark'] && lower !in result {
			result << lower
		}
	}
	return result, only
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
			meta.update_referrer_policy()
		}
		'theme-color' {
			meta.document_state.theme_color = if content.trim_space() == '' {
				none
			} else {
				content
			}
		}
		'color-scheme' {
			schemes, only := parse_meta_color_schemes(content)
			meta.document_state.supported_color_schemes = schemes
			meta.document_state.supported_color_schemes_are_only = only
		}
		else {}
	}
}

pub fn (mut meta HTMLMetaElementModel) update_referrer_policy() {
	if !meta.in_document {
		return
	}
	content := meta.content_ or { return }
	if content == '' {
		return
	}
	policy := match ascii_lowercase_string(content) {
		'never' { ReferrerPolicy.no_referrer }
		'default' { ReferrerPolicy.strict_origin_when_cross_origin }
		'always' { ReferrerPolicy.unsafe_url }
		'origin-when-crossorigin' { ReferrerPolicy.origin_when_cross_origin }
		else { referrer_policy_from_string(content) or { return } }
	}
	meta.document_state.referrer_policy = policy
}

fn parse_meta_csp(input string) SerializedCSPPolicy {
	mut directives := []dom.SerializedCSPDirective{}
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
		directives << dom.SerializedCSPDirective{
			name: name
			value: parts[1..].clone()
		}
	}
	return dom.SerializedCSPPolicy{
		directives: directives
		disposition: .enforce
		source: .meta
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

pub fn html_meta_element_http_equiv_state(meta &dom.HTMLMetaElement) ?MetaHttpEquivState {
	return meta.http_equiv_state()
}

fn html_meta_element_update_referrer_policy(meta &dom.HTMLMetaElement) {
	element := unsafe { &dom.Element(meta) }
	if !element.as_node().in_a_document_tree() {
		return
	}
	content := element.get_attribute('content') or { return }
	if content == '' {
		return
	}
	policy := match ascii_lowercase_string(content) {
		'never' { ReferrerPolicy.no_referrer }
		'default' { ReferrerPolicy.strict_origin_when_cross_origin }
		'always' { ReferrerPolicy.unsafe_url }
		'origin-when-crossorigin' { ReferrerPolicy.origin_when_cross_origin }
		else { referrer_policy_from_string(content) or { return } }
	}
	mut document := unsafe { &dom.Document(element.document()) }
	// HTMLMetaElement.cpp:109 writes the element's own current Document,
	// independently of any temporary Window associated-document replacement.
	mut container := document.policy_container()
	container.referrer_policy = policy
	document.set_meta_referrer_policy(policy.to_string())
}

pub fn html_meta_element_update_metadata(meta &dom.HTMLMetaElement, old_name ?string) {
	element := unsafe { &dom.Element(meta) }
	name := ascii_lowercase_string(element.get_attribute_value('name'))
	mut document := unsafe { &dom.Document(element.document()) }
	if name == 'theme-color' {
		document.obtain_theme_color()
	} else if name == 'color-scheme' {
		document.obtain_supported_color_schemes()
	} else if name == 'referrer' {
		html_meta_element_update_referrer_policy(meta)
	}
	if previous := old_name {
		old_lower := ascii_lowercase_string(previous)
		if old_lower == 'theme-color' {
			document.obtain_theme_color()
		} else if old_lower == 'color-scheme' {
			document.obtain_supported_color_schemes()
		}
	}
}

pub fn html_meta_element_inserted(meta &dom.HTMLMetaElement) {
	mut mutable_meta := unsafe { &dom.HTMLMetaElement(meta) }
	mutable_meta.inserted()
}

pub fn html_meta_element_removed_from(meta &dom.HTMLMetaElement, old_parent ?&dom.Node, old_root &dom.Node) {
	mut mutable_meta := unsafe { &dom.HTMLMetaElement(meta) }
	mutable_meta.removed_from_with_context(.yes, old_parent, old_root)
}

pub fn html_meta_element_attribute_changed(meta &dom.HTMLMetaElement, local_name string, old_value ?string, value ?string, namespace_ ?string) {
	mut mutable_meta := unsafe { &dom.HTMLMetaElement(meta) }
	mutable_meta.attribute_changed(local_name, old_value, value, namespace_)
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
	hints.margin_top = first_body_margin(attributes, 'marginheight', 'topmargin', inherited_frame_attributes, 'marginheight')
	hints.margin_bottom = first_body_margin(attributes, 'marginheight', 'bottommargin', inherited_frame_attributes, 'marginheight')
	hints.margin_left = first_body_margin(attributes, 'marginwidth', 'leftmargin', inherited_frame_attributes, 'marginwidth')
	hints.margin_right = first_body_margin(attributes, 'marginwidth', 'rightmargin', inherited_frame_attributes, 'marginwidth')
	return hints
}

pub fn html_body_element_attribute_changed(body &dom.HTMLBodyElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	mut element := unsafe { &dom.Element(body) }
	element.attribute_changed(name, old_value, value, namespace_)
	if namespace_ != none {
		return
	}
	mut document := unsafe { &dom.Document(element.document()) }
	if name in ['link', 'alink', 'vlink'] {
		parsed := legacy_dom_color(value or { '' }) or { return }
		match name {
			'link' { document.set_normal_link_color(parsed) }
			'alink' { document.set_active_link_color(parsed) }
			'vlink' { document.set_visited_link_color(parsed) }
			else {}
		}
	} else if name == 'background' {
		mut mutable_body := unsafe { &dom.HTMLBodyElement(body) }
		mutable_body.background_url_ = document.encoding_parse_url(value or { '' })
	}
}

pub fn html_body_element_global_event_handlers_to_event_target(body &dom.HTMLBodyElement, event_name string) ?&dom.EventTarget {
	element := unsafe { &dom.Element(body) }
	if dom.is_window_reflecting_body_element_event_handler(event_name) {
		window := element.document().get_window() or { return none }
		return unsafe { &dom.EventTarget(window) }
	}
	return unsafe { &dom.EventTarget(element.as_node()) }
}

pub fn html_body_element_window_event_handlers_to_event_target(body &dom.HTMLBodyElement) ?&dom.EventTarget {
	window := unsafe { &dom.Element(body) }.document().get_window() or { return none }
	return unsafe { &dom.EventTarget(window) }
}

pub fn html_source_element_inserted_into_media(mut media HTMLMediaElement, parent_has_src_attribute bool) ! {
	if !parent_has_src_attribute && media.network_state() == .empty {
		media.select_resource()!
	}
}

fn update_image_children_of_picture(picture &dom.Node) {
	for child in picture.children_as_vector() {
		element := child.as_element() or { continue }
		if element.local_name() != 'img' {
			continue
		}
		mut image := html_image_element_model_for_dom_element(unsafe {
			&dom.HTMLImageElement(element)
		})
		image.update_the_image_data(true, false)
	}
}

pub fn html_source_element_inserted(source &dom.HTMLSourceElement) {
	mut element := unsafe { &dom.Element(source) }
	element.inserted()
	parent := element.as_node().parent_element() or { return }
	if mut media := html_media_element_for_dom_element(parent) {
		if !parent.has_attribute('src') && media.network_state() == .empty {
			mut candidates := []string{}
			mut types := []string{}
			for child in parent.as_node().children_as_vector() {
				if source_candidate := child.as_element() {
					if source_candidate.local_name() == 'source' {
						candidates << source_candidate.get_attribute_value('src')
						types << source_candidate.get_attribute_value('type')
					}
				}
			}
			media.set_typed_source_candidates(candidates, types)
			media.select_resource() or {}
		}
	}
	if parent.local_name() == 'picture' {
		update_image_children_of_picture(parent.as_node())
	}
}

pub fn html_source_element_moved_from(source &dom.HTMLSourceElement, old_parent ?&dom.Node) {
	mut element := unsafe { &dom.Element(source) }
	element.moved_from(old_parent)
	if old_parent_node := old_parent {
		if old_parent_element := old_parent_node.as_element() {
			if old_parent_element.local_name() == 'picture' {
				update_image_children_of_picture(old_parent_node)
			}
		}
	}
	if parent := element.as_node().parent_element() {
		if parent.local_name() == 'picture' {
			update_image_children_of_picture(parent.as_node())
		}
	}
}

pub fn html_source_element_removed_from(source &dom.HTMLSourceElement, old_parent ?&dom.Node, old_root &dom.Node) {
	mut element := unsafe { &dom.Element(source) }
	element.removed_from(old_parent, old_root)
	if old_parent_node := old_parent {
		if old_parent_element := old_parent_node.as_element() {
			if old_parent_element.local_name() == 'picture' {
				update_image_children_of_picture(old_parent_node)
			}
		}
	}
}

pub fn html_source_element_attribute_changed(source &dom.HTMLSourceElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	mut element := unsafe { &dom.Element(source) }
	element.attribute_changed(name, old_value, value, namespace_)
	if name !in ['srcset', 'sizes', 'media', 'type', 'width', 'height'] {
		return
	}
	parent := element.as_node().parent_element() or { return }
	if parent.local_name() != 'picture' {
		return
	}
	mut sibling := element.as_node().next_sibling()
	for sibling != none {
		current := sibling or { break }
		if image_element := current.as_element() {
			if image_element.local_name() == 'img' {
				mut image := html_image_element_model_for_dom_element(unsafe {
					&dom.HTMLImageElement(image_element)
				})
				image.update_the_image_data(true, false)
			}
		}
		sibling = current.next_sibling()
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

pub fn html_anchor_element_rel_list(anchor &dom.HTMLAnchorElement) &dom.DOMTokenList {
	if list := anchor.rel_list_ {
		return list
	}
	element := unsafe { &dom.Element(anchor) }
	list := dom.DOMTokenList.create(element, 'rel')
	mut mutable_anchor := unsafe { &dom.HTMLAnchorElement(anchor) }
	mutable_anchor.rel_list_ = list
	return list
}

pub fn html_area_element_rel_list(area &dom.HTMLAreaElement) &dom.DOMTokenList {
	if list := area.rel_list_ {
		return list
	}
	element := unsafe { &dom.Element(area) }
	list := dom.DOMTokenList.create(element, 'rel')
	mut mutable_area := unsafe { &dom.HTMLAreaElement(area) }
	mutable_area.rel_list_ = list
	return list
}

pub fn html_area_element_attribute_changed(area &dom.HTMLAreaElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	mut element := unsafe { &dom.Element(area) }
	element.attribute_changed(name, old_value, value, namespace_)
	if name == 'rel' {
		if list := area.rel_list_ {
			mut mutable_list := unsafe { &dom.DOMTokenList(list) }
			mutable_list.associated_attribute_changed(value or { '' })
		}
	}
	// href URL state is parsed on demand by the translated hyperlink mixin.
}

pub fn html_area_element_default_tab_index_value(_ &dom.HTMLAreaElement) i32 {
	return 0
}

pub fn html_area_element_default_role(area &dom.HTMLAreaElement) aria.Role {
	return if unsafe { &dom.Element(area) }.get_attribute_value('href') != '' {
		.link
	} else {
		.generic
	}
}

pub fn html_anchor_element_text(anchor &dom.HTMLAnchorElement) string {
	return unsafe { &dom.Element(anchor) }.as_node().descendant_text_content()
}

pub fn set_html_anchor_element_text(anchor &dom.HTMLAnchorElement, text string) {
	mut node := unsafe { &dom.Element(anchor) }.as_node()
	node.string_replace_all(text)
}

pub fn html_anchor_element_has_download_preference(anchor &dom.HTMLAnchorElement) bool {
	return unsafe { &dom.Element(anchor) }.has_attribute('download')
}

pub fn html_anchor_element_attribute_changed(anchor &dom.HTMLAnchorElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	mut element := unsafe { &dom.Element(anchor) }
	html_element_attribute_changed(unsafe { &dom.HTMLElement(anchor) }, name, old_value, value, namespace_)
	if name == 'href' {
		html_hyperlink_element_utils_set_the_url(element)
	} else if name == 'rel' {
		if list := anchor.rel_list_ {
			mut mutable_list := unsafe { &dom.DOMTokenList(list) }
			mutable_list.associated_attribute_changed(value or { '' })
		}
	}
}

pub fn html_anchor_element_has_activation_behavior(anchor &dom.HTMLAnchorElement) bool {
	return unsafe { &dom.Element(anchor) }.creates_a_hyperlink()
}

pub fn html_anchor_element_default_tab_index_value(_ &dom.HTMLAnchorElement) i32 {
	return 0
}

pub fn html_anchor_element_default_role(anchor &dom.HTMLAnchorElement) aria.Role {
	return if unsafe { &dom.Element(anchor) }.get_attribute_value('href') != '' {
		.link
	} else {
		.generic
	}
}

// https://html.spec.whatwg.org/multipage/image-maps.html#dom-map-areas
pub fn html_map_element_areas(map_element &dom.HTMLMapElement) &dom.HTMLCollection {
	if areas := map_element.areas_ {
		return areas
	}
	element := unsafe { &dom.Element(map_element) }
	areas := dom.HTMLCollection.create(unsafe { &dom.ParentNode(element) }, .descendants, fn (candidate &dom.Element) bool {
		return candidate.local_name() == 'area'
	}, fn (_ &dom.Element, _ &dom.Element) bool {
		return false
	})
	mut mutable_map := unsafe { &dom.HTMLMapElement(map_element) }
	mutable_map.areas_ = areas
	return areas
}

pub fn html_mod_element_default_role(element &dom.HTMLModElement) aria.Role {
	local_name := unsafe { &dom.Element(element) }.local_name()
	if local_name == 'del' {
		return .deletion
	}
	if local_name == 'ins' {
		return .insertion
	}
	panic('HTMLModElement has unexpected local name ${local_name}')
}

pub fn html_quote_element_default_role(element &dom.HTMLQuoteElement) aria.Role {
	local_name := unsafe { &dom.Element(element) }.local_name()
	if local_name == 'blockquote' {
		return .blockquote
	}
	if local_name == 'q' {
		return .generic
	}
	panic('HTMLQuoteElement has unexpected local name ${local_name}')
}

fn is_labelable_element(element &dom.Element) bool {
	if element.local_name() == 'input' && ascii_lowercase_string(element.get_attribute_value('type')) == 'hidden' {
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

pub fn html_label_element_for_(label &dom.HTMLLabelElement) ?string {
	return unsafe { &dom.Element(label) }.get_attribute('for')
}

pub fn html_label_element_set_being_activated(label &dom.HTMLLabelElement, activated bool) {
	mut label_element := unsafe { &dom.Element(label) }
	label_element.set_being_activated(activated)
	if control := html_label_element_control(label) {
		mut mutable_control := unsafe { control }
		mutable_control.set_being_activated(activated)
	}
}

pub fn html_label_element_has_activation_behavior(_ &dom.HTMLLabelElement) bool {
	return true
}

pub fn html_label_element_activation_behavior(label &dom.HTMLLabelElement, event &dom.Event) {
	if label.click_in_progress_ {
		return
	}
	control := html_label_element_control(label) or { return }
	if event.type_name() == 'click' && event.interface_ == .mouse_event {
		mouse_event := unsafe { &dom.MouseEvent(event) }
		if mouse_event.detail() == 1 {
			if selection := unsafe { &dom.Element(label) }.document().get_selection() {
				if !selection.is_collapsed() {
					return
				}
			}
		}
	}
	if control.is_actually_disabled() {
		return
	}
	mut mutable_label := unsafe { &dom.HTMLLabelElement(label) }
	mutable_label.click_in_progress_ = true
	if event.interface_ == .mouse_event {
		mouse_event := unsafe { &dom.MouseEvent(event) }
		mut click_event := mouse_event.clone()
		mut document := unsafe { &dom.Document(control.document()) }
		document.update_layout(.html_label_element_activation_behavior)
		if paintable := control.as_node().paintable() {
			if document.navigable() != none {
				viewport := document.viewport_rect()
				page_x := mouse_event.client_x() + viewport.x
				page_y := mouse_event.client_y() + viewport.y
				box_position := paintable.box_type_agnostic_position()
				click_event.set_offset_x(math.round(page_x - box_position.x()))
				click_event.set_offset_y(math.round(page_y - box_position.y()))
			}
		}
		click_event.set_bubbles(true)
		click_event.set_cancelable(true)
		click_event.set_composed(true)
		click_event.set_is_trusted(event.is_trusted())
		base_event := unsafe { &dom.Event(click_event) }
		unsafe { &dom.EventTarget(control.as_node()) }.dispatch_event(base_event)
	} else {
		click_event := dom.Event.create('click', dom.EventInit{
			bubbles: true
			cancelable: true
			composed: true
		})
		unsafe { &dom.EventTarget(control.as_node()) }.dispatch_event(click_event)
	}
	mutable_label.click_in_progress_ = false
	mut document := unsafe { &dom.Document(control.document()) }
	document.set_focused_area(control.as_node())
}

pub fn html_label_element_form(label &dom.HTMLLabelElement) ?&dom.HTMLFormElement {
	control := html_label_element_control(label) or { return none }
	if form_id := control.get_attribute('form') {
		return form_element_find_form_by_id(control.as_node().root(), form_id)
	}
	ancestor := form_element_nearest_ancestor(control, 'form') or { return none }
	return unsafe { &dom.HTMLFormElement(ancestor) }
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

pub fn html_field_set_element_is_disabled(fieldset &dom.HTMLFieldSetElement) bool {
	element := unsafe { &dom.Element(fieldset) }
	if element.has_attribute('disabled') {
		return true
	}
	mut ancestor := element.as_node().parent_node()
	for ancestor != none {
		current := ancestor or { break }
		if candidate := current.as_element() {
			if candidate.local_name() == 'fieldset' && candidate.has_attribute('disabled') {
				mut first_legend := ?&dom.Element(none)
				for child in candidate.as_node().children_as_vector() {
					if child_element := child.as_element() {
						if child_element.local_name() == 'legend' {
							first_legend = child_element
							break
						}
					}
				}
				if legend := first_legend {
					if !element.as_node().is_descendant_of(legend.as_node()) {
						return true
					}
				} else {
					return true
				}
			}
		}
		ancestor = current.parent_node()
	}
	return false
}

pub fn html_field_set_element_elements(fieldset &dom.HTMLFieldSetElement) []&dom.Element {
	return html_fieldset_element_elements(fieldset)
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
	if element.output_element_model_ != unsafe { nil } {
		return unsafe { &HTMLOutputElementModel(element.output_element_model_) }
	}
	model := &HTMLOutputElementModel{
		element: element
		html_for_: unsafe { &dom.Element(element) }.get_attribute_value('for')
	}
	mut mutable_element := unsafe { &dom.HTMLOutputElement(element) }
	mutable_element.output_element_model_ = voidptr(model)
	return model
}

pub fn (mut output HTMLOutputElementModel) form_associated_element_attribute_changed(name string, _ ?string, value ?string, _ ?string) {
	if name == 'for' {
		output.html_for_ = value or { '' }
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

pub fn (mut output HTMLOutputElementModel) reset_algorithm() {
	output.reset()
}

pub fn (mut output HTMLOutputElementModel) clear() {
	output.default_value_override_ = output.default_value()
	mut node := unsafe { &dom.Element(output.element) }.as_node()
	node.string_replace_all('')
}

pub fn (mut output HTMLOutputElementModel) clear_algorithm() {
	output.clear()
}
