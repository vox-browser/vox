module main

import urlpattern
import x.json2

// https://urlpattern.spec.whatwg.org/
// URLPattern objects keep their constructor arguments in the realm. Each
// operation recreates the translated pattern from them, so no native pattern
// outlives its query.
fn compact_url_pattern_input(value json2.Any) urlpattern.URLPatternInput {
	if value is string {
		return urlpattern.URLPatternInput(value)
	}
	if value is map[string]json2.Any {
		object := value as map[string]json2.Any
		return urlpattern.URLPatternInit{
			protocol: json_string_property(object, 'protocol')
			username: json_string_property(object, 'username')
			password: json_string_property(object, 'password')
			hostname: json_string_property(object, 'hostname')
			port:     json_string_property(object, 'port')
			pathname: json_string_property(object, 'pathname')
			search:   json_string_property(object, 'search')
			hash:     json_string_property(object, 'hash')
			base_url: json_string_property(object, 'baseURL')
		}
	}
	return urlpattern.URLPatternInit{}
}

fn compact_url_pattern_input_value(input urlpattern.URLPatternInput) json2.Any {
	match input {
		string {
			return json2.Any(input)
		}
		urlpattern.URLPatternInit {
			mut object := map[string]json2.Any{}
			if value := input.protocol { object['protocol'] = json2.Any(value) }
			if value := input.username { object['username'] = json2.Any(value) }
			if value := input.password { object['password'] = json2.Any(value) }
			if value := input.hostname { object['hostname'] = json2.Any(value) }
			if value := input.port { object['port'] = json2.Any(value) }
			if value := input.pathname { object['pathname'] = json2.Any(value) }
			if value := input.search { object['search'] = json2.Any(value) }
			if value := input.hash { object['hash'] = json2.Any(value) }
			if value := input.base_url { object['baseURL'] = json2.Any(value) }
			return json2.Any(object)
		}
	}
}

fn compact_url_pattern_component(result urlpattern.URLPatternComponentResult) json2.Any {
	mut groups := map[string]json2.Any{}
	for name, value in result.groups {
		groups[name] = json2.Any(value)
	}
	return json2.Any({
		'input':  json2.Any(result.input)
		'groups': json2.Any(groups)
	})
}

fn compact_url_pattern_query(source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	ignore_case := request['ignoreCase'] or { json2.Any(false) }
	pattern := urlpattern.URLPattern.create(compact_url_pattern_input(request['input'] or {
		json2.Any(map[string]json2.Any{})
	}), json_string_property(request, 'baseURL'), urlpattern.URLPatternOptions{
		ignore_case: ignore_case is bool && ignore_case as bool
	}) or { return error('TypeError: ${err.msg()}') }
	op := json_string_property(request, 'op') or { 'create' }
	if op == 'create' {
		return json2.encode({
			'protocol':        json2.Any(pattern.protocol())
			'username':        json2.Any(pattern.username())
			'password':        json2.Any(pattern.password())
			'hostname':        json2.Any(pattern.hostname())
			'port':            json2.Any(pattern.port())
			'pathname':        json2.Any(pattern.pathname())
			'search':          json2.Any(pattern.search())
			'hash':            json2.Any(pattern.hash())
			'hasRegExpGroups': json2.Any(pattern.has_reg_exp_groups())
		})
	}
	input := compact_url_pattern_input(request['testInput'] or { json2.Any(map[string]json2.Any{}) })
	base := json_string_property(request, 'testBase')
	if op == 'test' {
		return json2.encode(pattern.test(input, base) or { return error('TypeError: ${err.msg()}') })
	}
	if op != 'exec' {
		return error('Invalid URLPattern operation')
	}
	executed := pattern.exec(input, base) or { return error('TypeError: ${err.msg()}') }
	if !executed.matched {
		return 'null'
	}
	result := executed.result
	return json2.encode({
		'inputs':   json2.Any(result.inputs.map(compact_url_pattern_input_value(it)))
		'protocol': compact_url_pattern_component(result.protocol)
		'username': compact_url_pattern_component(result.username)
		'password': compact_url_pattern_component(result.password)
		'hostname': compact_url_pattern_component(result.hostname)
		'port':     compact_url_pattern_component(result.port)
		'pathname': compact_url_pattern_component(result.pathname)
		'search':   compact_url_pattern_component(result.search)
		'hash':     compact_url_pattern_component(result.hash)
	})
}

fn compact_url_pattern_bootstrap() string {
	return r'
(function(){
 const records=new WeakMap(),get=WeakMap.prototype.get,set=WeakMap.prototype.set;
 const components=["protocol","username","password","hostname","port","pathname","search","hash"];
 const members=["baseURL","hash","hostname","password","pathname","port","protocol","search","username"];
 const string=value=>{if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);};
 const isObject=value=>value!==null&&(typeof value==="object"||typeof value==="function");
 function input(value){
  if(value===undefined||value===null)return {};
  if(!isObject(value))return string(value);
  const init={};for(const name of members){const member=value[name];if(member!==undefined)init[name]=string(member);}return init;
 }
 function options(value){if(value!==undefined&&value!==null&&!isObject(value))throw new TypeError("URLPatternOptions must be an object");return {ignoreCase:!!(value&&value.ignoreCase)};}
 function call(request){
  try{return __queryElements("","urlPattern",JSON.stringify(request),true);}
  catch(error){const match=/^TypeError:\s*(.*)/.exec(String(error.message));throw new TypeError(match?match[1]:String(error.message));}
 }
 function record(receiver){const own=__elementApply(get,records,[receiver]);if(!own)throw new TypeError("Illegal URLPattern receiver");return own;}
 function match(receiver,op,value,base){
  const own=record(receiver),request=Object.assign({op},own.request,{testInput:input(value)});
  if(base!==undefined)request.testBase=string(base);
  return call(request);
 }
 class URLPattern{
  constructor(value,base,settings){
   const request={};
   if(arguments.length>=2&&base!==undefined&&!isObject(base)){request.input=input(value);request.baseURL=string(base);Object.assign(request,options(settings));}
   else{request.input=input(value);Object.assign(request,options(base));}
   const created=call(Object.assign({op:"create"},request));
   __elementApply(set,records,[this,{request,created}]);
  }
  test(value,base){return match(this,"test",value,base);}
  exec(value,base){return match(this,"exec",value,base);}
  get hasRegExpGroups(){return record(this).created.hasRegExpGroups;}
 }
 for(const name of components)Object.defineProperty(URLPattern.prototype,name,{get:function(){return record(this).created[name];},enumerable:true,configurable:true});
 Object.defineProperty(URLPattern.prototype,Symbol.toStringTag,{value:"URLPattern",configurable:true});
 Object.defineProperty(globalThis,"URLPattern",{value:URLPattern,writable:true,configurable:true});
})();
'
}
