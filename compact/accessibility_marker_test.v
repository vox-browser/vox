module main

import browserjs
import html

fn test_accessible_marker_names_preserve_owner_alternatives_and_live_changes() {
	mut document := html.parse_document('<!doctype html><style>#custom::marker{content:"* "}#alt::marker{content:"🚅 " / "Train"}#empty::marker{content:"x" / ""}#summarycustom::marker{content:"visual "}</style><ul><li id="bullet">item</li><li id="custom">custom</li><li id="alt">alternative</li><li id="empty">empty</li></ul><ol id="list" start="7"><li id="ordinal">number</li></ol><button id="a" aria-labelledby="bullet"></button><button id="b" aria-labelledby="custom"></button><button id="c" aria-labelledby="alt"></button><button id="d" aria-labelledby="empty"></button><button id="e" aria-labelledby="ordinal"></button><div role="button" id="parent"><span style="display:list-item;list-style-type:none">plain</span></div><details><summary id="summary" title="tooltip">contents</summary></details><details open><summary id="summaryopen">open contents</summary></details><details><summary id="summarycustom">custom contents</summary></details>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
try{
 const label=id=>internals.getComputedLabel(document.getElementById(id));
 for(const [id,value] of [["a","• item"],["b","* custom"],["c","Train alternative"],["d","empty"],["e","7. number"],["parent","plain"],["summary","contents"],["summaryopen","open contents"],["summarycustom","custom contents"]]){
  if(label(id)!==value)throw new Error(id+": "+JSON.stringify(label(id)));
 }
 document.getElementById("list").setAttribute("start","9");
 if(label("e")!=="9. number")throw new Error("live ordinal "+label("e"));
 document.styleSheets[0].cssRules[1].style.content=`"painted" / "Changed"`;
 if(label("c")!=="Changed alternative")throw new Error("live alternative "+label("c"));
 console.log("marker names passed");
}catch(error){console.log("marker failure: "+String(error));throw error;}
'], runtime, mut messages)
	assert messages == ['marker names passed']
}
