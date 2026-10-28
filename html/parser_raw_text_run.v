module html

// In Text mode, and in the guarded In Body case below, ordinary characters
// share one stable insertion location. Keep delimiters, newline normalization and script
// escape transitions in the ordinary tokenizer, and bound each batch so the
// parser can keep servicing cooperative checkpoints.
fn (mut t HTMLTokenizer) consume_parser_text_run(stop StopAtInsertionPoint) ?[]rune {
	if t.state !in [.data, .rawtext, .script_data] || t.queued_tokens.len != 0
		|| t.aborted || t.blocked || t.should_pause_before_next_input_character(stop) { return none }
	start := t.current_offset
	mut end := start
	for end < t.decoded_input.len && end - start < 4096 {
		if stop == .yes {
			if point := t.insertion_point { if end >= point { break } }
		}
		if t.decoded_input[end] in [rune(`<`), 0, `\r`]
			|| (t.state == .data && t.decoded_input[end] == `&`) { break }
		end++
	}
	if end == start { return none }
	// next_token_impl normally resets this history before each token. A run
	// emits no token, but the following token needs the same final position.
	if t.source_positions.len > 0 {
		last := t.source_positions[t.source_positions.len - 1]
		t.source_positions.clear()
		t.source_positions << last
	}
	t.skip(end - start)
	return t.decoded_input[start..end]
}

fn (mut p HTMLParser) insert_text_run_if_available(stop StopAtInsertionPoint) bool {
	if p.next_line_feed_can_be_ignored { return false }
	body := p.insertion_mode in [.in_body, .in_cell, .in_caption]
	if !body && p.insertion_mode != .text { return false }
	current := p.current_node() or { return false }
	if !element_in_namespace(current, ns_html) { return false }
	if body {
		// A fragment's adjusted current node can select foreign-content rules.
		// Leave formatting reconstruction and table insertion to normal tokens.
		if p.parsing_fragment || p.foster_parenting || p.tokenizer.state != .data { return false }
		entries := p.list_of_active_formatting_elements.entries
		if entries.len > 0 {
			last := entries[entries.len - 1]
			if element := last.element {
				if !p.stack_of_open_elements.contains(element) { return false }
			}
		}
	}
	run := p.parser_text_run(stop) or { return false }
	p.insert_character(run[0])
	p.append_character_insertion_run(run[1..])
	if body && p.frameset_ok {
		for code_point in run {
			if code_point !in [rune(`\t`), `\n`, `\f`, `\r`, ` `] {
				p.frameset_ok = false
				break
			}
		}
	}
	return true
}
