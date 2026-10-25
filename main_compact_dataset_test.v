module main

import browserjs
import html

fn test_compact_dataset_reads_ssr_cache_and_replays_live_attribute_mutations() {
	mut document := html.parse_document('<!doctype html><div id="host" data-ssr-uid="search-1"><b>cached</b></div><svg id="icon" data-part-name="search"></svg>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const data=host.dataset;
if(data!==host.dataset||!(data instanceof DOMStringMap)||Object.prototype.toString.call(data)!=="[object DOMStringMap]")throw new Error("dataset identity");
const cache=Object.create(null),nodes=document.querySelectorAll("[data-ssr-uid]");
for(let i=0;i<nodes.length;i++)cache[nodes[i].dataset.ssrUid]=nodes[i].innerHTML;
if(cache["search-1"]!=="<b>cached</b>")throw new Error("SSR cache");
host.setAttribute("data-ssr-uid","search-2");
if(data.ssrUid!=="search-2"||!("ssrUid" in data)||Object.keys(data).join()!=="ssrUid")throw new Error("live dataset read");
data.selectedPlace=42;data.empty=null;
if(host.getAttribute("data-selected-place")!=="42"||host.getAttribute("data-empty")!=="null")throw new Error("dataset write reflection");
if(Object.getOwnPropertyDescriptor(data,"selectedPlace").enumerable!==true)throw new Error("dataset descriptor");
delete data.ssrUid;
if(data.ssrUid!==undefined||host.hasAttribute("data-ssr-uid")||"ssrUid" in data)throw new Error("dataset deletion");
icon.dataset.partName="route";
if(icon.getAttribute("data-part-name")!=="route")throw new Error("SVG dataset");
globalThis.savedDataset=data;
'], runtime, mut messages)
	assert messages == []string{}
	mut host := document.get_element_by_id('host')?
	assert host.get_attribute_value('data-selected-place') == '42'
	assert !host.has_attribute('data-ssr-uid')
	host.set_attribute_value('data-selected-place', 'native')
	assert runtime.evaluate_host('savedDataset.selectedPlace')! == 'native'
}

fn test_compact_dataset_handles_names_conversion_and_prototype_keys() {
	mut document := html.parse_document('<!doctype html><div id="host"></div><svg id="icon"></svg>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
function rejects(callback,name){try{callback();throw new Error("missing exception");}catch(error){if(error.name!==name||(name!=="TypeError"&&!(error instanceof DOMException)))throw error;}}
rejects(()=>new DOMStringMap(),"TypeError");
rejects(()=>{host.dataset["bad-name"]="x";},"SyntaxError");
rejects(()=>{host.dataset["bad name"]="x";},"InvalidCharacterError");
rejects(()=>{host.dataset.value=Symbol();},"TypeError");
let conversions=0;host.dataset.userId={toString(){conversions++;return "7";}};
if(conversions!==1||host.getAttribute("data-user-id")!=="7")throw new Error("dataset conversion");
host.dataset["foo-Bar"]="dash";host.dataset[""]="empty";host.dataset["ключ"]="значение";
host.dataset.__proto__="own";host.dataset.constructor="ctor";
if(host.getAttribute("data-foo--bar")!=="dash"||host.getAttribute("data-")!=="empty"||host.dataset["ключ"]!=="значение")throw new Error("dataset names");
if(host.dataset.__proto__!=="own"||host.dataset.constructor!=="ctor"||Object.getPrototypeOf(host.dataset)!==DOMStringMap.prototype)throw new Error("dataset prototype keys");
icon.setAttribute("data-UPPER","hidden");icon.setAttribute("data-lower-case","visible");
if(Object.keys(icon.dataset).join()!=="lowerCase"||icon.dataset.UPPER!==undefined)throw new Error("SVG attribute case");
const detached=document.createElement("div");detached.dataset.ssrUid="detached";
if(detached.dataset.ssrUid!=="detached"||detached.getAttribute("data-ssr-uid")!=="detached")throw new Error("detached dataset");
'], runtime, mut messages)
	assert messages == []string{}
}
