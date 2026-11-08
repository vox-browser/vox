module dom

// DOM owns the document and parser handle; the HTML module supplies the
// concrete parser. Keep the embedder's initialization hook on that document so
// a parser created by document.open() receives the same host as navigation.
pub struct DocumentHTMLParserCreationHook {
pub:
	target   voidptr
	callback fn (voidptr, voidptr) = unsafe { nil }
}

pub fn (mut document Document) set_html_parser_creation_hook(hook DocumentHTMLParserCreationHook) {
	document.html_parser_creation_hook_ = hook
}

pub fn (document &Document) notify_html_parser_created(parser voidptr) {
	if hook := document.html_parser_creation_hook_ {
		if hook.callback != unsafe { nil } { hook.callback(hook.target, parser) }
	}
}

pub fn (document &Document) has_html_parser_creation_hook() bool {
	return document.html_parser_creation_hook_ != none
}
