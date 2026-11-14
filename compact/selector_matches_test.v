module main

import browserjs
import html
import platform

fn test_compact_matches_preserves_pending_edits_created_nodes_errors_and_native_updates() {
	mut document := html.parse_document('<!doctype html><div id="target" class="before"></div><div id="other"></div>')
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.matchTarget=document.getElementById("target");
if(!matchTarget.matches(".before")||matchTarget.matches(".after")||!matchTarget.matches(":scope"))throw Error("initial matching");
matchTarget.className="after";
if(!matchTarget.matches(".after")||matchTarget.matches(".before"))throw Error("pending matching");
const created=document.createElement("span");created.setAttribute("data-label","λ😀");
if(!created.matches(`span[data-label="λ😀"]`))throw Error("created matching");
document.getElementById("other").appendChild(created);
if(!created.matches("#other > span"))throw Error("inserted matching");
for(const selector of ["[",":unknown-pseudo"]){let failed=false;try{matchTarget.matches(selector)}catch(e){failed=e.name==="SyntaxError"}if(!failed)throw Error("selector error");}
const foreign=document.implementation.createHTMLDocument("foreign");foreign.body.appendChild(created);
if(!created.matches("body > span"))throw Error("adopted matching");
document.body.appendChild(created);if(!created.matches("body > span"))throw Error("returned matching");
customElements.define("matches-probe",class extends HTMLElement{
 static get observedAttributes(){return ["data-mode"]}
 attributeChangedCallback(name,old,value){this.className=value;}
});
globalThis.matchReactor=document.createElement("matches-probe");matchReactor.id="reactor";
document.body.appendChild(matchReactor);matchReactor.setAttribute("data-mode","reacted");
if(!matchReactor.matches(".reacted"))throw Error("pending custom reaction");
globalThis.matchesPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('matchesPassed')! == 'true'
	mut target := document.get_element_by_id('target') or { panic('target') }
	target.set_attribute_value('class', 'native')
	assert runtime.evaluate_host('matchTarget.matches(".native")&&!matchTarget.matches(".after")')! == 'true'
	mut reactor := document.get_element_by_id('reactor') or { panic('reactor') }
	reactor.set_attribute_value('data-mode', 'native-reaction')
	assert runtime.evaluate_host('matchReactor.matches(".native-reaction")&&!matchReactor.matches(".reacted")')! == 'true'
}

fn test_selector_match_query_keeps_boolean_results_fallback_and_argument_brands() {
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close() }
	runtime.install_selector_match_query(fn (key string, selector string) !browserjs.SelectorMatchReply {
		if selector == '[' { return error('SyntaxError: invalid selector') }
		if key != 'é😀' { return browserjs.SelectorMatchReply{} }
		return browserjs.SelectorMatchReply{handled: true, matched: selector == '.yes'}
	})!
	assert runtime.evaluate_host(r'
__ladybirdSelectorMatches("é😀",".yes")===true&&__ladybirdSelectorMatches("é😀",".no")===false&&__ladybirdSelectorMatches("unknown",".yes")===undefined
')! == 'true'
	assert runtime.evaluate_host(r'
const noCoercion={toString(){throw Error("coerced")}};
[undefined,null,1,Symbol(),noCoercion,new String("é😀")].every(value=>__ladybirdSelectorMatches(value,".yes")===undefined&&__ladybirdSelectorMatches("é😀",value)===undefined)&&__ladybirdSelectorMatches()===undefined&&__ladybirdSelectorMatches("é😀",".yes",1)===undefined
')! == 'true'
	assert runtime.evaluate_host(r'(()=>{try{__ladybirdSelectorMatches("é😀","[");return false}catch(e){return e.message.includes("SyntaxError")}})()')! == 'true'
}

fn test_selector_match_query_restores_storage_and_keeps_realm_owners_separate() {
	mut first := browserjs.Runtime.create_with_engine(.javascriptcore)
	mut second := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { first.close(); second.close() }
	first.install_selector_match_query(fn (key string, _ string) !browserjs.SelectorMatchReply {
		return browserjs.SelectorMatchReply{handled:true,matched:key=='first'}
	})!
	second.install_selector_match_query(fn (key string, _ string) !browserjs.SelectorMatchReply {
		return browserjs.SelectorMatchReply{handled:true,matched:key=='second'}
	})!
	for _ in 0 .. 8 {
		work := platform.begin_thread_scratch('selector match caller')
		assert first.evaluate_host('__ladybirdSelectorMatches("first","*")&&!__ladybirdSelectorMatches("second","*")')! == 'true'
		assert second.evaluate_host('__ladybirdSelectorMatches("second","*")&&!__ladybirdSelectorMatches("first","*")')! == 'true'
		work.finish()
	}
	first.close()
	assert second.evaluate_host('__ladybirdSelectorMatches("second","*")')! == 'true'
}

// Short keys and selectors are converted into the host call's own frame;
// longer ones, at and around the buffer sizes, take the workspace. Multi-byte
// text, lone surrogates and NUL reach the callback exactly as before.
fn test_selector_match_query_passes_arguments_of_every_length_unchanged() {
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close() }
	mut seen := &[]string{}
	runtime.install_selector_match_query(fn [mut seen] (key string, selector string) !browserjs.SelectorMatchReply {
		// Arguments are borrowed for this call only.
		seen << '${key.len}:${key.clone()}|${selector.len}:${selector.clone()}'
		return browserjs.SelectorMatchReply{handled: true, matched: selector.len % 2 == 0}
	})!
	lengths := [0, 1, 94, 95, 96, 97, 138, 139, 414, 415, 416, 417, 1000, 5000]
	for length in lengths {
		for unit in ['a', 'é', '😀'] {
			seen.clear()
			result := runtime.evaluate_host('(()=>{const text=${json_string(unit)}.repeat(${length});return [__ladybirdSelectorMatches("k"+text,"s"+text),__ladybirdSelectorMatches("k","s"+text),__ladybirdSelectorMatches("k"+text,"s")].join(",")})()')!
			text := unit.repeat(length)
			expected := ['${1 + text.len}:k${text}|${1 + text.len}:s${text}', '1:k|${1 + text.len}:s${text}',
				'${1 + text.len}:k${text}|1:s']
			assert *seen == expected, '${unit} ${length}'
			assert result == '${(1 + text.len) % 2 == 0},${(1 + text.len) % 2 == 0},false', '${unit} ${length}'
		}
	}
	seen.clear()
	assert runtime.evaluate_host(r'__ladybirdSelectorMatches("a\u0000b","\ud800x")')! in ['true', 'false']
	last := *seen
	assert last.len == 1 && last[0].starts_with('3:a\0b|')
}

fn json_string(value string) string {
	return '"' + value + '"'
}
