module main

import browserjs
import dom

fn install_compact_document_state_binding(document &dom.Document, mut runtime browserjs.Runtime) ! {
	runtime.define_host_function('__ladybirdDocumentCookie', fn [document] (input string) !string {
		mut owner := unsafe { &dom.Document(document) }
		if input == 'get' { return owner.cookie() }
		if input.starts_with('set:') {
			owner.set_cookie(input[4..])!
			return ''
		}
		return error('Invalid document cookie operation')
	})!
}
