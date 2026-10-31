module browserjs

fn css_namespace_binding_factory() string {
	return r'(function(operate,global){
 "use strict";
 const namespace={},define=Object.defineProperty;
 const methods={
  escape(ident){if(arguments.length===0)throw new TypeError("CSS.escape requires an identifier");return operate("escape",ident);},
  supports(conditionText){if(arguments.length===0)throw new TypeError("CSS.supports requires an argument");return arguments.length>=2?operate("supportsProperty",conditionText,arguments[1]):operate("supportsCondition",conditionText);}
 };
 for(const name of ["escape","supports"])define(namespace,name,{value:methods[name],writable:true,enumerable:true,configurable:true});
 define(namespace,Symbol.toStringTag,{value:"CSS",configurable:true});
 define(global,"CSS",{value:namespace,writable:true,configurable:true});
})'
}

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_css_namespace_binding() ! {
		return error('Native CSS namespace binding requires JavaScriptCore')
	}
}
