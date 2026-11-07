module main

import browserjs
import dom

fn test_compact_element_animate_drives_computed_style_through_native_animations() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document('<!doctype html><div id="target" style="width:10px;opacity:1"></div>',
		dom.URL{ value: 'https://example.test/' }, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const fail=message=>{throw new Error(message);};
const target=document.getElementById("target");
if(!("animate" in Element.prototype)||Object.prototype.hasOwnProperty.call(target,"animate"))fail("animate is not an Element method");
const animation=target.animate([{width:"0px",opacity:0},{width:"100px",opacity:1}],{duration:1000,fill:"forwards"});
if(!(animation instanceof Animation)||animation.effect.target!==target)fail("Animation wrapper");
animation.pause();
animation.currentTime=500;
if(animation.playState!=="paused"||animation.currentTime!==500)fail("paused state "+animation.playState+" "+animation.currentTime);
const style=getComputedStyle(target);
if(style.width!=="50px"||style.opacity!=="0.5")fail("animated values "+style.width+" "+style.opacity);
animation.currentTime=1000;
if(style.width!=="100px"||animation.playState!=="paused")fail("forwards fill "+style.width+" "+animation.playState);
if(target.getAnimations().length!==1||target.getAnimations()[0]!==animation)fail("getAnimations");
const indexed=target.animate({opacity:[0.2,0.6]},{duration:100});
indexed.pause();indexed.currentTime=50;
if(style.opacity!=="0.4")fail("property-indexed "+style.opacity);
indexed.cancel();animation.cancel();
if(animation.playState!=="idle"||style.width!=="10px"||style.opacity!=="1")fail("cancel "+animation.playState+" "+style.width+" "+style.opacity);
for(const [name,read] of [["padding","paddingLeft"],["borderWidth","borderTopWidth"],["paddingLeft","paddingLeft"]]){
 target.style.border="1px solid black";
 const shorthand=target.animate([{[name]:"0px"},{[name]:"10px"}],{duration:1000});
 shorthand.pause();shorthand.currentTime=500;
 if(style[read]!=="5px")fail(name+" interpolation "+style[read]);
 shorthand.cancel();
}
const precedence=target.animate([{padding:"0px",paddingLeft:"20px"},{padding:"10px",paddingLeft:"40px"}],{duration:1000});
precedence.pause();precedence.currentTime=500;
if(style.paddingLeft!=="30px"||style.paddingTop!=="5px")fail("longhand precedence "+style.paddingLeft+" "+style.paddingTop);
precedence.cancel();
let threw=false;try{target.animate([{width:"0px"}],{duration:-1});}catch(error){threw=error instanceof TypeError;}
if(!threw)fail("negative duration");
console.log("web animations passed");
'], runtime, mut messages)
	assert messages == ['web animations passed']
}

fn test_compact_document_get_animations_lists_css_transitions() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document('<!doctype html><style>.t{width:10px;transition:width 10s linear}.t.to{width:20px}</style><div id="target" class="t"></div><div id="other"></div>',
		dom.URL{ value: 'https://example.test/' }, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const fail=message=>{throw new Error(message);};
const target=document.getElementById("target");
getComputedStyle(target).width;
if(document.getAnimations().length!==0)fail("animations before the change");
target.className="t to";
getComputedStyle(target).width;
const list=document.getAnimations();
if(list.length!==1)fail("count "+list.length);
const transition=list[0];
if(!(transition instanceof CSSTransition)||!(transition instanceof Animation))fail("interface");
if(transition.transitionProperty!=="width"||transition.playState!=="running")fail("state "+transition.transitionProperty+" "+transition.playState);
if(transition.effect.target!==target||transition.effect.pseudoElement!==null)fail("effect");
if(document.getAnimations()[0]!==transition)fail("identity");
if(target.getAnimations().length!==1||target.getAnimations()[0]!==transition)fail("element list");
if(document.getElementById("other").getAnimations().length!==0)fail("other element");
transition.currentTime=5000;
if(getComputedStyle(target).width!=="15px")fail("seek "+getComputedStyle(target).width);
if(Math.abs(transition.currentTime-5000)>1)fail("current time "+transition.currentTime);
let threw=false;try{new CSSTransition();}catch(error){threw=error instanceof TypeError;}
if(!threw)fail("constructor");
console.log("css transitions listed");
'], runtime, mut messages)
	assert messages == ['css transitions listed']
}

fn test_compact_new_transition_applies_its_current_value_immediately() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document('<!doctype html><div id="target" style="width:10px"></div>',
		dom.URL{ value: 'https://example.test/' }, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const target=document.getElementById("target");
getComputedStyle(target).width;
target.style.transition="width 100s linear -50s";
target.style.width="20px";
console.log("width "+getComputedStyle(target).width);
'], runtime, mut messages)
	// Half of the transition elapsed before it started.
	assert messages == ['width 15px']
}
