// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the command value algorithms in Editing/Internal/Algorithms.cpp:
// specified and effective command values, value equivalence, clearing, forcing,
// and pushing down values, and recording and restoring states and values.
module editing

import color
import css
import dom

fn editing_color_to_string_without_alpha(value color.Color) string {
	digits := '0123456789abcdef'
	mut result := '#'
	for component in [value.red, value.green, value.blue] {
		result += digits[int(component >> 4)].ascii_str() + digits[int(component & 0x0f)].ascii_str()
	}
	return result
}

// The font-family value a font element's face attribute sets as a presentational hint.
fn editing_font_face_presentational_hint(face string) ?string {
	mut declaration := css.CSSStyleProperties.create()
	declaration.set_property('font-family', face, '') or { return none }
	value := declaration.get_property_value('font-family')
	if value == '' {
		return none
	}
	return value
}

// HTMLFontElement::apply_presentational_hints() for the property the specified command value algorithm asks
// about, serialized as a normal (not resolved) value.
fn editing_font_element_presentational_hint(element &dom.Element, property_name string) ?string {
	match property_name {
		'color' {
			value := element.get_attribute('color') or { return none }
			parsed := color.parse_legacy_color_value(value) or { return none }
			return 'rgb(${parsed.red}, ${parsed.green}, ${parsed.blue})'
		}
		'font-size' {
			value := element.get_attribute('size') or { return none }
			return css.parse_legacy_font_size(value)
		}
		'font-family' {
			value := element.get_attribute('face') or { return none }
			return editing_font_face_presentational_hint(value)
		}
		else {
			return none
		}
	}
}

// https://w3c.github.io/editing/docs/execCommand/#specified-command-value
pub fn specified_command_value(element &dom.Element, command string) ?string {
	node := element.as_node()

	// 1. If command is "backColor" or "hiliteColor" and the Element's display property does not have resolved value
	//    "inline", return null.
	if command in [command_back_color, command_hilite_color] {
		display := resolved_display(node) or { return none }
		if !display.is_inline_outside() || !display.is_flow_inside() {
			return none
		}
	}

	// 2. If command is "createLink" or "unlink":
	if command in [command_create_link, command_unlink] {
		// 1. If element is an a element and has an href attribute, return the value of that attribute.
		if href_attribute := element.get_attribute('href') {
			return href_attribute
		}

		// 2. Return null.
		return none
	}

	// 3. If command is "subscript" or "superscript":
	if command in [command_subscript, command_superscript] {
		// 1. If element is a sup, return "superscript".
		if element.local_name() == 'sup' {
			return 'superscript'
		}

		// 2. If element is a sub, return "subscript".
		if element.local_name() == 'sub' {
			return 'subscript'
		}

		// 3. Return null.
		return none
	}

	// 4. If command is "strikethrough", and element has a style attribute set, and that attribute sets
	//    "text-decoration":
	// AD-HOC: The style attribute stores expanded longhands, and a reconstructed `text-decoration` shorthand is not
	//         a value list, so read the `text-decoration-line` longhand the attribute sets.
	if command == command_strikethrough {
		if text_decoration_style := property_in_style_attribute(element, 'text-decoration-line') {
			// 1. If element's style attribute sets "text-decoration" to a value containing "line-through", return
			//    "line-through".
			if value_contains_keyword(text_decoration_style, 'line-through') {
				return 'line-through'
			}

			// 2. Return null.
			return none
		}
	}

	// 5. If command is "strikethrough" and element is an s or strike element, return "line-through".
	if command == command_strikethrough && element.local_name() in ['s', 'strike'] {
		return 'line-through'
	}

	// 6. If command is "underline", and element has a style attribute set, and that attribute sets "text-decoration":
	// AD-HOC: Read the `text-decoration-line` longhand, as above.
	if command == command_underline {
		if text_decoration_style := property_in_style_attribute(element, 'text-decoration-line') {
			// 1. If element's style attribute sets "text-decoration" to a value containing "underline", return "underline".
			if value_contains_keyword(text_decoration_style, 'underline') {
				return 'underline'
			}

			// 2. Return null.
			return none
		}
	}

	// 7. If command is "underline" and element is a u element, return "underline".
	if command == command_underline && element.local_name() == 'u' {
		return 'underline'
	}

	// 8. Let property be the relevant CSS property for command.
	definition := find_command_definition(command) or { return none }

	// 9. If property is null, return null.
	property := definition.relevant_css_property or { return none }

	// 10. If element has a style attribute set, and that attribute has the effect of setting property, return the value
	//     that it sets property to.
	// FIXME: Use property_in_style_attribute once it supports shorthands.
	if inline_style := css.inline_style_for_element(element) {
		value := inline_style.get_property_value(property)
		if value != '' {
			return value
		}
	}

	// 11. If element is a font element that has an attribute whose effect is to create a presentational hint for
	//     property, return the value that the hint sets property to. (For a size of 7, this will be the non-CSS value
	//     "xxx-large".)
	if is_html_element_named(node, ['font']) {
		if hint := editing_font_element_presentational_hint(element, property) {
			return hint
		}
	}

	// 12. If element is in the following list, and property is equal to the CSS property name listed for it, return the
	//     string listed for it.
	//     * b, strong: font-weight: "bold"
	//     * i, em: font-style: "italic"
	if element.local_name() in ['b', 'strong'] && property == 'font-weight' {
		return 'bold'
	}
	if element.local_name() in ['i', 'em'] && property == 'font-style' {
		return 'italic'
	}

	// 13. Return null.
	return none
}

fn editing_resolved_background_alpha(node &dom.Node) u8 {
	value := resolved_value(node, 'background-color') or { return 255 }
	parsed := color.from_string(value) or { return 255 }
	return parsed.alpha
}

// https://w3c.github.io/editing/docs/execCommand/#effective-command-value
pub fn effective_command_value(input_node ?&dom.Node, command string) ?string {
	mut node := input_node or { return none }

	// 1. If neither node nor its parent is an Element, return null.
	// 2. If node is not an Element, return the effective command value of its parent for command.
	if !node.is_element() {
		parent := node.parent() or { return none }
		if !parent.is_element() {
			return none
		}
		return effective_command_value(parent, command)
	}

	// 3. If command is "createLink" or "unlink":
	if command in [command_create_link, command_unlink] {
		// 1. While node is not null, and is not an a element that has an href attribute, set node to its parent.
		mut current := ?&dom.Node(node)
		for {
			candidate := current or { break }
			if candidate.is_html_anchor_element() {
				element := candidate.as_element() or { break }
				if element.has_attribute('href') {
					// 3. Return the value of node's href attribute.
					return element.get_attribute_value('href')
				}
			}
			current = candidate.parent()
		}

		// 2. If node is null, return null.
		return none
	}

	// 4. If command is "backColor" or "hiliteColor":
	if command in [command_back_color, command_hilite_color] {
		// 1. While the resolved value of "background-color" on node is any fully transparent value, and node's parent
		//    is an Element, set node to its parent.
		for editing_resolved_background_alpha(node) == 0 {
			parent := node.parent() or { break }
			if !parent.is_element() {
				break
			}
			node = parent
		}

		// 2. Return the resolved value of "background-color" for node.
		return resolved_value(node, 'background-color')
	}

	// 5. If command is "subscript" or "superscript":
	if command in [command_subscript, command_superscript] {
		// 1. Let affected by subscript and affected by superscript be two boolean variables, both initially false.
		mut affected_by_subscript := false
		mut affected_by_superscript := false

		// 2. While node is an inline node:
		mut current := ?&dom.Node(node)
		for {
			candidate := current or { break }
			if !is_inline_node(candidate) {
				break
			}
			if element := candidate.as_element() {
				// 1. If node is a sub, set affected by subscript to true.
				if element.local_name() == 'sub' {
					affected_by_subscript = true
				}

				// 2. Otherwise, if node is a sup, set affected by superscript to true.
				else if element.local_name() == 'sup' {
					affected_by_superscript = true
				}
			}

			// 3. Set node to its parent.
			current = candidate.parent()
		}

		// 3. If affected by subscript and affected by superscript are both true, return the string "mixed".
		if affected_by_subscript && affected_by_superscript {
			return 'mixed'
		}

		// 4. If affected by subscript is true, return "subscript".
		if affected_by_subscript {
			return 'subscript'
		}

		// 5. If affected by superscript is true, return "superscript".
		if affected_by_superscript {
			return 'superscript'
		}

		// 6. Return null.
		return none
	}

	// 6. If command is "strikethrough", and the "text-decoration" property of node or any of its ancestors has resolved
	//    value containing "line-through", return "line-through". Otherwise, return null.
	// 7. If command is "underline", and the "text-decoration" property of node or any of its ancestors has resolved
	//    value containing "underline", return "underline". Otherwise, return null.
	if command in [command_strikethrough, command_underline] {
		keyword := if command == command_strikethrough { 'line-through' } else { 'underline' }
		mut inclusive_ancestor := ?&dom.Node(node)
		for {
			candidate := inclusive_ancestor or { break }
			if text_decoration_line := resolved_value(candidate, 'text-decoration-line') {
				if value_contains_keyword(text_decoration_line, keyword) {
					return keyword
				}
			}
			inclusive_ancestor = candidate.parent()
		}
		return none
	}

	// 8. Return the resolved value for node of the relevant CSS property for command.
	definition := find_command_definition(command) or { return none }
	property := definition.relevant_css_property or { return none }
	return resolved_value(node, property)
}

fn editing_color_components(value string) ?color.Color {
	return color.from_string(value)
}

// https://w3c.github.io/editing/docs/execCommand/#equivalent-values
pub fn values_are_equivalent(command string, a ?string, b ?string) bool {
	// Two quantities are equivalent values for a command if either both are null,
	// NOTE: Both need to be strings for all remaining conditions.
	left := a or { return b == none }
	right := b or { return false }

	// or both are strings and the command defines equivalent values and they match the definition.
	if command in [command_back_color, command_fore_color, command_hilite_color] {
		// Either both strings are valid CSS colors and have the same red, green, blue, and alpha components, or neither
		// string is a valid CSS color.
		left_color := editing_color_components(left)
		right_color := editing_color_components(right)
		if left_value := left_color {
			right_value := right_color or { return false }
			return left_value == right_value
		}
		return right_color == none
	}
	if command == command_bold {
		// Either the two strings are equal, or one is "bold" and the other is "700", or one is "normal" and the other
		// is "400".
		if left == right {
			return true
		}
		either_is_bold := 'bold' in [left, right]
		either_is_700 := '700' in [left, right]
		either_is_normal := 'normal' in [left, right]
		either_is_400 := '400' in [left, right]
		return (either_is_bold && either_is_700) || (either_is_normal && either_is_400)
	}

	// or both are strings and they're equal and the command does not define any equivalent values,
	return left == right
}

// https://w3c.github.io/editing/docs/execCommand/#loosely-equivalent-values
pub fn values_are_loosely_equivalent(command string, a ?string, b ?string) bool {
	// Two quantities are loosely equivalent values for a command if either they are equivalent values for the command,
	if values_are_equivalent(command, a, b) {
		return true
	}

	// or if the command is the fontSize command; one of the quantities is one of "x-small", "small", "medium", "large",
	// "x-large", "xx-large", or "xxx-large"; and the other quantity is the resolved value of "font-size" on a font
	// element whose size attribute has the corresponding value set ("1" through "7" respectively).
	if command == command_font_size {
		left := a or { return false }
		right := b or { return false }
		named_quantities := named_font_sizes()
		size_quantities := ['1', '2', '3', '4', '5', '6', '7']
		left_index := if left in named_quantities {
			named_quantities.index(left)
		} else {
			size_quantities.index(left)
		}
		right_index := if right in named_quantities {
			named_quantities.index(right)
		} else {
			size_quantities.index(right)
		}
		return left_index >= 0 && left_index == right_index
	}

	return false
}

fn editing_remove_text_decoration_value(element &dom.Element, keyword_to_delete string) {
	mut inline_style := css.inline_style_for_element(element) or { return }
	value := inline_style.get_property_value('text-decoration-line')
	if value == '' {
		return
	}
	components := value.split(' ').filter(it.trim_space() != '')
	remaining := components.filter(it.to_lower() != keyword_to_delete)
	if remaining.len == components.len {
		return
	}
	if remaining.len == 0 {
		inline_style.remove_property('text-decoration') or {}
		return
	}
	inline_style.set_property('text-decoration-line', remaining.join(' '), '') or {}
}

// https://w3c.github.io/editing/docs/execCommand/#clear-the-value
pub fn clear_the_value(command string, element &dom.Element) []&dom.Node {
	// 1. Let command be the current command.

	// 2. If element is not editable, return the empty list.
	node := element.as_node()
	if !node.is_editable() {
		return []
	}

	// 3. If element's specified command value for command is null, return the empty list.
	if specified_command_value(element, command) == none {
		return []
	}

	// 4. If element is a simple modifiable element:
	if is_simple_modifiable_element(node) {
		// 1. Let children be the children of element.
		children := node.children_as_vector()

		// 2. For each child in children, insert child into element's parent immediately before element, preserving
		//    ranges.
		parent := node.parent() or { return children }
		mut element_index := node.index()
		for child in children {
			move_node_preserving_ranges(child, parent, element_index)
			element_index++
		}

		// 3. Remove element from its parent.
		remove_node(node)

		// 4. Return children.
		return children
	}

	// 5. If command is "strikethrough", and element has a style attribute that sets "text-decoration" to some value
	//    containing "line-through", delete "line-through" from the value.
	// AD-HOC: The style attribute stores expanded longhands, so the line keywords live in the
	//         `text-decoration-line` longhand rather than in a shorthand value list.
	if command == command_strikethrough {
		editing_remove_text_decoration_value(element, 'line-through')
	}

	// 6. If command is "underline", and element has a style attribute that sets "text-decoration" to some value
	//    containing "underline", delete "underline" from the value.
	if command == command_underline {
		editing_remove_text_decoration_value(element, 'underline')
	}

	// 7. If the relevant CSS property for command is not null, unset that property of element.
	if definition := find_command_definition(command) {
		if property_to_remove := definition.relevant_css_property {
			if mut inline_style := css.inline_style_for_element(element) {
				inline_style.remove_property(property_to_remove) or {}
			}
		}
	}

	// 8. If element is a font element:
	if is_html_element_named(node, ['font']) {
		// 1. If command is "foreColor", unset element's color attribute, if set.
		if command == command_fore_color {
			remove_attribute(element, 'color')
		}

		// 2. If command is "fontName", unset element's face attribute, if set.
		if command == command_font_name {
			remove_attribute(element, 'face')
		}

		// 3. If command is "fontSize", unset element's size attribute, if set.
		if command == command_font_size {
			remove_attribute(element, 'size')
		}
	}

	// 9. If element is an a element and command is "createLink" or "unlink", unset the href property of element.
	if node.is_html_anchor_element() && command in [command_create_link, command_unlink] {
		remove_attribute(element, 'href')
	}

	// 10. If element's specified command value for command is null, return the empty list.
	if specified_command_value(element, command) == none {
		return []
	}

	// 11. Set the tag name of element to "span", and return the one-node list consisting of the result.
	return [set_the_tag_name(element, 'span').as_node()]
}

// https://w3c.github.io/editing/docs/execCommand/#force-the-value
pub fn force_the_value(node &dom.Node, command string, new_value ?string) {
	// 1. Let command be the current command.

	// 2. If node's parent is null, abort this algorithm.
	if node.parent() == none {
		return
	}

	// 3. If new value is null, abort this algorithm.
	value := new_value or { return }

	// 4. If node is an allowed child of "span":
	if is_allowed_child_of_node(allowed_child_node(node), allowed_child_name('span')) {
		// 1. Reorder modifiable descendants of node's previousSibling.
		if previous_sibling := node.previous_sibling() {
			reorder_modifiable_descendants(previous_sibling, command, new_value)
		}

		// 2. Reorder modifiable descendants of node's nextSibling.
		if next_sibling := node.next_sibling() {
			reorder_modifiable_descendants(next_sibling, command, new_value)
		}

		// 3. Wrap the one-node list consisting of node, with sibling criteria returning true for a simple modifiable
		//    element whose specified command value is equivalent to new value and whose effective command value is
		//    loosely equivalent to new value and false otherwise, and with new parent instructions returning null.
		wrap([node], fn [command, new_value] (sibling &dom.Node) bool {
			sibling_element := sibling.as_element() or { return false }
			return is_simple_modifiable_element(sibling)
				&& values_are_equivalent(command, specified_command_value(sibling_element, command), new_value)
				&& values_are_loosely_equivalent(command, effective_command_value(sibling, command), new_value)
		}, no_new_parent_instructions)
	}

	// 5. If node is invisible, abort this algorithm.
	if is_invisible_node(node) {
		return
	}

	// 6. If the effective command value of command is loosely equivalent to new value on node, abort this algorithm.
	if values_are_loosely_equivalent(command, effective_command_value(node, command), new_value) {
		return
	}

	// 7. If node is not an allowed child of "span":
	if !is_allowed_child_of_node(allowed_child_node(node), allowed_child_name('span')) {
		// 1. Let children be all children of node, omitting any that are Elements whose specified command value for
		//    command is neither null nor equivalent to new value.
		mut children := []&dom.Node{}
		for child in node.children_as_vector() {
			if child_element := child.as_element() {
				child_specified_value := specified_command_value(child_element, command)
				if child_specified_value != none
					&& !values_are_equivalent(command, child_specified_value, new_value) {
					continue
				}
			}
			children << child
		}

		// 2. Force the value of each node in children, with command and new value as in this invocation of the
		//    algorithm.
		for child in children {
			force_the_value(child, command, new_value)
		}

		// 3. Abort this algorithm.
		return
	}

	// 8. If the effective command value of command is loosely equivalent to new value on node, abort this algorithm.
	if values_are_loosely_equivalent(command, effective_command_value(node, command), new_value) {
		return
	}

	// 9. Let new parent be null.
	mut new_parent := ?&dom.Element(none)

	// 10. If the CSS styling flag is false:
	document := node.document()
	if !document.get_css_styling_flag() {
		// 1. If command is "bold" and new value is "bold", let new parent be the result of calling createElement("b")
		//    on the ownerDocument of node.
		if command == command_bold && value == 'bold' {
			new_parent = editing_create_html_element(document, 'b')
		}

		// 2. If command is "italic" and new value is "italic", let new parent be the result of calling
		//    createElement("i") on the ownerDocument of node.
		if command == command_italic && value == 'italic' {
			new_parent = editing_create_html_element(document, 'i')
		}

		// 3. If command is "strikethrough" and new value is "line-through", let new parent be the result of calling
		//    createElement("s") on the ownerDocument of node.
		if command == command_strikethrough && value == 'line-through' {
			new_parent = editing_create_html_element(document, 's')
		}

		// 4. If command is "underline" and new value is "underline", let new parent be the result of calling
		//    createElement("u") on the ownerDocument of node.
		if command == command_underline && value == 'underline' {
			new_parent = editing_create_html_element(document, 'u')
		}

		// 5.  If command is "foreColor", and new value is fully opaque with red, green, and blue components in the
		//     range 0 to 255:
		if command == command_fore_color {
			if new_value_color := color.from_string(value) {
				if new_value_color.alpha == 255 {
					// 1. Let new parent be the result of calling createElement("font") on the ownerDocument of node.
					font := editing_create_html_element(document, 'font')

					// 2. Set the color attribute of new parent to the result of applying the rules for serializing simple color
					//    values to new value (interpreted as a simple color).
					set_attribute_value(font, 'color', editing_color_to_string_without_alpha(new_value_color))
					new_parent = font
				}
			}
		}

		// 6. If command is "fontName", let new parent be the result of calling createElement("font") on the
		//    ownerDocument of node, then set the face attribute of new parent to new value.
		if command == command_font_name {
			font := editing_create_html_element(document, 'font')
			set_attribute_value(font, 'face', value)
			new_parent = font
		}
	}

	// 11. If command is "createLink" or "unlink":
	if command in [command_create_link, command_unlink] {
		// 1. Let new parent be the result of calling createElement("a") on the ownerDocument of node.
		anchor := editing_create_html_element(document, 'a')

		// 2. Set the href attribute of new parent to new value.
		set_attribute_value(anchor, 'href', value)
		new_parent = anchor

		// 3. Let ancestor be node's parent.
		mut ancestor := node.parent()

		// 4. While ancestor is not null:
		for {
			current := ancestor or { break }
			mut next := unsafe { current }

			// 1. If ancestor is an a, set the tag name of ancestor to "span", and let ancestor be the result.
			if current.is_html_anchor_element() {
				if current_element := current.as_element() {
					next = set_the_tag_name(current_element, 'span').as_node()
				}
			}

			// 2. Set ancestor to its parent.
			ancestor = next.parent()
		}
	}

	// 12. If command is "fontSize"; and new value is one of "x-small", "small", "medium", "large", "x-large",
	//     "xx-large", or "xxx-large"; and either the CSS styling flag is false, or new value is "xxx-large":
	font_sizes := named_font_sizes()
	if command == command_font_size && value in font_sizes
		&& (!document.get_css_styling_flag() || value == 'xxx-large') {
		// let new parent be the result of calling createElement("font") on the ownerDocument of node,
		font := editing_create_html_element(document, 'font')

		// then set the size attribute of new parent to the number from the following table based on new value:
		// * x-small: 1
		// * small: 2
		// * normal: 3
		// * large: 4
		// * x-large: 5
		// * xx-large: 6
		// * xxx-large: 7
		size := font_sizes.index(value) + 1
		set_attribute_value(font, 'size', size.str())
		new_parent = font
	}

	// 13. If command is "subscript" or "superscript" and new value is "subscript", let new parent be the result of
	//     calling createElement("sub") on the ownerDocument of node.
	if command in [command_subscript, command_superscript] && value == 'subscript' {
		new_parent = editing_create_html_element(document, 'sub')
	}

	// 14. If command is "subscript" or "superscript" and new value is "superscript", let new parent be the result of
	//     calling createElement("sup") on the ownerDocument of node.
	if command in [command_subscript, command_superscript] && value == 'superscript' {
		new_parent = editing_create_html_element(document, 'sup')
	}

	// 15. If new parent is null, let new parent be the result of calling createElement("span") on the ownerDocument of
	//     node.
	parent_element := new_parent or { editing_create_html_element(document, 'span') }
	parent_node := parent_element.as_node()

	// 16. Insert new parent in node's parent before node.
	node_parent := node.parent() or { return }
	insert_node_before(parent_node, node_parent, node)

	// 17. If the effective command value of command for new parent is not loosely equivalent to new value, and the
	//     relevant CSS property for command is not null, set that CSS property of new parent to new value (if the new
	//     value would be valid).
	if !values_are_loosely_equivalent(command, effective_command_value(parent_node, command), new_value) {
		if definition := find_command_definition(command) {
			if property := definition.relevant_css_property {
				mut inline_style := css.element_style(parent_element)
				inline_style.set_property(property, value, '') or {}
			}
		}
	}

	// 18. If command is "strikethrough", and new value is "line-through", and the effective command value of
	//     "strikethrough" for new parent is not "line-through", set the "text-decoration" property of new parent to
	//     "line-through".
	parent_strikethrough := effective_command_value(parent_node, command)
	if command == command_strikethrough && value == 'line-through'
		&& (parent_strikethrough == none || parent_strikethrough or { '' } != 'line-through') {
		mut inline_style := css.element_style(parent_element)
		inline_style.set_property('text-decoration', 'line-through', '') or {}
	}

	// 19. If command is "underline", and new value is "underline", and the effective command value of "underline" for
	//     new parent is not "underline", set the "text-decoration" property of new parent to "underline".
	parent_underline := effective_command_value(parent_node, command)
	if command == command_underline && value == 'underline'
		&& (parent_underline == none || parent_underline or { '' } != 'underline') {
		mut inline_style := css.element_style(parent_element)
		inline_style.set_property('text-decoration', 'underline', '') or {}
	}

	// 20. Append node to new parent as its last child, preserving ranges.
	move_node_preserving_ranges(node, parent_node, parent_node.child_count())

	// 21. If node is an Element and the effective command value of command for node is not loosely equivalent to new
	//     value:
	if node.is_element()
		&& !values_are_loosely_equivalent(command, effective_command_value(node, command), new_value) {
		// 1. Insert node into the parent of new parent before new parent, preserving ranges.
		grandparent := parent_node.parent() or { return }
		move_node_preserving_ranges(node, grandparent, parent_node.index())

		// 2. Remove new parent from its parent.
		remove_node(parent_node)

		// 3. Let children be all children of node, omitting any that are Elements whose specified command value for
		//    command is neither null nor equivalent to new value.
		mut children := []&dom.Node{}
		for child in node.children_as_vector() {
			if child_element := child.as_element() {
				child_value := specified_command_value(child_element, command)
				if child_value != none && !values_are_equivalent(command, child_value, new_value) {
					continue
				}
			}
			children << child
		}

		// 4. Force the value of each node in children, with command and new value as in this invocation of the
		//    algorithm.
		for child in children {
			force_the_value(child, command, new_value)
		}
	}
}

// https://w3c.github.io/editing/docs/execCommand/#push-down-values
pub fn push_down_values(command string, node &dom.Node, new_value ?string) {
	// 1. Let command be the current command.

	// 2. If node's parent is not an Element, abort this algorithm.
	node_parent := node.parent() or { return }
	if !node_parent.is_element() {
		return
	}

	// 3. If the effective command value of command is loosely equivalent to new value on node, abort this algorithm.
	if values_are_loosely_equivalent(command, effective_command_value(node, command), new_value) {
		return
	}

	// 4. Let current ancestor be node's parent.
	mut current_ancestor := ?&dom.Node(node_parent)

	// 5. Let ancestor list be a list of nodes, initially empty.
	mut ancestor_list := []&dom.Node{}

	// 6. While current ancestor is an editable Element and the effective command value of command is not loosely
	//    equivalent to new value on it, append current ancestor to ancestor list, then set current ancestor to its
	//    parent.
	for {
		current := current_ancestor or { break }
		if !current.is_element() || !current.is_editable()
			|| values_are_loosely_equivalent(command, effective_command_value(current, command), new_value) {
			break
		}
		ancestor_list << current
		current_ancestor = current.parent()
	}

	// 7. If ancestor list is empty, abort this algorithm.
	if ancestor_list.len == 0 {
		return
	}

	// 8. Let propagated value be the specified command value of command on the last member of ancestor list.
	last_ancestor_element := ancestor_list.last().as_element() or { return }
	mut propagated_value := specified_command_value(last_ancestor_element, command)

	// 9. If propagated value is null and is not equal to new value, abort this algorithm.
	if propagated_value == none && new_value != none {
		return
	}

	// 10. If the effective command value of command is not loosely equivalent to new value on the parent of the last
	//     member of ancestor list, and new value is not null, abort this algorithm.
	if new_value != none {
		if last_parent := ancestor_list.last().parent() {
			if !values_are_loosely_equivalent(command, effective_command_value(last_parent, command),
				new_value) {
				return
			}
		}
	}

	// 11. While ancestor list is not empty:
	for ancestor_list.len > 0 {
		// 1. Let current ancestor be the last member of ancestor list.
		// 2. Remove the last member from ancestor list.
		current := ancestor_list.pop()

		// 3. If the specified command value of current ancestor for command is not null, set propagated value to that
		//    value.
		// NOTE: Step 6 above guarantees that current_ancestor is an Element.
		current_element := current.as_element() or { continue }
		command_value := specified_command_value(current_element, command)
		if value := command_value {
			propagated_value = value
		}

		// 4. Let children be the children of current ancestor.
		children := current.children_as_vector()

		// 5. If the specified command value of current ancestor for command is not null, clear the value of current
		//    ancestor.
		if command_value != none {
			clear_the_value(command, current_element)
		}

		// 6. For every child in children:
		for child in children {
			// 1. If child is node, continue with the next child.
			if voidptr(child) == voidptr(node) {
				continue
			}

			// 2. If child is an Element whose specified command value for command is neither null nor equivalent to
			//    propagated value, continue with the next child.
			if child_element := child.as_element() {
				child_command_value := specified_command_value(child_element, command)
				if child_command_value != none
					&& !values_are_equivalent(command, child_command_value, propagated_value) {
					continue
				}
			}

			// 3. If child is the last member of ancestor list, continue with the next child.
			if ancestor_list.len > 0 && voidptr(child) == voidptr(ancestor_list.last()) {
				continue
			}

			// 4. Force the value of child, with command as in this algorithm and new value equal to propagated value.
			force_the_value(child, command, propagated_value)
		}
	}
}

// https://w3c.github.io/editing/docs/execCommand/#reorder-modifiable-descendants
pub fn reorder_modifiable_descendants(node &dom.Node, command string, new_value ?string) {
	// 1. Let candidate equal node.
	mut candidate := unsafe { node }

	// 2. While candidate is a modifiable element, and candidate has exactly one child, and that child is also a
	//    modifiable element, and candidate is not a simple modifiable element or candidate's specified command value
	//    for command is not equivalent to new value, set candidate to its child.
	for is_modifiable_element(candidate) && candidate.child_count() == 1 {
		first_child := candidate.first_child() or { break }
		if !is_modifiable_element(first_child) {
			break
		}
		candidate_element := candidate.as_element() or { break }
		if is_simple_modifiable_element(candidate) && values_are_equivalent(command,
			specified_command_value(candidate_element, command), new_value) {
			break
		}
		candidate = first_child
	}

	// 3. If candidate is node, or is not a simple modifiable element, or its specified command value is not equivalent
	//    to new value, or its effective command value is not loosely equivalent to new value, abort these steps.
	if voidptr(candidate) == voidptr(node) || !is_simple_modifiable_element(candidate) {
		return
	}
	candidate_element := candidate.as_element() or { return }
	if !values_are_equivalent(command, specified_command_value(candidate_element, command), new_value)
		|| !values_are_loosely_equivalent(command, effective_command_value(candidate, command), new_value) {
		return
	}

	// 4. While candidate has children, insert the first child of candidate into candidate's parent immediately before
	//    candidate, preserving ranges.
	candidate_parent := candidate.parent() or { return }
	for {
		first_child := candidate.first_child() or { break }
		move_node_preserving_ranges(first_child, candidate_parent, candidate.index())
	}

	// 5. Insert candidate into node's parent immediately after node.
	node_parent := node.parent() or { return }
	if next_sibling := node.next_sibling() {
		insert_node_before(candidate, node_parent, next_sibling)
	} else {
		append_node(candidate, node_parent) or { panic(err) }
	}

	// 6. Append the node as the last child of candidate, preserving ranges.
	move_node_preserving_ranges(node, candidate, candidate.child_count())
}

// https://w3c.github.io/editing/docs/execCommand/#record-current-overrides
pub fn record_current_overrides(document &dom.Document) []RecordedOverride {
	// 1. Let overrides be a list of (string, string or boolean) ordered pairs, initially empty.
	mut overrides := []RecordedOverride{}

	// 2. If there is a value override for "createLink", add ("createLink", value override for "createLink") to
	//    overrides.
	if override_ := document.command_value_override(command_create_link) {
		overrides << RecordedOverride{command_create_link, override_}
	}

	// 3. For each command in the list "bold", "italic", "strikethrough", "subscript", "superscript", "underline", in
	//    order: if there is a state override for command, add (command, command's state override) to overrides.
	for command in [command_bold, command_italic, command_strikethrough, command_subscript,
		command_superscript, command_underline] {
		if override_ := document.command_state_override(command) {
			overrides << RecordedOverride{command, override_}
		}
	}

	// 4. For each command in the list "fontName", "fontSize", "foreColor", "hiliteColor", in order: if there is a value
	//    override for command, add (command, command's value override) to overrides.
	for command in [command_font_name, command_font_size, command_fore_color, command_hilite_color] {
		if override_ := document.command_value_override(command) {
			overrides << RecordedOverride{command, override_}
		}
	}

	// 5. Return overrides.
	return overrides
}

// https://w3c.github.io/editing/docs/execCommand/#record-current-states-and-values
pub fn record_current_states_and_values(document &dom.Document) []RecordedOverride {
	// 1. Let overrides be a list of (string, string or boolean) ordered pairs, initially empty.
	mut overrides := []RecordedOverride{}

	// 2. Let node be the first formattable node effectively contained in the active range, or null if there is none.
	// 3. If node is null, return overrides.
	node := first_formattable_node_effectively_contained(active_range(document)) or { return overrides }

	// 4. Add ("createLink", node's effective command value for "createLink") to overrides.
	if effective_value := effective_command_value(node, command_create_link) {
		overrides << RecordedOverride{command_create_link, effective_value}
	}

	// 5. For each command in the list "bold", "italic", "strikethrough", "subscript", "superscript", "underline", in
	//    order: if node's effective command value for command is one of its inline command activated values, add
	//    (command, true) to overrides, and otherwise add (command, false) to overrides.
	for command in [command_bold, command_italic, command_strikethrough, command_subscript,
		command_superscript, command_underline] {
		effective_value := effective_command_value(node, command)
		definition := find_command_definition(command) or { continue }
		activated := if value := effective_value {
			value in definition.inline_activated_values
		} else {
			false
		}
		overrides << RecordedOverride{command, activated}
	}

	// 6. For each command in the list "fontName", "foreColor", "hiliteColor", in order: add (command, command's value)
	//    to overrides.
	for command in [command_font_name, command_fore_color, command_hilite_color] {
		overrides << RecordedOverride{command, query_command_value(node.document(), command) or {
			''
		}}
	}

	// 7. Add ("fontSize", node's effective command value for "fontSize") to overrides.
	if effective_value := effective_command_value(node, command_font_size) {
		overrides << RecordedOverride{command_font_size, effective_value}
	}

	// 8. Return overrides.
	return overrides
}

// https://w3c.github.io/editing/docs/execCommand/#record-the-values
pub fn record_the_values_of_nodes(node_list []&dom.Node) []RecordedNodeValue {
	// 1. Let values be a list of (node, command, specified command value) triples, initially empty.
	mut values := []RecordedNodeValue{}

	// 2. For each node in node list, for each command in the list "subscript", "bold", "fontName",
	//    "fontSize", "foreColor", "hiliteColor", "italic", "strikethrough", and "underline" in that
	//    order:
	// AD-HOC: We include "preserveWhitespace" as well.
	commands := [command_subscript, command_bold, command_font_name, command_font_size,
		command_fore_color, command_hilite_color, command_italic, command_strikethrough,
		command_underline, command_preserve_whitespace]
	for node in node_list {
		for command in commands {
			// 1. Let ancestor equal node.
			mut ancestor := ?&dom.Node(node)

			// 2. If ancestor is not an Element, set it to its parent.
			if !node.is_element() {
				ancestor = node.parent()
			}

			// 3. While ancestor is an Element and its specified command value for command is null, set
			//    it to its parent.
			mut recorded := ?string(none)
			for {
				current := ancestor or { break }
				element := current.as_element() or { break }
				if value := specified_command_value(element, command) {
					recorded = value
					break
				}
				ancestor = current.parent()
			}

			// 4. If ancestor is an Element, add (node, command, ancestor's specified command value for
			//    command) to values. Otherwise add (node, command, null) to values.
			values << RecordedNodeValue{
				node:                    node
				command:                 command
				specified_command_value: recorded
			}
		}
	}

	// 3. Return values.
	return values
}

// https://w3c.github.io/editing/docs/execCommand/#restore-states-and-values
pub fn restore_states_and_values(mut document dom.Document, overrides []RecordedOverride) {
	// 1. Let node be the first formattable node effectively contained in the active range, or null if there is none.
	// 2. If node is not null,
	if first_node := first_formattable_node_effectively_contained(active_range(document)) {
		mut current_node := unsafe { first_node }

		// then for each (command, override) pair in overrides, in order:
		for override_ in overrides {
			command := override_.command
			value := override_.value
			match value {
				bool {
					// 1. If override is a boolean, and queryCommandState(command) returns something different from override,
					//    take the action for command, with value equal to the empty string.
					if (query_command_state(document, command) or { false }) == value {
						continue
					}
					take_the_action_for_command(mut document, command, '')
				}
				string {
					// 2. Otherwise, if override is a string, and command is neither "createLink" nor "fontSize", and
					//    queryCommandValue(command) returns something not equivalent to override, take the action for command,
					//    with value equal to override.
					if command !in [command_create_link, command_font_size] {
						if (query_command_value(document, command) or { '' }) == value {
							continue
						}
						take_the_action_for_command(mut document, command, value)
					}

					// 3. Otherwise, if override is a string; and command is "createLink"; and either there is a value override
					//    for "createLink" that is not equal to override, or there is no value override for "createLink" and
					//    node's effective command value for "createLink" is not equal to override: take the action for
					//    "createLink", with value equal to override.
					else if command == command_create_link {
						needs_action := if value_override := document.command_value_override(command_create_link) {
							value_override != value
						} else {
							link := effective_command_value(current_node, command_create_link)
							link == none || link or { '' } != value
						}
						if !needs_action {
							continue
						}
						take_the_action_for_command(mut document, command_create_link, value)
					}

					// 4. Otherwise, if override is a string; and command is "fontSize"; and either there is a value override
					//    for "fontSize" that is not equal to override, or there is no value override for "fontSize" and node's
					//    effective command value for "fontSize" is not loosely equivalent to override:
					else {
						needs_action := if value_override := document.command_value_override(command_font_size) {
							value_override != value
						} else {
							!values_are_loosely_equivalent(command_font_size, effective_command_value(current_node,
								command_font_size), value)
						}
						if !needs_action {
							continue
						}

						// 1. Convert override to an integer number of pixels, and set override to the legacy font size for the
						//    result.
						override_pixel_size := font_size_to_pixel_size(value)
						legacy_size := legacy_font_size(override_pixel_size.to_int())

						// 2. Take the action for "fontSize", with value equal to override.
						take_the_action_for_command(mut document, command_font_size, legacy_size)
					}
				}
			}

			// 5. Otherwise, continue this loop from the beginning.

			// 6. Set node to the first formattable node effectively contained in the active range, if there is one.
			if new_formattable_node := first_formattable_node_effectively_contained(active_range(document)) {
				current_node = new_formattable_node
			}
		}
	}

	// 3. Otherwise, for each (command, override) pair in overrides, in order:
	else {
		for override_ in overrides {
			// 1. If override is a boolean, set the state override for command to override.
			// 2. If override is a string, set the value override for command to override.
			match override_.value {
				bool { document.set_command_state_override(override_.command, override_.value) }
				string { document.set_command_value_override(override_.command, override_.value) }
			}
		}
	}
}

// https://w3c.github.io/editing/docs/execCommand/#restore-the-values
pub fn restore_the_values_of_nodes(values []RecordedNodeValue) {
	// 1. For each (node, command, value) triple in values:
	for recorded_node_value in values {
		node := recorded_node_value.node
		command := recorded_node_value.command
		value := recorded_node_value.specified_command_value

		// 1. Let ancestor equal node.
		mut ancestor := ?&dom.Node(node)

		// 2. If ancestor is not an Element, set it to its parent.
		if !node.is_element() {
			ancestor = node.parent()
		}

		// 3. While ancestor is an Element and its specified command value for command is null, set it to its parent.
		mut ancestor_element := ?&dom.Element(none)
		mut ancestor_value := ?string(none)
		for {
			current := ancestor or { break }
			element := current.as_element() or { break }
			if specified := specified_command_value(element, command) {
				ancestor_element = element
				ancestor_value = specified
				break
			}
			ancestor = current.parent()
		}
		ancestor_is_element := if current := ancestor { current.is_element() } else { false }

		// 4. If value is null and ancestor is an Element, push down values on node for command, with new value null.
		if value == none && ancestor_is_element {
			push_down_values(command, node, none)
		}

		// 5. Otherwise, if ancestor is an Element and its specified command value for command is not equivalent to
		//    value, or if ancestor is not an Element and value is not null, force the value of command to value on
		//    node.
		else if (ancestor_is_element && ancestor_element != none
			&& !values_are_equivalent(command, ancestor_value, value))
			|| (!ancestor_is_element && value != none) {
			force_the_value(node, command, value)
		}
	}
}

// https://w3c.github.io/editing/docs/execCommand/#set-the-selection's-value
pub fn set_the_selections_value(mut document dom.Document, command string, new_value ?string) {
	// 1. Let command be the current command.

	// 2. If there is no formattable node effectively contained in the active range:
	if first_formattable_node_effectively_contained(active_range(document)) == none {
		// 1. If command has inline command activated values, set the state override to true if new value is among them
		//    and false if it's not.
		definition := find_command_definition(command) or { return }
		if definition.inline_activated_values.len > 0 {
			new_override := if value := new_value {
				value in definition.inline_activated_values
			} else {
				false
			}
			document.set_command_state_override(command, new_override)
		}

		// 2. If command is "subscript", unset the state override for "superscript".
		if command == command_subscript {
			document.clear_command_state_override(command_superscript)
		}

		// 3. If command is "superscript", unset the state override for "subscript".
		if command == command_superscript {
			document.clear_command_state_override(command_subscript)
		}

		// 4. If new value is null, unset the value override (if any).
		if value := new_value {
			// 5. Otherwise, if command is "createLink" or it has a value specified, set the value override to new value.
			if command == command_create_link || definition.value != unsafe { nil } {
				document.set_command_value_override(command, value)
			}
		} else {
			document.clear_command_value_override(command)
		}

		// 6. Abort these steps.
		return
	}

	// 3. If the active range's start node is an editable Text node, and its start offset is neither zero nor its start
	//    node's length, call splitText() on the active range's start node, with argument equal to the active range's
	//    start offset. Then set the active range's start node to the result, and its start offset to zero.
	mut range_ := active_range(document) or { return }
	start := range_.start()
	if start.node.is_editable() && start.node.is_text() && start.offset != 0
		&& start.offset != start.node.length() {
		text := unsafe { &dom.Text(start.node) }
		new_node := split_text(text, start.offset) or { panic(err) }
		range_.set_start(new_node.as_node(), 0) or { panic(err) }
	}

	// 4. If the active range's end node is an editable Text node, and its end offset is neither zero nor its end node's
	//    length, call splitText() on the active range's end node, with argument equal to the active range's end offset.
	end := range_.end()
	if end.node.is_editable() && end.node.is_text() && end.offset != 0 && end.offset != end.node.length() {
		text := unsafe { &dom.Text(end.node) }
		split_text(text, end.offset) or { panic(err) }
	}

	// 5. Let element list be all editable Elements effectively contained in the active range.
	mut element_list := []&dom.Element{}
	for descendant in nodes_effectively_contained_in_range(active_range(document)) {
		if descendant.is_editable() {
			if element := descendant.as_element() {
				element_list << element
			}
		}
	}

	// 6. For each element in element list, clear the value of element.
	for element in element_list {
		clear_the_value(command, element)
	}

	// 7. Let node list be all editable nodes effectively contained in the active range.
	node_list := nodes_effectively_contained_in_range(active_range(document)).filter(it.is_editable())

	// 8. For each node in node list:
	for node in node_list {
		// 1. Push down values on node.
		push_down_values(command, node, new_value)

		// 2. If node is an allowed child of "span", force the value of node.
		if is_allowed_child_of_node(allowed_child_node(node), allowed_child_name('span')) {
			force_the_value(node, command, new_value)
		}
	}
}

// https://w3c.github.io/editing/docs/execCommand/#standard-inline-value-command
pub fn standard_inline_indeterminate(document &dom.Document, command string) bool {
	// If a command is a standard inline value command, it is indeterminate if among formattable nodes that are
	// effectively contained in the active range, there are two that have distinct effective command values.
	mut first_node_value := ?string(none)
	for node in nodes_effectively_contained_in_range(active_range(document)) {
		if !is_formattable_node(node) {
			continue
		}
		node_value := effective_command_value(node, command) or { continue }
		if first := first_node_value {
			if first != node_value {
				return true
			}
		} else {
			first_node_value = node_value
		}
	}
	return false
}

// https://w3c.github.io/editing/docs/execCommand/#standard-inline-value-command
pub fn standard_inline_value(document &dom.Document, command string) string {
	// Its value is the effective command value of the first formattable node that is effectively contained in the
	// active range;
	range_ := active_range(document)
	mut value := ?string(none)
	for node in nodes_effectively_contained_in_range(range_) {
		if !is_formattable_node(node) {
			continue
		}
		value = effective_command_value(node, command)
		break
	}

	// or if there is no such node, the effective command value of the active range's start node;
	if value == none {
		if active := range_ {
			value = effective_command_value(active.start_container(), command)
		}
	}

	// or if that is null, the empty string.
	return value or { '' }
}
