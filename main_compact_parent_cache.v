module main

// Native DOM mutation versions invalidate cached parent identities. Pending
// facade writes still pass through the ordinary query replay boundary first.
fn compact_native_parent_bootstrap() string {
	return r'
const __parentTreeVersion=globalThis.__ladybirdDOMTreeVersion;
const __nativeParentOwners=new WeakMap(),__parentCacheDelete=WeakMap.prototype.delete;
function __compactNativeParent(state){
 if(typeof __parentTreeVersion!=="function")return __queryElements(state.bridgeKey,"nodeParent","");
 const version=__parentTreeVersion();
 if(!__state.operations.length&&!__dirtyElementStates.size&&typeof version==="number"&&version>=0){
  const cached=__elementApply(__elementRecordGet,__nativeParentOwners,[state]);
  if(cached&&cached.version===version)return cached.parent;
 }
 const snapshot=__queryElements(state.bridgeKey,"cachedParent","");
 const parent=__queryElement(snapshot.parent);
 const currentVersion=__parentTreeVersion();
 if(snapshot.cacheable&&typeof currentVersion==="number"&&currentVersion>=0){
  __elementApply(__elementRecordSet,__nativeParentOwners,[state,{version:currentVersion,parent}]);
 }else{
  __elementApply(__parentCacheDelete,__nativeParentOwners,[state]);
 }
 return parent;
}'
}
