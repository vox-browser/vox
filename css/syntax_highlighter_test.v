module css

fn test_syntax_highlighter_retains_spans_and_folding_regions() {
	result := SyntaxHighlighter.create().rehighlight_text('a { color: #123; }', Palette{})
	assert result.spans.len > 0
	assert result.spans.any(it.data == .ident)
	assert result.spans.any(it.data == .open_curly)
	assert result.spans.any(it.data == .hash)
	assert result.folding_regions.len == 1
}

fn test_invalidation_set_serialization_retains_all_properties() {
	mut set := InvalidationSet{
		needs_invalidate_self_: true
	}
	set.set_needs_invalidate_class('active')
	serialized := set.to_string()
	assert serialized == '\$, .active'
}
