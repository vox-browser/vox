module css

fn test_selector_plain_bytes_exclude_every_structural_byte() {
	for byte in [u8(`"`), `'`, `(`, `)`, `[`, `]`, `\\`, `>`, `+`, `~`, `|`, ` `, `\t`, `\n`, `\r`, `\f`] {
		assert !selector_plain_bytes[byte], '${byte}'
	}
	for byte in [u8(`a`), `Z`, `0`, `-`, `_`, `.`, `#`, `:`, `*`, `=`, `^`, `$`, `!`, 0x0b, 0x80, 0xff] {
		assert selector_plain_bytes[byte], '${byte}'
	}
}

// Runs of plain bytes end at every combinator, bracket, quote, escape and
// white space byte, so they never hide a combinator from the scan.
fn test_bad_top_level_combinators_around_plain_byte_runs() {
	for text, bad in {
		'.a > .b':            false
		'.a>.b+.c~.d':        false
		'a || b':             false
		'.a .b':              false
		'.a >':                true
		'.a+':                 true
		'.a > > .b':          true
		'.a>+.b':             true
		'> .a':               true
		'.mobileOnly\\+':     false
		'.a\\> .b':           false
		'a[title="x > y"]':   false
		"a[title='+'] + b":   false
		':not(> a)':          false
		'.a:is(.b, .c) ~ .d': false
	} {
		assert selector_text_has_bad_top_level_combinators(text, false) == bad, text
	}
	assert !selector_text_has_bad_top_level_combinators('> .a', true)
	assert selector_text_has_bad_top_level_combinators('> .a >', true)
}

fn test_balanced_selector_text_around_plain_byte_runs() {
	for text, balanced in {
		'.a:is(.b, [c="d"])':  true
		'.a:is(.b':           false
		'.a)':                false
		'a[b="]"]':           true
		"a[b=']']":           true
		'a[b="x':             false
		'.a\\(':               true
		'.a\\]b':              true
		'.a[b]]':             false
	} {
		assert parser_balanced_selector_text(text) == balanced, text
	}
}
