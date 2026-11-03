module main

import browserjs
import dom
import html
import platform
import x.json2

struct CompactElementScrollQuery {
	name  string
	value f64
}

struct CompactScrollMethodQuery {
	behavior string = 'auto'
	left ?f64
	top ?f64
	relative bool
}

fn compact_scroll_method(root &dom.Node, source string, viewport bool, runtime &browserjs.Runtime) !string {
	query := compact_decode_query[CompactScrollMethodQuery](source)!
	mut document := unsafe { &dom.Document(root.document()) }
	mut scope := platform.RetainedArenaScope{}
	storage := document.native_storage()
	if storage != unsafe { nil } { scope = storage.enter_nested() }
	defer { scope.finish() }
	behavior := match query.behavior {
		'auto' { dom.ScrollBehavior.auto_ }
		'instant' { dom.ScrollBehavior.instant }
		'smooth' { dom.ScrollBehavior.smooth }
		else { return error('TypeError: Invalid scroll behavior') }
	}
	if viewport {
		window := document.get_window() or { return 'null' }
		mut owner := unsafe { &html.WindowModel(window) }
		options := html.ScrollToOptions{
			left: query.left
			top: query.top
			behavior: match behavior { .auto_ { .auto_ } .instant { .instant } .smooth { .smooth } }
		}
		if query.relative { _ = owner.scroll_by(options) } else { _ = owner.scroll(options) }
	} else {
		mut element := root.as_element() or { return error('TypeError: Invalid Element receiver') }
		options := dom.ScrollToOptions_{left: query.left, top: query.top, behavior: behavior}
		if query.relative { _ = element.scroll_by_with_options(options) } else { _ = element.el_scroll_with_options(options) }
	}
	if runtime != unsafe { nil } {
		mut mutable_runtime := unsafe { &browserjs.Runtime(runtime) }
		mutable_runtime.mark_document_state_dirty()
		mutable_runtime.mark_document_replay_effects()
	}
	return 'null'
}

fn compact_scroll_methods_bootstrap() string {
	return r'(function(){
 const global=globalThis,apply=Reflect.apply,get=WeakMap.prototype.get,finite=Number.isFinite,string=String;
 function options(args){
  const result={behavior:"auto"};
  if(args.length>1){result.left=+args[0];result.top=+args[1];}
  else if(args.length&&args[0]!=null){
   const value=args[0];if(typeof value!=="object"&&typeof value!=="function")throw new TypeError("Expected scroll options");
   const behavior=value.behavior;if(behavior!==undefined){if(typeof behavior==="symbol")throw new TypeError("Invalid scroll behavior");result.behavior=string(behavior);}
   if(!["auto","instant","smooth"].includes(result.behavior))throw new TypeError("Invalid scroll behavior");
   const left=value.left;if(left!==undefined)result.left=+left;
   const top=value.top;if(top!==undefined)result.top=+top;
  }
  for(const axis of ["left","top"])if(axis in result&&!finite(result[axis]))result[axis]=0;
  return result;
 }
 for(const viewport of [false,true])for(const name of ["scroll","scrollTo","scrollBy"]){
  const method={ [name](){
   const receiver=this==null?global:this;
   let key="";
   if(viewport){if(receiver!==global)throw new TypeError("Illegal Window receiver");}
   else{const record=apply(get,__elementRecords,[receiver]);if(!record)throw new TypeError("Illegal Element receiver");key=record.bridgeKey;}
   const value=options(arguments);value.relative=name==="scrollBy";
   __queryElements(key,viewport?"windowScroll":"elementScroll",JSON.stringify(value));
  }}[name];
  Object.defineProperty(viewport?global:Element.prototype,name,{value:method,writable:true,enumerable:true,configurable:true});
 }
})();'
}

// The shared query boundary replays pending DOM/style writes before native
// scrolling, which owns clamping, scroll snapping, events and paint invalidation.
fn compact_element_set_scroll(root &dom.Node, source string, runtime &browserjs.Runtime) !string {
	mut element := root.as_element() or { return error('TypeError: Invalid Element receiver') }
	query := compact_decode_query[CompactElementScrollQuery](source)!
	mut storage := element.document().native_storage()
	mut allocation_scope := platform.RetainedArenaScope{}
	if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
	defer { allocation_scope.finish() }
	previous_x := element.scroll_left()
	previous_y := element.scroll_top()
	match query.name {
		'scrollLeft' { element.set_scroll_left(query.value) }
		'scrollTop' { element.set_scroll_top(query.value) }
		else { return error('Invalid element scroll property') }
	}
	if runtime != unsafe { nil }
		&& (previous_x != element.scroll_left() || previous_y != element.scroll_top()) {
		mut mutable_runtime := unsafe { &browserjs.Runtime(runtime) }
		mutable_runtime.mark_document_state_dirty()
		mutable_runtime.mark_document_replay_effects()
	}
	return 'null'
}
