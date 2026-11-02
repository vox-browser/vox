module main

import dom
import x.json2

struct CompactCharacterDataQuery {
	op     string
	offset int
	count  int
	data   string
}

fn (mut binding CompactElementQueryBinding) character_data_query(root &dom.Node, source string) !string {
	mut data := root.as_character_data() or { return error('TypeError: Illegal CharacterData receiver') }
	query := compact_decode_query[CompactCharacterDataQuery](source)!
	if query.op == 'substringData' {
		return json2.encode({
			'value': json2.Any(data.substring_data(query.offset, query.count)!)
		})
	}
	if query.op in ['wholeText', 'splitText'] {
		if !root.is_text() && !root.is_cdata_section() {
			return error('TypeError: Illegal Text receiver')
		}
		mut text := unsafe { &dom.Text(root) }
		if query.op == 'wholeText' {
			return json2.encode({
				'value': json2.Any(text.whole_text())
			})
		}
		result := text.split_text(query.offset)!
		if root.is_connected() { binding.note_node_tree_mutation() }
		return json2.encode({
			'node': binding.node_state(result.as_node())
		})
	}
	match query.op {
		'appendData' { data.append_data(query.data.clone())! }
		'insertData' { data.insert_data(query.offset, query.data.clone())! }
		'deleteData' { data.delete_data(query.offset, query.count)! }
		'replaceData' { data.replace_data(query.offset, query.count, query.data.clone())! }
		else { return error('Unknown CharacterData operation') }
	}
	if root.is_connected() { binding.note_node_tree_mutation() }
	return 'null'
}

fn compact_character_data_bootstrap() string {
	return r'
function CharacterData(){throw new TypeError("Illegal CharacterData constructor");}
const __compactTextCreate=document.createTextNode,__compactCommentCreate=Document.prototype.createComment;
function __compactCharacterConstruct(create,data,target,fallback){
 const node=__elementApply(create,document,[data]),prototype=target.prototype;
 Object.setPrototypeOf(node,prototype!==null&&(typeof prototype==="object"||typeof prototype==="function")?prototype:fallback);return node;
}
function Text(data=""){if(!new.target)throw new TypeError("Text requires new");return __compactCharacterConstruct(__compactTextCreate,data,new.target,Text.prototype);}
function Comment(data=""){if(!new.target)throw new TypeError("Comment requires new");return __compactCharacterConstruct(__compactCommentCreate,data,new.target,Comment.prototype);}
function CDATASection(){throw new TypeError("Illegal CDATASection constructor");}
function ProcessingInstruction(){throw new TypeError("Illegal ProcessingInstruction constructor");}
for(const [constructor,base] of [[CharacterData,Node],[Text,CharacterData],[Comment,CharacterData],[CDATASection,Text],[ProcessingInstruction,CharacterData]]){
 Object.setPrototypeOf(constructor,base);Object.setPrototypeOf(constructor.prototype,base.prototype);
 Object.defineProperty(constructor,"prototype",{writable:false});Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:constructor.name,configurable:true});
 Object.defineProperty(globalThis,constructor.name,{value:constructor,writable:true,configurable:true});
}
function __compactCharacterPrototype(type){return type===3?Text.prototype:type===4?CDATASection.prototype:type===7?ProcessingInstruction.prototype:type===8?Comment.prototype:null;}
function __compactCharacterState(receiver,text){const state=__compactNodeState(receiver);if(!(text?[3,4]:[3,4,7,8]).includes(state.nodeType))throw new TypeError(text?"Illegal Text receiver":"Illegal CharacterData receiver");return state;}
function __compactCharacterString(value){if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);}
function __compactCharacterOperation(state,request){
 try{return __queryElements(state.bridgeKey,"characterData",JSON.stringify(request));}
 catch(error){const match=/^IndexSizeError:\s*(.*)/.exec(String(error.message));if(match)throw new DOMException(match[1],"IndexSizeError");throw error;}
}
Object.defineProperty(Text.prototype,"wholeText",{get:function(){return __compactCharacterOperation(__compactCharacterState(this,true),{op:"wholeText"}).value;},enumerable:true,configurable:true});
Object.defineProperty(Text.prototype,"splitText",{value:function splitText(offset){const state=__compactCharacterState(this,true);if(arguments.length===0)throw new TypeError("splitText requires an offset");const result=__compactCharacterOperation(state,{op:"splitText",offset:(+offset)>>>0});__compactInvalidateContent(state);return __queryElement(result.node);},writable:true,enumerable:true,configurable:true});
const __compactCharacterMethods={
 substringData(offset,count){const state=__compactCharacterState(this,false);if(arguments.length<2)throw new TypeError("substringData requires offset and count");return __compactCharacterOperation(state,{op:"substringData",offset:(+offset)>>>0,count:(+count)>>>0}).value;},
 appendData(data){const state=__compactCharacterState(this,false);if(arguments.length===0)throw new TypeError("appendData requires data");__compactCharacterOperation(state,{op:"appendData",data:__compactCharacterString(data)});__compactInvalidateContent(state);},
 insertData(offset,data){const state=__compactCharacterState(this,false);if(arguments.length<2)throw new TypeError("insertData requires offset and data");const converted=(+offset)>>>0;__compactCharacterOperation(state,{op:"insertData",offset:converted,data:__compactCharacterString(data)});__compactInvalidateContent(state);},
 deleteData(offset,count){const state=__compactCharacterState(this,false);if(arguments.length<2)throw new TypeError("deleteData requires offset and count");__compactCharacterOperation(state,{op:"deleteData",offset:(+offset)>>>0,count:(+count)>>>0});__compactInvalidateContent(state);},
 replaceData(offset,count,data){const state=__compactCharacterState(this,false);if(arguments.length<3)throw new TypeError("replaceData requires offset, count and data");const first=(+offset)>>>0,second=(+count)>>>0;__compactCharacterOperation(state,{op:"replaceData",offset:first,count:second,data:__compactCharacterString(data)});__compactInvalidateContent(state);}
};
for(const name of Object.keys(__compactCharacterMethods))Object.defineProperty(CharacterData.prototype,name,{value:__compactCharacterMethods[name],writable:true,enumerable:true,configurable:true});
Object.defineProperty(CharacterData.prototype,"remove",{value:function remove(){const state=__compactCharacterState(this,false);__queryElements(state.bridgeKey,"childNodeMutation",JSON.stringify({method:"remove",nodes:[]}));state.parentKey="";state.nativeParent=true;state.removed=true;},writable:true,enumerable:true,configurable:true});
'
}
