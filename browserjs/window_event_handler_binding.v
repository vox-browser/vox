// HTML/{Global,Window}EventHandlers source accessors over actual native records.
module browserjs

import json2

fn window_event_handler_bootstrap() string {
	mut entries := []string{}
	for name in window_event_handler_names() {
		entries << '[${json2.encode(name.attribute)},${json2.encode(name.event)}]'
	}
	return r'(function(entries){
 const native=__ladybirdWindowHandler,define=Object.defineProperty;
 return function(window){for(let index=0;index<entries.length;index++){
  const attribute=entries[index][0],event=entries[index][1];
  const getter=function(){return native("get",this,event);};
  const setter=function(value){native("set",this,event,value);};
  define(getter,"name",{value:"get "+attribute,configurable:true});
  define(setter,"name",{value:"set "+attribute,configurable:true});
  define(window,attribute,{get:getter,set:setter,enumerable:true,configurable:true});
 }};
})(' + '[' + entries.join(',') + '])'
}
