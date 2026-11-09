module main

// Native mutations invalidate content in constant time. Each exposed element
// retires its old facade fields when it next reads or replays content; the
// native document version continues to validate serialized content itself.
fn compact_element_content_cache_bootstrap() string {
	return r'
const __contentEpochs=new WeakMap(),__contentEpochGet=WeakMap.prototype.get,__contentEpochSet=WeakMap.prototype.set;
let __contentEpoch=0;
function __compactRegisterContent(state){__elementApply(__contentEpochSet,__contentEpochs,[state,__contentEpoch]);}
function __compactInvalidateAllContent(){__contentEpoch++;}
function __compactRefreshContent(state){
 const previous=__elementApply(__contentEpochGet,__contentEpochs,[state]);
 if(previous===__contentEpoch)return;
 if(previous!==undefined){
  if(!state.textContentDirty)delete state.textContent;
  if(!state.innerHTMLDirty)delete state.innerHTML;
  state.nativeContent=true;
 }
 __compactRegisterContent(state);
}
const __compactReadElementContent=__elementContent;
__elementContent=function(s,name){__compactRefreshContent(s);return __compactReadElementContent(s,name);};
'
}
