module main

import browserjs
import html

fn test_saved_tag_collection_observes_native_tree_changes() {
	mut document := html.parse_document('<!doctype html><div id="host"><i id="first"></i></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://old.reddit.com/', [
		'globalThis.saved=host.getElementsByTagName("i");globalThis.original=saved[0];',
	], runtime, mut messages)
	assert runtime.evaluate_host('saved.length===1&&saved[0]===original')! == 'true'
	host := document.get_element_by_id('host')?
	mut parent := host.as_node()
	child := document.create_element('i')!
	parent.append_child(child.as_node())!
	assert runtime.evaluate_host('saved.length===2&&saved[0]===original&&saved[1]===host.lastChild')! == 'true'
	parent.remove_child(child.as_node())!
	assert runtime.evaluate_host('saved.length===1&&saved[0]===original&&saved[1]===undefined')! == 'true'
	assert messages == []string{}
}

fn test_tag_collection_iteration_observes_mutations_without_losing_members() {
	mut document := html.parse_document('<!doctype html><div id="host"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://old.reddit.com/', [
		r'
host.innerHTML="<i></i>".repeat(512);
const saved=host.getElementsByTagName("i");
let count=0;
for(const element of saved){
 if(element.tagName!=="I")throw new Error("lost collection member");
 if(++count===1)host.appendChild(document.createElement("i"));
}
if(count!==513||saved.length!==513)throw new Error("iteration did not stay live");
globalThis.iterationPassed=true;
',
	], runtime, mut messages)
	assert runtime.evaluate_host('iterationPassed')! == 'true'
	assert messages == []string{}
}

fn test_collection_reads_flush_all_pending_attribute_and_content_edits() {
	mut document := html.parse_document('<!doctype html><div id="host"><i id="first"></i></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://old.reddit.com/', [
		r'
const saved=host.getElementsByTagName("i");
first.setAttribute("data-pending","one");
saved.length;
host.textContent="text only";
if(saved.length!==0)throw new Error("text replacement not flushed");
host.innerHTML="<i id=replacement></i>";
if(saved.length!==1)throw new Error("markup replacement not flushed");
saved[0].setAttribute("data-pending","two");
saved.length;
',
	], runtime, mut messages)
	replacement := document.get_element_by_id('replacement')?
	assert replacement.get_attribute_value('data-pending') == 'two'
	assert messages == []string{}
}
