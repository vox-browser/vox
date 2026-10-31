module browserjs

fn test_css_namespace_uses_native_identifier_serialization_and_supports_parser() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_css_namespace_binding()!
	assert runtime.evaluate_host(r'
CSS.escape("0a#") === "\\30 a\\#" && CSS.escape("a b") === "a\\ b" && CSS.escape("\0") === "\ufffd" &&
CSS.supports("display","grid") && CSS.supports("display: grid") && CSS.supports("(display: grid) and (color: red)") &&
CSS.supports("--native-token","value") && !CSS.supports("display","definitely-invalid") && !CSS.supports("not-a-property","value") && !CSS.supports("display: grid garbage") &&
Object.prototype.toString.call(CSS)==="[object CSS]" && typeof CSS==="object" && CSS.supports.length===1 && CSS.escape.length===1;
')! == 'true'
}

fn test_css_namespace_overload_conversion_order_and_original_exceptions() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_css_namespace_binding()!
	assert runtime.evaluate_host(r'
const order=[];const supported=CSS.supports.call(null,{toString(){order.push("property");return "display"}},{toString(){order.push("value");return "grid"}});
const marker={};let original=false,errors=0;try{CSS.supports({toString(){throw marker}},"grid")}catch(error){original=error===marker}
for(const call of [()=>CSS.supports(),()=>CSS.escape(),()=>CSS.escape(Symbol()),()=>CSS.supports(Symbol()),()=>CSS.supports("display",Symbol()),()=>new CSS.escape("x")])try{call()}catch(error){if(error instanceof TypeError)errors++}
supported&&order.join(",")==="property,value"&&original&&errors===6&&CSS.escape(null)==="null"&&!CSS.supports(null)&&!CSS.supports("display",undefined);
')! == 'true'
	runtime.evaluate_host('globalThis.CSS=17')!
	runtime.install_css_namespace_binding()!
	assert runtime.evaluate_host('CSS')! == '17'
}
