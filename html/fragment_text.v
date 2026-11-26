module html

import dom
import encoding.utf8

pub struct FragmentTextActivity {
pub:
	fast u64
	fallback u64
}

$if test {
	__global fragment_text_disabled bool
	__global fragment_text_diagnostic bool
	__global fragment_text_fast u64
	__global fragment_text_fallback u64
	pub fn set_fragment_text_for_testing(enabled bool) { fragment_text_disabled = !enabled }
	pub fn diagnose_fragment_text_for_testing(enabled bool) FragmentTextActivity {
		result := FragmentTextActivity{fragment_text_fast, fragment_text_fallback}
		fragment_text_fast = 0
		fragment_text_fallback = 0
		fragment_text_diagnostic = enabled
		return result
	}
}

// In these HTML body contexts an uninterrupted data-state character run inserts
// one Text child. References, tags, preprocessing and other insertion modes keep
// the tokenizer/tree builder. Allocate the result in the caller's document
// storage, just as the full parser's final adoption does.
fn plain_fragment_text(context &dom.Element, markup string) ?[]&dom.Node {
	$if test { if fragment_text_disabled { return none } }
	if !context.document().is_html_document() || (context.namespace_uri() or { '' }) != ns_html
		|| context.local_name() !in ['a', 'div', 'span', 'p', 'body'] { return none }
	for byte in markup { if byte in [u8(0), `\r`, `<`, `&`] { return none } }
	if !utf8.validate_str(markup) { return none }
	$if test { if fragment_text_diagnostic { fragment_text_fast++ } }
	if markup.len == 0 { return []&dom.Node{} }
	// The input may be a VM/temporary buffer. Its retained copy belongs to the
	// destination document, not to the caller or a parser workspace.
	return [context.document().create_text_node(markup.clone()).as_node()]
}
