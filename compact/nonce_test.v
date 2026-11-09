module main

import browserjs
import dom
import html

fn test_nonce_private_slot_for_html_svg_and_clones() {
	mut document := html.parse_document('<!doctype html><script id="s" nonce="abc"></script><svg id="svg" nonce="def"></svg>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,'https://nonce.test/',[r'
for(const [id,expected] of [["s","abc"],["svg","def"]]){
 const e=document.getElementById(id);
 if(e.nonce!==expected)throw new Error("initial "+id+" "+e.nonce);
 e.nonce="private";if(e.getAttribute("nonce")!==expected)throw new Error("IDL modified content");
 const copy=e.cloneNode(false);if(copy.nonce!=="private")throw new Error("clone "+id+" "+copy.nonce);
 e.setAttribute("nonce","content");if(e.nonce!=="content")throw new Error("attribute update");
 e.removeAttribute("nonce");if(e.nonce!=="")throw new Error("remove");
}
const detached=document.createElement("script");detached.nonce="detached";
if(detached.nonce!=="detached"||detached.getAttribute("nonce")!==null)throw new Error("detached");
console.log("nonce checks passed");
'],runtime,mut messages)
	assert messages == ['nonce checks passed']
}

fn test_inline_script_preparation_uses_actual_csp_owner() {
	mut document := dom.Document.create(dom.URL{value:'https://nonce.test/'})
	document.set_content_type('text/html')
	document.set_document_type(.html)
	defer { document.finalize() }
	mut root := document.create_element('html')!
	document.as_node().append_child(root.as_node())!
	document.set_csp_hook(dom.DocumentCSPHook{inline_check:fn (_ voidptr, owner &dom.Element, kind string, source string) bool {
		assert kind == 'script' && source == 'blocked()'
		assert owner.cryptographic_nonce() == 'script-nonce'
		return true
	}})
	mut script := document.create_element('script')!
	script.set_attribute_value('nonce','script-nonce')
	script.as_node().append_child(document.create_text_node('blocked()').as_node())!
	root.as_node().append_child(script.as_node())!
	mut model := html.html_script_element_model_for_dom_element(unsafe { &dom.HTMLScriptElement(script) })
	model.prepare_script(document)
	assert model.has_already_started()
	assert !model.is_ready_to_be_parser_executed()
}
