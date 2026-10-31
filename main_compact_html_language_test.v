module main

import browserjs
import html

fn test_compact_html_language_reflects_parser_and_script_attributes() {
	mut document := html.parse_document('<!doctype html><html lang="en-US"><body><div id="target"></div><svg id="foreign"></svg></body></html>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
if(document.documentElement.lang!=="en-US"||target.lang!=="")throw new Error("parser locale");
target.lang="fr-CA";if(target.getAttribute("lang")!=="fr-CA")throw new Error("reflected language setter");
target.setAttribute("lang","ja");if(target.lang!=="ja")throw new Error("attribute language setter");
target.removeAttribute("lang");if(target.lang!=="")throw new Error("removed language");
const detached=document.createElement("div");detached.lang=null;if(detached.getAttribute("lang")!=="null")throw new Error("DOMString language");
const descriptor=Object.getOwnPropertyDescriptor(HTMLElement.prototype,"lang");
for(const receiver of [{},foreign]){let rejected=false;try{descriptor.get.call(receiver)}catch(error){rejected=error instanceof TypeError}if(!rejected)throw new Error("language brand");}
let converted=false;try{descriptor.set.call({}, {toString(){converted=true;return "x"}})}catch(error){}if(converted)throw new Error("brand before conversion");
let symbolRejected=false;try{target.lang=Symbol()}catch(error){symbolRejected=error instanceof TypeError}if(!symbolRejected)throw new Error("language DOMString symbol");
document.documentElement.lang="de";
'], runtime, mut messages)
	assert messages == []string{}
	assert document.document_element()?.get_attribute_value('lang') == 'de'
}
