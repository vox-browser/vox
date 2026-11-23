module css

// Owning a component tree reuses the tokenizer's static, terminated literal
// for each single printable character and copies every longer spelling.
fn test_single_character_spellings_share_terminated_literals() {
	values := ParserTokenStream.from_transient_source('p{color:red}', 'utf-8').values
	owned := own_stylesheet_components(values)
	block := owned[1].block()
	colon := block.value[1].token()
	assert colon.original_source_text_ == ':'
	assert colon.original_source_text_.str == tokenizer_ascii_source_text[int(`:`) - 0x20].str
	assert unsafe { colon.original_source_text_.str[1] } == 0
	name := block.value[0].token()
	assert name.original_source_text_ == 'color'
	assert name.value.str == name.original_source_text_.str
	assert unsafe { name.original_source_text_.str[name.original_source_text_.len] } == 0
	tag := owned[0].token()
	assert tag.original_source_text_.str == tokenizer_ascii_source_text[int(`p`) - 0x20].str
	assert tag.value.str == tag.original_source_text_.str
}
