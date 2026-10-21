module html

// In the tree builder's Text mode these characters all take the same
// insert-character step. Keep delimiters, newline normalization and script
// escape transitions in the ordinary tokenizer, and bound each batch so the
// parser can keep servicing cooperative checkpoints.
fn (mut t HTMLTokenizer) consume_parser_text_run(stop StopAtInsertionPoint) ?[]rune {
	if t.state !in [.rawtext, .script_data] || t.queued_tokens.len != 0
		|| t.aborted || t.blocked || t.should_pause_before_next_input_character(stop) { return none }
	start := t.current_offset
	mut end := start
	for end < t.decoded_input.len && end - start < 4096 {
		if stop == .yes {
			if point := t.insertion_point { if end >= point { break } }
		}
		if t.decoded_input[end] in [rune(`<`), 0, `\r`] { break }
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
	if p.insertion_mode != .text || p.next_line_feed_can_be_ignored { return false }
	current := p.current_node() or { return false }
	if !element_in_namespace(current, ns_html) { return false }
	run := p.parser_text_run(stop) or { return false }
	p.insert_character(run[0])
	p.character_insertion_builder << run[1..]
	return true
}
