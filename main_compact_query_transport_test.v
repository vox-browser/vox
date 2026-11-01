module main

import browserjs
import html
import x.json2

fn test_compact_query_fields_keep_pending_replay_and_delimiter_fallback() {
	$if !darwin { return }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	runtime.evaluate_host(r'
const __state={operations:[]},pending={};
const inputs=[];
const __nativeElementQuery=input=>{inputs.push(input);return "null";};
const __pendingElementStates=()=>pending;
const __queryElement=value=>value;
')!
	runtime.evaluate_host(compact_element_query_bootstrap())!
	runtime.evaluate_host(r'__queryElements("key","nodeText","line one\nстрока\u0000tail");')!
	first := runtime.evaluate_host('inputs[0]')!
	if disable_compact_query_fields {
		assert json2.decode[map[string]json2.Any](first)!['selector']!.str() == 'line one\nстрока\x00tail'
	} else {
		assert first == '@key\nnodeText\nline one\nстрока\x00tail'
	}
	assert runtime.evaluate_host(r'
__state.operations.push({kind:"pending"});
pending.key={attributesDirty:true,textContentDirty:true};
__queryElements("key","nodeText","");
const replay=JSON.parse(inputs[1]);
replay.snapshot&&JSON.parse(replay.snapshot).operations.length===1&&__state.operations.length===0&&!pending.key.attributesDirty&&!pending.key.textContentDirty
')! == 'true'
	assert runtime.evaluate_host(r'
delete pending.key;
__queryElements("line\nkey","nodeText","");
JSON.parse(inputs[2]).key==="line\nkey"
')! == 'true'
}

fn test_compact_query_fields_match_json_native_reads_writes_and_errors() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><p id="target">before</p>')
	defer { document.finalize() }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', []string{}, runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host(r'
const directKey=target.__state.bridgeKey;
function plainQuery(action,selector){return JSON.parse(__ladybirdElementQuery("@"+directKey+"\n"+action+"\n"+selector));}
function jsonQuery(action,selector){return JSON.parse(__ladybirdElementQuery(JSON.stringify({key:directKey,action,selector})));}
plainQuery("nodeText","")===jsonQuery("nodeText","")&&plainQuery("matches","p#target")===true
')! == 'true'
	assert runtime.evaluate_host(r'
const directText="first\nстрока\u0000last";
plainQuery("setNodeText",directText);
plainQuery("nodeText","")===directText&&jsonQuery("nodeText","")===directText
')! == 'true'
	assert runtime.evaluate_host(r'
let malformed=false;
try{__ladybirdElementQuery("@missing-separator");}catch(error){malformed=true;}
malformed
')! == 'true'
}

fn test_compact_query_fields_preserve_mutation_replay_before_selector_reads() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><div id="owner"><i id="child">old</i></div>')
	defer { document.finalize() }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
child.className="new-class";
child.textContent="new text";
if(document.querySelector(".new-class")!==child)throw new Error("pending attributes not replayed");
if(child.firstChild.data!=="new text")throw new Error("pending content not replayed");
'], runtime, mut messages)
	assert messages == []string{}
	child := document.get_element_by_id('child')?
	assert child.get_attribute_value('class') == 'new-class'
	assert child.as_node().text_content()? == 'new text'
}
