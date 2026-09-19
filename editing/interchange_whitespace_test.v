module editing

import dom

fn interchange_token_signature(tokens []InterchangeWhitespaceToken) []string {
	return tokens.map(if it.type_ == .protected_space { 'nbsp' } else { 'text:${it.text}' })
}

fn test_ascii_whitespace_text_classification() {
	document := dom.Document.create_for_fragment_parsing()
	assert is_ascii_whitespace_text(document.create_text_node(' \t\n\r').as_node())
	assert !is_ascii_whitespace_text(document.create_text_node(' a ').as_node())
	assert !is_ascii_whitespace_text(unsafe { &dom.Node(document) })
}

fn test_rebalance_whitespace_protects_fragment_edges() {
	assert interchange_token_signature(rebalance_whitespace_for_interchange(' a ')) == [
		'nbsp',
		'text:a',
		'nbsp',
	]
	assert interchange_token_signature(rebalance_whitespace_for_interchange('  a  ')) == [
		'nbsp',
		'text: a',
		'nbsp',
		'nbsp',
	]
}

fn test_rebalance_whitespace_preserves_interior_run_length() {
	assert interchange_token_signature(rebalance_whitespace_for_interchange('a b')) == ['text:a b']
	assert interchange_token_signature(rebalance_whitespace_for_interchange('a  b')) == [
		'text:a',
		'nbsp',
		'text: b',
	]
	assert interchange_token_signature(rebalance_whitespace_for_interchange('a   b')) == [
		'text:a',
		'nbsp',
		'text: ',
		'nbsp',
		'text:b',
	]
	assert interchange_token_signature(rebalance_whitespace_for_interchange('x\n\ny')) == [
		'text:x',
		'nbsp',
		'text: y',
	]
}

fn test_rebalance_whitespace_keeps_non_collapsible_unicode() {
	assert interchange_token_signature(rebalance_whitespace_for_interchange('😀\té')) == [
		'text:😀\té',
	]
}
