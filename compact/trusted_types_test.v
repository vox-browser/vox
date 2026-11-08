module main

import browserjs
import html

fn test_compact_trusted_types_policies_values_and_type_tables() {
	$if !darwin {
		return
	}
	document := html.parse_document('<!doctype html><body></body>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/', [r'
const entries=[];
const policy=trustedTypes.createPolicy("p",{createHTML:(s,extra)=>s+"!"+(extra||""),createScript:s=>null});
const value=policy.createHTML("x","y");
entries.push(value instanceof TrustedHTML,trustedTypes.isHTML(value),trustedTypes.isScript(value),String(value),JSON.stringify({value}),policy.name);
entries.push(String(policy.createScript("s")),trustedTypes.isScript(policy.createScript("s")));
let threw="";try{policy.createScriptURL("u");}catch(error){threw=error.constructor.name;}
entries.push(threw);
threw="";try{new TrustedHTML();}catch(error){threw=error.constructor.name;}
entries.push(threw,trustedTypes.defaultPolicy);
const fallback=trustedTypes.createPolicy("default",{});
threw="";try{trustedTypes.createPolicy("default",{});}catch(error){threw=error.constructor.name;}
entries.push(trustedTypes.defaultPolicy===fallback,threw,trustedTypes.isHTML(trustedTypes.emptyHTML),String(trustedTypes.emptyScript)==="");
entries.push(trustedTypes.getAttributeType("iframe","srcdoc"),trustedTypes.getAttributeType("DIV","onclick"),trustedTypes.getAttributeType("script","href","http://www.w3.org/2000/svg"),trustedTypes.getAttributeType("div","title"));
entries.push(trustedTypes.getPropertyType("script","src"),trustedTypes.getPropertyType("div","innerHTML"),trustedTypes.getPropertyType("div","title"));
entries.push(String(TrustedHTML.fromLiteral`<b>`));
console.log(entries.join("|"));
'], runtime, mut messages)
	assert messages == ['true|true|false|x!y|{"value":"x!y"}|p||true|TypeError|TypeError||true|TypeError|true|true|TrustedHTML|TrustedScript|TrustedScriptURL||TrustedScriptURL|TrustedHTML||<b>'], messages.join('\n')
}
