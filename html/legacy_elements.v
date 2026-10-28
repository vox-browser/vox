// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLBRElement.cpp, HTMLDivElement.cpp, HTMLFontElement.cpp,
// HTMLFrameElement.cpp, HTMLFrameSetElement.cpp, HTMLHeadingElement.cpp,
// HTMLHRElement.cpp, HTMLHtmlElement.cpp, HTMLLegendElement.cpp,
// HTMLLIElement.cpp, HTMLMarqueeElement.cpp, HTMLOListElement.cpp,
// HTMLParagraphElement.cpp, HTMLTableCaptionElement.cpp,
// HTMLTableColElement.cpp, and HTMLUListElement.cpp.
module html

import color
import dom
import css
import strconv

pub struct LegacyDimension {
pub:
	value      f64
	percentage bool
}

pub struct LegacyPresentationalHints {
pub mut:
	color               ?dom.Color
	background_color    ?dom.Color
	font_family         ?string
	font_size           ?string
	text_align          ?string
	list_style_type     ?string
	clear               ?string
	caption_side        ?string
	width               ?LegacyDimension
	height              ?LegacyDimension
	margin_left         ?LegacyDimension
	margin_right        ?LegacyDimension
	margin_top          ?LegacyDimension
	margin_bottom       ?LegacyDimension
	border_style        ?string
	border_top_width    ?f64
	border_right_width  ?f64
	border_bottom_width ?f64
	border_left_width   ?f64
}

fn legacy_element_color(value string) ?dom.Color {
	parsed := color.parse_legacy_color_value(value) or { return none }
	return dom.Color{
		r: parsed.red
		g: parsed.green
		b: parsed.blue
		a: parsed.alpha
	}
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#rules-for-parsing-dimension-values
pub fn parse_legacy_dimension_value(input string) ?LegacyDimension {
	mut position := 0
	for position < input.len && is_number_ascii_whitespace(input[position]) {
		position++
	}
	if position == input.len || !is_number_ascii_digit(input[position]) {
		return none
	}
	start := position
	for position < input.len && is_number_ascii_digit(input[position]) {
		position++
	}
	if position < input.len && input[position] == `.` {
		position++
		for position < input.len && is_number_ascii_digit(input[position]) {
			position++
		}
	}
	number_end := position
	value := strconv.atof64(input[start..number_end]) or { return none }
	return LegacyDimension{
		value: value
		percentage: position < input.len && input[position] == `%`
	}
}

$if test {
	fn parse_current_dimension_value(value f64, remaining_input string) LegacyDimension {
		return LegacyDimension{
			value: value
			percentage: remaining_input.starts_with('%')
		}
	}
}

pub fn parse_dimension_value(input string) ?LegacyDimension {
	return parse_legacy_dimension_value(input)
}

pub fn parse_nonzero_dimension_value(input string) ?LegacyDimension {
	value := parse_dimension_value(input) or { return none }
	return if value.value == 0 { none } else { value }
}

pub fn parse_legacy_color_value(input string) ?dom.Color {
	return legacy_element_color(input)
}

$if test {
	fn parse_border(value string) u32 {
		parsed := strconv.parse_uint(value, 10, 32) or { return 0 }
		return u32(parsed)
	}
}

// https://html.spec.whatwg.org/multipage/rendering.html#rules-for-parsing-a-legacy-font-size
pub fn parse_legacy_font_size(input string) ?string {
	return css.parse_legacy_font_size(input)
}

// HTMLFontElement::parse_legacy_font_size().
pub fn html_font_element_parse_legacy_font_size(input string) ?string {
	return parse_legacy_font_size(input)
}

fn legacy_list_style_type(value string, ordered_only bool) ?string {
	match value {
		'1' {
			return 'decimal'
		}
		'a' {
			return 'lower-alpha'
		}
		'A' {
			return 'upper-alpha'
		}
		'i' {
			return 'lower-roman'
		}
		'I' {
			return 'upper-roman'
		}
		else {}
	}
	if ordered_only {
		return none
	}
	return match ascii_lowercase_string(value) {
		'none' { 'none' }
		'disc' { 'disc' }
		'circle' { 'circle' }
		'square' { 'square' }
		else { none }
	}
}

fn legacy_text_alignment(local_name string, value string) ?string {
	lower := ascii_lowercase_string(value)
	if lower !in ['left', 'right', 'center', 'justify'] {
		return none
	}
	if local_name == 'div' && lower != 'justify' {
		return 'libweb-${lower}'
	}
	return lower
}

pub fn is_legacy_presentational_hint(local_name string, attribute_name string) bool {
	return match local_name {
		'font' { attribute_name in ['color', 'face', 'size'] }
		'hr' { attribute_name in ['align', 'color', 'noshade', 'width', 'size'] }
		'marquee' { attribute_name in ['bgcolor', 'height', 'hspace', 'vspace', 'width'] }
		'li', 'ol', 'ul' { attribute_name == 'type' }
		'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'p', 'div' { attribute_name == 'align' }
		'br' { attribute_name == 'clear' }
		'caption' { attribute_name == 'align' }
		'col', 'colgroup' { attribute_name == 'width' }
		else { false }
	}
}

// Converts the legacy HTML rendering rules into CSS-neutral typed values. The
// CSS cascade bridge applies these as author presentational hints.
pub fn legacy_element_presentational_hints(local_name string, attributes map[string]string) LegacyPresentationalHints {
	mut hints := LegacyPresentationalHints{}
	match local_name {
		'font' {
			if value := attributes['color'] {
				hints.color = legacy_element_color(value)
			}
			if value := attributes['face'] {
				if value != '' {
					hints.font_family = value
				}
			}
			if value := attributes['size'] {
				hints.font_size = parse_legacy_font_size(value)
			}
		}
		'hr' {
			has_solid_border := 'color' in attributes || 'noshade' in attributes
			if has_solid_border {
				hints.border_style = 'solid'
			}
			if align := attributes['align'] {
				match ascii_lowercase_string(align) {
					'left' {
						hints.margin_left = LegacyDimension{
							value: 0
						}
					}
					'right' {
						hints.margin_right = LegacyDimension{
							value: 0
						}
					}
					'center' {
						hints.margin_left = LegacyDimension{
							value: 0
							percentage: true
						}
						hints.margin_right = LegacyDimension{
							value: 0
							percentage: true
						}
					}
					else {}
				}
			}
			if value := attributes['color'] {
				hints.color = legacy_element_color(value)
			}
			if value := attributes['size'] {
				if size := parse_non_negative_integer(value) {
					if has_solid_border {
						width := f64(size) / 2.0
						hints.border_top_width = width
						hints.border_right_width = width
						hints.border_bottom_width = width
						hints.border_left_width = width
					} else if size == 1 {
						hints.border_bottom_width = 0
					} else if size > 1 {
						hints.height = LegacyDimension{
							value: f64(size - 2)
						}
					}
				}
			}
			if value := attributes['width'] {
				hints.width = parse_legacy_dimension_value(value)
			}
		}
		'marquee' {
			if value := attributes['bgcolor'] {
				hints.background_color = legacy_element_color(value)
			}
			if value := attributes['height'] {
				hints.height = parse_legacy_dimension_value(value)
			}
			if value := attributes['width'] {
				hints.width = parse_legacy_dimension_value(value)
			}
			if value := attributes['hspace'] {
				dimension := parse_legacy_dimension_value(value)
				hints.margin_left = dimension
				hints.margin_right = dimension
			}
			if value := attributes['vspace'] {
				dimension := parse_legacy_dimension_value(value)
				hints.margin_top = dimension
				hints.margin_bottom = dimension
			}
		}
		'li', 'ul', 'ol' {
			if value := attributes['type'] {
				hints.list_style_type = legacy_list_style_type(value, local_name == 'ol')
			}
		}
		'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'p', 'div' {
			if value := attributes['align'] {
				hints.text_align = legacy_text_alignment(local_name, value)
			}
		}
		'br' {
			if value := attributes['clear'] {
				hints.clear = match ascii_lowercase_string(value) {
					'left' { 'left' }
					'right' { 'right' }
					'all', 'both' { 'both' }
					else { none }
				}
			}
		}
		'caption' {
			if attributes['align'] == 'bottom' {
				hints.caption_side = 'bottom'
			}
		}
		'col', 'colgroup' {
			if value := attributes['width'] {
				hints.width = parse_legacy_dimension_value(value)
			}
		}
		else {}
	}
	return hints
}

fn reflected_bounded_legacy_unsigned(element &dom.Element, name string, default_value u32) u32 {
	if string_value := element.get_attribute(name) {
		if value := parse_non_negative_integer(string_value) {
			if value <= 0x7fff_ffff {
				return value
			}
		}
	}
	return default_value
}

pub fn html_marquee_element_scroll_amount(element &dom.HTMLMarqueeElement) u32 {
	return reflected_bounded_legacy_unsigned(unsafe { &dom.Element(element) }, 'scrollamount', 6)
}

pub fn set_html_marquee_element_scroll_amount(element &dom.HTMLMarqueeElement, value u32) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('scrollamount', (if value > 0x7fff_ffff {
		u32(6)
	} else {
		value
	}).str())
}

pub fn html_marquee_element_scroll_delay(element &dom.HTMLMarqueeElement) u32 {
	return reflected_bounded_legacy_unsigned(unsafe { &dom.Element(element) }, 'scrolldelay', 85)
}

pub fn set_html_marquee_element_scroll_delay(element &dom.HTMLMarqueeElement, value u32) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('scrolldelay', (if value > 0x7fff_ffff {
		u32(85)
	} else {
		value
	}).str())
}

pub fn html_legend_element_form(element &dom.HTMLLegendElement) ?&dom.HTMLFormElement {
	legend_node := unsafe { &dom.Element(element) }.as_node()
	parent := legend_node.parent_element() or { return none }
	if parent.local_name() != 'fieldset' {
		return none
	}
	mut ancestor := parent.as_node().parent_node()
	for ancestor != none {
		current := ancestor or { break }
		if candidate := current.as_element() {
			if candidate.local_name() == 'form' {
				return unsafe { &dom.HTMLFormElement(candidate) }
			}
		}
		ancestor = current.parent_node()
	}
	return none
}

pub fn html_html_element_should_use_body_background(html_has_containment bool, body_has_containment bool, has_background_layers bool, background_color dom.Color) bool {
	return !html_has_containment && !body_has_containment && !has_background_layers && background_color.a == 0
}

pub fn html_html_element_should_use_body_background_properties(html_has_containment bool, body_has_containment bool, has_background_layers bool, background_color dom.Color) bool {
	return html_html_element_should_use_body_background(html_has_containment, body_has_containment, has_background_layers, background_color)
}

pub fn legacy_element_adjusted_display(local_name string, display string) string {
	if display == 'contents' && local_name in ['br', 'frame', 'frameset'] {
		return 'none'
	}
	if local_name == 'br' && display != 'none' {
		return 'inline'
	}
	return display
}

@[heap]
pub struct HTMLFrameElementModel {
pub mut:
	container &NavigableContainerModel
mut:
	event_target_ &dom.EventTarget
	event_counts_ map[string]int
}

pub fn HTMLFrameElementModel.create(base_url dom.URL, owner_origin dom.Origin) &HTMLFrameElementModel {
	mut container := NavigableContainerModel.create(base_url, owner_origin)
	container.set_potentially_delays_load_event(true)
	return &HTMLFrameElementModel{
		container: container
		event_target_: dom.EventTarget.new()
	}
}

pub fn (mut frame HTMLFrameElementModel) set_navigation_hook(hook ?EmbeddedNavigationHook) {
	frame.container.set_navigation_hook(hook)
}

pub fn (mut frame HTMLFrameElementModel) set_name(value string) {
	frame.container.set_name(value)
}

pub fn (mut frame HTMLFrameElementModel) set_src(value string, inclusive_ancestor_urls []dom.URL) ! {
	frame.container.set_src(value)
	if frame.container.content_navigable() != none {
		frame.process_the_frame_attributes(.no, inclusive_ancestor_urls)!
	}
}

pub fn (mut frame HTMLFrameElementModel) fire_event(name string) {
	frame.event_counts_[name]++
	frame.event_target_.dispatch_event(dom.Event.create(name, dom.EventInit{}))
}

pub fn (frame &HTMLFrameElementModel) event_count(name string) int {
	return frame.event_counts_[name]
}

pub fn (frame &HTMLFrameElementModel) default_tab_index_value() i32 {
	return 0
}

pub fn (mut frame HTMLFrameElementModel) inserted(in_document_tree bool, has_browsing_context bool, inclusive_ancestor_urls []dom.URL) ! {
	if !in_document_tree || !has_browsing_context {
		return
	}
	frame.container.create_new_child_navigable()
	frame.process_the_frame_attributes(.yes, inclusive_ancestor_urls)!
}

pub fn (mut frame HTMLFrameElementModel) process_the_frame_attributes(initial_insertion InitialInsertion, inclusive_ancestor_urls []dom.URL) ! {
	url := frame.container.shared_attribute_processing_steps(initial_insertion, inclusive_ancestor_urls) or { return }
	if initial_insertion == .yes && url.serialize() == 'about:blank' {
		frame.fire_event('load')
		return
	}
	frame.container.navigate_an_iframe_or_frame(url, .strict_origin_when_cross_origin, none, initial_insertion)!
}

pub fn (mut frame HTMLFrameElementModel) removed_from_document() {
	frame.container.destroy_the_child_navigable()
}

fn html_frame_element_model(frame &dom.HTMLFrameElement) &HTMLFrameElementModel {
	if frame.frame_element_model_ != unsafe { nil } {
		return unsafe { &HTMLFrameElementModel(frame.frame_element_model_) }
	}
	element := unsafe { &dom.Element(frame) }
	mut model := HTMLFrameElementModel.create(element.document().base_url(), element.document().origin())
	model.container.set_name(element.get_attribute_value('name'))
	model.container.set_src(element.get_attribute_value('src'))
	attach_navigable_container_load_event_delay_hook(element, model.container)
	mut mutable_frame := unsafe { &dom.HTMLFrameElement(frame) }
	mutable_frame.frame_element_model_ = model
	return model
}

pub fn html_frame_element_inserted(frame &dom.HTMLFrameElement) ! {
	mut element := unsafe { &dom.Element(frame) }
	element.inserted()
	mut model := html_frame_element_model(frame)
	model.inserted(element.as_node().in_a_document_tree(), element.document().get_browsing_context() != none, [])!
}

pub fn html_frame_element_removed_from(frame &dom.HTMLFrameElement, old_parent ?&dom.Node, old_root &dom.Node) {
	mut element := unsafe { &dom.Element(frame) }
	element.removed_from(old_parent, old_root)
	mut model := html_frame_element_model(frame)
	model.removed_from_document()
}

pub fn html_frame_element_attribute_changed(frame &dom.HTMLFrameElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	mut element := unsafe { &dom.Element(frame) }
	element.attribute_changed(name, old_value, value, namespace_)
	if namespace_ != none {
		return
	}
	mut model := html_frame_element_model(frame)
	if name == 'name' {
		model.set_name(value or { '' })
		return
	}
	if name == 'src' {
		model.set_src(value or { '' }, []) or {}
	}
}

pub fn html_frame_element_default_tab_index_value(_ &dom.HTMLFrameElement) i32 {
	return 0
}

pub fn html_frame_element_process_the_frame_attributes(frame &dom.HTMLFrameElement, initial_insertion InitialInsertion) ! {
	mut model := html_frame_element_model(frame)
	model.process_the_frame_attributes(initial_insertion, [])!
}

pub fn html_frame_element_model_for_testing(frame &dom.HTMLFrameElement) &HTMLFrameElementModel {
	return html_frame_element_model(frame)
}

pub fn html_frame_set_element_attribute_changed(frameset &dom.HTMLFrameSetElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	// DOM's tag dispatch runs the base global and frameset Window handler hooks.
	mut element := unsafe { &dom.Element(frameset) }
	element.attribute_changed(name, old_value, value, namespace_)
}

pub fn html_frame_set_element_global_event_handlers_to_event_target(frameset &dom.HTMLFrameSetElement, event_name string) ?&dom.EventTarget {
	element := unsafe { &dom.Element(frameset) }
	if dom.is_window_reflecting_body_element_event_handler(event_name) {
		window := element.document().get_window() or { return none }
		return unsafe { &dom.EventTarget(window) }
	}
	return unsafe { &dom.EventTarget(element.as_node()) }
}

pub fn html_frame_set_element_window_event_handlers_to_event_target(frameset &dom.HTMLFrameSetElement) ?&dom.EventTarget {
	window := unsafe { &dom.Element(frameset) }.document().get_window() or { return none }
	return unsafe { &dom.EventTarget(window) }
}
