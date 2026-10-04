// Window.idl legacy Replaceable event attribute over the actual native Window.
module browserjs

fn window_current_event_binding_factory() string {
	return r'(function(){
 const native=__ladybirdWindowCurrentEvent,define=Object.defineProperty;
 const descriptor=Object.getOwnPropertyDescriptor;
 return function(window){
  const accessors={
   get event(){return native("get",this);},
   set event(value){native("validate",this);define(this,"event",{value,writable:true,enumerable:true,configurable:true});}
  };
  define(window,"event",descriptor(accessors,"event"));
 };
})()'
}
