module main

import browserjs
import html

fn test_compact_document_style_sheets_lists_owner_sheets_in_tree_order() {
	mut document := html.parse_document('<!doctype html><style id="first">a{color:red}</style><div id="host"></div><style id="second">b{color:blue}</style>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const fail=message=>{throw new Error(message);};
const list=document.styleSheets;
if(!(list instanceof StyleSheetList)||document.styleSheets!==list)fail("StyleSheetList identity");
if(list.length!==2||list[0]!==document.getElementById("first").sheet||list.item(1)!==document.getElementById("second").sheet||list[2]!==undefined||list.item(2)!==null)fail("sheets "+list.length);
if(list[0].cssRules[0].selectorText!=="a")fail("sheet rules");
const added=document.createElement("style");added.textContent="i{color:green}";document.body.insertBefore(added,document.getElementById("host"));
if(list.length!==3||list[1]!==added.sheet)fail("live insertion "+list.length);
document.getElementById("first").remove();
if(list.length!==2||[...list][0]!==added.sheet)fail("live removal");
const shadow=document.getElementById("host").attachShadow({mode:"open"});
shadow.innerHTML="<style>p{color:red}</style>";
if(shadow.styleSheets.length!==1||list.length!==2)fail("shadow root sheets "+shadow.styleSheets.length);
console.log("styleSheets passed");
'], runtime, mut messages)
	assert messages == ['styleSheets passed']
}
