module html

import dom
import platform

pub type HTMLParserCreationCallback = fn (voidptr, &HTMLParser)

@[heap]
struct HTMLParserCreationBinding {
	target   voidptr
	callback HTMLParserCreationCallback
}

fn html_parser_created(target voidptr, parser voidptr) {
	binding := unsafe { &HTMLParserCreationBinding(target) }
	binding.callback(binding.target, unsafe { &HTMLParser(parser) })
}

// The context belongs to the document's host. The adapter itself is allocated
// with the document, without a process-global registry or captured closure.
pub fn install_document_parser_creation_hook(document &dom.Document, target voidptr, callback HTMLParserCreationCallback) {
	mut allocations := enter_html_document_storage(document)
	defer { allocations.finish() }
	binding := &HTMLParserCreationBinding{target: target, callback: callback}
	mut owner := unsafe { &dom.Document(document) }
	owner.set_html_parser_creation_hook(dom.DocumentHTMLParserCreationHook{
		target: binding
		callback: html_parser_created
	})
}

// Resource completion and parser resume can run from a frame workspace or
// another document's callback. New DOM and script data belong to this owner.
fn enter_html_document_storage(document ?&dom.Document) platform.RetainedArenaScope {
	owner := document or { return platform.RetainedArenaScope{} }
	mut storage := owner.native_storage()
	if storage == unsafe { nil } { return platform.RetainedArenaScope{} }
	return storage.enter_nested()
}
