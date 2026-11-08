module html

// The table insertion-mode handlers for HTMLParser, translated from HTMLParser.cpp:
// in table / in table text / in table body / in row / in cell / in caption / in column group.
// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-intable etc.

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-intable
fn (mut p HTMLParser) handle_in_table(mut token HTMLToken) {
	if token.is_character() {
		if cn := p.current_node() {
			if cn.local_name() in ['table', 'tbody', 'tfoot', 'thead', 'tr'] {
				p.pending_table_character_tokens = []
				p.original_insertion_mode = p.insertion_mode
				p.insertion_mode = .in_table_text
				p.process_using_the_rules_for(.in_table_text, mut token)
				return
			}
		}
	}
	if token.is_comment_or_processing_instruction() {
		p.insert_comment(token)
		return
	}
	if token.is_doctype() {
		return
	}
	if token.is_start_tag() && token.tag_name == 'caption' {
		p.clear_the_stack_back_to_a_table_context()
		p.list_of_active_formatting_elements.add_marker()
		p.insert_html_element(token)
		p.insertion_mode = .in_caption
		return
	}
	if token.is_start_tag() && token.tag_name == 'colgroup' {
		p.clear_the_stack_back_to_a_table_context()
		p.insert_html_element(token)
		p.insertion_mode = .in_column_group
		return
	}
	if token.is_start_tag() && token.tag_name == 'col' {
		p.clear_the_stack_back_to_a_table_context()
		mut synth := HTMLToken.make_start_tag('colgroup')
		p.insert_html_element(synth)
		p.insertion_mode = .in_column_group
		p.process_using_the_rules_for(.in_column_group, mut token)
		return
	}
	if token.is_start_tag() && token.tag_name in ['tbody', 'tfoot', 'thead'] {
		p.clear_the_stack_back_to_a_table_context()
		p.insert_html_element(token)
		p.insertion_mode = .in_table_body
		return
	}
	if token.is_start_tag() && token.tag_name in ['td', 'th', 'tr'] {
		p.clear_the_stack_back_to_a_table_context()
		mut synth := HTMLToken.make_start_tag('tbody')
		p.insert_html_element(synth)
		p.insertion_mode = .in_table_body
		p.process_using_the_rules_for(.in_table_body, mut token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'table' {
		if !p.stack_of_open_elements.has_in_table_scope('table') {
			return
		}
		p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped('table')
		p.reset_the_insertion_mode_appropriately()
		p.process_using_the_rules_for(p.insertion_mode, mut token)
		return
	}
	if token.is_end_tag() && token.tag_name == 'table' {
		if !p.stack_of_open_elements.has_in_table_scope('table') {
			return
		}
		p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped('table')
		p.reset_the_insertion_mode_appropriately()
		return
	}
	if token.is_end_tag()
		&& token.tag_name in ['body', 'caption', 'col', 'colgroup', 'html', 'tbody', 'td', 'tfoot', 'th', 'thead', 'tr'] {
		return
	}
	if (token.is_start_tag() && token.tag_name in ['style', 'script', 'template'])
		|| (token.is_end_tag() && token.tag_name == 'template') {
		p.handle_in_head(mut token)
		return
	}
	if token.is_start_tag() && token.tag_name == 'input' {
		type_attribute := token.attribute('type') or { '' }
		if type_attribute.to_lower() != 'hidden' {
			p.in_table_anything_else(mut token)
			return
		}
		p.insert_html_element(token)
		p.stack_of_open_elements.pop()
		token.acknowledge_self_closing_flag_if_set()
		return
	}
	if token.is_start_tag() && token.tag_name == 'form' {
		if p.form_element != none || p.stack_of_open_elements.contains_template_element() {
			return
		}
		element := p.insert_html_element(token)
		p.form_element = element
		p.stack_of_open_elements.pop()
		return
	}
	if token.is_end_of_file() {
		p.handle_in_body(mut token)
		return
	}
	p.in_table_anything_else(mut token)
}

fn (mut p HTMLParser) in_table_anything_else(mut token HTMLToken) {
	p.foster_parenting = true
	p.handle_in_body(mut token)
	p.foster_parenting = false
}

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-intabletext
fn (mut p HTMLParser) handle_in_table_text(mut token HTMLToken) {
	if token.is_character() {
		if token.code_point == 0 {
			return
		}
		p.pending_table_character_tokens << token
		return
	}
	// Anything else: flush the pending character tokens, then reprocess in the original mode.
	mut any_non_whitespace := false
	for pending in p.pending_table_character_tokens {
		if !pending.is_parser_whitespace() {
			any_non_whitespace = true
			break
		}
	}
	if any_non_whitespace {
		// Reprocess the pending characters using the "in table" anything-else rules (fostered).
		mut pending_tokens := p.pending_table_character_tokens.clone()
		for mut pending in pending_tokens {
			p.foster_parenting = true
			p.handle_in_body(mut pending)
			p.foster_parenting = false
		}
	} else {
		for pending in p.pending_table_character_tokens {
			p.insert_character(pending.code_point)
		}
	}
	p.pending_table_character_tokens = []
	p.insertion_mode = p.original_insertion_mode
	p.process_using_the_rules_for(p.insertion_mode, mut token)
}

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-intbody
fn (mut p HTMLParser) handle_in_table_body(mut token HTMLToken) {
	if token.is_start_tag() && token.tag_name == 'tr' {
		p.clear_the_stack_back_to_a_table_body_context()
		p.insert_html_element(token)
		p.insertion_mode = .in_row
		return
	}
	if token.is_start_tag() && token.tag_name in ['th', 'td'] {
		p.clear_the_stack_back_to_a_table_body_context()
		mut synth := HTMLToken.make_start_tag('tr')
		p.insert_html_element(synth)
		p.insertion_mode = .in_row
		p.process_using_the_rules_for(.in_row, mut token)
		return
	}
	if token.is_end_tag() && token.tag_name in ['tbody', 'tfoot', 'thead'] {
		if !p.stack_of_open_elements.has_in_table_scope(token.tag_name) {
			return
		}
		p.clear_the_stack_back_to_a_table_body_context()
		p.stack_of_open_elements.pop()
		p.insertion_mode = .in_table
		return
	}
	if (token.is_start_tag()
		&& token.tag_name in ['caption', 'col', 'colgroup', 'tbody', 'tfoot', 'thead'])
		|| (token.is_end_tag() && token.tag_name == 'table') {
		if !p.stack_of_open_elements.has_in_table_scope('tbody')
			&& !p.stack_of_open_elements.has_in_table_scope('thead')
			&& !p.stack_of_open_elements.has_in_table_scope('tfoot') {
			return
		}
		p.clear_the_stack_back_to_a_table_body_context()
		p.stack_of_open_elements.pop()
		p.insertion_mode = .in_table
		p.process_using_the_rules_for(.in_table, mut token)
		return
	}
	if token.is_end_tag()
		&& token.tag_name in ['body', 'caption', 'col', 'colgroup', 'html', 'td', 'th', 'tr'] {
		return
	}
	p.handle_in_table(mut token)
}

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-intr
fn (mut p HTMLParser) handle_in_row(mut token HTMLToken) {
	if token.is_start_tag() && token.tag_name in ['th', 'td'] {
		p.clear_the_stack_back_to_a_table_row_context()
		p.insert_html_element(token)
		p.insertion_mode = .in_cell
		p.list_of_active_formatting_elements.add_marker()
		return
	}
	if token.is_end_tag() && token.tag_name == 'tr' {
		if !p.stack_of_open_elements.has_in_table_scope('tr') {
			return
		}
		p.clear_the_stack_back_to_a_table_row_context()
		p.stack_of_open_elements.pop()
		p.insertion_mode = .in_table_body
		return
	}
	if (token.is_start_tag()
		&& token.tag_name in ['caption', 'col', 'colgroup', 'tbody', 'tfoot', 'thead', 'tr'])
		|| (token.is_end_tag() && token.tag_name == 'table') {
		if !p.stack_of_open_elements.has_in_table_scope('tr') {
			return
		}
		p.clear_the_stack_back_to_a_table_row_context()
		p.stack_of_open_elements.pop()
		p.insertion_mode = .in_table_body
		p.process_using_the_rules_for(.in_table_body, mut token)
		return
	}
	if token.is_end_tag() && token.tag_name in ['tbody', 'tfoot', 'thead'] {
		if !p.stack_of_open_elements.has_in_table_scope(token.tag_name) {
			return
		}
		if !p.stack_of_open_elements.has_in_table_scope('tr') {
			return
		}
		p.clear_the_stack_back_to_a_table_row_context()
		p.stack_of_open_elements.pop()
		p.insertion_mode = .in_table_body
		p.process_using_the_rules_for(.in_table_body, mut token)
		return
	}
	if token.is_end_tag()
		&& token.tag_name in ['body', 'caption', 'col', 'colgroup', 'html', 'td', 'th'] {
		return
	}
	p.handle_in_table(mut token)
}

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-intd
fn (mut p HTMLParser) handle_in_cell(mut token HTMLToken) {
	if token.is_end_tag() && token.tag_name in ['td', 'th'] {
		if !p.stack_of_open_elements.has_in_table_scope(token.tag_name) {
			return
		}
		p.generate_implied_end_tags('')
		p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped(token.tag_name)
		p.list_of_active_formatting_elements.clear_up_to_the_last_marker()
		p.insertion_mode = .in_row
		return
	}
	if token.is_start_tag()
		&& token.tag_name in ['caption', 'col', 'colgroup', 'tbody', 'td', 'tfoot', 'th', 'thead', 'tr'] {
		if !p.stack_of_open_elements.has_in_table_scope('td')
			&& !p.stack_of_open_elements.has_in_table_scope('th') {
			return
		}
		p.close_the_cell()
		p.process_using_the_rules_for(p.insertion_mode, mut token)
		return
	}
	if token.is_end_tag() && token.tag_name in ['body', 'caption', 'col', 'colgroup', 'html'] {
		return
	}
	if token.is_end_tag() && token.tag_name in ['table', 'tbody', 'tfoot', 'thead', 'tr'] {
		if !p.stack_of_open_elements.has_in_table_scope(token.tag_name) {
			return
		}
		p.close_the_cell()
		p.process_using_the_rules_for(p.insertion_mode, mut token)
		return
	}
	p.handle_in_body(mut token)
}

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-incaption
fn (mut p HTMLParser) handle_in_caption(mut token HTMLToken) {
	if token.is_end_tag() && token.tag_name == 'caption' {
		if !p.stack_of_open_elements.has_in_table_scope('caption') {
			return
		}
		p.generate_implied_end_tags('')
		p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped('caption')
		p.list_of_active_formatting_elements.clear_up_to_the_last_marker()
		p.insertion_mode = .in_table
		return
	}
	if (token.is_start_tag()
		&& token.tag_name in ['caption', 'col', 'colgroup', 'tbody', 'td', 'tfoot', 'th', 'thead', 'tr'])
		|| (token.is_end_tag() && token.tag_name == 'table') {
		if !p.stack_of_open_elements.has_in_table_scope('caption') {
			return
		}
		p.generate_implied_end_tags('')
		p.stack_of_open_elements.pop_until_an_element_with_tag_name_has_been_popped('caption')
		p.list_of_active_formatting_elements.clear_up_to_the_last_marker()
		p.insertion_mode = .in_table
		p.process_using_the_rules_for(.in_table, mut token)
		return
	}
	if token.is_end_tag()
		&& token.tag_name in ['body', 'col', 'colgroup', 'html', 'tbody', 'td', 'tfoot', 'th', 'thead', 'tr'] {
		return
	}
	p.handle_in_body(mut token)
}

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-incolgroup
fn (mut p HTMLParser) handle_in_column_group(mut token HTMLToken) {
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
	if token.is_start_tag() && token.tag_name == 'col' {
		p.insert_html_element(token)
		p.stack_of_open_elements.pop()
		token.acknowledge_self_closing_flag_if_set()
		return
	}
	if token.is_end_tag() && token.tag_name == 'colgroup' {
		if cn := p.current_node() {
			if cn.local_name() != 'colgroup' {
				return
			}
		}
		p.stack_of_open_elements.pop()
		p.insertion_mode = .in_table
		return
	}
	if token.is_end_tag() && token.tag_name == 'col' {
		return
	}
	if (token.is_start_tag() || token.is_end_tag()) && token.tag_name == 'template' {
		p.handle_in_head(mut token)
		return
	}
	if token.is_end_of_file() {
		p.handle_in_body(mut token)
		return
	}
	// Anything else.
	if cn := p.current_node() {
		if cn.local_name() != 'colgroup' {
			return
		}
	}
	p.stack_of_open_elements.pop()
	p.insertion_mode = .in_table
	p.process_using_the_rules_for(.in_table, mut token)
}
