// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the dependency-complete element algorithms in HTMLElement.cpp,
// HTMLTitleElement.cpp, HTMLLIElement.cpp, and HTMLOListElement.cpp.
module html

import aria
import dom
import math

pub enum AutocapitalizationHint {
	default_
	none_
	sentences
	words
	characters
}

pub enum AutocorrectionState {
	on
	off
}

pub type HiddenValue = bool | f64 | string

fn dom_element_from_html_element(element &dom.HTMLElement) &dom.Element {
	return unsafe { &dom.Element(element) }
}

pub fn html_element_is_focusable(element &dom.HTMLElement) bool {
	dom_element := dom_element_from_html_element(element)
	return dom_element.is_focusable() || dom_element.as_node().is_editing_host()
}

fn last_text_descendant(node &dom.Node) ?&dom.Text {
	mut result := ?&dom.Text(none)
	if node.is_text() {
		result = unsafe { &dom.Text(node) }
	}
	for child in node.children_as_vector() {
		if text := last_text_descendant(child) {
			result = text
		}
	}
	return result
}

pub fn html_element_attribute_changed(element &dom.HTMLElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	mut dom_element := dom_element_from_html_element(element)
	dom_element.attribute_changed(name, old_value, value, namespace_)
	mut mutable_element := unsafe { &dom.HTMLElement(element) }
	if name == 'nonce' && namespace_ == none {
		mutable_element.set_cryptographic_nonce(value or { '' })
	}
	if name == 'inert' {
		mutable_element.set_subtree_inertness(value != none)
	}
	if namespace_ == none && name == 'popover' && mutable_element.popover_visibility_state() == .showing && !popover_optional_string_equal(html_element_popover_value_to_state(old_value), html_element_popover_value_to_state(value)) {
		html_element_hide_popover(element, .yes, .yes, .no, .yes, none) or {}
	}
}

pub fn html_element_cloned(element &dom.HTMLElement, copy &dom.Node, clone_children bool) ! {
	dom_element_from_html_element(element).as_node().cloned(copy, clone_children)!
	copy_element := copy.as_element() or { return }
	if !copy_element.is_html_element() {
		return
	}
	mut copy_html_element := unsafe { &dom.HTMLElement(copy_element) }
	copy_html_element.set_cryptographic_nonce(element.cryptographic_nonce())
}

pub fn html_element_inserted(element &dom.HTMLElement) {
	mut dom_element := dom_element_from_html_element(element)
	dom_element.inserted()
	mut parent := dom_element.as_node().parent_element()
	for parent != none {
		ancestor := parent or { break }
		if ancestor.is_html_element() {
			ancestor_html := unsafe { &dom.HTMLElement(ancestor) }
			if ancestor_html.inert() && !dom_element.has_attribute('inert') {
				mut mutable_element := unsafe { &dom.HTMLElement(element) }
				mutable_element.set_subtree_inertness(true)
			}
			break
		}
		parent = ancestor.as_node().parent_element()
	}
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-translate
pub fn html_element_translate(element &dom.HTMLElement) bool {
	return dom_element_from_html_element(element).translation_mode() == .translate_enabled
}

pub fn set_html_element_translate(element &dom.HTMLElement, new_value bool) {
	html_element_set_translate(element, new_value)
}

pub fn html_element_set_translate(element &dom.HTMLElement, new_value bool) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('translate', if new_value { 'yes' } else { 'no' })
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-dir
pub fn html_element_dir(element &dom.HTMLElement) string {
	value := ascii_lowercase_string(dom_element_from_html_element(element).get_attribute_value('dir'))
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
	html_element_set_content_editable(element, value)!
}

pub fn html_element_set_content_editable(element &dom.HTMLElement, value string) ! {
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

pub fn html_element_rendered_text_fragment(element &dom.HTMLElement, input string) &dom.DocumentFragment {
	document := dom_element_from_html_element(element).document()
	fragment := document.create_document_fragment()
	mut fragment_node := unsafe { &dom.Node(fragment) }
	mut position := 0
	for position < input.len {
		start := position
		for position < input.len && input[position] !in [`\n`, `\r`] {
			position++
		}
		if position > start {
			fragment_node.append_child(document.create_text_node(input[start..position]).as_node()) or {}
		}
		for position < input.len && input[position] in [`\n`, `\r`] {
			if input[position] == `\r` && position + 1 < input.len && input[position + 1] == `\n` {
				position++
			}
			position++
			br := dom.create_element(document, 'br', ns_html, none, none, false) or { continue }
			fragment_node.append_child(br.as_node()) or {}
		}
	}
	return fragment
}

fn merge_html_element_text_with_next(node &dom.Node) {
	if !node.is_text() {
		return
	}
	next := node.next_sibling() or { return }
	if !next.is_text() {
		return
	}
	mut text := unsafe { &dom.Text(node) }
	next_text := unsafe { &dom.Text(next) }
	text.set_data(text.data() + next_text.data())
	mut mutable_next := unsafe { &dom.Node(next) }
	mutable_next.remove(false)
}

fn merge_with_the_next_text_node(node &dom.Text) {
	merge_html_element_text_with_next(unsafe { &dom.Node(node) })
}

pub fn html_element_set_outer_text(element &dom.HTMLElement, value string) ! {
	node := dom_element_from_html_element(element).as_node()
	mut parent := node.parent() or {
		return error('NoModificationAllowedError: setOuterText parent is null')
	}
	next := node.next_sibling()
	previous := node.previous_sibling()
	fragment := html_element_rendered_text_fragment(element, value)
	mut fragment_node := unsafe { &dom.Node(fragment) }
	if !fragment_node.has_children() {
		fragment_node.append_child(node.document().create_text_node('').as_node()) or {}
	}
	parent.replace_child(fragment_node, node)!
	if next_node := next {
		if preceding := next_node.previous_sibling() {
			merge_html_element_text_with_next(preceding)
		}
	}
	if previous_node := previous {
		merge_html_element_text_with_next(previous_node)
	}
}

pub fn html_element_set_inner_text(element &dom.HTMLElement, value string) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_inner_text(value)
}

struct RequiredLineBreakCount {
	count int
}

type RenderedTextItem = RequiredLineBreakCount | string

fn html_element_rendered_text_collection_steps(node &dom.Node) []RenderedTextItem {
	mut items := []RenderedTextItem{}
	for child in node.children_as_vector() {
		items << html_element_rendered_text_collection_steps(child)
	}
	layout_node := node.layout_node() or {
		return items
	}
	if layout_node.visibility_ != .visible {
		return items
	}
	if layout_node.content_visibility_ == .hidden {
		return items
	}
	if node.is_text() {
		mut text_items := []RenderedTextItem{}
		for chunk in layout_node.rendered_text_chunks() {
			text_items << RenderedTextItem(chunk)
		}
		return text_items
	}
	element := node.as_element() or { return items }
	if element.local_name() == 'br' {
		items << RenderedTextItem('\n')
		return items
	}
	display := layout_node.display()
	if display.is_table_cell() && node.next_sibling() != none {
		items << RenderedTextItem('\t')
	}
	if display.is_table_row() && node.next_sibling() != none {
		items << RenderedTextItem('\n')
	}
	if element.local_name() == 'p' {
		items.prepend(RenderedTextItem(RequiredLineBreakCount{ count: 2 }))
		items << RenderedTextItem(RequiredLineBreakCount{ count: 2 })
	}
	if display.is_block_outside() || display.is_table_caption() {
		items.prepend(RenderedTextItem(RequiredLineBreakCount{ count: 1 }))
		items << RenderedTextItem(RequiredLineBreakCount{ count: 1 })
	}
	return items
}

fn rendered_text_collection_steps(node &dom.Node) []RenderedTextItem {
	return html_element_rendered_text_collection_steps(node)
}

pub fn html_element_get_the_text_steps(element &dom.HTMLElement) string {
	node := dom_element_from_html_element(element).as_node()
	mut document := unsafe { &dom.Document(node.document()) }
	document.update_layout(.html_element_get_the_text_steps)
	if node.layout_node() == none {
		return node.descendant_text_content()
	}
	mut results := []RenderedTextItem{}
	for child in node.children_as_vector() {
		results << html_element_rendered_text_collection_steps(child)
	}
	for results.len > 0 && results[0] is RequiredLineBreakCount {
		results.delete(0)
	}
	for results.len > 0 && results.last() is RequiredLineBreakCount {
		results.delete_last()
	}
	mut output := ''
	mut index := 0
	for index < results.len {
		item := results[index]
		if item is string {
			output += item
			index++
			continue
		}
		mut maximum := (item as RequiredLineBreakCount).count
		index++
		for index < results.len && results[index] is RequiredLineBreakCount {
			count := (results[index] as RequiredLineBreakCount).count
			if count > maximum {
				maximum = count
			}
			index++
		}
		output += '\n'.repeat(maximum)
	}
	return output
}

pub fn html_element_inner_text(element &dom.HTMLElement) string {
	return html_element_get_the_text_steps(element)
}

pub fn html_element_outer_text(element &dom.HTMLElement) string {
	return html_element_get_the_text_steps(element)
}

fn html_element_is_body(element &dom.Element) bool {
	return element.is_html_element() && element.local_name() == 'body'
}

fn any_ancestor_establishes_a_fixed_position_containing_block(node &dom.LayoutNode) bool {
	mut ancestor := node.containing_block_
	for ancestor != none {
		current := ancestor or { break }
		if current.establishes_fixed_positioning_containing_block_ {
			return true
		}
		ancestor = current.containing_block_
	}
	return false
}

// https://drafts.csswg.org/cssom-view/#dom-htmlelement-scrollparent
pub fn html_element_scroll_parent(element &dom.HTMLElement) ?&dom.Element {
	dom_element := dom_element_from_html_element(element)
	mut document := unsafe { &dom.Document(dom_element.document()) }
	document.update_layout_if_needed_for_node(dom_element.as_node(), .html_element_scroll_parent)
	layout_node := dom_element.as_node().layout_node() or { return none }
	if dom_element.is_document_element() || html_element_is_body(dom_element) {
		return none
	}
	no_fixed_containing_block := !any_ancestor_establishes_a_fixed_position_containing_block(layout_node)
	if layout_node.is_fixed_position_ && no_fixed_containing_block {
		return none
	}
	mut ancestor := layout_node.containing_block_
	for ancestor != none {
		current := ancestor or { break }
		if current.is_viewport_ {
			scrolling_element := document.scrolling_element() or { return none }
			if !scrolling_element.as_node().is_closed_shadow_hidden_from(dom_element.as_node()) {
				return scrolling_element
			}
			return none
		}
		if ancestor_node := current.dom_node_ {
			if ancestor_element := ancestor_node.as_element() {
				if !ancestor_node.is_closed_shadow_hidden_from(dom_element.as_node()) && current.is_scroll_container_ {
					return ancestor_element
				}
			}
		}
		if current.is_fixed_position_ && no_fixed_containing_block {
			return none
		}
		ancestor = current.containing_block_
	}
	return none
}

// https://drafts.csswg.org/cssom-view-1/#dom-htmlelement-offsetparent
pub fn html_element_offset_parent(element &dom.HTMLElement) ?&dom.Element {
	dom_element := dom_element_from_html_element(element)
	mut document := unsafe { &dom.Document(dom_element.document()) }
	document.update_layout_if_needed_for_node(dom_element.as_node(), .html_element_offset_parent)
	layout_node := dom_element.as_node().layout_node() or { return none }
	if dom_element.is_document_element() || html_element_is_body(dom_element) {
		return none
	}
	no_fixed_containing_block := !any_ancestor_establishes_a_fixed_position_containing_block(layout_node)
	if layout_node.is_fixed_position_ && no_fixed_containing_block {
		return none
	}
	mut ancestor := dom_element.as_node().flat_tree_parent_element()
	for ancestor != none {
		current := ancestor or { break }
		current_layout := current.as_node().layout_node()
		closed_shadow_hidden := current.as_node().is_closed_shadow_hidden_from(dom_element.as_node())
		if closed_shadow_hidden {
			if ancestor_layout := current_layout {
				if ancestor_layout.is_fixed_position_ && no_fixed_containing_block {
					return none
				}
			}
		} else {
			if ancestor_layout := current_layout {
				if !no_fixed_containing_block && ancestor_layout.establishes_fixed_positioning_containing_block_ {
					return current
				}
				if no_fixed_containing_block && ancestor_layout.is_positioned_ {
					return current
				}
			}
			if no_fixed_containing_block {
				if html_element_is_body(current) {
					return current
				}
				if !layout_node.is_positioned_ && current.local_name() in ['td', 'th', 'table'] {
					return current
				}
			}
		}
		ancestor = current.as_node().flat_tree_parent_element()
	}
	return none
}

// https://www.w3.org/TR/cssom-view-1/#dom-htmlelement-offsettop
fn unite_layout_rect(first dom.Rect, second dom.Rect) dom.Rect {
	if first.width <= 0 || first.height <= 0 {
		return second
	}
	if second.width <= 0 || second.height <= 0 {
		return first
	}
	left := math.min(first.x, second.x)
	top := math.min(first.y, second.y)
	right := math.max(first.x + first.width, second.x + second.width)
	bottom := math.max(first.y + first.height, second.y + second.height)
	return dom.Rect{left, top, right - left, bottom - top}
}

enum PaintableBoxRectKind {
	content
	padding
	border
}

fn united_rect_for_continuation_chain(start &dom.LayoutNode, kind PaintableBoxRectKind) ?dom.Rect {
	mut result := ?dom.Rect(none)
	mut current := ?&dom.LayoutNode(start)
	for current != none {
		node := current or { break }
		if node.has_geometry_ {
			rect := paintable_box_rect_of_kind(node, node.border_box_, kind)
			if united := result {
				if rect.width > 0 && rect.height > 0 {
					result = unite_layout_rect(united, rect)
				}
			} else {
				result = rect
			}
		}
		current = node.continuation_next()
	}
	return result
}

fn paintable_box_rect_of_kind(node &dom.LayoutNode, border_box dom.Rect, kind PaintableBoxRectKind) dom.Rect {
	mut rect := border_box
	if kind == .padding || kind == .content {
		rect = dom.Rect{
			x: rect.x + node.box_model().border_left
			y: rect.y + node.box_model().border_top
			width: math.max(0.0, rect.width - node.box_model().border_left - node.box_model().border_right)
			height: math.max(0.0, rect.height - node.box_model().border_top - node.box_model().border_bottom)
		}
	}
	if kind == .content {
		rect = dom.Rect{
			x: rect.x + node.box_model().padding_left
			y: rect.y + node.box_model().padding_top
			width: math.max(0.0, rect.width - node.box_model().padding_left - node.box_model().padding_right)
			height: math.max(0.0, rect.height - node.box_model().padding_top - node.box_model().padding_bottom)
		}
	}
	return rect
}

fn paintable_box_absolute_united_border_box_rect(start &dom.LayoutNode) ?dom.Rect {
	return united_rect_for_continuation_chain(start, .border)
}

fn paintable_box_absolute_united_content_rect(start &dom.LayoutNode) ?dom.Rect {
	return united_rect_for_continuation_chain(start, .content)
}

fn paintable_box_absolute_united_padding_box_rect(start &dom.LayoutNode) ?dom.Rect {
	return united_rect_for_continuation_chain(start, .padding)
}

pub fn html_element_offset_top(element &dom.HTMLElement) int {
	dom_element := dom_element_from_html_element(element)
	if html_element_is_body(dom_element) {
		return 0
	}
	mut document := unsafe { &dom.Document(dom_element.document()) }
	document.update_layout_if_needed_for_node(dom_element.as_node(), .html_element_offset_top)
	layout_node := dom_element.as_node().layout_node() or { return 0 }
	if !layout_node.has_geometry_ {
		return 0
	}
	top_border_edge := (paintable_box_absolute_united_border_box_rect(layout_node) or {
		layout_node.border_box_
	}).y
	offset_parent := html_element_offset_parent(element) or { return int(top_border_edge / document.layout_coordinate_scale()) }
	parent_layout := offset_parent.as_node().layout_node() or { return int(top_border_edge / document.layout_coordinate_scale()) }
	if html_element_is_body(offset_parent) && !parent_layout.is_positioned_ {
		return int(top_border_edge / document.layout_coordinate_scale())
	}
	parent_padding_box := paintable_box_absolute_united_padding_box_rect(parent_layout) or {
		dom.Rect{ y: parent_layout.border_box_.y + parent_layout.box_model().border_top }
	}
	return int((top_border_edge - parent_padding_box.y) / document.layout_coordinate_scale())
}

// https://www.w3.org/TR/cssom-view-1/#dom-htmlelement-offsetleft
pub fn html_element_offset_left(element &dom.HTMLElement) int {
	dom_element := dom_element_from_html_element(element)
	if html_element_is_body(dom_element) {
		return 0
	}
	mut document := unsafe { &dom.Document(dom_element.document()) }
	document.update_layout_if_needed_for_node(dom_element.as_node(), .html_element_offset_left)
	layout_node := dom_element.as_node().layout_node() or { return 0 }
	if !layout_node.has_geometry_ {
		return 0
	}
	left_border_edge := (paintable_box_absolute_united_border_box_rect(layout_node) or {
		layout_node.border_box_
	}).x
	offset_parent := html_element_offset_parent(element) or { return int(left_border_edge / document.layout_coordinate_scale()) }
	parent_layout := offset_parent.as_node().layout_node() or { return int(left_border_edge / document.layout_coordinate_scale()) }
	if html_element_is_body(offset_parent) && !parent_layout.is_positioned_ {
		return int(left_border_edge / document.layout_coordinate_scale())
	}
	parent_padding_box := paintable_box_absolute_united_padding_box_rect(parent_layout) or {
		dom.Rect{ x: parent_layout.border_box_.x + parent_layout.box_model().border_left }
	}
	return int((left_border_edge - parent_padding_box.x) / document.layout_coordinate_scale())
}

// https://drafts.csswg.org/cssom-view/#dom-htmlelement-offsetwidth
pub fn html_element_offset_width(element &dom.HTMLElement) int {
	dom_element := dom_element_from_html_element(element)
	mut document := unsafe { &dom.Document(dom_element.document()) }
	document.update_layout_if_needed_for_node(dom_element.as_node(), .html_element_offset_width)
	layout_node := dom_element.as_node().layout_node() or { return 0 }
	return int(math.round((paintable_box_absolute_united_border_box_rect(layout_node) or {
		return 0
	}).width / document.layout_coordinate_scale()))
}

// https://drafts.csswg.org/cssom-view/#dom-htmlelement-offsetheight
pub fn html_element_offset_height(element &dom.HTMLElement) int {
	dom_element := dom_element_from_html_element(element)
	mut document := unsafe { &dom.Document(dom_element.document()) }
	document.update_layout_if_needed_for_node(dom_element.as_node(), .html_element_offset_height)
	layout_node := dom_element.as_node().layout_node() or { return 0 }
	return int(math.round((paintable_box_absolute_united_border_box_rect(layout_node) or {
		return 0
	}).height / document.layout_coordinate_scale()))
}

pub fn html_element_set_subtree_inertness(element &dom.HTMLElement, is_inert bool) {
	mut mutable_element := unsafe { &dom.HTMLElement(element) }
	mutable_element.set_subtree_inertness(is_inert)
}

// https://html.spec.whatwg.org/multipage/webappapis.html#fire-a-synthetic-pointer-event
pub fn html_element_fire_a_synthetic_pointer_event(element &dom.HTMLElement, type_ string, target &dom.Element, not_trusted bool) bool {
	_ = element
	pointer_event := dom.PointerEvent.create(type_, dom.PointerEventInit{
		MouseEventInit: dom.MouseEventInit{
			EventModifierInit: dom.EventModifierInit{
				UIEventInit: dom.UIEventInit{
					EventInit: dom.EventInit{
						bubbles: true
						cancelable: true
						composed: true
					}
				}
			}
		}
	})
	mut event := unsafe { &dom.Event(pointer_event) }
	if not_trusted {
		event.set_is_trusted(false)
	}
	return dom.event_target_dispatch_event(unsafe { &dom.EventTarget(target.as_node()) }, event)
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-click
pub fn html_element_click(element &dom.HTMLElement) {
	dom_element := dom_element_from_html_element(element)
	if dom_element.is_actually_disabled() || element.click_in_progress() {
		return
	}
	mut mutable_element := unsafe { &dom.HTMLElement(element) }
	mutable_element.set_click_in_progress(true)
	html_element_fire_a_synthetic_pointer_event(element, 'click', dom_element, true)
	mutable_element.set_click_in_progress(false)
}

pub fn html_element_labels(element &dom.HTMLElement) ?&dom.NodeList {
	dom_element := dom_element_from_html_element(element)
	if !is_labelable_element(dom_element) && !html_element_is_form_associated_custom_element(element) {
		return none
	}
	if labels := element.labels_list() {
		return labels
	}
	labels := dom.LiveNodeList.create(dom_element.as_node().root(), .descendants, fn [element] (node &dom.Node) bool {
		candidate := node.as_element() or { return false }
		if !candidate.is_html_element() || candidate.local_name() != 'label' {
			return false
		}
		control := html_label_element_control(unsafe { &dom.HTMLLabelElement(candidate) }) or {
			return false
		}
		return voidptr(control) == voidptr(dom_element_from_html_element(element))
	})
	mut mutable_element := unsafe { &dom.HTMLElement(element) }
	mutable_element.set_labels_list(labels)
	return labels
}

fn html_element_accessible_name(element &dom.Element) string {
	return element.as_node().accessible_name(element.document(), .no) or { '' }
}

fn html_element_explicit_role(element &dom.Element) ?aria.Role {
	value := element.get_attribute('role') or { return none }
	for token in value.fields() {
		role := aria.role_from_string(token) or { continue }
		if !aria.is_abstract_role(role) {
			return match role {
				.directory { aria.Role.list }
				.img { aria.Role.image }
				.presentation { aria.Role.none_ }
				else { role }
			}
		}
	}
	return none
}

pub fn html_element_default_role(element &dom.HTMLElement) ?aria.Role {
	dom_element := dom_element_from_html_element(element)
	name := dom_element.local_name()
	match name {
		'address', 'hgroup' {
			return .group
		}
		'article' {
			return .article
		}
		'aside' {
			mut ancestor := dom_element.as_node().parent_element()
			for ancestor != none {
				candidate := ancestor or { break }
				if candidate.local_name() in ['article', 'aside', 'nav', 'section'] && html_element_accessible_name(dom_element) == '' {
					return .generic
				}
				ancestor = candidate.as_node().parent_element()
			}
			return .complementary
		}
		'b', 'bdi', 'bdo', 'i', 'samp', 'small', 'u' {
			return .generic
		}
		'code' {
			return .code
		}
		'dd' {
			return .definition
		}
		'dir' {
			return .list
		}
		'dt', 'dfn' {
			return .term
		}
		'em' {
			return .emphasis
		}
		'figure' {
			return .figure
		}
		'footer', 'header' {
			mut ancestor := dom_element.as_node().parent_element()
			for ancestor != none {
				candidate := ancestor or { break }
				mut within_sectioning_ancestor := candidate.local_name() in ['article', 'aside',
					'main', 'nav', 'section']
				if role := html_element_explicit_role(candidate) {
					within_sectioning_ancestor = within_sectioning_ancestor || role in [
						.article,
						.complementary,
						.main,
						.navigation,
						.region,
					]
				}
				if within_sectioning_ancestor {
					return if name == 'footer' {
						aria.Role.sectionfooter
					} else {
						aria.Role.sectionheader
					}
				}
				ancestor = candidate.as_node().parent_element()
			}
			return if name == 'footer' { aria.Role.contentinfo } else { aria.Role.banner }
		}
		'main' {
			return .main
		}
		'mark' {
			return .mark
		}
		'nav' {
			return .navigation
		}
		's' {
			return .deletion
		}
		'search' {
			return .search
		}
		'section' {
			return if html_element_accessible_name(dom_element) == '' {
				aria.Role.generic
			} else {
				aria.Role.region
			}
		}
		'strong' {
			return .strong
		}
		'sub' {
			return .subscript
		}
		'summary' {
			return .button
		}
		'sup' {
			return .superscript
		}
		else {
			return none
		}
	}
}

pub fn html_element_did_receive_focus(element &dom.HTMLElement) {
	dom_element := dom_element_from_html_element(element)
	state := html_element_content_editable(element)
	if state !in ['true', 'plaintext-only'] {
		return
	}
	mut manager := dom_element.document().editing_host_manager()
	manager.set_active_contenteditable_element(dom_element.as_node())
	if selection := dom_element.document().get_selection() {
		if range := selection.range() {
			if dom_element.as_node().is_inclusive_ancestor_of(range.start_container()) || dom_element.as_node().is_inclusive_ancestor_of(range.end_container()) {
				return
			}
		}
	}
	if text := last_text_descendant(dom_element.as_node()) {
		manager.set_selection_anchor(unsafe { &dom.Node(text) }, text.length())
	} else {
		manager.set_selection_anchor(dom_element.as_node(), 0)
	}
}

pub fn html_element_did_lose_focus(element &dom.HTMLElement) {
	if html_element_content_editable(element) !in ['true', 'plaintext-only'] {
		return
	}
	mut manager := dom_element_from_html_element(element).document().editing_host_manager()
	manager.set_active_contenteditable_element(none)
}

pub fn html_element_removed_from(element &dom.HTMLElement, old_parent ?&dom.Node, old_root &dom.Node) {
	mut dom_element := dom_element_from_html_element(element)
	dom_element.removed_from(old_parent, old_root)
	if html_element_popover(element) != none {
		html_element_hide_popover(element, .no, .no, .no, .yes, none) or {}
	}
	if parent_node := old_parent {
		mut parent_element := parent_node.as_element()
		if parent_element == none {
			parent_element = parent_node.parent_element()
		}
		if parent := parent_element {
			if parent.is_html_element() && unsafe { &dom.HTMLElement(parent) }.inert() && !dom_element.has_attribute('inert') {
				mut mutable_element := unsafe { &dom.HTMLElement(element) }
				mutable_element.set_subtree_inertness(false)
			}
		}
	}
}

pub fn html_element_is_form_associated_custom_element(element &dom.HTMLElement) bool {
	dom_element := dom_element_from_html_element(element)
	definition := dom.look_up_custom_element_definition(dom_element.custom_element_registry(), dom_element.namespace_uri(), dom_element.local_name(), dom_element.custom_element_is_value()) or {
		return false
	}
	return definition.form_associated()
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#dom-attachinternals
pub fn html_element_attach_internals(element &dom.HTMLElement) !&ElementInternals {
	dom_element := dom_element_from_html_element(element)
	if dom_element.custom_element_is_value() != none {
		return error('NotSupportedError: ElementInternals cannot be attached to a customized built-in element')
	}
	definition := dom.look_up_custom_element_definition(dom_element.custom_element_registry(), dom_element.namespace_uri(), dom_element.local_name(), none) or {
		return error('NotSupportedError: ElementInternals cannot be attached to an element that is not a custom element')
	}
	if definition.disable_internals() {
		return error('NotSupportedError: ElementInternals are disabled for this custom element')
	}
	if element.attached_internals_handle() != unsafe { nil } {
		return error('NotSupportedError: ElementInternals already attached')
	}
	if dom_element.custom_element_state_ !in [.precustomized, .custom] {
		return error('NotSupportedError: Custom element is in an invalid state to attach ElementInternals')
	}
	internals := ElementInternals.create(element)
	mut mutable_element := unsafe { &dom.HTMLElement(element) }
	mutable_element.set_attached_internals_handle(voidptr(internals))
	return internals
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
	html_element_set_hidden(element, value)
}

pub fn html_element_set_hidden(element &dom.HTMLElement, value HiddenValue) {
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
	if dom_element.local_name() == 'object' && ascii_lowercase_string(dom_element.get_attribute_value('type')) == 'image' {
		return true
	}
	return dom_element.local_name() == 'a' && dom_element.has_attribute('href')
}

pub fn set_html_element_draggable(element &dom.HTMLElement, value bool) {
	html_element_set_draggable(element, value)
}

pub fn html_element_set_draggable(element &dom.HTMLElement, value bool) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('draggable', if value { 'true' } else { 'false' })
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-spellcheck
pub fn html_element_spellcheck(element &dom.HTMLElement) bool {
	dom_element := dom_element_from_html_element(element)
	if value := dom_element.get_attribute('spellcheck') {
		if value == '' || ascii_lowercase_string(value) == 'true' {
			return true
		}
		if ascii_lowercase_string(value) == 'false' {
			return false
		}
	}
	is_text_control := dom_element.local_name() == 'textarea' || (dom_element.local_name() == 'input' && ascii_lowercase_string(dom_element.get_attribute('type') or { 'text' }) in [
		'text',
		'search',
		'tel',
		'url',
		'email',
		'password',
	])
	if dom_element.as_node().is_editable_or_editing_host() || is_text_control {
		return true
	}
	if parent := dom_element.as_node().parent_element() {
		if parent.is_html_element() {
			return html_element_spellcheck(unsafe { &dom.HTMLElement(parent) })
		}
	}
	return false
}

pub fn html_element_set_spellcheck(element &dom.HTMLElement, value bool) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('spellcheck', if value { 'true' } else { 'false' })
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-writingsuggestions
pub fn html_element_writing_suggestions(element &dom.HTMLElement) string {
	dom_element := dom_element_from_html_element(element)
	if value := dom_element.get_attribute('writingsuggestions') {
		return if ascii_lowercase_string(value) == 'false' { 'false' } else { 'true' }
	}
	if parent := dom_element.as_node().parent_element() {
		if parent.is_html_element() && html_element_writing_suggestions(unsafe { &dom.HTMLElement(parent) }) == 'false' {
			return 'false'
		}
	}
	return 'true'
}

pub fn set_html_element_writing_suggestions(element &dom.HTMLElement, value string) {
	html_element_set_writing_suggestions(element, value)
}

pub fn html_element_set_writing_suggestions(element &dom.HTMLElement, value string) {
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
	html_element_set_autocapitalize(element, value)
}

pub fn html_element_set_autocapitalize(element &dom.HTMLElement, value string) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('autocapitalize', value)
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-autocorrect
pub fn html_element_autocorrect(element &dom.HTMLElement, form_owner ?&dom.HTMLElement) bool {
	return html_element_used_autocorrection_state(element, form_owner) == .on
}

pub fn html_element_used_autocorrection_state(element &dom.HTMLElement, form_owner ?&dom.HTMLElement) AutocorrectionState {
	dom_element := dom_element_from_html_element(element)
	if dom_element.local_name() == 'input' {
		type_ := ascii_lowercase_string(dom_element.get_attribute_value('type'))
		if type_ in ['url', 'email', 'password'] {
			return .off
		}
	}
	if value := dom_element.get_attribute('autocorrect') {
		return if ascii_lowercase_string(value) == 'off' { .off } else { .on }
	}
	if owner := form_owner {
		if value := owner.get_attribute('autocorrect') {
			return if ascii_lowercase_string(value) == 'off' { .off } else { .on }
		}
	}
	return .on
}

pub fn set_html_element_autocorrect(element &dom.HTMLElement, value bool) {
	html_element_set_autocorrect(element, value)
}

pub fn html_element_set_autocorrect(element &dom.HTMLElement, value bool) {
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

pub fn html_title_element_children_changed(element &dom.HTMLTitleElement, metadata dom.ChildrenChangedMetadata) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.children_changed(metadata)
	navigable := dom_element.as_node().navigable() or { return }
	if !navigable.is_traversable() {
		return
	}
	document := dom_element.document()
	if document == unsafe { nil } || document.page() == unsafe { nil } {
		return
	}
	mut page := unsafe { &dom.Page(document.page()) }
	page.client_page_did_change_title(document.title())
}

pub fn html_slot_element_attribute_changed(slot &dom.HTMLSlotElement, local_name string, old_value ?string, value ?string, namespace_ ?string) {
	mut element := unsafe { &dom.Element(slot) }
	element.attribute_changed(local_name, old_value, value, namespace_)
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

pub fn html_li_element_attribute_changed(element &dom.HTMLLIElement, local_name string, old_value ?string, value ?string, namespace_ ?string) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.attribute_changed(local_name, old_value, value, namespace_)
}

pub fn htmlli_element_attribute_changed(element &dom.HTMLLIElement, local_name string, old_value ?string, value ?string, namespace_ ?string) {
	html_li_element_attribute_changed(element, local_name, old_value, value, namespace_)
}

pub fn htmlli_element_value(element &dom.HTMLLIElement) i32 {
	return html_li_element_value(element)
}

pub fn htmlli_element_set_value(element &dom.HTMLLIElement, value i32) {
	set_html_li_element_value(element, value)
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

pub fn html_olist_element_is_presentational_hint(_ &dom.HTMLOListElement, name string) bool {
	return name == 'type'
}

// The compact style bridge consumes the resolved list-style-type string.
pub fn html_olist_element_apply_presentational_hints(element &dom.HTMLOListElement) ?string {
	value := unsafe { &dom.Element(element) }.get_attribute('type') or { return none }
	return match value {
		'1' { 'decimal' }
		'a' { 'lower-alpha' }
		'A' { 'upper-alpha' }
		'i' { 'lower-roman' }
		'I' { 'upper-roman' }
		else { none }
	}
}

pub fn html_olist_element_attribute_changed(element &dom.HTMLOListElement, local_name string, old_value ?string, value ?string, namespace_ ?string) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.attribute_changed(local_name, old_value, value, namespace_)
}

pub fn htmlol_list_element_attribute_changed(element &dom.HTMLOListElement, local_name string, old_value ?string, value ?string, namespace_ ?string) {
	html_olist_element_attribute_changed(element, local_name, old_value, value, namespace_)
}

pub fn htmlol_list_element_start(element &dom.HTMLOListElement) i32 {
	return html_olist_element_start(element)
}

pub fn htmlol_list_element_set_start(element &dom.HTMLOListElement, value i32) {
	set_html_olist_element_start(element, value)
}

pub fn htmlol_list_element_starting_value(element &dom.HTMLOListElement) i32 {
	return html_olist_element_starting_value(element)
}

// Receiver-spelled aliases mirror HTMLOListElement exactly for the upstream
// method inventory. Keep the shorter historical names above for callers.
pub fn htmlo_list_element_attribute_changed(element &dom.HTMLOListElement, local_name string, old_value ?string, value ?string, namespace_ ?string) {
	html_olist_element_attribute_changed(element, local_name, old_value, value, namespace_)
}

pub fn htmlo_list_element_start(element &dom.HTMLOListElement) i32 {
	return html_olist_element_start(element)
}

pub fn htmlo_list_element_set_start(element &dom.HTMLOListElement, value i32) {
	set_html_olist_element_start(element, value)
}

pub fn htmlo_list_element_starting_value(element &dom.HTMLOListElement) i32 {
	return html_olist_element_starting_value(element)
}

// https://html.spec.whatwg.org/multipage/sections.html#get-an-element's-computed-heading-level
pub fn html_element_computed_heading_level(element &dom.HTMLElement) u32 {
	dom_element := dom_element_from_html_element(element)
	mut level := match dom_element.local_name() {
		'h1' { u32(1) }
		'h2' { u32(2) }
		'h3' { u32(3) }
		'h4' { u32(4) }
		'h5' { u32(5) }
		'h6' { u32(6) }
		else { panic('computed heading level requires an h1-h6 element') }
	}
	level += html_element_computed_heading_offset(element)
	return if level > 9 { u32(9) } else { level }
}

pub fn html_heading_element_computed_heading_level(element &dom.HTMLHeadingElement) u32 {
	return html_element_computed_heading_level(unsafe { &dom.HTMLElement(element) })
}

pub fn html_heading_element_heading_level(element &dom.HTMLHeadingElement) u32 {
	return html_heading_element_computed_heading_level(element)
}

pub fn html_element_computed_heading_offset(element &dom.HTMLElement) u32 {
	mut offset := u32(0)
	mut inclusive_ancestor := ?&dom.Node(dom_element_from_html_element(element).as_node())
	for inclusive_ancestor != none {
		ancestor := inclusive_ancestor or { break }
		if ancestor_element := ancestor.as_element() {
			if ancestor_element.is_html_element() {
				if value := ancestor_element.get_attribute('headingoffset') {
					if next_offset := parse_non_negative_integer(value) {
						offset += next_offset
					}
				}
				if ancestor_element.has_attribute('headingreset') {
					return offset
				}
			}
		}
		inclusive_ancestor = ancestor.flat_tree_parent()
	}
	return offset
}
