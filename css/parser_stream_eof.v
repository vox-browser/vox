module css

// Component input is immutable. Its virtual EOF has no source location or
// payload to customize, so repeated lookahead can share one process-owned
// token instead of allocating another sum-type payload at every boundary.
const parser_stream_eof_value = ComponentValue.from_token(Token{type_: .end_of_file})

fn parser_stream_eof() ComponentValue {
	return parser_stream_eof_value
}
