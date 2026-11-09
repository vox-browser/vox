module main

import css
import dom
import html
import json2

fn compact_typed_style_query(root &dom.Node, name string) !string {
	element := root.as_element() or { return error('TypeError: Expected Element') }
	if css.property_id_from_string(name) == none && !name.starts_with('--') { return error('TypeError: Invalid CSS property') }
	mut document := unsafe { &dom.Document(element.document()) }
	document.update_style()
	// Layout selects position options before their computed values are exposed.
	if document.get_window() == none { _ = html.WindowModel.create_top_level(document,none,'')! }
	window := unsafe { &html.WindowModel(document.get_window() or { return error('Missing Window') }) }
	declaration := window.get_computed_style(element,none)
	resolved := declaration.get_property_value(name)
	mut property_map := css.StylePropertyMapReadOnly.create_computed_style(dom.AbstractElement.new(element,none))
	mut value := property_map.get(name) or { return 'null' }
	if source := value.source_value_ {
		text := source.serialize(.normal)
		if text.contains('anchor(') || text.contains('anchor-size(') {
			values := css.CSSStyleValue.parse_a_css_style_value(name,resolved,false)!
			if values.len > 0 { value = values[0] }
		}
	}
	if keyword := value.keyword_value_ { return json2.encode({'kind':json2.Any('keyword'),'value':json2.Any(keyword.value())}) }
	if numeric := value.numeric_value_ {
		if numeric is css.CSSUnitValue { return json2.encode({'kind':json2.Any('unit'),'value':json2.Any(numeric.value()),'unit':json2.Any(numeric.unit())}) }
	}
	return json2.encode({'kind':json2.Any('style'),'text':json2.Any(value.to_string()!)})
}

fn compact_typed_style_bootstrap() string {
	return r'
(function(){
 const records=new WeakMap(),maps=new WeakMap(),cache=new WeakMap();
 const string=value=>{if(typeof value==="symbol")throw new TypeError("Cannot convert Symbol to string");return String(value);};
 const record=value=>{const state=records.get(value);if(!state)throw new TypeError("Illegal CSSStyleValue receiver");return state;};
 class CSSStyleValue{constructor(){throw new TypeError("Illegal CSSStyleValue constructor");}toString(){return record(this).text;}}
 class CSSKeywordValue extends CSSStyleValue{
  constructor(value){if(!arguments.length)throw new TypeError("Missing keyword");const text=string(value);if(!text)throw new TypeError("Empty keyword");const object=Object.create(new.target.prototype);records.set(object,{kind:"keyword",value:text});return object;}
  get value(){return record(this).value;}set value(value){const own=record(this),text=string(value);if(!text)throw new TypeError("Empty keyword");own.value=text;}
  toString(){return record(this).value;}
 }
 class CSSNumericValue extends CSSStyleValue{constructor(){throw new TypeError("Illegal CSSNumericValue constructor");}}
 class CSSUnitValue extends CSSNumericValue{
  constructor(value,unit){if(arguments.length<2)throw new TypeError("Missing unit value");value=Number(value);unit=string(unit).toLowerCase();if(!Number.isFinite(value)||!["number","percent","px","cm","mm","q","in","pt","pc","em","ex","ch","rem","vw","vh","vmin","vmax","deg","grad","rad","turn","s","ms","hz","khz","dpi","dpcm","dppx","fr"].includes(unit))throw new TypeError("Invalid unit value");const object=Object.create(new.target.prototype);records.set(object,{kind:"unit",value,unit});return object;}
  get value(){return record(this).value;}set value(value){const own=record(this);value=Number(value);if(!Number.isFinite(value))throw new TypeError("Invalid numeric value");own.value=value;}
  get unit(){return record(this).unit;}
  toString(){const own=record(this);return own.value+(own.unit==="number"?"":own.unit==="percent"?"%":own.unit);}
 }
 function reify(value){if(value===null)return undefined;if(value.kind==="keyword")return new CSSKeywordValue(value.value);if(value.kind==="unit")return new CSSUnitValue(value.value,value.unit);const object=Object.create(CSSStyleValue.prototype);records.set(object,value);return object;}
 class StylePropertyMapReadOnly{
  constructor(){throw new TypeError("Illegal StylePropertyMapReadOnly constructor");}
  get(property){const state=maps.get(this);if(!state)throw new TypeError("Illegal StylePropertyMapReadOnly receiver");if(!arguments.length)throw new TypeError("Missing property");return reify(__queryElements(state.bridgeKey,"typedStyle",string(property),true));}
  getAll(property){const value=this.get(property);return value===undefined?[]:[value];}
  has(property){return this.get(property)!==undefined;}
 }
 for(const constructor of [CSSStyleValue,CSSKeywordValue,CSSNumericValue,CSSUnitValue,StylePropertyMapReadOnly]){Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:constructor.name,configurable:true});Object.defineProperty(globalThis,constructor.name,{value:constructor,writable:true,configurable:true});}
 for(const unit of ["number","percent","px","cm","mm","q","in","pt","pc","em","ex","ch","rem","vw","vh","vmin","vmax","deg","grad","rad","turn","s","ms","hz","khz","dpi","dpcm","dppx","fr"])Object.defineProperty(CSS,unit,{value:function(value){if(!arguments.length)throw new TypeError("Missing value");return new CSSUnitValue(value,unit);},writable:true,configurable:true});
 Object.defineProperty(Element.prototype,"computedStyleMap",{value:function computedStyleMap(){const state=__elementApply(__elementRecordGet,__elementRecords,[this]);if(!state)throw new TypeError("Illegal Element receiver");let map=cache.get(this);if(!map){map=Object.create(StylePropertyMapReadOnly.prototype);maps.set(map,state);cache.set(this,map);}return map;},writable:true,enumerable:true,configurable:true});
})();
'
}
