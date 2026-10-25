module main

import dom
import x.json2

// Pending compact mutations are replayed before testing the native tree. In
// particular, a fragment stops containing its children when they are inserted.
fn (mut binding CompactElementQueryBinding) contains_query(root &dom.Node, key string) !string {
	other := if key == '' {
		binding.document.as_node()
	} else {
		binding.node_for_key(key) or { return error('TypeError: Expected a Node') }
	}
	return json2.encode(root.contains(other))
}

fn compact_contains_bootstrap() string {
	return r'
const __compactNodeContains={contains(other){
 "use strict";
 const own=__compactNodeState(this);
 if(arguments.length===0)throw new TypeError("contains requires one argument");
 if(other===null||other===undefined)return false;
 const target=__compactNodeState(other);
 return __queryElements(own.bridgeKey,"contains",target.bridgeKey);
}}.contains;
for(const owner of [Element.prototype,document])Object.defineProperty(owner,"contains",{value:__compactNodeContains,writable:true,enumerable:true,configurable:true});
'
}
