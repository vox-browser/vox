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

const formatting_start_tags = ['b', 'big', 'code', 'em', 'font', 'i', 's', 'small', 'strike', 'strong',
	'tt', 'u']

const formatting_end_tags = ['a', 'b', 'big', 'code', 'em', 'font', 'i', 'nobr', 's', 'small',
	'strike', 'strong', 'tt', 'u']

fn (mut p HTMLParser) document_as_node() &dom.Node {
	return unsafe { &dom.Node(p.document_) }
}

// https://html.spec.whatwg.org/multipage/parsing.html#the-initial-insertion-mode
fn (mut p HTMLParser) handle_initial(mut token HTMLToken) {
	if token.is_character() && token.is_parser_whitespace() {
		return
	}
	if token.is_comment_or_processing_instruction() {
		mut doc_node := p.document_as_node()
		comment := p.comment_or_processing_instruction_node(token)
		doc_node.append_child(comment) or {}
		return
	}
	if token.is_doctype() {
		mut doctype := dom.DocumentType.create(p.document_)
		doctype.set_name(p.own_tokenizer_string(token.doctype.name))
		doctype.set_public_id(p.own_tokenizer_string(token.doctype.public_identifier))
		doctype.set_system_id(p.own_tokenizer_string(token.doctype.system_identifier))
		mut doc_node := p.document_as_node()
		doc_node.append_child(doctype.as_node()) or {}
		p.document_.set_quirks_mode(p.which_quirks_mode(token))
		p.insertion_mode = .before_html
		return
	}
	p.document_.set_quirks_mode(.yes)
	p.insertion_mode = .before_html
	p.process_using_the_rules_for(.before_html, mut token)
}

// https://html.spec.whatwg.org/multipage/parsing.html#the-before-html-insertion-mode
fn (mut p HTMLParser) handle_before_html(mut token HTMLToken) {
	if token.is_doctype() {
		return
	}
	if token.is_comment_or_processing_instruction() {
		mut doc_node := p.document_as_node()
		comment := p.comment_or_processing_instruction_node(token)
		doc_node.append_child(comment) or {}
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
	if token.is_comment_or_processing_instruction() {
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
	if token.is_comment_or_processing_instruction() {
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
	if token.is_start_tag() && token.tag_name in ['base', 'basefont', 'bgsound', 'link'] {
		p.insert_html_element(token)
		p.stack_of_open_elements.pop()
		token.acknowledge_self_closing_flag_if_set()
		return
	}
	if token.is_start_tag() && token.tag_name == 'meta' {
		element := p.insert_html_element(token)
		p.stack_of_open_elements.pop()
		token.acknowledge_self_closing_flag_if_set()
		p.process_meta_element(element)
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
	if token.is_start_tag() && ((token.tag_name == 'noscript' && p.scripting_mode != .disabled) || token.tag_name in [
		'noframes',
		'style',
	]) {
		p.parse_generic_raw_text_element(token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'noscript' && p.scripting_mode == .disabled {
		p.insert_html_element(token)
		p.insertion_mode = .in_head_noscript
		return
	}
	if token.is_start_tag() && token.tag_name == 'script' {
		location := p.find_appropriate_place_for_inserting_node()
		mut parent := location.parent or { return }
		element := p.create_element_for(token, ns_html, parent)
		parent.insert_before(element.as_node(), location.insert_before_sibling, false)
		p.register_parser_inserted_script(element, token)
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
	if token.is_start_tag() && token.tag_name == 'template' {
		p.list_of_active_formatting_elements.add_marker()
		p.frameset_ok = false
		p.insertion_mode = .in_template
		p.stack_of_template_insertion_modes << InsertionMode.in_template
		p.insert_html_element(token)
		return
	}
	if token.is_end_tag() && token.tag_name == 'template' {
		if !p.stack_of_open_elements.contains_template_element() {
			return
		}
		template := p.stack_of_open_elements.last_element_with_tag_name('template').element
		p.generate_all_implied_end_tags_thoroughly()
		p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped('template')
		p.list_of_active_formatting_elements.clear_up_to_the_last_marker()
		if p.stack_of_template_insertion_modes.len > 0 {
			p.stack_of_template_insertion_modes.pop()
		}
		p.reset_the_insertion_mode_appropriately()
		if p.document_.allow_declarative_shadow_roots() {
			if owner := template {
				if owner.has_attribute('shadowrootmode') {
					if parent := owner.as_node().parent() { materialize_declarative_shadow_roots(parent) }
				}
			}
		}
		return
	}
	if (token.is_start_tag() && token.tag_name == 'head') || token.is_end_tag() {
		return
	}
	p.in_head_anything_else(mut token)
}

fn (mut p HTMLParser) switch_template_insertion_mode(mode InsertionMode) {
	if p.stack_of_template_insertion_modes.len > 0 {
		p.stack_of_template_insertion_modes.pop()
	}
	p.stack_of_template_insertion_modes << mode
}

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-intemplate
fn (mut p HTMLParser) handle_in_template(mut token HTMLToken) {
	if token.is_character() || token.is_comment_or_processing_instruction() || token.is_doctype() {
		p.handle_in_body(mut token)
		return
	}
	if (token.is_start_tag() && token.tag_name in head_element_start_tags) || (token.is_end_tag() && token.tag_name == 'template') {
		p.handle_in_head(mut token)
		return
	}
	if token.is_start_tag() && token.tag_name in ['caption', 'colgroup', 'tbody', 'tfoot', 'thead'] {
		p.switch_template_insertion_mode(.in_table)
		p.insertion_mode = .in_table
		p.process_using_the_rules_for(.in_table, mut token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'col' {
		p.switch_template_insertion_mode(.in_column_group)
		p.insertion_mode = .in_column_group
		p.process_using_the_rules_for(.in_column_group, mut token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'tr' {
		p.switch_template_insertion_mode(.in_table_body)
		p.insertion_mode = .in_table_body
		p.process_using_the_rules_for(.in_table_body, mut token)
		return
	}
	if token.is_start_tag() && token.tag_name in ['td', 'th'] {
		p.switch_template_insertion_mode(.in_row)
		p.insertion_mode = .in_row
		p.process_using_the_rules_for(.in_row, mut token)
		return
	}
	if token.is_start_tag() {
		p.switch_template_insertion_mode(.in_body)
		p.insertion_mode = .in_body
		p.process_using_the_rules_for(.in_body, mut token)
		return
	}
	if token.is_end_tag() {
		return
	}
	if token.is_end_of_file() {
		if !p.stack_of_open_elements.contains_template_element() {
			p.stop_parsing = true
			return
		}
		p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped('template')
		p.list_of_active_formatting_elements.clear_up_to_the_last_marker()
		if p.stack_of_template_insertion_modes.len > 0 {
			p.stack_of_template_insertion_modes.pop()
		}
		p.reset_the_insertion_mode_appropriately()
		p.process_using_the_rules_for(p.insertion_mode, mut token)
		return
	}
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
	if token.is_parser_whitespace() || token.is_comment_or_processing_instruction() || (token.is_start_tag() && token.tag_name in [
		'basefont',
		'bgsound',
		'link',
		'meta',
		'noframes',
		'style',
	]) {
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
	if token.is_comment_or_processing_instruction() {
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
	if token.is_start_tag() && token.tag_name == 'frameset' {
		p.insert_html_element(token)
		p.insertion_mode = .in_frameset
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
	if token.is_comment_or_processing_instruction() {
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
				top.set_attribute_value(p.own_tokenizer_string(attribute.local_name), p.own_tokenizer_string(attribute.value))
			}
		}
		return
	}
	if (token.is_start_tag() && token.tag_name in head_element_start_tags) || (token.is_end_tag() && token.tag_name == 'template') {
		p.handle_in_head(mut token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'body' {
		if p.stack_of_open_elements.elements.len == 1 || p.stack_of_open_elements.elements[1].local_name() != 'body' || p.stack_of_open_elements.contains_template_element() {
			return
		}
		p.frameset_ok = false
		mut body := p.stack_of_open_elements.elements[1]
		for attribute in token.attributes {
			if !body.has_attribute(attribute.local_name) {
				body.set_attribute_value(p.own_tokenizer_string(attribute.local_name), p.own_tokenizer_string(attribute.value))
			}
		}
		return
	}
	if token.is_start_tag() && token.tag_name == 'frameset' {
		if p.stack_of_open_elements.elements.len == 1 || p.stack_of_open_elements.elements[1].local_name() != 'body' {
			return
		}
		if !p.frameset_ok {
			return
		}
		mut body_node := p.stack_of_open_elements.elements[1].as_node()
		body_node.remove(true)
		for p.stack_of_open_elements.elements.len > 1 {
			if p.stack_of_open_elements.last().local_name() == 'html' {
				break
			}
			p.stack_of_open_elements.pop()
		}
		p.insert_html_element(token)
		p.insertion_mode = .in_frameset
		return
	}
	if token.is_end_of_file() {
		if p.stack_of_template_insertion_modes.len > 0 {
			p.handle_in_template(mut token)
			return
		}
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
			if is_special_tag(node.local_name(), node.namespace_uri()) && node.local_name() !in [
				'address',
				'div',
				'p',
			] {
				break
			}
		}
		if p.stack_of_open_elements.has_in_button_scope('p') {
			p.close_a_p_element()
		}
		p.insert_html_element(token)
		return
	}
	if token.is_start_tag() && token.tag_name in ['dd', 'dt'] {
		p.frameset_ok = false
		for i := p.stack_of_open_elements.elements.len - 1; i >= 0; i-- {
			node := p.stack_of_open_elements.elements[i]
			if node.local_name() == 'dd' {
				p.generate_implied_end_tags('dd')
				p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped('dd')
				break
			}
			if node.local_name() == 'dt' {
				p.generate_implied_end_tags('dt')
				p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped('dt')
				break
			}
			if is_special_tag(node.local_name(), node.namespace_uri()) && node.local_name() !in [
				'address',
				'div',
				'p',
			] {
				break
			}
		}
		if p.stack_of_open_elements.has_in_button_scope('p') {
			p.close_a_p_element()
		}
		p.insert_html_element(token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'plaintext' {
		if p.stack_of_open_elements.has_in_button_scope('p') {
			p.close_a_p_element()
		}
		p.insert_html_element(token)
		p.tokenizer.switch_to(.plaintext)
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
	if token.is_start_tag() && token.tag_name == 'nobr' {
		p.reconstruct_the_active_formatting_elements()
		if p.stack_of_open_elements.has_in_scope('nobr') {
			p.run_the_adoption_agency_algorithm(token)
			p.reconstruct_the_active_formatting_elements()
		}
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
	if token.is_start_tag() && token.tag_name in ['applet', 'marquee', 'object'] {
		p.reconstruct_the_active_formatting_elements()
		p.insert_html_element(token)
		p.list_of_active_formatting_elements.add_marker()
		p.frameset_ok = false
		return
	}
	if token.is_end_tag() && token.tag_name in ['applet', 'marquee', 'object'] {
		if !p.stack_of_open_elements.has_in_scope(token.tag_name) {
			return
		}
		p.generate_implied_end_tags('')
		p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped(token.tag_name)
		p.list_of_active_formatting_elements.clear_up_to_the_last_marker()
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
	if token.is_end_tag() && token.tag_name in ['dd', 'dt'] {
		if !p.stack_of_open_elements.has_in_scope(token.tag_name) {
			return
		}
		p.generate_implied_end_tags(token.tag_name)
		p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped(token.tag_name)
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
	if token.is_end_tag() && token.tag_name == 'form' {
		if !p.stack_of_open_elements.contains_template_element() {
			form := p.form_element or { return }
			p.form_element = none
			if !p.stack_of_open_elements.has_in_scope_element(form) {
				return
			}
			p.generate_implied_end_tags('')
			p.stack_of_open_elements.remove(form)
			return
		}
		if !p.stack_of_open_elements.has_in_scope('form') {
			return
		}
		p.generate_implied_end_tags('')
		p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped('form')
		return
	}
	if token.is_start_tag() && token.tag_name == 'button' {
		if p.stack_of_open_elements.has_in_scope('button') {
			p.generate_implied_end_tags('')
			p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped('button')
		}
		p.reconstruct_the_active_formatting_elements()
		p.insert_html_element(token)
		p.frameset_ok = false
		return
	}
	if token.is_start_tag() && token.tag_name == 'textarea' {
		p.insert_html_element(token)
		// A leading newline inside <textarea> is ignored.
		p.next_line_feed_can_be_ignored = true
		p.tokenizer.switch_to(.rcdata)
		p.original_insertion_mode = p.insertion_mode
		p.frameset_ok = false
		p.insertion_mode = .text
		return
	}
	if token.is_start_tag() && token.tag_name == 'xmp' {
		if p.stack_of_open_elements.has_in_button_scope('p') {
			p.close_a_p_element()
		}
		p.reconstruct_the_active_formatting_elements()
		p.frameset_ok = false
		p.parse_generic_raw_text_element(token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'iframe' {
		p.frameset_ok = false
		p.parse_generic_raw_text_element(token)
		return
	}
	if token.is_start_tag() && (token.tag_name == 'noembed'
		|| (token.tag_name == 'noscript' && p.scripting_mode != .disabled)) {
		p.parse_generic_raw_text_element(token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'select' {
		mut is_fragment_select := false
		if p.parsing_fragment {
			if ctx := p.context_element {
				is_fragment_select = ctx.local_name() == 'select'
			}
		}
		if is_fragment_select {
			// Ignore the token.
		} else if p.stack_of_open_elements.has_in_scope('select') {
			// Nested selects collapse: pop until a select has been popped.
			p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped('select')
		} else {
			p.reconstruct_the_active_formatting_elements()
			p.insert_html_element(token)
			p.frameset_ok = false
		}
		return
	}
	if token.is_start_tag() && token.tag_name == 'option' {
		if p.stack_of_open_elements.has_in_scope('select') {
			p.generate_implied_end_tags('optgroup')
		} else if cn := p.current_node() {
			if cn.local_name() == 'option' {
				p.stack_of_open_elements.pop()
			}
		}
		p.reconstruct_the_active_formatting_elements()
		p.insert_html_element(token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'optgroup' {
		if p.stack_of_open_elements.has_in_scope('select') {
			p.generate_implied_end_tags('')
		} else if cn := p.current_node() {
			if cn.local_name() == 'option' {
				p.stack_of_open_elements.pop()
			}
		}
		p.reconstruct_the_active_formatting_elements()
		p.insert_html_element(token)
		return
	}
	if token.is_start_tag() && token.tag_name in ['rb', 'rtc'] {
		if p.stack_of_open_elements.has_in_scope('ruby') {
			p.generate_implied_end_tags('')
		}
		p.insert_html_element(token)
		return
	}
	if token.is_start_tag() && token.tag_name in ['rp', 'rt'] {
		if p.stack_of_open_elements.has_in_scope('ruby') {
			p.generate_implied_end_tags('rtc')
		}
		p.insert_html_element(token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'table' {
		if !p.document_.in_quirks_mode() && p.stack_of_open_elements.has_in_button_scope('p') {
			p.close_a_p_element()
		}
		p.insert_html_element(token)
		p.frameset_ok = false
		p.insertion_mode = .in_table
		return
	}
	if token.is_start_tag() && token.tag_name == 'math' {
		p.reconstruct_the_active_formatting_elements()
		p.adjust_mathml_attributes(mut token)
		HTMLParser.adjust_foreign_attributes(mut token)
		p.insert_foreign_element(token, ns_mathml, false)
		if token.is_self_closing() {
			p.stack_of_open_elements.pop()
			token.acknowledge_self_closing_flag_if_set()
		}
		return
	}
	if token.is_start_tag() && token.tag_name == 'svg' {
		p.reconstruct_the_active_formatting_elements()
		p.adjust_svg_attributes(mut token)
		HTMLParser.adjust_foreign_attributes(mut token)
		p.insert_foreign_element(token, ns_svg, false)
		if token.is_self_closing() {
			p.stack_of_open_elements.pop()
			token.acknowledge_self_closing_flag_if_set()
		}
		return
	}
	if token.is_end_tag() && token.tag_name == 'br' {
		mut br_token := HTMLToken.make_start_tag('br')
		p.process_using_the_rules_for(p.insertion_mode, mut br_token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'image' {
		token.set_tag_name('img')
		p.process_using_the_rules_for(p.insertion_mode, mut token)
		return
	}
	// Void elements: area, br, embed, img, keygen, wbr.
	if token.is_start_tag() && token.tag_name in ['area', 'br', 'embed', 'img', 'keygen', 'wbr'] {
		p.reconstruct_the_active_formatting_elements()
		p.insert_html_element(token)
		p.stack_of_open_elements.pop()
		token.acknowledge_self_closing_flag_if_set()
		p.frameset_ok = false
		return
	}
	if token.is_start_tag() && token.tag_name == 'input' {
		mut is_fragment_select := false
		if p.parsing_fragment {
			if context := p.context_element {
				is_fragment_select = context.local_name() == 'select'
			}
		}
		if is_fragment_select {
			return
		}
		if p.stack_of_open_elements.has_in_scope('select') {
			p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped('select')
		}
		p.reconstruct_the_active_formatting_elements()
		p.insert_html_element(token)
		p.stack_of_open_elements.pop()
		token.acknowledge_self_closing_flag_if_set()
		type_attribute := token.attribute('type')
		if type_attribute == none || ascii_lowercase_string(type_attribute or { '' }) != 'hidden' {
			p.frameset_ok = false
		}
		return
	}
	if token.is_start_tag() && token.tag_name in ['param', 'source', 'track'] {
		p.insert_html_element(token)
		p.stack_of_open_elements.pop()
		token.acknowledge_self_closing_flag_if_set()
		return
	}
	if token.is_start_tag() && token.tag_name == 'hr' {
		if p.stack_of_open_elements.has_in_button_scope('p') {
			p.close_a_p_element()
		}
		if p.stack_of_open_elements.has_in_scope('select') {
			p.generate_implied_end_tags('')
		}
		p.insert_html_element(token)
		p.stack_of_open_elements.pop()
		token.acknowledge_self_closing_flag_if_set()
		p.frameset_ok = false
		return
	}
	// Stray table-structure start tags outside a table are ignored.
	if token.is_start_tag() && token.tag_name in ['caption', 'col', 'colgroup', 'frame', 'head',
		'tbody', 'td', 'tfoot', 'th', 'thead', 'tr'] {
		return
	}
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
		if current := p.current_node() {
			if current.local_name() == 'script' {
				if script_model := p.script_models[current.as_node().unique_id().value()] {
					mut script := unsafe { &HTMLScriptElementModel(script_model) }
					script.already_started_ = true
				}
			}
		}
		p.stack_of_open_elements.pop()
		p.insertion_mode = p.original_insertion_mode
		p.process_using_the_rules_for(p.insertion_mode, mut token)
		return
	}
	if token.is_end_tag() {
		p.flush_character_insertions()
		current := p.current_node()
		p.stack_of_open_elements.pop()
		p.insertion_mode = p.original_insertion_mode
		if element := current {
			if token.tag_name == 'script' && element.local_name() == 'script' {
				p.tokenizer.store_old_insertion_point()
				p.tokenizer.update_insertion_point()
				p.prepare_and_execute_parser_inserted_script(element)
				p.tokenizer.restore_old_insertion_point()
				if pending := p.document_.pending_parsing_blocking_script() {
					pending_model := html_script_element_model_for_dom_element(pending)
					// A cached external script written by another script still
					// waits for the outer evaluation to return. Inline writes keep
					// their synchronous execution at the live insertion point.
					if (p.script_nesting_level > 0 && pending_model.from_external_file_)
						|| p.document_.has_a_style_sheet_that_is_blocking_scripts()
						|| !html_script_element_is_ready_to_be_parser_executed(pending) {
						p.start_the_speculative_html_parser()
						p.parser_pause_flag = true
						p.schedule_resume_check()
						return
					}
					mut document := unsafe { &dom.Document(p.document_) }
					the_script := document.take_pending_parsing_blocking_script()
					// Preparing the element restored the previous insertion point.
					// Parser execution opens a fresh one for synchronous document.write().
					p.tokenizer.store_old_insertion_point()
					p.tokenizer.update_insertion_point()
					p.increment_script_nesting_level()
					html_script_element_parser_execute_ready_script(the_script)
					p.decrement_script_nesting_level()
					// A nested write may have paused for either kind of script.
					// Keep that pause until the pending script can resume parsing.
					if p.script_nesting_level == 0
						&& p.document_.pending_parsing_blocking_script() == none
						&& p.document_.pending_parsing_blocking_svg_script() == none {
						p.parser_pause_flag = false
					}
					p.tokenizer.restore_old_insertion_point()
				}
			}
		}
		return
	}
}

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-afterbody
fn (mut p HTMLParser) handle_after_body(mut token HTMLToken) {
	if token.is_character() && token.is_parser_whitespace() {
		p.handle_in_body(mut token)
		return
	}
	if token.is_comment_or_processing_instruction() {
		mut first := p.stack_of_open_elements.first()
		mut first_node := first.as_node()
		comment := p.comment_or_processing_instruction_node(token)
		first_node.append_child(comment) or {}
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
	if token.is_comment_or_processing_instruction() {
		mut doc_node := p.document_as_node()
		comment := p.comment_or_processing_instruction_node(token)
		doc_node.append_child(comment) or {}
		return
	}
	if token.is_doctype() || token.is_parser_whitespace() || (token.is_start_tag() && token.tag_name == 'html') {
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

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inframeset
fn (mut p HTMLParser) handle_in_frameset(mut token HTMLToken) {
	if token.is_character() && token.is_parser_whitespace() {
		p.insert_character(token.code_point)
		return
	}
	if token.is_comment_or_processing_instruction() {
		p.insert_comment(token)
		return
	}
	if token.is_doctype() {
		return
	}
	if token.is_start_tag() && token.tag_name == 'html' {
		p.process_using_the_rules_for(.in_body, mut token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'frameset' {
		p.insert_html_element(token)
		return
	}
	if token.is_end_tag() && token.tag_name == 'frameset' {
		current_node := p.current_node() or { return }
		if current_node.is_document_element() {
			return
		}
		p.stack_of_open_elements.pop()
		new_current_node := p.current_node() or { return }
		if !p.parsing_fragment && new_current_node.local_name() != 'frameset' {
			p.insertion_mode = .after_frameset
		}
		return
	}
	if token.is_start_tag() && token.tag_name == 'frame' {
		p.insert_html_element(token)
		p.stack_of_open_elements.pop()
		token.acknowledge_self_closing_flag_if_set()
		return
	}
	if token.is_start_tag() && token.tag_name == 'noframes' {
		p.process_using_the_rules_for(.in_head, mut token)
		return
	}
	if token.is_end_of_file() {
		p.stop_parsing = true
		return
	}
}

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-afterframeset
fn (mut p HTMLParser) handle_after_frameset(mut token HTMLToken) {
	if token.is_character() && token.is_parser_whitespace() {
		p.insert_character(token.code_point)
		return
	}
	if token.is_comment_or_processing_instruction() {
		p.insert_comment(token)
		return
	}
	if token.is_doctype() {
		return
	}
	if token.is_start_tag() && token.tag_name == 'html' {
		p.process_using_the_rules_for(.in_body, mut token)
		return
	}
	if token.is_end_tag() && token.tag_name == 'html' {
		p.insertion_mode = .after_after_frameset
		return
	}
	if token.is_start_tag() && token.tag_name == 'noframes' {
		p.process_using_the_rules_for(.in_head, mut token)
		return
	}
	if token.is_end_of_file() {
		p.stop_parsing = true
		return
	}
}

// https://html.spec.whatwg.org/multipage/parsing.html#the-after-after-frameset-insertion-mode
fn (mut p HTMLParser) handle_after_after_frameset(mut token HTMLToken) {
	if token.is_comment_or_processing_instruction() {
		mut document_node := p.document_as_node()
		comment := p.comment_or_processing_instruction_node(token)
		document_node.append_child(comment) or {}
		return
	}
	if token.is_doctype() || token.is_parser_whitespace() || (token.is_start_tag() && token.tag_name == 'html') {
		p.process_using_the_rules_for(.in_body, mut token)
		return
	}
	if token.is_end_of_file() {
		p.stop_parsing = true
		return
	}
	if token.is_start_tag() && token.tag_name == 'noframes' {
		p.process_using_the_rules_for(.in_head, mut token)
		return
	}
}
