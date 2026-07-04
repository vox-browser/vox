module html

import dom

// The insertion-mode handlers for HTMLParser (see html_parser.v). Each mirrors a section of
// https://html.spec.whatwg.org/multipage/parsing.html. Cases that "act as the anything-else entry"
// are factored into an *_anything_else helper (V has no goto).

const head_element_start_tags = ['base', 'basefont', 'bgsound', 'link', 'meta', 'noframes', 'script',
	'style', 'template', 'title']

const block_start_tags = ['address', 'article', 'aside', 'blockquote', 'center', 'details', 'dialog',
	'dir', 'div', 'dl', 'fieldset', 'figcaption', 'figure', 'footer', 'header', 'hgroup', 'main',
	'menu', 'nav', 'ol', 'p', 'search', 'section', 'summary', 'ul']

const block_end_tags = ['address', 'article', 'aside', 'blockquote', 'button', 'center', 'details',
	'dialog', 'dir', 'div', 'dl', 'fieldset', 'figcaption', 'figure', 'footer', 'header', 'hgroup',
	'listing', 'main', 'menu', 'nav', 'ol', 'pre', 'search', 'section', 'select', 'summary', 'ul']

const heading_tags = ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']

const formatting_start_tags = ['b', 'big', 'code', 'em', 'font', 'i', 's', 'small', 'strike',
	'strong', 'tt', 'u']

const formatting_end_tags = ['a', 'b', 'big', 'code', 'em', 'font', 'i', 'nobr', 's', 'small',
	'strike', 'strong', 'tt', 'u']

fn (mut p HTMLParser) document_as_node() &dom.Node {
	return unsafe { &dom.Node(p.document) }
}

// https://html.spec.whatwg.org/multipage/parsing.html#the-initial-insertion-mode
fn (mut p HTMLParser) handle_initial(mut token HTMLToken) {
	if token.is_character() && token.is_parser_whitespace() {
		return
	}
	if token.is_comment() {
		mut doc_node := p.document_as_node()
		comment := p.document.create_comment(token.comment())
		doc_node.append_child(comment.as_node()) or {}
		return
	}
	if token.is_doctype() {
		mut doctype := dom.DocumentType.create(p.document)
		doctype.set_name(token.doctype.name)
		doctype.set_public_id(token.doctype.public_identifier)
		doctype.set_system_id(token.doctype.system_identifier)
		mut doc_node := p.document_as_node()
		doc_node.append_child(doctype.as_node()) or {}
		p.document.set_quirks_mode(p.which_quirks_mode(token))
		p.insertion_mode = .before_html
		return
	}
	p.document.set_quirks_mode(.yes)
	p.insertion_mode = .before_html
	p.process_using_the_rules_for(.before_html, mut token)
}

// https://html.spec.whatwg.org/multipage/parsing.html#the-before-html-insertion-mode
fn (mut p HTMLParser) handle_before_html(mut token HTMLToken) {
	if token.is_doctype() {
		return
	}
	if token.is_comment() {
		mut doc_node := p.document_as_node()
		comment := p.document.create_comment(token.comment())
		doc_node.append_child(comment.as_node()) or {}
		return
	}
	if token.is_character() && token.is_parser_whitespace() {
		return
	}
	if token.is_start_tag() && token.tag_name == 'html' {
		mut doc_node := p.document_as_node()
		element := p.create_element_for(token, ns_html, doc_node)
		doc_node.append_child(element.as_node()) or {}
		p.stack_of_open_elements.push(element)
		p.insertion_mode = .before_head
		return
	}
	if token.is_end_tag() && token.tag_name !in ['head', 'body', 'html', 'br'] {
		return
	}
	// Anything else (and end tags head/body/html/br).
	mut synth := HTMLToken.make_start_tag('html')
	mut doc_node := p.document_as_node()
	element := p.create_element_for(synth, ns_html, doc_node)
	doc_node.append_child(element.as_node()) or {}
	p.stack_of_open_elements.push(element)
	p.insertion_mode = .before_head
	p.process_using_the_rules_for(.before_head, mut token)
}

// https://html.spec.whatwg.org/multipage/parsing.html#the-before-head-insertion-mode
fn (mut p HTMLParser) handle_before_head(mut token HTMLToken) {
	if token.is_character() && token.is_parser_whitespace() {
		return
	}
	if token.is_comment() {
		p.insert_comment(token)
		return
	}
	if token.is_doctype() {
		return
	}
	if token.is_start_tag() && token.tag_name == 'html' {
		p.handle_in_body(mut token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'head' {
		element := p.insert_html_element(token)
		p.head_element = element
		p.insertion_mode = .in_head
		return
	}
	if token.is_end_tag() && token.tag_name !in ['head', 'body', 'html', 'br'] {
		return
	}
	// Anything else.
	mut synth := HTMLToken.make_start_tag('head')
	element := p.insert_html_element(synth)
	p.head_element = element
	p.insertion_mode = .in_head
	p.process_using_the_rules_for(.in_head, mut token)
}

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inhead
fn (mut p HTMLParser) handle_in_head(mut token HTMLToken) {
	if token.is_character() && token.is_parser_whitespace() {
		p.insert_character(token.code_point)
		return
	}
	if token.is_comment() {
		p.insert_comment(token)
		return
	}
	if token.is_doctype() {
		return
	}
	if token.is_start_tag() && token.tag_name == 'html' {
		p.handle_in_body(mut token)
		return
	}
	if token.is_start_tag() && token.tag_name in ['base', 'basefont', 'bgsound', 'link', 'meta'] {
		p.insert_html_element(token)
		p.stack_of_open_elements.pop()
		token.acknowledge_self_closing_flag_if_set()
		return
	}
	if token.is_start_tag() && token.tag_name == 'title' {
		// Generic RCDATA element parsing.
		p.insert_html_element(token)
		p.tokenizer.switch_to(.rcdata)
		p.original_insertion_mode = p.insertion_mode
		p.insertion_mode = .text
		return
	}
	if token.is_start_tag()
		&& ((token.tag_name == 'noscript' && p.scripting_enabled)
		|| token.tag_name in ['noframes', 'style']) {
		p.parse_generic_raw_text_element(token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'noscript' && !p.scripting_enabled {
		p.insert_html_element(token)
		p.insertion_mode = .in_head_noscript
		return
	}
	if token.is_start_tag() && token.tag_name == 'script' {
		// FIXME: no scripting. Insert the element and treat its content as raw text via the
		// script-data tokenizer state, without preparing/executing the script.
		location := p.find_appropriate_place_for_inserting_node()
		mut parent := location.parent or { return }
		element := p.create_element_for(token, ns_html, parent)
		parent.insert_before(element.as_node(), location.insert_before_sibling, false)
		p.stack_of_open_elements.push(element)
		p.tokenizer.switch_to(.script_data)
		p.original_insertion_mode = p.insertion_mode
		p.insertion_mode = .text
		return
	}
	if token.is_end_tag() && token.tag_name == 'head' {
		p.stack_of_open_elements.pop()
		p.insertion_mode = .after_head
		return
	}
	if token.is_end_tag() && token.tag_name in ['body', 'html', 'br'] {
		p.in_head_anything_else(mut token)
		return
	}
	// FIXME: <template> start/end is not supported.
	if (token.is_start_tag() && token.tag_name == 'head') || token.is_end_tag() {
		return
	}
	p.in_head_anything_else(mut token)
}

fn (mut p HTMLParser) in_head_anything_else(mut token HTMLToken) {
	p.stack_of_open_elements.pop()
	p.insertion_mode = .after_head
	p.process_using_the_rules_for(.after_head, mut token)
}

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inheadnoscript
fn (mut p HTMLParser) handle_in_head_noscript(mut token HTMLToken) {
	if token.is_doctype() {
		return
	}
	if token.is_start_tag() && token.tag_name == 'html' {
		p.handle_in_body(mut token)
		return
	}
	if token.is_end_tag() && token.tag_name == 'noscript' {
		p.stack_of_open_elements.pop()
		p.insertion_mode = .in_head
		return
	}
	if token.is_parser_whitespace() || token.is_comment()
		|| (token.is_start_tag()
		&& token.tag_name in ['basefont', 'bgsound', 'link', 'meta', 'noframes', 'style']) {
		p.handle_in_head(mut token)
		return
	}
	if token.is_end_tag() && token.tag_name == 'br' {
		p.in_head_noscript_anything_else(mut token)
		return
	}
	if (token.is_start_tag() && token.tag_name in ['head', 'noscript']) || token.is_end_tag() {
		return
	}
	p.in_head_noscript_anything_else(mut token)
}

fn (mut p HTMLParser) in_head_noscript_anything_else(mut token HTMLToken) {
	p.stack_of_open_elements.pop()
	p.insertion_mode = .in_head
	p.process_using_the_rules_for(.in_head, mut token)
}

// https://html.spec.whatwg.org/multipage/parsing.html#the-after-head-insertion-mode
fn (mut p HTMLParser) handle_after_head(mut token HTMLToken) {
	if token.is_character() && token.is_parser_whitespace() {
		p.insert_character(token.code_point)
		return
	}
	if token.is_comment() {
		p.insert_comment(token)
		return
	}
	if token.is_doctype() {
		return
	}
	if token.is_start_tag() && token.tag_name == 'html' {
		p.handle_in_body(mut token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'body' {
		p.insert_html_element(token)
		p.frameset_ok = false
		p.insertion_mode = .in_body
		return
	}
	if token.is_start_tag() && token.tag_name in head_element_start_tags {
		// Push the head element back on, process in "in head", then remove it again.
		if head := p.head_element {
			p.stack_of_open_elements.push(head)
			p.handle_in_head(mut token)
			p.stack_of_open_elements.remove(head)
		}
		return
	}
	if token.is_end_tag() && token.tag_name == 'template' {
		p.handle_in_head(mut token)
		return
	}
	if token.is_end_tag() && token.tag_name in ['body', 'html', 'br'] {
		p.after_head_anything_else(mut token)
		return
	}
	if (token.is_start_tag() && token.tag_name == 'head') || token.is_end_tag() {
		return
	}
	p.after_head_anything_else(mut token)
}

fn (mut p HTMLParser) after_head_anything_else(mut token HTMLToken) {
	mut synth := HTMLToken.make_start_tag('body')
	p.insert_html_element(synth)
	p.insertion_mode = .in_body
	p.process_using_the_rules_for(.in_body, mut token)
}

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inbody
fn (mut p HTMLParser) handle_in_body(mut token HTMLToken) {
	if token.is_character() {
		if token.code_point == 0 {
			return
		}
		p.reconstruct_the_active_formatting_elements()
		p.insert_character(token.code_point)
		if !token.is_parser_whitespace() {
			p.frameset_ok = false
		}
		return
	}
	if token.is_comment() {
		p.insert_comment(token)
		return
	}
	if token.is_doctype() {
		return
	}
	if token.is_start_tag() && token.tag_name == 'html' {
		if p.stack_of_open_elements.contains_template_element() {
			return
		}
		mut top := p.stack_of_open_elements.first()
		for attribute in token.attributes {
			if !top.has_attribute(attribute.local_name) {
				top.set_attribute_value(attribute.local_name, attribute.value)
			}
		}
		return
	}
	if (token.is_start_tag() && token.tag_name in head_element_start_tags)
		|| (token.is_end_tag() && token.tag_name == 'template') {
		p.handle_in_head(mut token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'body' {
		if p.stack_of_open_elements.elements.len == 1
			|| p.stack_of_open_elements.elements[1].local_name() != 'body'
			|| p.stack_of_open_elements.contains_template_element() {
			return
		}
		p.frameset_ok = false
		mut body := p.stack_of_open_elements.elements[1]
		for attribute in token.attributes {
			if !body.has_attribute(attribute.local_name) {
				body.set_attribute_value(attribute.local_name, attribute.value)
			}
		}
		return
	}
	if token.is_end_of_file() {
		p.stop_parsing = true
		return
	}
	if token.is_end_tag() && token.tag_name == 'body' {
		if !p.stack_of_open_elements.has_in_scope('body') {
			return
		}
		p.insertion_mode = .after_body
		return
	}
	if token.is_end_tag() && token.tag_name == 'html' {
		if !p.stack_of_open_elements.has_in_scope('body') {
			return
		}
		p.insertion_mode = .after_body
		p.process_using_the_rules_for(.after_body, mut token)
		return
	}
	if token.is_start_tag() && token.tag_name in block_start_tags {
		if p.stack_of_open_elements.has_in_button_scope('p') {
			p.close_a_p_element()
		}
		p.insert_html_element(token)
		return
	}
	if token.is_start_tag() && token.tag_name in heading_tags {
		if p.stack_of_open_elements.has_in_button_scope('p') {
			p.close_a_p_element()
		}
		if cn := p.current_node() {
			if cn.local_name() in heading_tags {
				p.stack_of_open_elements.pop()
			}
		}
		p.insert_html_element(token)
		return
	}
	if token.is_start_tag() && token.tag_name in ['pre', 'listing'] {
		if p.stack_of_open_elements.has_in_button_scope('p') {
			p.close_a_p_element()
		}
		p.insert_html_element(token)
		p.next_line_feed_can_be_ignored = true
		p.frameset_ok = false
		return
	}
	if token.is_start_tag() && token.tag_name == 'form' {
		if p.form_element != none && !p.stack_of_open_elements.contains_template_element() {
			return
		}
		if p.stack_of_open_elements.has_in_button_scope('p') {
			p.close_a_p_element()
		}
		element := p.insert_html_element(token)
		if !p.stack_of_open_elements.contains_template_element() {
			p.form_element = element
		}
		return
	}
	if token.is_start_tag() && token.tag_name == 'li' {
		p.frameset_ok = false
		for i := p.stack_of_open_elements.elements.len - 1; i >= 0; i-- {
			node := p.stack_of_open_elements.elements[i]
			if node.local_name() == 'li' {
				p.generate_implied_end_tags('li')
				p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped('li')
				break
			}
			if is_special_tag(node.local_name(), node.namespace_uri())
				&& node.local_name() !in ['address', 'div', 'p'] {
				break
			}
		}
		if p.stack_of_open_elements.has_in_button_scope('p') {
			p.close_a_p_element()
		}
		p.insert_html_element(token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'a' {
		if existing := p.list_of_active_formatting_elements.last_element_with_tag_name_before_marker('a') {
			p.run_the_adoption_agency_algorithm(token)
			p.stack_of_open_elements.remove(existing)
			p.list_of_active_formatting_elements.remove(existing)
		}
		p.reconstruct_the_active_formatting_elements()
		element := p.insert_html_element(token)
		p.list_of_active_formatting_elements.add(element, token)
		return
	}
	if token.is_start_tag() && token.tag_name in formatting_start_tags {
		p.reconstruct_the_active_formatting_elements()
		element := p.insert_html_element(token)
		p.list_of_active_formatting_elements.add(element, token)
		return
	}
	if token.is_end_tag() && token.tag_name in formatting_end_tags {
		if p.run_the_adoption_agency_algorithm(token) == .run_any_other_end_tag_steps {
			p.in_body_any_other_end_tag(mut token)
		}
		return
	}
	if token.is_end_tag() && token.tag_name in block_end_tags {
		if !p.stack_of_open_elements.has_in_scope(token.tag_name) {
			return
		}
		p.generate_implied_end_tags('')
		p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped(token.tag_name)
		return
	}
	if token.is_end_tag() && token.tag_name == 'p' {
		if !p.stack_of_open_elements.has_in_button_scope('p') {
			mut synth := HTMLToken.make_start_tag('p')
			p.insert_html_element(synth)
		}
		p.close_a_p_element()
		return
	}
	if token.is_end_tag() && token.tag_name == 'li' {
		if !p.stack_of_open_elements.has_in_list_item_scope('li') {
			return
		}
		p.generate_implied_end_tags('li')
		p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped('li')
		return
	}
	if token.is_end_tag() && token.tag_name in heading_tags {
		mut in_scope := false
		for h in heading_tags {
			if p.stack_of_open_elements.has_in_scope(h) {
				in_scope = true
				break
			}
		}
		if !in_scope {
			return
		}
		p.generate_implied_end_tags('')
		// Pop until any heading element has been popped.
		for {
			popped := p.stack_of_open_elements.pop()
			if popped.local_name() in heading_tags {
				break
			}
			if p.stack_of_open_elements.is_empty() {
				break
			}
		}
		return
	}
	// FIXME: table/select/foreign and several other start tags are not handled specially.
	if token.is_start_tag() {
		p.reconstruct_the_active_formatting_elements()
		p.insert_html_element(token)
		return
	}
	if token.is_end_tag() {
		p.in_body_any_other_end_tag(mut token)
		return
	}
}

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inbody (any other end tag)
fn (mut p HTMLParser) in_body_any_other_end_tag(mut token HTMLToken) {
	for i := p.stack_of_open_elements.elements.len - 1; i >= 0; i-- {
		node := p.stack_of_open_elements.elements[i]
		if node.local_name() == token.tag_name {
			p.generate_implied_end_tags(token.tag_name)
			for {
				cn := p.current_node() or { break }
				if same_element(cn, node) {
					break
				}
				p.stack_of_open_elements.pop()
			}
			p.stack_of_open_elements.pop()
			return
		}
		if is_special_tag(node.local_name(), node.namespace_uri()) {
			return
		}
	}
}

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-incdata (text insertion mode)
fn (mut p HTMLParser) handle_text(mut token HTMLToken) {
	if token.is_character() {
		p.insert_character(token.code_point)
		return
	}
	if token.is_end_of_file() {
		// FIXME: no script "already started" handling.
		p.stack_of_open_elements.pop()
		p.insertion_mode = p.original_insertion_mode
		p.process_using_the_rules_for(p.insertion_mode, mut token)
		return
	}
	if token.is_end_tag() {
		// FIXME: <script> end tag does not prepare/execute the script.
		p.stack_of_open_elements.pop()
		p.insertion_mode = p.original_insertion_mode
		return
	}
}

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-afterbody
fn (mut p HTMLParser) handle_after_body(mut token HTMLToken) {
	if token.is_character() && token.is_parser_whitespace() {
		p.handle_in_body(mut token)
		return
	}
	if token.is_comment() {
		mut first := p.stack_of_open_elements.first()
		mut first_node := first.as_node()
		comment := p.document.create_comment(token.comment())
		first_node.append_child(comment.as_node()) or {}
		return
	}
	if token.is_doctype() {
		return
	}
	if token.is_start_tag() && token.tag_name == 'html' {
		p.handle_in_body(mut token)
		return
	}
	if token.is_end_tag() && token.tag_name == 'html' {
		if p.parsing_fragment {
			return
		}
		p.insertion_mode = .after_after_body
		return
	}
	if token.is_end_of_file() {
		p.stop_parsing = true
		return
	}
	// Anything else.
	p.insertion_mode = .in_body
	p.process_using_the_rules_for(.in_body, mut token)
}

// https://html.spec.whatwg.org/multipage/parsing.html#the-after-after-body-insertion-mode
fn (mut p HTMLParser) handle_after_after_body(mut token HTMLToken) {
	if token.is_comment() {
		mut doc_node := p.document_as_node()
		comment := p.document.create_comment(token.comment())
		doc_node.append_child(comment.as_node()) or {}
		return
	}
	if token.is_doctype() || token.is_parser_whitespace()
		|| (token.is_start_tag() && token.tag_name == 'html') {
		p.handle_in_body(mut token)
		return
	}
	if token.is_end_of_file() {
		p.stop_parsing = true
		return
	}
	// Anything else.
	p.insertion_mode = .in_body
	p.process_using_the_rules_for(.in_body, mut token)
}
