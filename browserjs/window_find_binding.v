// Source Window.find uses its receiver's actual owning WindowModel/Page.
module browserjs

pub type WindowFindBeforeSearchHook = fn (&Runtime) !

fn window_find_binding_factory() string {
	return r'(function(){
 const native=__ladybirdWindowFind,define=Object.defineProperty;
 return function(window){
  const methods={find(string=""){return native(this,string);}};
  define(window,"find",{value:methods.find,writable:true,enumerable:true,configurable:true});
 };
})()'
}
