module main

import browserjs
import dom
import html
import page

fn test_compact_attribute_writes_notify_input_models_once_with_the_actual_namespace() {
	url := dom.URL{value: 'https://input-attributes.test/'}
	owner := page.Page.create(1)!
	mut document := html.create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.enable_native_storage()
	mut allocation := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><body><input id="clean" value="initial"><input id="dirty" value="initial"><input id="changing"></body>')
	allocation.finish()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, url.serialize(), [r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(JSON.stringify(actual)+" != "+JSON.stringify(expected))};
check(clean.value,"initial");const observer=new MutationObserver(()=>{});observer.observe(clean,{attributes:true,attributeOldValue:true});
clean.setAttribute("VALUE","after");check(clean.value,"after");const changes=observer.takeRecords();check(changes.length,1);check(changes[0].attributeName,"value");check(changes[0].oldValue,"initial");
dirty.value="user value";dirty.setAttributeNS(null,"value","new default");check(dirty.value,"user value");check(dirty.defaultValue,"new default");
changing.value="invalid number";changing.setAttributeNS(null,"type","number");check(changing.value,"");check(changing.type,"number");
changing.value="42";changing.setAttributeNS("urn:foreign","type","file");check(changing.type,"number");check(changing.value,"42");
clean.setAttributeNS("urn:foreign","value","foreign");check(clean.value,"after");
console.log("input attribute hooks passed");
'], runtime, mut messages)
	assert messages == ['input attribute hooks passed'], messages.join('\n')
}
