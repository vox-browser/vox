module main

import browserjs
import dom

fn test_document_timeline_identity_brand_and_origin_time() {
	mut document := parse_browser_navigation_document('<!doctype html><div></div>', dom.URL{value:'https://timeline.test/'}, none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
 const timeline=document.timeline;
 if(!(timeline instanceof DocumentTimeline)||!(timeline instanceof AnimationTimeline)||timeline!==document.timeline)throw Error("timeline identity");
 if(typeof timeline.currentTime!=="number")throw Error("active clock");
 let rejected=false;try{Object.getOwnPropertyDescriptor(AnimationTimeline.prototype,"currentTime").get.call({})}catch(e){rejected=e instanceof TypeError}
 if(!rejected)throw Error("timeline brand");
 const shifted=new DocumentTimeline({originTime:25});
 if(!(shifted instanceof DocumentTimeline)||typeof shifted.currentTime!=="number")throw Error("constructed timeline");
 if(DocumentTimeline.length!==0)throw Error("constructor length");
 let reads=0;new DocumentTimeline({get originTime(){reads++;return 2;}});if(reads!==1)throw Error("dictionary read");
 for(const originTime of [Infinity,NaN,1n,{valueOf(){return 1n}}]){let threw=false;try{new DocumentTimeline({originTime})}catch(e){threw=e instanceof TypeError}if(!threw)throw Error("origin conversion");}

 '], runtime, mut messages)
	assert messages == []string{},messages.str()
	document.update_animations_and_send_events(1000)
	assert runtime.evaluate_host('document.timeline.currentTime')! == '1000'
	assert runtime.evaluate_host('shifted.currentTime')! == '975'
}
