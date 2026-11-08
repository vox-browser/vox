module css

import os

const disable_borrowed_token_spelling = os.getenv('VOX_DISABLE_BORROWED_TOKEN_SPELLING') != ''

// Whole-sheet conversion owns the decoded source until every retained rule
// has exported its strings. Its private tokenizer can borrow exact source
// spans; public tokenization continues to return terminated owned spellings.
fn ParserTokenStream.from_transient_source(input string, encoding string) ParserTokenStream {
	return ParserTokenStream.from_source_with_spelling(input, encoding,
		!disable_borrowed_token_spelling)
}
