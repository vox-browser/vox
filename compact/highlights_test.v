module main

import browserjs
import dom
import layout

fn test_native_highlight_collections_retain_range_identity_and_mutating_iteration() {
	mut document := parse_browser_navigation_document('<!doctype html><p id="text">highlight text</p>', dom.URL{ value: 'https://highlights.test/' }, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const first=new Range(),second=new Range();first.selectNodeContents(text);second.selectNodeContents(text);
const highlight=new Highlight(first,first);if(highlight.size!==1||!highlight.has(first))throw Error("range set");
const iterator=highlight.values();if(iterator.next().value!==first)throw Error("iterator first");highlight.add(second);if(iterator.next().value!==second)throw Error("iterator additions");
const old=Set.prototype.add;Set.prototype.add=function(){throw Error("author Set");};try{highlight.add(first);}finally{Set.prototype.add=old;}
CSS.highlights.set("first",highlight);const other=new Highlight(second);CSS.highlights.set("second",other);highlight.priority=2;
const rect=text.getBoundingClientRect(),hits=CSS.highlights.highlightsFromPoint(rect.x+2,rect.y+2);
if(hits.length!==2||hits[0].highlight!==highlight||hits[0].ranges.length!==2)throw Error("native range hit order");
if(CSS.highlights.highlightsFromPoint(-1,-1).length)throw Error("outside viewport");
CSS.highlights.clear();if(CSS.highlights.size!==0)throw Error("clear");
const staticRange=new StaticRange({startContainer:text.firstChild,startOffset:0,endContainer:text.firstChild,endOffset:2});if(new Highlight(staticRange).size!==1)throw Error("static text range");
for(const key of ["size","entries","forEach","has","keys","values",Symbol.iterator,"add","clear","delete"]){delete Set.prototype[key];}Object.freeze(Set.prototype);
const protectedHighlight=new Highlight(staticRange);protectedHighlight.add(first);if(protectedHighlight.size!==2||[...protectedHighlight].length!==2)throw Error("tampered Set registry");
globalThis.highlightsPassed=true;
'], runtime, mut messages)
	assert messages == []string{}, messages.str()
	assert runtime.evaluate_host('String(globalThis.highlightsPassed)')! == 'true'
}
