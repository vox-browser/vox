module main

import browserjs
import html

fn test_compact_document_referrer_reads_the_live_native_value_and_checks_receiver() {
	mut document := html.parse_document('<!doctype html><body></body>')
	document.set_referrer('https://pikabu.ru/new')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://pikabu.ru/story/test', [r'
const read=Object.getOwnPropertyDescriptor(Document.prototype,"referrer").get;
if(document.referrer!=="https://pikabu.ru/new"||read.call(document)!==document.referrer||document.implementation.createHTMLDocument("").referrer!=="")throw new Error("native document referrer");
document.referrer="overwritten";if(document.referrer!=="https://pikabu.ru/new")throw new Error("readonly referrer");
for(const receiver of [null,{},document.body]){let rejected=false;try{read.call(receiver);}catch(error){rejected=error instanceof TypeError;}if(!rejected)throw new Error("referrer receiver");}
globalThis.referrerPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('referrerPassed')! == 'true'
	document.set_referrer('https://pikabu.ru/hot')
	assert runtime.evaluate_host('document.referrer')! == 'https://pikabu.ru/hot'
}
