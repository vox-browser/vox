module html

import dom

// Runtime tests for the HTML tree-construction data structures (StackOfOpenElements and
// ListOfActiveFormattingElements), translated from their C++ behaviour. Elements are created in the
// HTML namespace so the scope algorithms behave as in a real parse.

fn el(doc &dom.Document, tag string) &dom.Element {
	return doc.create_element_ns(ns_html, tag) or { panic('create ${tag}: ${err}') }
}

fn name_of(element ?&dom.Element) string {
	e := element or { return 'none' }
	return e.local_name()
}

// ===== StackOfOpenElements =====

fn test_stack_push_pop_current() {
	doc := dom.Document.create(dom.url_about_blank())
	mut stack := StackOfOpenElements{}
	assert stack.is_empty()

	html_el := el(doc, 'html')
	div := el(doc, 'div')
	stack.push(html_el)
	stack.push(div)
	assert !stack.is_empty()
	assert same_element(stack.current_node(), div)
	assert same_element(stack.first(), html_el)
	assert same_element(stack.last(), div)

	popped := stack.pop()
	assert same_element(popped, div)
	assert same_element(stack.current_node(), html_el)
}

fn test_stack_contains_and_remove() {
	doc := dom.Document.create(dom.url_about_blank())
	mut stack := StackOfOpenElements{}
	a := el(doc, 'html')
	b := el(doc, 'div')
	c := el(doc, 'span')
	stack.push(a)
	stack.push(b)
	stack.push(c)
	assert stack.contains(b)
	stack.remove(b)
	assert !stack.contains(b)
	assert stack.elements().len == 2
	// Removing does not disturb identity of the others.
	assert same_element(stack.current_node(), c)
}

fn test_stack_replace_and_insert_below() {
	doc := dom.Document.create(dom.url_about_blank())
	mut stack := StackOfOpenElements{}
	a := el(doc, 'html')
	b := el(doc, 'div')
	c := el(doc, 'span')
	stack.push(a)
	stack.push(b)
	stack.push(c)

	x := el(doc, 'section')
	stack.replace(b, x)
	assert !stack.contains(b)
	assert stack.contains(x)
	// Order preserved: html, section, span.
	assert name_of(stack.elements()[1]) == 'section'

	y := el(doc, 'p')
	stack.insert_immediately_below(y, x)
	// html, section, p, span
	assert stack.elements().len == 4
	assert name_of(stack.elements()[2]) == 'p'
}

fn test_stack_has_in_scope() {
	doc := dom.Document.create(dom.url_about_blank())
	mut stack := StackOfOpenElements{}
	stack.push(el(doc, 'html'))
	stack.push(el(doc, 'div'))
	stack.push(el(doc, 'p'))

	assert stack.has_in_scope('p')
	assert stack.has_in_scope('div')
	assert stack.has_in_scope('html')
	// 'span' is not on the stack; the search terminates at html (in the base scope list).
	assert !stack.has_in_scope('span')
}

fn test_stack_button_scope_vs_regular_scope() {
	doc := dom.Document.create(dom.url_about_blank())
	mut stack := StackOfOpenElements{}
	stack.push(el(doc, 'html'))
	stack.push(el(doc, 'p'))
	stack.push(el(doc, 'button'))
	stack.push(el(doc, 'span'))

	// 'button' terminates button-scope but not regular scope.
	assert stack.has_in_scope('p')
	assert !stack.has_in_button_scope('p')
}

fn test_stack_table_scope() {
	doc := dom.Document.create(dom.url_about_blank())
	mut stack := StackOfOpenElements{}
	stack.push(el(doc, 'html'))
	stack.push(el(doc, 'table'))
	stack.push(el(doc, 'tr'))

	assert stack.has_in_table_scope('tr')
	assert stack.has_in_table_scope('table')
	// 'table' terminates table scope, so a div above it is not "in table scope".
	assert !stack.has_in_table_scope('div')
	// But it IS in regular scope (table is not in the regular base list).
	assert stack.has_in_scope('table')
}

fn test_stack_has_in_scope_element() {
	doc := dom.Document.create(dom.url_about_blank())
	mut stack := StackOfOpenElements{}
	html_el := el(doc, 'html')
	div := el(doc, 'div')
	stack.push(html_el)
	stack.push(div)
	assert stack.has_in_scope_element(div)
	assert stack.has_in_scope_element(html_el)

	// An element not on the stack is not in scope.
	other := el(doc, 'div')
	assert !stack.has_in_scope_element(other)
}

fn test_stack_pop_until_tag() {
	doc := dom.Document.create(dom.url_about_blank())
	mut stack := StackOfOpenElements{}
	stack.push(el(doc, 'html'))
	stack.push(el(doc, 'div'))
	stack.push(el(doc, 'span'))
	stack.push(el(doc, 'b'))

	stack.pop_until_an_element_with_tag_name_has_been_popped('div')
	// div and everything above it are popped, leaving only html.
	assert stack.elements().len == 1
	assert name_of(stack.current_node()) == 'html'
}

fn test_stack_last_element_and_immediately_above() {
	doc := dom.Document.create(dom.url_about_blank())
	mut stack := StackOfOpenElements{}
	html_el := el(doc, 'html')
	div := el(doc, 'div')
	span := el(doc, 'span')
	stack.push(html_el)
	stack.push(div)
	stack.push(span)

	result := stack.last_element_with_tag_name('div')
	assert result.index == 1
	assert name_of(result.element) == 'div'
	assert stack.last_element_with_tag_name('missing').index == -1

	// element_immediately_above(span) is div.
	assert name_of(stack.element_immediately_above(span)) == 'div'
	assert stack.element_immediately_above(html_el) == none
}

fn test_stack_topmost_special_node_below() {
	doc := dom.Document.create(dom.url_about_blank())
	mut stack := StackOfOpenElements{}
	formatting := el(doc, 'i') // 'i' is a formatting element, not special
	stack.push(el(doc, 'html'))
	stack.push(formatting)
	stack.push(el(doc, 'div')) // 'div' is special
	stack.push(el(doc, 'b')) // 'b' is not special

	// The topmost special node above the formatting element is div.
	assert name_of(stack.topmost_special_node_below(formatting)) == 'div'
}

fn test_stack_on_element_popped_callback() {
	doc := dom.Document.create(dom.url_about_blank())
	mut stack := StackOfOpenElements{}
	stack.push(el(doc, 'html'))
	stack.push(el(doc, 'div'))

	mut count := 0
	pc := &count
	stack.set_on_element_popped(fn [pc] (e &dom.Element) {
		unsafe {
			*pc = *pc + 1
		}
	})
	stack.pop()
	stack.pop()
	assert count == 2
}

fn test_stack_contains_template_element() {
	doc := dom.Document.create(dom.url_about_blank())
	mut stack := StackOfOpenElements{}
	stack.push(el(doc, 'html'))
	assert !stack.contains_template_element()
	stack.push(el(doc, 'template'))
	assert stack.contains_template_element()
}

// ===== ListOfActiveFormattingElements =====

fn test_afe_add_contains_remove() {
	doc := dom.Document.create(dom.url_about_blank())
	mut list := ListOfActiveFormattingElements{}
	assert list.is_empty()

	b := el(doc, 'b')
	token := HTMLToken.make_start_tag('b')
	list.add(b, &token)
	assert !list.is_empty()
	assert list.contains(b)
	assert list.find_index(b) or { -1 } == 0

	list.remove(b)
	assert !list.contains(b)
	assert list.is_empty()
}

fn test_afe_marker_and_clear() {
	doc := dom.Document.create(dom.url_about_blank())
	mut list := ListOfActiveFormattingElements{}
	a := el(doc, 'a')
	ta := HTMLToken.make_start_tag('a')
	list.add(a, &ta)
	list.add_marker()
	b := el(doc, 'b')
	tb := HTMLToken.make_start_tag('b')
	list.add(b, &tb)
	i := el(doc, 'i')
	ti := HTMLToken.make_start_tag('i')
	list.add(i, &ti)
	assert list.entries().len == 4

	// last_element_with_tag_name_before_marker stops at the marker.
	assert name_of(list.last_element_with_tag_name_before_marker('i')) == 'i'
	assert list.last_element_with_tag_name_before_marker('a') == none

	// clear_up_to_the_last_marker removes entries above and including the last marker.
	list.clear_up_to_the_last_marker()
	assert list.entries().len == 1
	assert list.contains(a)
}

fn test_afe_replace_and_insert_at() {
	doc := dom.Document.create(dom.url_about_blank())
	mut list := ListOfActiveFormattingElements{}
	a := el(doc, 'a')
	ta := HTMLToken.make_start_tag('a')
	list.add(a, &ta)

	b := el(doc, 'b')
	tb := HTMLToken.make_start_tag('b')
	list.replace(a, b, &tb)
	assert !list.contains(a)
	assert list.contains(b)

	c := el(doc, 'c')
	tc := HTMLToken.make_start_tag('c')
	list.insert_at(0, c, &tc)
	assert list.find_index(c) or { -1 } == 0
	assert list.find_index(b) or { -1 } == 1
}

fn test_afe_noahs_ark_clause() {
	doc := dom.Document.create(dom.url_about_blank())
	mut list := ListOfActiveFormattingElements{}
	// Four identical <b> elements (same tag, namespace, no attributes). The Noah's Ark clause caps
	// matching entries at three, so adding the fourth removes the earliest.
	first := el(doc, 'b')
	t1 := HTMLToken.make_start_tag('b')
	list.add(first, &t1)
	e2 := el(doc, 'b')
	t2 := HTMLToken.make_start_tag('b')
	list.add(e2, &t2)
	e3 := el(doc, 'b')
	t3 := HTMLToken.make_start_tag('b')
	list.add(e3, &t3)
	e4 := el(doc, 'b')
	t4 := HTMLToken.make_start_tag('b')
	list.add(e4, &t4)

	assert list.entries().len == 3
	assert !list.contains(first)
	assert list.contains(e2)
	assert list.contains(e4)
}
