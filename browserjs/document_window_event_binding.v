// Actual Document/Window event records at the compact facade boundary.
module browserjs

import dom

pub type DocumentEventTargetResolver = fn (string) ?&dom.Document

fn document_window_event_method_factory() string {
	return r'(function(){
 const define=Object.defineProperty,prototype=EventTarget.prototype;
 const add=prototype.addEventListener,remove=prototype.removeEventListener,dispatch=prototype.dispatchEvent;
 return function(window,document){
  for(const target of [window,document]){
   define(target,"addEventListener",{value:add,writable:true,enumerable:true,configurable:true});
   define(target,"removeEventListener",{value:remove,writable:true,enumerable:true,configurable:true});
   define(target,"dispatchEvent",{value:dispatch,writable:true,enumerable:true,configurable:true});
  }
 };
})()'
}
