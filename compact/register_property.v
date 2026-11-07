module main

import css
import dom
import x.json2

// https://drafts.css-houdini.org/css-properties-values-api/#the-registerproperty-function
fn (mut binding CompactElementQueryBinding) register_property_query(source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	inherits := request['inherits'] or { json2.Any(false) }
	mut document := unsafe { &dom.Document(binding.document) }
	css.register_property_for_document(mut document, css.PropertyDefinition{
		name:          json_string_property(request, 'name') or { '' }
		syntax:        json_string_property(request, 'syntax') or { '*' }
		inherits:      inherits is bool && inherits as bool
		initial_value: json_string_property(request, 'initialValue')
	})!
	binding.note_node_tree_mutation()
	return 'null'
}

// Runs after the native CSS namespace exists.
fn compact_register_property_bootstrap() string {
	return r'
if(typeof CSS==="object"&&CSS!==null&&!("registerProperty" in CSS))Object.defineProperty(CSS,"registerProperty",{value:function registerProperty(definition){
 if(arguments.length<1)throw new TypeError("registerProperty requires a PropertyDefinition");
 if(definition!==undefined&&definition!==null&&typeof definition!=="object"&&typeof definition!=="function")throw new TypeError("PropertyDefinition must be an object");
 const string=value=>{if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);};
 const source=definition||{},inherits=source.inherits,initialValue=source.initialValue,name=source.name,syntax=source.syntax;
 if(inherits===undefined)throw new TypeError("PropertyDefinition.inherits is required");
 if(name===undefined)throw new TypeError("PropertyDefinition.name is required");
 const request={inherits:!!inherits,name:string(name),syntax:syntax===undefined?"*":string(syntax)};
 if(initialValue!==undefined)request.initialValue=string(initialValue);
 try{__queryElements("","registerProperty",JSON.stringify(request),true);}
 catch(error){const match=/^(SyntaxError|InvalidModificationError):\s*(.*)/.exec(String(error.message));if(match)throw new DOMException(match[2],match[1]);throw error;}
},writable:true,enumerable:true,configurable:true});
'
}
