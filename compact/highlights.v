module main

import dom
import x.json2

@[heap]
struct CompactHighlight {
mut:
	ranges   []string
	priority int
	type_    string = 'highlight'
}

struct CompactHighlightRegistration {
mut:
	name      string
	highlight string
	active    bool = true
}

struct CompactHighlightRange {
	live         &dom.Range = unsafe { nil }
	start        &dom.Node  = unsafe { nil }
	end          &dom.Node  = unsafe { nil }
	start_offset int
	end_offset   int
}

fn (mut binding CompactElementQueryBinding) highlight_query(source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	op := json_string_property(request, 'op') or { return error('Invalid Highlight operation') }
	if op == 'create' {
		binding.next_key++
		id := '__highlight_${binding.next_key}'
		binding.highlights[id] = &CompactHighlight{}
		return json2.encode(id)
	}
	if op == 'range' {
		id := json_string_property(request, 'id') or { return error('Invalid range identity') }
		if id !in binding.highlight_ranges {
			if key := json_string_property(request, 'live') {
				live := binding.ranges[key] or { return error('TypeError: Expected Range') }
				binding.highlight_ranges[id] = CompactHighlightRange{ live: live }
			} else {
				binding.highlight_ranges[id] = CompactHighlightRange{
					start:        binding.range_node_argument(request, 'start')!
					end:          binding.range_node_argument(request, 'end')!
					start_offset: compact_range_int(request, 'startOffset')
					end_offset:   compact_range_int(request, 'endOffset')
				}
			}
		}
		return 'null'
	}
	if op.starts_with('registry') || op == 'hit' {
		return binding.highlight_registry_query(op, request)
	}
	id := json_string_property(request, 'highlight') or { return error('TypeError: Expected Highlight') }
	mut highlight := binding.highlights[id] or { return error('TypeError: Expected Highlight') }
	value := json_string_property(request, 'value') or { '' }
	match op {
		'size' { return json2.encode(highlight.ranges.filter(it != '').len) }
		'priority' { return json2.encode(highlight.priority) }
		'setPriority' {
			highlight.priority = compact_range_int(request, 'priority')
			return 'null'
		}
		'type' { return json2.encode(highlight.type_) }
		'setType' {
			highlight.type_ = value
			return 'null'
		}
		'has' { return json2.encode(value in highlight.ranges) }
		'add' {
			if value !in highlight.ranges { highlight.ranges << value }
			return 'null'
		}
		'delete' {
			for i, range in highlight.ranges {
				if range == value {
					highlight.ranges[i] = ''
					return 'true'
				}
			}
			return 'false'
		}
		'clear' {
			for i in 0 .. highlight.ranges.len { highlight.ranges[i] = '' }
			return 'null'
		}
		'next' {
			for i := compact_range_int(request, 'index'); i < highlight.ranges.len; i++ {
				if highlight.ranges[i] != '' {
					return json2.encode({
						'index': json2.Any(i + 1)
						'value': json2.Any(highlight.ranges[i])
					})
				}
			}
			return 'null'
		}
		else { return error('Invalid Highlight operation') }
	}
}

fn (mut binding CompactElementQueryBinding) highlight_registry_query(op string, request map[string]json2.Any) !string {
	name := json_string_property(request, 'name') or { '' }
	if op == 'registrySize' {
		return json2.encode(binding.highlight_registry.filter(it.active).len)
	}
	if op == 'registryClear' {
		for i in 0 .. binding.highlight_registry.len {
			binding.highlight_registry[i].active = false
		}
		return 'null'
	}
	if op == 'registryNext' {
		for i := compact_range_int(request, 'index'); i < binding.highlight_registry.len; i++ {
			entry := binding.highlight_registry[i]
			if entry.active {
				return json2.encode({
					'index': json2.Any(i + 1)
					'name':  json2.Any(entry.name)
					'value': json2.Any(entry.highlight)
				})
			}
		}
		return 'null'
	}
	if op == 'hit' {
		x, y := (request['x'] or { json2.Any(0.0) }).f64(), (request['y'] or { json2.Any(0.0) }).f64()
		viewport := binding.document.viewport_rect()
		if x < 0 || y < 0 || x >= viewport.width || y >= viewport.height || !binding.document.is_fully_active() {
			return '[]'
		}
		mut ordered := []string{}
		for i := binding.highlight_registry.len - 1; i >= 0; i-- {
			entry := binding.highlight_registry[i]
			if !entry.active || entry.highlight in ordered { continue }
			highlight := binding.highlights[entry.highlight] or { continue }
			mut at := ordered.len
			for j, other in ordered {
				other_highlight := binding.highlights[other] or { continue }
				if highlight.priority > other_highlight.priority {
					at = j
					break
				}
			}
			ordered.insert(at, entry.highlight)
		}
		mut hits := []json2.Any{}
		for id in ordered {
			highlight := binding.highlights[id] or { continue }
			mut ranges := []string{}
			for range_id in highlight.ranges {
				if range_id == '' { continue }
				range := binding.highlight_ranges[range_id] or { continue }
				if binding.highlight_range_contains(range, x, y) { ranges << range_id }
			}
			if ranges.len > 0 {
				hits << json2.Any({
					'highlight': json2.Any(id)
					'ranges':    json2.Any(ranges.map(json2.Any(it)))
				})
			}
		}
		return json2.encode(hits)
	}
	for i, entry in binding.highlight_registry {
		if !entry.active || entry.name != name { continue }
		match op {
			'registryGet' { return json2.encode(entry.highlight) }
			'registryHas' { return 'true' }
			'registryDelete' {
				binding.highlight_registry[i].active = false
				return 'true'
			}
			'registrySet' {
				id := json_string_property(request, 'value') or { return error('TypeError: Expected Highlight') }
				if id !in binding.highlights { return error('TypeError: Expected Highlight') }
				binding.highlight_registry[i].highlight = id
				return 'null'
			}
			else { return error('Invalid HighlightRegistry operation') }
		}
	}
	match op {
		'registryGet' { return 'null' }
		'registryHas', 'registryDelete' { return 'false' }
		'registrySet' {
			id := json_string_property(request, 'value') or { return error('TypeError: Expected Highlight') }
			if id !in binding.highlights { return error('TypeError: Expected Highlight') }
			binding.highlight_registry << CompactHighlightRegistration{ name: name, highlight: id }
			return 'null'
		}
		else { return error('Invalid HighlightRegistry operation') }
	}
}

fn (binding &CompactElementQueryBinding) highlight_range_contains(record CompactHighlightRange, x f64, y f64) bool {
	mut range := record.live
	temporary := range == unsafe { nil }
	if temporary {
		if record.start == unsafe { nil } || record.end == unsafe { nil }
			|| record.start_offset > record.start.length() || record.end_offset > record.end.length()
			|| voidptr(record.start.root()) != voidptr(record.end.root()) {
			return false
		}
		range = dom.Range.create(binding.document)
		range.set_start(record.start, record.start_offset) or {
			range.finalize()
			return false
		}
		range.set_end(record.end, record.end_offset) or {
			range.finalize()
			return false
		}
		// Reversed static boundary points do not become a collapsed highlight.
		if voidptr(range.start_container()) != voidptr(record.start) || range.start_offset() != record.start_offset {
			range.finalize()
			return false
		}
	}
	defer { if temporary { range.finalize() } }
	if range.collapsed() || voidptr(range.root()) != voidptr(binding.document.as_node()) {
		return false
	}
	for rect in range.get_client_rects().rects {
		if rect.width > 0 && rect.height > 0 && x >= rect.x && x < rect.x + rect.width && y >= rect.y && y < rect.y + rect.height {
			return true
		}
	}
	return false
}

fn compact_highlights_bootstrap() string {
	return r'
(function(){
 const apply=Reflect.apply,define=Object.defineProperty,create=Object.create,weakGet=WeakMap.prototype.get,weakSet=WeakMap.prototype.set,mapGet=Map.prototype.get,mapSet=Map.prototype.set;
 const highlights=new WeakMap(),ranges=new WeakMap(),rangeObjects=new Map(),objects=new Map(),registries=new WeakMap();let rangeCounter=0;
 const getters={};for(const name of ["startContainer","startOffset","endContainer","endOffset"])getters[name]=Object.getOwnPropertyDescriptor(AbstractRange.prototype,name).get;
 function query(op,fields){return __queryElements("","highlight",JSON.stringify(Object.assign({op},fields)),true);}
 function own(receiver){const id=apply(weakGet,highlights,[receiver]);if(!id)throw new TypeError("Illegal Highlight receiver");return id;}
 function registry(receiver){if(!apply(weakGet,registries,[receiver]))throw new TypeError("Illegal HighlightRegistry receiver");}
 function node(value){const state=__compactNodeState(value);return {key:state.bridgeKey,state:state.created?state:undefined};}
 function range(value){let id=apply(weakGet,ranges,[value]);if(id)return id;let live;try{live=__compactRangeKey(value);}catch(error){apply(getters.startContainer,value,[]);}id="__highlight_range_"+(++rangeCounter);const fields={id};if(live)fields.live=live;else{fields.start=node(apply(getters.startContainer,value,[]));fields.startOffset=apply(getters.startOffset,value,[]);fields.end=node(apply(getters.endContainer,value,[]));fields.endOffset=apply(getters.endOffset,value,[]);}query("range",fields);apply(weakSet,ranges,[value,id]);apply(mapSet,rangeObjects,[id,value]);return id;}
 function Highlight(...initialRanges){if(!new.target)throw new TypeError("Highlight requires new");const converted=initialRanges.map(range),id=query("create",{});apply(weakSet,highlights,[this,id]);apply(mapSet,objects,[id,this]);for(const value of converted)query("add",{highlight:id,value});}
 function HighlightRegistry(){throw new TypeError("Illegal HighlightRegistry constructor");}
 define(Highlight,"length",{value:0});
 for(const Constructor of [Highlight,HighlightRegistry]){define(Constructor,"prototype",{writable:false});define(Constructor.prototype,Symbol.toStringTag,{value:Constructor.name,configurable:true});define(globalThis,Constructor.name,{value:Constructor,writable:true,configurable:true});}
 function method(prototype,name,operation,length){const value=({[name](...args){return apply(operation,this,args);}})[name];define(value,"name",{value:name,configurable:true});define(value,"length",{value:length,configurable:true});define(prototype,name,{value,writable:true,enumerable:true,configurable:true});return value;}
 function argument(args,name){if(args.length<1)throw new TypeError(name+" requires an argument");}
 define(Highlight.prototype,"size",{get:function(){return query("size",{highlight:own(this)});},enumerable:true,configurable:true});
 define(Highlight.prototype,"priority",{get:function(){return query("priority",{highlight:own(this)});},set:function(value){const id=own(this),number=+value;query("setPriority",{highlight:id,priority:number>>0});},enumerable:true,configurable:true});
 define(Highlight.prototype,"type",{get:function(){return query("type",{highlight:own(this)});},set:function(value){const id=own(this),text=String(value);if(!["highlight","spelling-error","grammar-error"].includes(text))return;query("setType",{highlight:id,value:text});},enumerable:true,configurable:true});
 for(const op of ["add","has","delete"]){method(Highlight.prototype,op,function(value){const id=own(this);argument(arguments,op);const result=query(op,{highlight:id,value:range(value)});return op==="add"?this:result;},1);}
 method(Highlight.prototype,"clear",function(){query("clear",{highlight:own(this)});},0);
 function iterator(receiver,isRegistry,kind){const id=isRegistry?(registry(receiver),null):own(receiver);let index=0,done=false;const result=create(Object.getPrototypeOf(Object.getPrototypeOf([][Symbol.iterator]())));define(result,"next",{value:function next(){if(done)return {value:undefined,done:true};const row=query(isRegistry?"registryNext":"next",{highlight:id,index});if(!row){done=true;return {value:undefined,done:true};}index=row.index;const value=apply(mapGet,isRegistry?objects:rangeObjects,[row.value]),key=isRegistry?row.name:value;return {value:kind==="entries"?[key,value]:kind==="keys"?key:value,done:false};},writable:true,configurable:true});define(result,Symbol.toStringTag,{value:isRegistry?"HighlightRegistry Iterator":"Highlight Iterator",configurable:true});return result;}
 for(const Constructor of [Highlight,HighlightRegistry]){const isRegistry=Constructor===HighlightRegistry;for(const kind of ["keys","values","entries"]){method(Constructor.prototype,kind,function(){return iterator(this,isRegistry,kind);},0);}define(Constructor.prototype,Symbol.iterator,{value:isRegistry?Constructor.prototype.entries:Constructor.prototype.values,writable:true,configurable:true});method(Constructor.prototype,"forEach",function(callback,thisArg){if(isRegistry)registry(this);else own(this);if(typeof callback!=="function")throw new TypeError("Expected callback");for(const entry of iterator(this,isRegistry,"entries"))apply(callback,thisArg,[entry[1],entry[0],this]);},1);}
 const registryObject=create(HighlightRegistry.prototype);apply(weakSet,registries,[registryObject,true]);
 define(HighlightRegistry.prototype,"size",{get:function(){registry(this);return query("registrySize",{});},enumerable:true,configurable:true});
 for(const name of ["get","has","delete"]){method(HighlightRegistry.prototype,name,function(value){registry(this);argument(arguments,name);const result=query("registry"+name[0].toUpperCase()+name.slice(1),{name:String(value)});return name==="get"?(result===null?undefined:apply(mapGet,objects,[result])):result;},1);}
 method(HighlightRegistry.prototype,"clear",function(){registry(this);query("registryClear",{});},0);
 method(HighlightRegistry.prototype,"set",function(name,value){registry(this);if(arguments.length<2)throw new TypeError("HighlightRegistry.set requires two arguments");const text=String(name),id=own(value);query("registrySet",{name:text,value:id});return this;},2);
 method(HighlightRegistry.prototype,"highlightsFromPoint",function(x,y,options){registry(this);if(arguments.length<2)throw new TypeError("highlightsFromPoint requires coordinates");x=Math.fround(+x);y=Math.fround(+y);if(!Number.isFinite(x)||!Number.isFinite(y))throw new TypeError("Expected finite coordinates");if(options!=null&&typeof options!=="object"&&typeof options!=="function")throw new TypeError("Expected options dictionary");if(options&&options.shadowRoots!==undefined)for(const root of options.shadowRoots){if(!(root instanceof ShadowRoot))throw new TypeError("Expected ShadowRoot");}return query("hit",{x,y}).map(hit=>({highlight:apply(mapGet,objects,[hit.highlight]),ranges:hit.ranges.map(id=>apply(mapGet,rangeObjects,[id]))}));},2);
 for(const [prototype,names] of [[Highlight.prototype,["size","priority","type"]],[HighlightRegistry.prototype,["size"]]])for(const name of names){const descriptor=Object.getOwnPropertyDescriptor(prototype,name);if(descriptor.get)define(descriptor.get,"name",{value:"get "+name,configurable:true});if(descriptor.set)define(descriptor.set,"name",{value:"set "+name,configurable:true});}
 define(CSS,"highlights",{get:function(){return registryObject;},enumerable:true,configurable:true});
})();
'
}
