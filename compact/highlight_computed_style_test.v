module main

import browserjs
import dom

fn test_named_highlight_cssom_matches_names_and_originating_container() {
 mut document := parse_browser_navigation_document('<!doctype html><style>#outer{width:200px}#target{container-type:inline-size}#target::highlight(foo){text-decoration:underline;text-decoration-thickness:0px}@container(width >= 300px){#target::highlight(foo){text-decoration-thickness:10cqw}#target::highlight(bar){text-decoration-thickness:5cqw}}</style><div id="outer"><div id="target">Text</div></div>',dom.URL{value:'https://highlight-style.test/'},none)
 mut runtime := browserjs.Runtime.create()
 defer { runtime.close(); document.finalize() }
 mut messages := []string{}
 run_document_javascript(document,document.url.serialize(),[r'try{function read(name){return getComputedStyle(target,"::highlight("+name+")").textDecorationThickness;}if(read("foo")!=="0px")throw new Error("initial foo "+read("foo"));outer.style.width="300px";if(read("foo")!=="30px"||read("bar")!=="15px"||read("foo")!=="30px")throw new Error("named styles "+read("foo")+" "+read("bar"));if(getComputedStyle(target,"::highlight(foo bar)").length!==0)throw new Error("invalid argument");globalThis.highlightStylePassed=true;}catch(error){globalThis.highlightStyleError=String(error);}'],runtime,mut messages)
 assert messages == []string{},messages.str()
 assert runtime.evaluate_host('globalThis.highlightStyleError||String(globalThis.highlightStylePassed)')! == 'true'
}
