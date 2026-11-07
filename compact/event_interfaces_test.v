module main

import browserjs
import html

fn test_compact_transition_animation_and_command_events_carry_their_members() {
	mut document := html.parse_document('<!doctype html><button id="b"></button>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const fail=message=>{throw new Error(message);};
const transition=new TransitionEvent("transitionend",{propertyName:"opacity",elapsedTime:1.5,bubbles:true});
if(!(transition instanceof Event)||transition.type!=="transitionend"||!transition.bubbles||transition.propertyName!=="opacity"||transition.elapsedTime!==1.5||transition.pseudoElement!=="")fail("TransitionEvent");
const animation=new AnimationEvent("animationstart");
if(animation.animationName!==""||animation.elapsedTime!==0||Object.prototype.toString.call(animation)!=="[object AnimationEvent]")fail("AnimationEvent defaults");
const button=document.getElementById("b"),command=new CommandEvent("command",{command:"toggle-popover",source:button});
if(command.command!=="toggle-popover"||command.source!==button)fail("CommandEvent");
let threw=false;try{new TransitionEvent("x",{elapsedTime:NaN});}catch(error){threw=error instanceof TypeError;}
if(!threw)fail("non-finite elapsedTime");
if(TransitionEvent.length!==1||Object.getOwnPropertyDescriptor(TransitionEvent.prototype,"propertyName").get.name!=="get propertyName")fail("WebIDL shape");
console.log("event interfaces passed");
'], runtime, mut messages)
	assert messages == ['event interfaces passed']
}
