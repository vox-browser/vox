module main

// The query boundary replays tree mutations before reading the native
// shadow-including connection state, including for non-Element node wrappers.
fn compact_node_connected_bootstrap() string {
	return r'
const __compactNodeConnected=Object.getOwnPropertyDescriptor({get isConnected(){
 "use strict";
 const own=__compactNodeState(this);
 return __queryElements(own.bridgeKey,"nodeConnected","");
}},"isConnected").get;
for(const owner of [Element.prototype,document])Object.defineProperty(owner,"isConnected",{get:__compactNodeConnected,enumerable:true,configurable:true});
'
}
