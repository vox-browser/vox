module html

// A speculative resource scan does not publish text nodes. Use the same
// guarded committed runs as the tree builder, leaving delimiters, references,
// NULs and script escape transitions to the ordinary tokenizer.
pub fn (mut tokenizer HTMLTokenizer) skip_resource_discovery_text_run() bool {
	// RCDATA has the same ordinary-character delimiters as Data. Temporarily
	// select that run guard only; no token is emitted or parser callback run.
	previous := tokenizer.state
	if previous == .rcdata { tokenizer.state = .data }
	skipped := tokenizer.consume_parser_text_run(.no) != none
	tokenizer.state = previous
	return skipped
}
