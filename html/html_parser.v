module html

import dom

// Public identifier prefixes which select quirks mode. Kept in the same order as
// HTMLParser.cpp's s_quirks_public_ids.
const quirks_public_id_prefixes = ['+//Silmaril//dtd html Pro v0r11 19970101//',
	'-//AS//DTD HTML 3.0 asWedit + extensions//',
	'-//AdvaSoft Ltd//DTD HTML 3.0 asWedit + extensions//', '-//IETF//DTD HTML 2.0 Level 1//',
	'-//IETF//DTD HTML 2.0 Level 2//', '-//IETF//DTD HTML 2.0 Strict Level 1//',
	'-//IETF//DTD HTML 2.0 Strict Level 2//', '-//IETF//DTD HTML 2.0 Strict//',
	'-//IETF//DTD HTML 2.0//', '-//IETF//DTD HTML 2.1E//', '-//IETF//DTD HTML 3.0//',
	'-//IETF//DTD HTML 3.2 Final//', '-//IETF//DTD HTML 3.2//', '-//IETF//DTD HTML 3//',
	'-//IETF//DTD HTML Level 0//', '-//IETF//DTD HTML Level 1//', '-//IETF//DTD HTML Level 2//',
	'-//IETF//DTD HTML Level 3//', '-//IETF//DTD HTML Strict Level 0//',
	'-//IETF//DTD HTML Strict Level 1//', '-//IETF//DTD HTML Strict Level 2//',
	'-//IETF//DTD HTML Strict Level 3//', '-//IETF//DTD HTML Strict//', '-//IETF//DTD HTML//',
	'-//Metrius//DTD Metrius Presentational//',
	'-//Microsoft//DTD Internet Explorer 2.0 HTML Strict//',
	'-//Microsoft//DTD Internet Explorer 2.0 HTML//',
	'-//Microsoft//DTD Internet Explorer 2.0 Tables//',
	'-//Microsoft//DTD Internet Explorer 3.0 HTML Strict//',
	'-//Microsoft//DTD Internet Explorer 3.0 HTML//',
	'-//Microsoft//DTD Internet Explorer 3.0 Tables//', '-//Netscape Comm. Corp.//DTD HTML//',
	'-//Netscape Comm. Corp.//DTD Strict HTML//', "-//O'Reilly and Associates//DTD HTML 2.0//",
	"-//O'Reilly and Associates//DTD HTML Extended 1.0//",
	"-//O'Reilly and Associates//DTD HTML Extended Relaxed 1.0//",
	'-//SQ//DTD HTML 2.0 HoTMetaL + extensions//',
	'-//SoftQuad Software//DTD HoTMetaL PRO 6.0::19990601::extensions to HTML 4.0//',
	'-//SoftQuad//DTD HoTMetaL PRO 4.0::19971010::extensions to HTML 4.0//',
	'-//Spyglass//DTD HTML 2.0 Extended//', '-//Sun Microsystems Corp.//DTD HotJava HTML//',
	'-//Sun Microsystems Corp.//DTD HotJava Strict HTML//', '-//W3C//DTD HTML 3 1995-03-24//',
	'-//W3C//DTD HTML 3.2 Draft//', '-//W3C//DTD HTML 3.2 Final//', '-//W3C//DTD HTML 3.2//',
	'-//W3C//DTD HTML 3.2S Draft//', '-//W3C//DTD HTML 4.0 Frameset//',
	'-//W3C//DTD HTML 4.0 Transitional//', '-//W3C//DTD HTML Experimental 19960712//',
	'-//W3C//DTD HTML Experimental 970421//', '-//W3C//DTD W3 HTML//', '-//W3O//DTD W3 HTML 3.0//',
	'-//WebTechs//DTD Mozilla HTML 2.0//', '-//WebTechs//DTD Mozilla HTML//']

// Translation of the core of Libraries/LibWeb/HTML/Parser/HTMLParser.cpp — the tree-construction
// stage that turns tokens into a DOM tree.
//
// This covers the tree-construction insertion modes, foster parenting, template contents, foreign
// (SVG/MathML) content, active formatting elements, and the adoption agency algorithm. Script
// execution, declarative shadow roots, parser-created custom-element reactions, and form association
// still depend on HTML subsystems that have not reached this translation yet.

pub enum InsertionMode {
	initial
	before_html
	before_head
	in_head
	in_head_noscript
	after_head
	in_body
	text
	in_table
	in_table_text
	in_caption
	in_column_group
	in_table_body
	in_row
	in_cell
	in_template
	after_body
	in_frameset
	after_frameset
	after_after_body
	after_after_frameset
}

pub struct AdjustedInsertionLocation {
pub:
	parent                ?&dom.Node
	insert_before_sibling ?&dom.Node
}

pub struct HTMLParser {
pub mut:
	document                           &dom.Document = unsafe { nil }
	tokenizer                          HTMLTokenizer
	insertion_mode                     InsertionMode = .initial
	original_insertion_mode            InsertionMode = .initial
	stack_of_open_elements             StackOfOpenElements
	list_of_active_formatting_elements ListOfActiveFormattingElements
	stack_of_template_insertion_modes  []InsertionMode
	head_element                       ?&dom.Element
	form_element                       ?&dom.Element
	frameset_ok                        bool = true
	parsing_fragment                   bool
	// Scripting is disabled: this port has no JS engine, so <noscript> content is parsed as normal
	// markup (the "scripting flag is disabled" branches).
	scripting_enabled             bool
	next_line_feed_can_be_ignored bool
	foster_parenting              bool
	stop_parsing                  bool
	aborted                       bool
	context_element               ?&dom.Element

	character_insertion_node    ?&dom.Text
	character_insertion_builder []rune

	pending_table_character_tokens []HTMLToken
}

// Parse `input` into `document`. The document is marked as an HTML document so that HTML-namespaced
// elements report uppercase tag names, matching a real parse.
pub fn HTMLParser.create(document &dom.Document, input string) &HTMLParser {
	mut doc := document
	doc.set_document_type(.html)
	return &HTMLParser{
		document:  document
		tokenizer: HTMLTokenizer.new(input)
	}
}

fn same_node(a &dom.Node, b &dom.Node) bool {
	return a.is_same_node(b)
}

fn node_as_text(n &dom.Node) &dom.Text {
	return unsafe { &dom.Text(n) }
}

// ===== the run loop =====

pub fn (mut p HTMLParser) run() {
	p.stop_parsing = false
	for {
		mut token := p.tokenizer.next_token() or { break }

		if p.next_line_feed_can_be_ignored {
			p.next_line_feed_can_be_ignored = false
			if token.is_character() && token.code_point == `\n` {
				continue
			}
		}

		// https://html.spec.whatwg.org/multipage/parsing.html#tree-construction-dispatcher
		if p.should_process_using_html_rules(token) {
			p.process_using_the_rules_for(p.insertion_mode, mut token)
		} else {
			p.process_using_the_rules_for_foreign_content(mut token)
		}

		if token.is_end_of_file() {
			break
		}
		if p.stop_parsing {
			break
		}
	}
	p.flush_character_insertions()
}

fn (mut p HTMLParser) process_using_the_rules_for(mode InsertionMode, mut token HTMLToken) {
	match mode {
		.initial { p.handle_initial(mut token) }
		.before_html { p.handle_before_html(mut token) }
		.before_head { p.handle_before_head(mut token) }
		.in_head { p.handle_in_head(mut token) }
		.in_head_noscript { p.handle_in_head_noscript(mut token) }
		.after_head { p.handle_after_head(mut token) }
		.in_body { p.handle_in_body(mut token) }
		.text { p.handle_text(mut token) }
		.after_body { p.handle_after_body(mut token) }
		.after_after_body { p.handle_after_after_body(mut token) }
		.in_table { p.handle_in_table(mut token) }
		.in_table_text { p.handle_in_table_text(mut token) }
		.in_table_body { p.handle_in_table_body(mut token) }
		.in_row { p.handle_in_row(mut token) }
		.in_cell { p.handle_in_cell(mut token) }
		.in_caption { p.handle_in_caption(mut token) }
		.in_column_group { p.handle_in_column_group(mut token) }
		.in_template { p.handle_in_template(mut token) }
		.in_frameset { p.handle_in_frameset(mut token) }
		.after_frameset { p.handle_after_frameset(mut token) }
		.after_after_frameset { p.handle_after_after_frameset(mut token) }
	}
}

// ===== tree-building primitives =====

fn (p &HTMLParser) current_node() ?&dom.Element {
	if p.stack_of_open_elements.is_empty() {
		return none
	}
	return p.stack_of_open_elements.current_node()
}

fn (p &HTMLParser) adjusted_current_node() ?&dom.Element {
	if p.parsing_fragment && p.stack_of_open_elements.elements.len == 1 {
		return p.context_element
	}
	return p.current_node()
}

// https://html.spec.whatwg.org/multipage/parsing.html#appropriate-place-for-inserting-a-node
fn (mut p HTMLParser) find_appropriate_place_for_inserting_node_with_override(override_target ?&dom.Element) AdjustedInsertionLocation {
	target := override_target or { p.current_node() or { return AdjustedInsertionLocation{} } }
	mut location := AdjustedInsertionLocation{
		parent:                target.as_node()
		insert_before_sibling: none
	}
	if p.foster_parenting && target.local_name() in ['table', 'tbody', 'tfoot', 'thead', 'tr'] {
		last_template := p.stack_of_open_elements.last_element_with_tag_name('template')
		last_table := p.stack_of_open_elements.last_element_with_tag_name('table')
		if template := last_template.element {
			if last_table.element == none || last_template.index > last_table.index {
				template_element := unsafe { &dom.HTMLTemplateElement(template) }
				return AdjustedInsertionLocation{
					parent:                template_element.content().as_node()
					insert_before_sibling: none
				}
			}
		}
		if lt := last_table.element {
			if parent := lt.as_node().parent_node() {
				// If last table has a parent node, insert immediately before last table.
				location = AdjustedInsertionLocation{
					parent:                parent
					insert_before_sibling: lt.as_node()
				}
			} else if previous_element := p.stack_of_open_elements.element_immediately_above(lt) {
				// Otherwise, inside the element immediately above last table.
				location = AdjustedInsertionLocation{
					parent:                previous_element.as_node()
					insert_before_sibling: none
				}
			}
		} else {
			// No last table (fragment case): inside the first element, after its last child.
			location = AdjustedInsertionLocation{
				parent:                p.stack_of_open_elements.first().as_node()
				insert_before_sibling: none
			}
		}
	}
	// If the adjusted insertion location is inside a template element, redirect to its contents.
	if parent := location.parent {
		if el := parent.as_element() {
			if element_in_namespace(el, ns_html) && el.local_name() == 'template' {
				template_element := unsafe { &dom.HTMLTemplateElement(el) }
				return AdjustedInsertionLocation{
					parent:                template_element.content().as_node()
					insert_before_sibling: none
				}
			}
		}
	}
	return location
}

fn (mut p HTMLParser) find_appropriate_place_for_inserting_node() AdjustedInsertionLocation {
	return p.find_appropriate_place_for_inserting_node_with_override(none)
}

// ===== table-context stack helpers =====

fn (mut p HTMLParser) clear_the_stack_back_to_a_table_context() {
	for {
		cn := p.current_node() or { break }
		if cn.local_name() in ['table', 'template', 'html'] {
			break
		}
		p.stack_of_open_elements.pop()
	}
}

fn (mut p HTMLParser) clear_the_stack_back_to_a_table_row_context() {
	for {
		cn := p.current_node() or { break }
		if cn.local_name() in ['tr', 'template', 'html'] {
			break
		}
		p.stack_of_open_elements.pop()
	}
}

fn (mut p HTMLParser) clear_the_stack_back_to_a_table_body_context() {
	for {
		cn := p.current_node() or { break }
		if cn.local_name() in ['tbody', 'tfoot', 'thead', 'template', 'html'] {
			break
		}
		p.stack_of_open_elements.pop()
	}
}

fn (mut p HTMLParser) close_the_cell() {
	p.generate_implied_end_tags('')
	for {
		cn := p.current_node() or { break }
		if cn.local_name() in ['td', 'th'] {
			break
		}
		p.stack_of_open_elements.pop()
	}
	p.stack_of_open_elements.pop()
	p.list_of_active_formatting_elements.clear_up_to_the_last_marker()
	p.insertion_mode = .in_row
}

// https://html.spec.whatwg.org/multipage/parsing.html#reset-the-insertion-mode-appropriately
fn (mut p HTMLParser) reset_the_insertion_mode_appropriately() {
	mut last := false
	for i := p.stack_of_open_elements.elements.len - 1; i >= 0; i-- {
		mut node := p.stack_of_open_elements.elements[i]
		if i == 0 {
			last = true
			if p.parsing_fragment {
				if ctx := p.context_element {
					node = ctx
				}
			}
		}
		if element_in_namespace(node, ns_html) {
			ln := node.local_name()
			if !last && ln in ['td', 'th'] {
				p.insertion_mode = .in_cell
				return
			}
			if ln == 'tr' {
				p.insertion_mode = .in_row
				return
			}
			if ln in ['tbody', 'thead', 'tfoot'] {
				p.insertion_mode = .in_table_body
				return
			}
			if ln == 'caption' {
				p.insertion_mode = .in_caption
				return
			}
			if ln == 'colgroup' {
				p.insertion_mode = .in_column_group
				return
			}
			if ln == 'table' {
				p.insertion_mode = .in_table
				return
			}
			if ln == 'template' {
				p.insertion_mode = if p.stack_of_template_insertion_modes.len > 0 {
					p.stack_of_template_insertion_modes[p.stack_of_template_insertion_modes.len - 1]
				} else {
					InsertionMode.in_body
				}
				return
			}
			if !last && ln == 'head' {
				p.insertion_mode = .in_head
				return
			}
			if ln == 'body' {
				p.insertion_mode = .in_body
				return
			}
			if ln == 'frameset' {
				p.insertion_mode = .in_frameset
				return
			}
			if ln == 'html' {
				p.insertion_mode = if p.head_element == none {
					InsertionMode.before_head
				} else {
					InsertionMode.after_head
				}
				return
			}
		}
		if last {
			p.insertion_mode = .in_body
			return
		}
	}
}

// https://html.spec.whatwg.org/multipage/parsing.html#create-an-element-for-the-token
fn (mut p HTMLParser) create_element_for(token &HTMLToken, namespace_ ?string, intended_parent &dom.Node) &dom.Element {
	// FIXME: the C++ uses intendedParent only to find the node document; here it is always p.document.
	_ = intended_parent
	local_name := token.tag_name
	is_value := token.attribute('is')
	mut element := dom.create_element(p.document, local_name, namespace_, none, is_value, false) or {
		panic('create_element_for(${local_name}): ${err}')
	}
	// Append each attribute in the token to element. Foreign-content attributes carry a prefix and
	// namespace (from adjust_foreign_attributes). (FIXME: form association, custom elements, and
	// speculative parsing are not handled.)
	for attribute in token.attributes {
		if attribute.prefix != none || attribute.namespace_ != none {
			element.set_attribute_value_ns(attribute.local_name, attribute.value, attribute.prefix,
				attribute.namespace_)
		} else if !element.has_attribute(attribute.local_name) {
			element.set_attribute_value(attribute.local_name, attribute.value)
		}
	}
	return element
}

// https://html.spec.whatwg.org/multipage/parsing.html#insert-a-foreign-element
fn (mut p HTMLParser) insert_foreign_element(token &HTMLToken, namespace_ ?string, only_add_to_element_stack bool) &dom.Element {
	location := p.find_appropriate_place_for_inserting_node()
	parent := location.parent or { panic('insert_foreign_element with no insertion parent') }
	element := p.create_element_for(token, namespace_, parent)
	if !only_add_to_element_stack {
		p.insert_an_element_at_the_adjusted_insertion_location(element)
	}
	p.stack_of_open_elements.push(element)
	return element
}

// https://html.spec.whatwg.org/multipage/parsing.html#insert-an-html-element
fn (mut p HTMLParser) insert_html_element(token &HTMLToken) &dom.Element {
	return p.insert_foreign_element(token, ns_html, false)
}

fn (mut p HTMLParser) insert_an_element_at_the_adjusted_insertion_location(element &dom.Element) {
	location := p.find_appropriate_place_for_inserting_node()
	mut parent := location.parent or { return }
	parent.insert_before(element.as_node(), location.insert_before_sibling, false)
}

fn (mut p HTMLParser) insert_comment(token &HTMLToken) {
	location := p.find_appropriate_place_for_inserting_node()
	mut parent := location.parent or { return }
	comment := p.document.create_comment(token.comment())
	parent.insert_before(comment.as_node(), location.insert_before_sibling, false)
}

fn (mut p HTMLParser) find_character_insertion_node() ?&dom.Text {
	location := p.find_appropriate_place_for_inserting_node()
	mut parent := location.parent or { return none }
	if sibling := location.insert_before_sibling {
		if prev := sibling.previous_sibling() {
			if prev.is_text() {
				return node_as_text(prev)
			}
		}
		new_text := p.document.create_text_node('')
		parent.insert_before(new_text.as_node(), sibling, false)
		return new_text
	}
	if parent.is_document() {
		return none
	}
	if last := parent.last_child() {
		if last.is_text() {
			return node_as_text(last)
		}
	}
	mut new_text := p.document.create_text_node('')
	parent.append_child(new_text.as_node()) or {}
	return new_text
}

fn (mut p HTMLParser) flush_character_insertions() {
	if p.character_insertion_builder.len == 0 {
		return
	}
	mut node := p.character_insertion_node or {
		p.character_insertion_builder = []
		return
	}

	data := runes_to_string(p.character_insertion_builder)
	if node.data() == '' {
		node.set_data(data)
	} else {
		node.append_data(data) or {}
	}
	p.character_insertion_builder = []
}

fn (mut p HTMLParser) insert_character(data rune) {
	node := p.find_character_insertion_node() or { return }
	if cin := p.character_insertion_node {
		if same_node(node.as_node(), cin.as_node()) {
			p.character_insertion_builder << data
			return
		}
		p.flush_character_insertions()
		p.character_insertion_node = node
		p.character_insertion_builder << data
		return
	}
	p.character_insertion_node = node
	p.character_insertion_builder << data
}

// ===== implied end tags / p closing =====

const implied_end_tag_names = ['dd', 'dt', 'li', 'optgroup', 'option', 'p', 'rb', 'rp', 'rt', 'rtc']

fn (mut p HTMLParser) generate_implied_end_tags(exception string) {
	for {
		cn := p.current_node() or { break }
		if cn.local_name() == exception || cn.local_name() !in implied_end_tag_names {
			break
		}
		p.stack_of_open_elements.pop()
	}
}

fn (mut p HTMLParser) generate_all_implied_end_tags_thoroughly() {
	all := ['caption', 'colgroup', 'dd', 'dt', 'li', 'optgroup', 'option', 'p', 'rb', 'rp', 'rt',
		'rtc', 'tbody', 'td', 'tfoot', 'th', 'thead', 'tr']
	for {
		cn := p.current_node() or { break }
		if cn.local_name() !in all {
			break
		}
		p.stack_of_open_elements.pop()
	}
}

fn (mut p HTMLParser) close_a_p_element() {
	p.generate_implied_end_tags('p')
	p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped('p')
}

// https://html.spec.whatwg.org/multipage/parsing.html#reconstruct-the-active-formatting-elements
fn (mut p HTMLParser) reconstruct_the_active_formatting_elements() {
	if p.list_of_active_formatting_elements.is_empty() {
		return
	}
	entries := p.list_of_active_formatting_elements.entries
	last := entries[entries.len - 1]
	if last.is_marker() {
		return
	}
	if last_el := last.element {
		if p.stack_of_open_elements.contains(last_el) {
			return
		}
	}

	mut index := entries.len - 1
	// Rewind.
	for {
		if index == 0 {
			break
		}
		index--
		entry := p.list_of_active_formatting_elements.entries[index]
		if entry.is_marker() {
			index++ // Advance.
			break
		}
		if el := entry.element {
			if p.stack_of_open_elements.contains(el) {
				index++ // Advance.
				break
			}
		}
	}

	// Create / Advance loop.
	for {
		entry := p.list_of_active_formatting_elements.entries[index]
		token := entry.token or { break }
		old_element := entry.element or { break }
		new_element := p.insert_html_element(token)
		p.list_of_active_formatting_elements.replace(old_element, new_element, token)
		if index == p.list_of_active_formatting_elements.entries.len - 1 {
			break
		}
		index++
	}
}

fn (mut p HTMLParser) parse_generic_raw_text_element(token &HTMLToken) {
	p.insert_html_element(token)
	p.tokenizer.switch_to(.rawtext)
	p.original_insertion_mode = p.insertion_mode
	p.insertion_mode = .text
}

fn (p &HTMLParser) which_quirks_mode(token &HTMLToken) dom.QuirksMode {
	_ = p
	if token.doctype.force_quirks {
		return .yes
	}
	// NOTE: the tokenizer lower-cases the name for us.
	if token.doctype.name != 'html' {
		return .yes
	}
	public_identifier := ascii_lowercase_string(token.doctype.public_identifier)
	system_identifier := ascii_lowercase_string(token.doctype.system_identifier)
	if public_identifier in ['-//w3o//dtd w3 html strict 3.0//en//',
		'-/w3c/dtd html 4.0 transitional/en', 'html'] {
		return .yes
	}
	if system_identifier == 'http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd' {
		return .yes
	}
	for public_id in quirks_public_id_prefixes {
		if public_identifier.starts_with(ascii_lowercase_string(public_id)) {
			return .yes
		}
	}
	if token.doctype.missing_system_identifier
		&& (public_identifier.starts_with('-//w3c//dtd html 4.01 frameset//')
		|| public_identifier.starts_with('-//w3c//dtd html 4.01 transitional//')) {
		return .yes
	}
	if public_identifier.starts_with('-//w3c//dtd xhtml 1.0 frameset//')
		|| public_identifier.starts_with('-//w3c//dtd xhtml 1.0 transitional//') {
		return .limited
	}
	if !token.doctype.missing_system_identifier
		&& (public_identifier.starts_with('-//w3c//dtd html 4.01 frameset//')
		|| public_identifier.starts_with('-//w3c//dtd html 4.01 transitional//')) {
		return .limited
	}
	return .no
}

// ===== adoption agency algorithm =====
// https://html.spec.whatwg.org/multipage/parsing.html#adoption-agency-algorithm

enum AdoptionAgencyOutcome {
	do_nothing
	run_any_other_end_tag_steps
}

fn (mut p HTMLParser) run_the_adoption_agency_algorithm(token &HTMLToken) AdoptionAgencyOutcome {
	subject := token.tag_name

	// 2. If the current node is an HTML element whose tag name is subject, and is not in the list of
	//    active formatting elements, pop it and return.
	if cn := p.current_node() {
		if cn.local_name() == subject && !p.list_of_active_formatting_elements.contains(cn) {
			p.stack_of_open_elements.pop()
			return .do_nothing
		}
	}

	mut outer_loop_counter := 0
	for {
		if outer_loop_counter >= 8 {
			return .do_nothing
		}
		outer_loop_counter++

		// 3. formattingElement = last element with tag name subject before the last marker.
		formatting_element := p.list_of_active_formatting_elements.last_element_with_tag_name_before_marker(subject) or {
			return .run_any_other_end_tag_steps
		}

		// 4. Not in the stack of open elements -> remove from AFE and return.
		if !p.stack_of_open_elements.contains(formatting_element) {
			p.list_of_active_formatting_elements.remove(formatting_element)
			return .do_nothing
		}

		// 5. In the stack but not in scope -> return.
		if !p.stack_of_open_elements.has_in_scope_element(formatting_element) {
			return .do_nothing
		}

		// 7. furthestBlock = topmost special node below formattingElement.
		furthest_block := p.stack_of_open_elements.topmost_special_node_below(formatting_element) or {
			// 8. No furthestBlock: pop up to and including formattingElement, remove from AFE, return.
			for {
				cn := p.current_node() or { break }
				if same_element(cn, formatting_element) {
					break
				}
				p.stack_of_open_elements.pop()
			}
			p.stack_of_open_elements.pop()
			p.list_of_active_formatting_elements.remove(formatting_element)
			return .do_nothing
		}

		// 9. commonAncestor = element immediately above formattingElement.
		common_ancestor := p.stack_of_open_elements.element_immediately_above(formatting_element) or {
			return .do_nothing
		}

		// 10. bookmark.
		mut bookmark := p.list_of_active_formatting_elements.find_index(formatting_element) or { 0 }

		// 11. node and lastNode = furthestBlock.
		mut node := furthest_block
		mut last_node := furthest_block
		mut node_above_node := p.stack_of_open_elements.element_immediately_above(node)

		mut inner_loop_counter := 0
		for {
			inner_loop_counter++

			// 2. node = element immediately above node.
			node = node_above_node or { break }
			node_above_node = p.stack_of_open_elements.element_immediately_above(node)

			// 3. If node is formattingElement, break.
			if same_element(node, formatting_element) {
				break
			}

			mut node_index := p.list_of_active_formatting_elements.find_index(node)

			// 4. innerLoopCounter > 3 and node in AFE -> remove from AFE.
			if inner_loop_counter > 3 {
				if idx := node_index {
					if idx < bookmark {
						bookmark--
					}
					p.list_of_active_formatting_elements.remove(node)
					node_index = none
				}
			}

			// 5. node not in AFE -> remove from stack and continue.
			idx := node_index or {
				p.stack_of_open_elements.remove(node)
				continue
			}

			// 6. Create a new element for node's token, replace entries, node = new element.
			entry := p.list_of_active_formatting_elements.entries[idx]
			entry_token := entry.token or { continue }
			element := p.create_element_for(entry_token, ns_html, common_ancestor.as_node())
			p.list_of_active_formatting_elements.replace(node, element, entry_token)
			p.stack_of_open_elements.replace(node, element)
			node = element

			// 7. If lastNode is furthestBlock, move bookmark after new node.
			if same_element(last_node, furthest_block) {
				bookmark = (p.list_of_active_formatting_elements.find_index(node) or { 0 }) + 1
			}

			// 8. Append lastNode to node.
			mut node_dom := node.as_node()
			node_dom.append_child(last_node.as_node()) or {}

			// 9. lastNode = node.
			last_node = node
		}

		// 14. Insert lastNode at the appropriate place with commonAncestor as override target.
		adjusted_location :=
			p.find_appropriate_place_for_inserting_node_with_override(common_ancestor)
		mut adjusted_parent := adjusted_location.parent or { return .do_nothing }
		adjusted_parent.insert_before(last_node.as_node(), adjusted_location.insert_before_sibling,
			false)

		// 15. Create a new element for formattingElement's token, with furthestBlock as intended parent.
		formatting_element_index := p.list_of_active_formatting_elements.find_index(formatting_element) or {
			return .do_nothing
		}
		fe_entry := p.list_of_active_formatting_elements.entries[formatting_element_index]
		fe_token := fe_entry.token or { return .do_nothing }
		token_data := create_own_token(fe_token)
		new_element := p.create_element_for(token_data, ns_html, furthest_block.as_node())

		// 16. Move furthestBlock's children into the new element.
		mut fb_node := furthest_block.as_node()
		mut new_element_node := new_element.as_node()
		for child in fb_node.children_as_vector() {
			removed := fb_node.remove_child(child) or { continue }
			new_element_node.append_child(removed) or {}
		}

		// 17. Append the new element to furthestBlock.
		fb_node.append_child(new_element.as_node()) or {}

		// 18. Remove formattingElement from AFE, insert new element at bookmark.
		if formatting_element_index < bookmark {
			bookmark--
		}
		p.list_of_active_formatting_elements.remove(formatting_element)
		p.list_of_active_formatting_elements.insert_at(bookmark, new_element, token_data)

		// 19. Remove formattingElement from the stack, insert new element below furthestBlock.
		p.stack_of_open_elements.remove(formatting_element)
		p.stack_of_open_elements.insert_immediately_below(new_element, furthest_block)
	}
	return .do_nothing
}
