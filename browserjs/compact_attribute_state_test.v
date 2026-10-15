module browserjs

import dom
import json2

fn compact_attribute_test_state(records []json2.Any, attributes map[string]json2.Any) string {
	return json2.encode({
		'attributeRecords': json2.Any(records)
		'attributes': json2.Any(attributes)
		'attributesDirty': json2.Any(false)
	})
}

fn compact_attribute_test_field(record map[string]json2.Any, name string) json2.Any {
	return record[name] or { panic('missing compact attribute field ${name}') }
}

fn test_compact_attribute_serializer_preserves_order_namespace_prefix_and_first_raw_value() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns(dom.namespace_html_uri, 'audio') or { panic(err) }
	assert element.attribute_list() == none
	empty_records, empty_projection := compact_attribute_state(element)
	assert empty_records.len == 0 && empty_projection.len == 0 && element.attribute_list() == none
	raw := 'raw' + [u8(0)].bytestr() + '😀' + [u8(0xed), 0xa0, 0x80].bytestr()
	element.set_attribute_ns_for_bindings('urn:foreign-controls', 'controls', raw) or { panic(err) }
	element.set_attribute_value('controls', 'null slot')
	element.set_attribute_ns_for_bindings('urn:prefixed', 'q:item', 'prefixed raw') or { panic(err) }
	element.set_attribute_value('q:item', 'literal colon raw')
	before := element.attribute_list() or { panic('missing attribute list') }
	identities := before.attrs.map(voidptr(it))
	records, projection := compact_attribute_state(element)
	assert records.len == 4 && projection.len == 2
	assert (compact_attribute_test_field(projection, 'controls') as string) == raw
	assert (compact_attribute_test_field(projection, 'q:item') as string) == 'prefixed raw'
	first := records[0] as map[string]json2.Any
	second := records[1] as map[string]json2.Any
	third := records[2] as map[string]json2.Any
	fourth := records[3] as map[string]json2.Any
	assert (compact_attribute_test_field(first, 'namespaceURI') as string) == 'urn:foreign-controls'
	assert compact_attribute_test_field(first, 'prefix') is json2.Null
	assert (compact_attribute_test_field(first, 'value') as string) == raw
	assert compact_attribute_test_field(second, 'namespaceURI') is json2.Null
	assert (compact_attribute_test_field(third, 'name') as string) == 'q:item'
	assert (compact_attribute_test_field(third, 'localName') as string) == 'item'
	assert (compact_attribute_test_field(third, 'prefix') as string) == 'q'
	assert (compact_attribute_test_field(fourth, 'localName') as string) == 'q:item'
	assert compact_attribute_test_field(fourth, 'prefix') is json2.Null
	assert compact_attribute_test_field(fourth, 'namespaceURI') is json2.Null
	after := element.attribute_list() or { panic('attribute list removed') }
	assert after.attrs.map(voidptr(it)) == identities
	assert element.get_attribute_ns('urn:foreign-controls', 'controls') or { '' } == raw
	assert element.get_attribute_ns(none, 'controls') or { '' } == 'null slot'
}

fn test_compact_attribute_public_mutations_select_first_match_and_capture_independent_journal_values() {
	$if !darwin { return }
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns(dom.namespace_html_uri, 'video') or { panic(err) }
	element.set_attribute_ns_for_bindings('urn:first', 'controls', 'foreign first') or { panic(err) }
	element.set_attribute_value('controls', 'null second')
	element.set_attribute_ns_for_bindings('urn:third', 'controls', 'foreign third') or { panic(err) }
	records, projection := compact_attribute_state(element)
	mut runtime := Runtime.create()
	defer { runtime.close() }
	_ = runtime.evaluate_host(compact_attribute_bootstrap())!
	_ = runtime.evaluate_host('globalThis.cas=' + compact_attribute_test_state(records, projection) + ';0')!
	assert runtime.evaluate_host(r'(()=>{
 const originalProjection=cas.attributes,first=__compactAttributes.set(cas,"controls","first changed"),later=__compactAttributes.set(cas,"controls","first changed again");
 if(first.namespaceURI!=="urn:first"||first.value!=="first changed"||later.value!=="first changed again"||first===later||cas.attributes.controls!=="first changed again"||cas.attributeRecords[1].value!=="null second")return false;
 const removed=__compactAttributes.remove(cas,"controls");if(removed.namespaceURI!=="urn:first"||cas.attributes.controls!=="null second")return false;
 const changedNull=__compactAttributes.set(cas,"controls","changed null");if(changedNull.namespaceURI!==null||cas.attributeRecords[1].value!=="foreign third")return false;
 if(__compactAttributes.remove(cas,"controls").namespaceURI!==null||cas.attributes.controls!=="foreign third")return false;
 if(__compactAttributes.remove(cas,"controls").namespaceURI!=="urn:third"||Object.hasOwn(cas.attributes,"controls")||__compactAttributes.remove(cas,"controls")!==null)return false;
 const colon=__compactAttributes.set(cas,"q:literal","colon value");
 return colon.name==="q:literal"&&colon.localName==="q:literal"&&colon.prefix===null&&colon.namespaceURI===null&&cas.attributes["q:literal"]==="colon value"&&cas.attributesDirty===true&&cas.attributes===originalProjection&&cas.attributeRecords.length===1&&!("attributeOperations" in cas);
})()')! == 'true'
}

fn test_compact_attribute_reflection_targets_null_slot_without_erasing_foreign_projection_or_order() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	_ = runtime.evaluate_host(compact_attribute_bootstrap())!
	assert runtime.evaluate_host(r'(()=>{
 const foreign={name:"controls",localName:"controls",prefix:null,namespaceURI:"urn:foreign",value:"foreign value"},prefixed={name:"q:controls",localName:"controls",prefix:"q",namespaceURI:"urn:prefixed",value:"prefixed value"};
 const state={attributeRecords:[foreign,prefixed],attributes:{controls:"foreign value","q:controls":"prefixed value"},attributesDirty:false};
 __compactAttributes.reflect(state,"controls",true);
 if(state.attributeRecords.length!==3||state.attributes.controls!=="foreign value"||state.attributeRecords[2].namespaceURI!==null||state.attributeRecords[2].value!=="")return false;
 __compactAttributes.reflect(state,"controls",false);
 if(state.attributeRecords.length!==2||state.attributes.controls!=="foreign value"||state.attributeRecords[0]!==foreign||state.attributeRecords[1]!==prefixed)return false;
 const firstNull={name:"controls",localName:"controls",prefix:null,namespaceURI:null,value:"raw null"};state.attributeRecords.unshift(firstNull);
 __compactAttributes.reflect(state,"controls",false);
 if(state.attributes.controls!=="foreign value"||state.attributeRecords[0]!==foreign)return false;
 __compactAttributes.reflect(state,"preload","");
 if(!Object.hasOwn(state.attributes,"preload")||state.attributes.preload!=="")return false;
 const raw="NOnE\u0000\ud800";__compactAttributes.reflect(state,"preload",raw);
 if(state.attributes.preload!==raw||state.attributeRecords[2].value!==raw)return false;
 __compactAttributes.reflect(state,"preload",false);
 const removed=__compactAttributes.remove(state,"controls"),replacement=__compactAttributes.set(state,"controls","new null");
 return removed.namespaceURI==="urn:foreign"&&replacement.namespaceURI===null&&state.attributeRecords[0]===prefixed&&state.attributeRecords[1].name==="controls"&&state.attributes.controls==="new null"&&state.attributes["q:controls"]==="prefixed value"&&!Object.hasOwn(state.attributes,"preload")&&state.attributesDirty&&!("attributeOperations" in state);
})()')! == 'true'
}

fn test_compact_attribute_projection_and_mutation_use_captured_intrinsics_with_special_names() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	_ = runtime.evaluate_host(compact_attribute_bootstrap())!
	assert runtime.evaluate_host(r'(()=>{
 const state={attributeRecords:[],attributes:{},attributesDirty:false};let calls=0;
 const saved={create:Object.create,define:Object.defineProperty,keys:Object.keys,remove:Reflect.deleteProperty,apply:Reflect.apply,push:Array.prototype.push,splice:Array.prototype.splice,get:WeakMap.prototype.get,set:WeakMap.prototype.set,boolean:Boolean};
 const poison=function(){calls++;throw "author intrinsic"};
 Object.create=Object.defineProperty=Object.keys=Reflect.deleteProperty=Reflect.apply=Array.prototype.push=Array.prototype.splice=WeakMap.prototype.get=WeakMap.prototype.set=globalThis.Boolean=poison;
 saved.define(Object.prototype,"controls",{get:poison,set:poison,configurable:true});
 try{
  const proto=__compactAttributes.set(state,"__proto__","proto raw");
  __compactAttributes.set(state,"constructor","constructor raw");__compactAttributes.set(state,"toString","toString raw");
  __compactAttributes.reflect(state,"controls",true);__compactAttributes.reflect(state,"controls",false);
  const removed=__compactAttributes.remove(state,"__proto__");
  return calls===0&&proto.localName==="__proto__"&&removed.value==="proto raw"&&state.attributes.constructor==="constructor raw"&&state.attributes.toString==="toString raw"&&state.attributeRecords.length===2&&state.attributesDirty===true;
 }finally{
  saved.remove(Object.prototype,"controls");Object.create=saved.create;Object.defineProperty=saved.define;Object.keys=saved.keys;Reflect.deleteProperty=saved.remove;Reflect.apply=saved.apply;Array.prototype.push=saved.push;Array.prototype.splice=saved.splice;WeakMap.prototype.get=saved.get;WeakMap.prototype.set=saved.set;globalThis.Boolean=saved.boolean;
 }
})()')! == 'true'
}
