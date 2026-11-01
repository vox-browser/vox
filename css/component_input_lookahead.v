module css

import os

const disable_component_input_reuse = os.getenv('VOX_DISABLE_COMPONENT_INPUT_REUSE') != ''
const component_input_diagnostics = os.getenv('VOX_COMPONENT_INPUT_DIAGNOSTICS') != ''

__global component_input_lookahead_reported bool

@[inline]
fn component_input_initial_capacity() int {
	return if disable_component_input_reuse { 0 } else { 8 }
}

// Lookahead observes only a kind. Owning tokens are still copied when they
// enter a component, including their exact source spelling and positions.
@[inline]
fn (stream RawTokenStream) component_token_type() TokenType {
	if disable_component_input_reuse { return stream.next_token().type_ }
	if component_input_diagnostics && !component_input_lookahead_reported {
		component_input_lookahead_reported = true
		eprintln('Vox CSS component input: scalar lookahead and reserved small blocks')
	}
	if stream.source != unsafe { nil } { return stream.source.current.type_ }
	if stream.index < stream.tokens.len { return stream.tokens[stream.index].type_ }
	return .end_of_file
}
