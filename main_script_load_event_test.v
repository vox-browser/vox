module main

import browserjs
import dom
import html

fn test_external_script_load_uses_native_target_and_runs_before_document_ready() {
	$if !darwin && !linux {
		return
	}
	mut document := html.parse_document_with_url('<div id="result">pending</div><script id="first" defer src="bundle.js"></script><script id="second" defer src="bundle.js"></script><script id="bootstrap"></script>', dom.URL{ value: 'https://script-load.example/' })
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	mut sources := script_sources(document, document.url.serialize(), {
		'https://script-load.example/bundle.js': PreloadedResource{ body: 'globalThis.executions = (globalThis.executions || 0) + 1;' }
	}, mut messages)
	assert voidptr(sources[1].external_element?) == voidptr(document.get_element_by_id('first')?)
	assert voidptr(sources[2].external_element?) == voidptr(document.get_element_by_id('second')?)
	sources[0] = browserjs.ScriptSource{
		code: r'
globalThis.order=[];globalThis.checks=[];
const first=document.getElementById("first"),second=document.getElementById("second");
const removed=()=>order.push("removed");first.addEventListener("load",removed);first.removeEventListener("load",removed);
first.onload=function(event){checks.push(this===first&&event.target===first&&event.currentTarget===first&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&executions===1);order.push("first-handler");this.id="renamed";this.remove();};
first.addEventListener("load",function(event){checks.push(this===first&&event.target===first);order.push("first-listener");},{once:true});
const attribute=Object.getOwnPropertyDescriptor(first,"onload");
checks.push(attribute.get.call(document.getElementById("result"))===null);
for(const receiver of [{},null,new Proxy(first,{})]){try{attribute.get.call(receiver);checks.push(false)}catch(error){checks.push(error instanceof TypeError)}}
second.onload=()=>order.push("cleared");second.onload=null;
second.addEventListener("load",function(event){checks.push(this===second&&event.target===second&&executions===2&&this.onload===null);order.push("second-listener");});
document.getElementById("bootstrap").onload=()=>order.push("inline-load");
document.addEventListener("DOMContentLoaded",()=>{order.push("ready");document.getElementById("result").textContent=checks.every(Boolean)?order.join(","):"failed";});
'
	}
	run_document_script_sources(document, document.url.serialize(), sources, runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'first-handler,first-listener,second-listener,ready'
}

fn test_throwing_external_classic_script_still_fires_load_and_allows_later_scripts() {
	$if !darwin && !linux {
		return
	}
	mut document := html.parse_document_with_url('<div id="result">pending</div><script defer id="throwing" src="throwing.js"></script><script defer id="later" src="later.js"></script><script>globalThis.order=[];throwing.onload=()=>order.push("throwing-load");throwing.onerror=()=>order.push("wrong-error");later.addEventListener("load",()=>order.push("later-load"));document.addEventListener("DOMContentLoaded",()=>{order.push("ready");result.textContent=order.join(",");});</script>', dom.URL{ value: 'https://script-load.example/' })
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	sources := script_sources(document, document.url.serialize(), {
		'https://script-load.example/throwing.js': PreloadedResource{ body: 'throw new Error("script-load-test-exception");' }
		'https://script-load.example/later.js':    PreloadedResource{ body: 'order.push("later-script");' }
	}, mut messages)
	run_document_script_sources(document, document.url.serialize(), sources, runtime, mut messages)
	assert messages.any(it.contains('script-load-test-exception'))
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'throwing-load,later-script,later-load,ready'
}
