module main

import browserjs
import html

fn test_static_ranges_keep_native_boundary_identity_and_snapshot_offsets() {
	mut document := html.parse_document('<!doctype html><div id="host">abc<span>def</span></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,'about:blank',[r'
const check=(condition,label)=>{if(!condition)throw new Error(label)},text=host.firstChild;
const range=new StaticRange({startContainer:text,startOffset:1,endContainer:text,endOffset:2});
check(range instanceof StaticRange&&range instanceof AbstractRange&&!(range instanceof Range),"inheritance");
check(range.startContainer===text&&range.endContainer===text&&range.startOffset===1&&range.endOffset===2&&!range.collapsed,"boundaries");
check(!Object.hasOwn(StaticRange.prototype,"startContainer")&&Object.getOwnPropertyDescriptor(AbstractRange.prototype,"startContainer").get.call(range)===text,"shared AbstractRange getters");
text.data="";check(range.startOffset===1&&range.endOffset===2,"immutable offsets after text mutation");
const event=new InputEvent("beforeinput",{targetRanges:[range]});
check(event.getTargetRanges()[0]===range&&event.getTargetRanges()!==event.getTargetRanges(),"sequence identity");
const other=host.lastChild.firstChild,point=new StaticRange({startContainer:other,startOffset:0,endContainer:other,endOffset:0});
check(point.collapsed,"collapsed identity");
let rejected=0;for(const call of [()=>StaticRange({}),()=>new StaticRange(),()=>new StaticRange({}),()=>new StaticRange({startContainer:document.doctype,startOffset:0,endContainer:host,endOffset:0})])try{call()}catch(error){if(error instanceof TypeError||error.name==="InvalidNodeTypeError")rejected++}
check(rejected===4,"constructor errors");
let closed=false;const sequence={[Symbol.iterator](){return{next(){return{value:{},done:false}},return(){closed=true;return{done:true}}}}};
try{new InputEvent("input",{targetRanges:sequence})}catch(error){check(error instanceof TypeError,"range branding")};check(closed,"iterator close");
globalThis.staticRangePassed=true;
'],runtime,mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('staticRangePassed')! == 'true'
}
