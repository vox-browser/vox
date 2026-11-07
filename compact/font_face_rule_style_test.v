module main

import browserjs
import html

// An @font-face rule's style is its descriptor declaration block.
fn test_compact_font_face_rule_style_reads_and_writes_descriptors() {
	$if !darwin {
		return
	}
	document := html.parse_document('<!doctype html><style>@font-face{font-family:foo;src:url(http://example.com)}</style><body></body>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/', [r'
const rule=document.styleSheets[0].cssRules[0];
rule.style.setProperty("unicode-range","U+1357");
const first=rule.style.getPropertyValue("unicode-range");
rule.style.setProperty("unicode-range","u+abc");
const second=rule.style.getPropertyValue("unicode-range").toUpperCase();
rule.style.setProperty("unicode-range","not a range");
console.log([first.toUpperCase(),second,rule.style.getPropertyValue("unicode-range").toUpperCase(),rule.style.getPropertyValue("font-family"),rule.style.length].join(" "));
'], runtime, mut messages)
	assert messages == ['U+1357 U+ABC U+ABC foo 3'], messages.str()
}
