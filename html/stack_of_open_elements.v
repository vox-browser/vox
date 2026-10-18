module html

import dom

// Translation of Libraries/LibWeb/HTML/Parser/StackOfOpenElements.{h,cpp}.
// https://html.spec.whatwg.org/multipage/parsing.html#stack-of-open-elements
//
// The stack grows downwards: the topmost node is the first added, the bottommost (current node) is
// the most recently added. Element identity uses same_element (see parser_common.v), NOT `==`.

// The base list of tag names that terminate the "in scope" search.
const scope_base_list = ['applet', 'caption', 'html', 'table', 'td', 'th', 'marquee', 'object',
	'select', 'template']

pub struct StackOfOpenElements {
mut:
	elements          []&dom.Element
	on_element_popped ?fn (&dom.Element)
	on_element_popped_context voidptr
	on_element_popped_with_context fn (voidptr, &dom.Element) = unsafe { nil }
}

pub struct LastElementResult {
pub mut:
	element ?&dom.Element
	index   int = -1
}

pub fn (s &StackOfOpenElements) is_empty() bool {
	return s.elements.len == 0
}

pub fn (s &StackOfOpenElements) first() &dom.Element {
	return s.elements[0]
}

pub fn (s &StackOfOpenElements) last() &dom.Element {
	return s.elements[s.elements.len - 1]
}

pub fn (s &StackOfOpenElements) current_node() &dom.Element {
	return s.elements[s.elements.len - 1]
}

pub fn (mut s StackOfOpenElements) push(element &dom.Element) {
	s.elements << element
}

pub fn (mut s StackOfOpenElements) pop() &dom.Element {
	element := s.elements.pop()
	if s.on_element_popped_with_context != unsafe { nil } {
		s.on_element_popped_with_context(s.on_element_popped_context, element)
	} else if cb := s.on_element_popped {
		cb(element)
	}
	return element
}

pub fn (mut s StackOfOpenElements) set_on_element_popped(on_element_popped fn (&dom.Element)) {
	s.on_element_popped_context = unsafe { nil }
	s.on_element_popped_with_context = unsafe { nil }
	s.on_element_popped = on_element_popped
}

// The stack traces its receiver as ordinary managed data. A static callback
// avoids a captured function whose executable registry independently owns it.
pub fn (mut s StackOfOpenElements) set_on_element_popped_with_context(context voidptr, callback fn (voidptr, &dom.Element)) {
	s.on_element_popped = none
	s.on_element_popped_context = context
	s.on_element_popped_with_context = callback
}

pub fn (s &StackOfOpenElements) elements() []&dom.Element {
	return s.elements
}

pub fn (mut s StackOfOpenElements) remove(element &dom.Element) {
	for i, el in s.elements {
		if same_element(el, element) {
			s.elements.delete(i)
			return
		}
	}
}

pub fn (mut s StackOfOpenElements) replace(to_remove &dom.Element, to_add &dom.Element) {
	for i, el in s.elements {
		if same_element(el, to_remove) {
			s.elements[i] = to_add
			break
		}
	}
}

pub fn (mut s StackOfOpenElements) insert_immediately_below(element_to_add &dom.Element, target &dom.Element) {
	for i, el in s.elements {
		if same_element(el, target) {
			s.elements.insert(i + 1, element_to_add)
			break
		}
	}
}

pub fn (s &StackOfOpenElements) contains(element &dom.Element) bool {
	for el in s.elements {
		if same_element(el, element) {
			return true
		}
	}
	return false
}

pub fn (s &StackOfOpenElements) contains_template_element() bool {
	for el in s.elements {
		if !element_in_namespace(el, ns_html) {
			continue
		}
		if el.local_name() == 'template' {
			return true
		}
	}
	return false
}

// https://html.spec.whatwg.org/multipage/parsing.html#has-an-element-in-the-specific-scope
fn (s &StackOfOpenElements) has_in_scope_impl_tag(tag_name string, list []string, check_math_and_svg bool) bool {
	for i := s.elements.len - 1; i >= 0; i-- {
		element := s.elements[i]
		if element_in_namespace(element, ns_html) && element.local_name() == tag_name {
			return true
		}
		if element_in_namespace(element, ns_html) && element.local_name() in list {
			return false
		}
		if check_math_and_svg && element_in_namespace(element, ns_svg)
			&& element.local_name() in special_svg_tags {
			return false
		}
		if check_math_and_svg && element_in_namespace(element, ns_mathml)
			&& element.local_name() in special_mathml_tags {
			return false
		}
	}
	panic('has_in_scope_impl_tag: VERIFY_NOT_REACHED (html should always be on the stack)')
}

fn (s &StackOfOpenElements) has_in_scope_impl_element(target_node &dom.Element, list []string) bool {
	for i := s.elements.len - 1; i >= 0; i-- {
		element := s.elements[i]
		if same_element(element, target_node) {
			return true
		}
		if element_in_namespace(element, ns_html) && element.local_name() in list {
			return false
		}
		if element_in_namespace(element, ns_svg) && element.local_name() in special_svg_tags {
			return false
		}
		if element_in_namespace(element, ns_mathml) && element.local_name() in special_mathml_tags {
			return false
		}
	}
	panic('has_in_scope_impl_element: VERIFY_NOT_REACHED')
}

pub struct StackOfOpenElementsElementTarget {
pub:
	element &dom.Element @[required]
}

pub type StackOfOpenElementsScopeTarget = StackOfOpenElementsElementTarget | string

// C++ overloads has_in_scope_impl for tag names and element identity. V uses a
// sum type so both algorithms retain the exact method name.
pub fn (s &StackOfOpenElements) has_in_scope_impl(target StackOfOpenElementsScopeTarget, list []string, check_math_and_svg ...bool) bool {
	match target {
		string {
			check := if check_math_and_svg.len > 0 { check_math_and_svg[0] } else { true }
			return s.has_in_scope_impl_tag(target, list, check)
		}
		StackOfOpenElementsElementTarget {
			return s.has_in_scope_impl_element(target.element, list)
		}
	}
}

// https://html.spec.whatwg.org/multipage/parsing.html#has-an-element-in-scope
pub fn (s &StackOfOpenElements) has_in_scope(tag_name string) bool {
	return s.has_in_scope_impl_tag(tag_name, scope_base_list, true)
}

pub fn (s &StackOfOpenElements) has_in_scope_element(target_node &dom.Element) bool {
	return s.has_in_scope_impl_element(target_node, scope_base_list)
}

// https://html.spec.whatwg.org/multipage/parsing.html#has-an-element-in-button-scope
pub fn (s &StackOfOpenElements) has_in_button_scope(tag_name string) bool {
	mut list := scope_base_list.clone()
	list << 'button'
	return s.has_in_scope_impl_tag(tag_name, list, true)
}

// https://html.spec.whatwg.org/multipage/parsing.html#has-an-element-in-table-scope
pub fn (s &StackOfOpenElements) has_in_table_scope(tag_name string) bool {
	return s.has_in_scope_impl_tag(tag_name, ['html', 'table', 'template'], false)
}

// https://html.spec.whatwg.org/multipage/parsing.html#has-an-element-in-list-item-scope
pub fn (s &StackOfOpenElements) has_in_list_item_scope(tag_name string) bool {
	mut list := scope_base_list.clone()
	list << 'ol'
	list << 'ul'
	return s.has_in_scope_impl_tag(tag_name, list, true)
}

pub fn (mut s StackOfOpenElements) pop_until_an_element_with_tag_name_has_been_popped(tag_name string) {
	for !(element_in_namespace(s.last(), ns_html) && s.last().local_name() == tag_name) {
		s.pop()
	}
	s.pop()
}

pub fn (s &StackOfOpenElements) topmost_special_node_below(formatting_element &dom.Element) ?&dom.Element {
	mut found_element := ?&dom.Element(none)
	for i := s.elements.len - 1; i >= 0; i-- {
		element := s.elements[i]
		if same_element(element, formatting_element) {
			break
		}
		if is_special_tag(element.local_name(), element.namespace_uri()) {
			found_element = element
		}
	}
	return found_element
}

pub fn (s &StackOfOpenElements) last_element_with_tag_name(tag_name string) LastElementResult {
	for i := s.elements.len - 1; i >= 0; i-- {
		element := s.elements[i]
		if element.local_name() == tag_name {
			return LastElementResult{
				element: element
				index:   i
			}
		}
	}
	return LastElementResult{
		element: none
		index:   -1
	}
}

pub fn (s &StackOfOpenElements) element_immediately_above(target &dom.Element) ?&dom.Element {
	mut found_target := false
	for i := s.elements.len - 1; i >= 0; i-- {
		element := s.elements[i]
		if same_element(element, target) {
			found_target = true
		} else if found_target {
			return element
		}
	}
	return none
}
