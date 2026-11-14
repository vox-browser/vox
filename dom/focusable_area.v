// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Element::is_focusable() and Element::meets_focusable_area_rendering_requirements() with the
// is_focusable() overrides of HTMLElement, HTMLAnchorElement, HTMLAreaElement, HTMLButtonElement, HTMLDialogElement,
// HTMLIFrameElement, HTMLInputElement, HTMLMediaElement, HTMLObjectElement, HTMLSelectElement, HTMLSummaryElement,
// and HTMLTextAreaElement, and the image map association HTMLAreaElement's focusability depends on. V elements share
// one DOM type, so the virtual overrides dispatch on the element's HTML local name.
module dom

fn element_has_valid_tabindex(e &Element) bool {
	return parse_html_integer(e.get_attribute_value('tabindex')) != none
}

pub fn (e &Element) meets_focusable_area_rendering_requirements() bool {
	// https://html.spec.whatwg.org/multipage/interaction.html#focusable-area
	// Elements can only be focusable areas if they are being rendered, delegating their rendering to
	// their children, or being used as relevant canvas fallback content. Reject display: none
	// subtrees without forcing layout; display: contents is intentionally allowed by this check.
	if !e.as_node().is_connected() {
		return false
	}
	return e.document().update_style_for_element(e, true)
}

// Element::is_focusable().
fn element_base_is_focusable(e &Element) bool {
	return element_has_valid_tabindex(e) && e.meets_focusable_area_rendering_requirements()
}

// HTMLElement::is_focusable().
fn html_element_base_is_focusable(e &Element) bool {
	return (element_base_is_focusable(e) || e.as_node().is_editing_host())
		&& e.meets_focusable_area_rendering_requirements()
}

pub fn (e &Element) is_focusable() bool {
	if !e.is_html_element() {
		return element_base_is_focusable(e)
	}
	return match e.local_name() {
		// https://html.spec.whatwg.org/multipage/interaction.html#the-tabindex-attribute:the-a-element
		'a' {
			(html_element_base_is_focusable(e) || e.has_attribute('href'))
				&& e.meets_focusable_area_rendering_requirements()
		}
		'area' {
			html_area_element_is_focusable(e)
		}
		'button', 'select', 'textarea' {
			!e.is_actually_disabled() && e.meets_focusable_area_rendering_requirements()
		}
		'input' {
			to_ascii_lowercase(e.get_attribute_value('type')) != 'hidden' && !e.is_actually_disabled()
				&& e.meets_focusable_area_rendering_requirements()
		}
		'dialog', 'iframe', 'object', 'audio', 'video' {
			e.meets_focusable_area_rendering_requirements()
		}
		'summary' {
			(html_element_base_is_focusable(e) || html_summary_element_is_summary_for_its_parent_details(e))
				&& e.meets_focusable_area_rendering_requirements()
		}
		else {
			html_element_base_is_focusable(e)
		}
	}
}

// Author summaries and the user-agent fallback share activation and focus behavior.
pub fn (summary &HTMLSummaryElement) associated_details_element() ?&HTMLDetailsElement {
	element := unsafe { &Element(summary) }
	parent := element.as_node().parent_element() or { return none }
	if is_html_element_with_local_name(parent, 'details') {
		for child in parent.as_node().children_as_vector() {
			if child_element := child.as_element() {
				if is_html_element_with_local_name(child_element, 'summary') {
					if voidptr(child_element) == voidptr(element) {
						return unsafe { &HTMLDetailsElement(parent) }
					}
					break
				}
			}
		}
	}
	if shadow_root := element.as_node().root().as_shadow_root() {
		if shadow_root.is_user_agent_internal() {
			if host := shadow_root.host() {
				if is_html_element_with_local_name(host, 'details') {
					details := unsafe { &HTMLDetailsElement(host) }
					if default_summary := details.default_summary_ {
						if voidptr(default_summary) == voidptr(summary) {
							return details
						}
					}
				}
			}
		}
	}
	return none
}

// HTMLSummaryElement::is_summary_for_its_parent_details().
fn html_summary_element_is_summary_for_its_parent_details(summary &Element) bool {
	summary_element := unsafe { &HTMLSummaryElement(summary) }
	return summary_element.associated_details_element() != none
}

// HTMLAreaElement::is_focusable().
fn html_area_element_is_focusable(area &Element) bool {
	// NB: Platform conventions decide whether an area element without a tabindex attribute is a focusable area. Like
	//     other engines, only area elements that create a hyperlink are considered focusable areas.
	if !area.creates_a_hyperlink() && !element_has_valid_tabindex(area) {
		return false
	}

	// The shapes of area elements in an image map associated with an img element that is being rendered and is not
	// inert.
	// NB: Area elements are never rendered themselves, so the rendering and inertness requirements apply to an
	//     associated image element instead.
	mut ancestor := area.as_node().parent_element()
	for {
		candidate := ancestor or { return false }
		if is_html_element_with_local_name(candidate, 'map') {
			return html_map_element_first_image_with_focusable_shapes(candidate) != none
		}
		ancestor = candidate.as_node().parent_element()
	}
	return false
}

// HTMLImageElement.cpp's parse_hash_name_reference_to_map_element(), the rules for parsing a hash-name reference to
// a map element.
fn parse_hash_name_reference_to_map_element(value string, scope &Node) ?&Element {
	// 1. If the string being parsed does not contain a U+0023 NUMBER SIGN character, or if the first such character
	//    in the string is the last character in the string, then return null.
	hash_offset := value.index('#') or { return none }
	if hash_offset == value.len - 1 {
		return none
	}

	// 2. Let s be the string from the character immediately after the first U+0023 NUMBER SIGN character in the
	//    string being parsed up to the end of that string.
	s := value[hash_offset + 1..]

	// 3. Return the first element of type type in scope's tree, in tree order, that has an id or name attribute
	//    whose value is s, or null if there is no such element.
	root := scope.root()
	mut node := ?&Node(root)
	for node != none {
		current := node or { break }
		if element := current.as_element() {
			// NB: s is never empty, so an absent attribute cannot match it.
			if is_html_element_with_local_name(element, 'map')
				&& (element.get_attribute_value('id') == s || element.get_attribute_value('name') == s) {
				return element
			}
		}
		node = current.next_in_pre_order(root)
	}
	return none
}

// https://html.spec.whatwg.org/multipage/image-maps.html#image-map-processing-model
// HTMLImageElement::associated_map_element().
fn html_image_element_associated_map_element(image &Element) ?&Element {
	// If an img element has a usemap attribute specified, user agents must process it as follows:
	usemap := image.get_attribute('usemap') or { return none }

	// 1. Parse the attribute's value using the rules for parsing a hash-name reference to a map element, with the
	//    element as the context node. This will return either an element (the map) or null.
	// 2. If that returned null, then return. The image is not associated with an image map after all.
	return parse_hash_name_reference_to_map_element(usemap, image.as_node())
}

// HTMLMapElement::first_image_with_focusable_shapes(): the first img element in tree order that uses the image map
// and is being rendered and not inert.
fn html_map_element_first_image_with_focusable_shapes(map_element &Element) ?&Element {
	root := map_element.as_node().root()
	mut node := ?&Node(root)
	for node != none {
		current := node or { break }
		node = current.next_in_pre_order(root)
		image := current.as_element() or { continue }
		if !is_html_element_with_local_name(image, 'img') {
			continue
		}
		associated := html_image_element_associated_map_element(image) or { continue }
		if associated != map_element {
			continue
		}
		// https://html.spec.whatwg.org/multipage/interaction.html#focusable-area
		// The shapes of area elements in an image map associated with an img element that is being rendered and is
		// not inert.
		if image.meets_focusable_area_rendering_requirements() && !image.as_node().is_inert() {
			return image
		}
	}
	return none
}
