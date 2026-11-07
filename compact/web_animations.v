module main

import animations
import css
import dom
import x.json2

// https://drafts.csswg.org/web-animations-1/
// Element.animate() and the Animation interface over the translated
// Animations module. The binding retains each script-visible Animation by key;
// its effect samples through the same document style hook as CSS animations.
fn compact_web_animation_number(value json2.Any) ?f64 {
	return match value {
		f64 { value }
		i64 { f64(value) }
		int { f64(value) }
		else { none }
	}
}

fn compact_web_animation_composite_or_auto(value string) !animations.CompositeOperationOrAuto {
	return match value {
		'replace' { .replace }
		'add' { .add }
		'accumulate' { .accumulate }
		'auto' { .auto_ }
		else { error('TypeError: Invalid composite operation') }
	}
}

fn compact_web_animation_keyframes(value json2.Any) ![]animations.BaseKeyframe {
	if value is map[string]json2.Any {
		object := value as map[string]json2.Any
		mut indexed := animations.BasePropertyIndexedKeyframe{}
		if offsets := object['offsets'] {
			if offsets is []json2.Any {
				for offset in offsets { indexed.offsets << compact_web_animation_number(offset) }
			}
		}
		if easings := object['easings'] {
			if easings is []json2.Any {
				for easing in easings { indexed.easings << easing.str() }
			}
		}
		if composites := object['composites'] {
			if composites is []json2.Any {
				for composite in composites { indexed.composites << compact_web_animation_composite_or_auto(composite.str())! }
			}
		}
		if properties := object['properties'] {
			if properties is map[string]json2.Any {
				for name, values in properties {
					mut list := []string{}
					if values is []json2.Any {
						for item in values { list << item.str() }
					}
					indexed.properties[name] = list
				}
			}
		}
		return animations.process_property_indexed_keyframes(indexed) or { return error('TypeError: ${err.msg()}') }
	}
	mut keyframes := []animations.BaseKeyframe{}
	if value is []json2.Any {
		for item in value {
			if item !is map[string]json2.Any { continue }
			frame := item as map[string]json2.Any
			mut keyframe := animations.BaseKeyframe{}
			if offset := frame['offset'] { keyframe.offset = compact_web_animation_number(offset) }
			if easing := json_string_property(frame, 'easing') { keyframe.easing = easing }
			if composite := json_string_property(frame, 'composite') {
				keyframe.composite = compact_web_animation_composite_or_auto(composite)!
			}
			if properties := frame['properties'] {
				if properties is map[string]json2.Any {
					for name, property in properties { keyframe.properties[name] = property.str() }
				}
			}
			keyframes << keyframe
		}
	}
	return keyframes
}

fn compact_web_animation_options(value json2.Any) !animations.KeyframeAnimationOptions {
	mut options := animations.KeyframeAnimationOptions{}
	if value !is map[string]json2.Any { return options }
	object := value as map[string]json2.Any
	mut timing := animations.OptionalEffectTiming{}
	if duration := object['duration'] {
		if number := compact_web_animation_number(duration) {
			timing.duration = animations.IterationDuration(number)
		} else if duration is string {
			timing.duration = animations.IterationDuration(duration)
		}
	}
	if delay := object['delay'] { timing.delay = compact_web_animation_number(delay) }
	if end_delay := object['endDelay'] { timing.end_delay = compact_web_animation_number(end_delay) }
	if iterations := object['iterations'] { timing.iterations = compact_web_animation_number(iterations) }
	if iteration_start := object['iterationStart'] { timing.iteration_start = compact_web_animation_number(iteration_start) }
	if easing := json_string_property(object, 'easing') { timing.easing = easing }
	if fill := json_string_property(object, 'fill') {
		timing.fill = match fill {
			'none' { animations.FillMode.none_ }
			'forwards' { animations.FillMode.forwards }
			'backwards' { animations.FillMode.backwards }
			'both' { animations.FillMode.both }
			'auto' { animations.FillMode.auto_ }
			else { return error('TypeError: Invalid fill mode') }
		}
	}
	if direction := json_string_property(object, 'direction') {
		timing.direction = match direction {
			'normal' { animations.PlaybackDirection.normal }
			'reverse' { animations.PlaybackDirection.reverse }
			'alternate' { animations.PlaybackDirection.alternate }
			'alternate-reverse' { animations.PlaybackDirection.alternate_reverse }
			else { return error('TypeError: Invalid playback direction') }
		}
	}
	options.timing = timing
	if composite := json_string_property(object, 'composite') {
		options.composite = match composite {
			'replace' { animations.CompositeOperation.replace }
			'add' { animations.CompositeOperation.add }
			'accumulate' { animations.CompositeOperation.accumulate }
			else { return error('TypeError: Invalid composite operation') }
		}
	}
	if pseudo := json_string_property(object, 'pseudoElement') { options.pseudo_element = pseudo }
	if id := json_string_property(object, 'id') { options.id = id }
	return options
}

fn compact_web_animation_time(value animations.NullableCSSNumberish) json2.Any {
	numberish := value.value or { return json2.Any(json2.Null{}) }
	return match numberish {
		f64 { json2.Any(numberish) }
		animations.PercentageValue { json2.Any(json2.Null{}) }
	}
}

fn compact_web_animation_state(key string, animation &animations.Animation) json2.Any {
	return json2.Any({
		'key':          json2.Any(key)
		'currentTime':  compact_web_animation_time(animation.current_time_for_bindings())
		'startTime':    compact_web_animation_time(animation.start_time_for_bindings())
		'playState':    json2.Any(animation.play_state_for_bindings().str())
		'pending':      json2.Any(animation.pending_for_bindings())
		'playbackRate': json2.Any(animation.playback_rate())
		'replaceState': json2.Any(animation.replace_state().str())
		'id':           json2.Any(animation.id())
	})
}

// Animation state changes must be visible to the next style read.
fn compact_web_animation_refresh(mut animation animations.Animation, document &dom.Document) {
	animation.update()
	mut owner := unsafe { &dom.Document(document) }
	owner.needs_animated_style_update = true
	owner.update_animated_style_if_needed()
}

fn (mut binding CompactElementQueryBinding) web_animation_query(key string, source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	op := json_string_property(request, 'op') or { return error('Invalid animation operation') }
	if op == 'animate' {
		node := binding.node_for_key(key) or { return error('TypeError: Invalid Element receiver') }
		element := node.as_element() or { return error('TypeError: Invalid Element receiver') }
		keyframes := compact_web_animation_keyframes(request['keyframes'] or { json2.Any([]json2.Any{}) })!
		options := compact_web_animation_options(request['options'] or { json2.Any(json2.Null{}) })!
		mut animatable := animations.Animatable.new(element)
		mut animation := animatable.animate(keyframes, options) or {
			message := err.msg()
			return error(if message.starts_with('TypeError:') || message.starts_with('SyntaxError:') { message } else { 'TypeError: ${message}' })
		}
		binding.next_key++
		animation_key := '__animation_${binding.next_key}'
		binding.web_animations[animation_key] = voidptr(animation)
		compact_web_animation_refresh(mut animation, element.document())
		return json2.encode(compact_web_animation_state(animation_key, animation))
	}
	if op == 'documentList' {
		// https://drafts.csswg.org/web-animations-1/#dom-documentorshadowroot-getanimations
		mut items := []json2.Any{}
		for record in css.document_css_animations(binding.document) {
			items << json2.Any({
				'css':           json2.Any(true)
				'transition':    json2.Any(record.is_transition)
				'key':           json2.Any('__css_${u64(record.handle):x}')
				'name':          json2.Any(record.name)
				'pseudoElement': json2.Any(record.pseudo_element)
				'playState':     json2.Any(record.play_state)
				'target':        binding.element_state(record.element)
			})
		}
		for animation_key, handle in binding.web_animations {
			animation := unsafe { &animations.Animation(handle) }
			if animation.is_relevant() {
				items << compact_web_animation_state(animation_key, animation)
			}
		}
		return json2.encode(items)
	}
	if op == 'list' {
		node := binding.node_for_key(key) or { return error('TypeError: Invalid Element receiver') }
		element := node.as_element() or { return error('TypeError: Invalid Element receiver') }
		mut states := []json2.Any{}
		if element.animations_animatable_handle_ != unsafe { nil } {
			mut animatable := unsafe { &animations.Animatable(element.animations_animatable_handle_) }
			for animation in animatable.get_animations(animations.GetAnimationsOptions{})! {
				for animation_key, handle in binding.web_animations {
					if handle == voidptr(animation) { states << compact_web_animation_state(animation_key, animation) }
				}
			}
		}
		return json2.encode(states)
	}
	animation_key := json_string_property(request, 'animation') or { return error('TypeError: Illegal Animation receiver') }
	handle := binding.web_animations[animation_key] or { return error('TypeError: Illegal Animation receiver') }
	mut animation := unsafe { &animations.Animation(handle) }
	document := binding.document
	value := request['value'] or { json2.Any(json2.Null{}) }
	match op {
		'state' {}
		'play' { animation.play()! }
		'pause' { animation.pause()! }
		'cancel' { animation.cancel() }
		'finish' { animation.finish()! }
		'reverse' { animation.reverse()! }
		'persist' { animation.persist() }
		'updatePlaybackRate' { animation.update_playback_rate(compact_web_animation_number(value) or { 0 })! }
		'setPlaybackRate' { animation.set_playback_rate(compact_web_animation_number(value) or { 0 })! }
		'setId' { animation.set_id(value.str()) }
		'setCurrentTime' {
			if number := compact_web_animation_number(value) {
				animation.set_current_time_for_bindings(animations.CSSNumberish(number))!
			} else {
				animation.set_current_time_for_bindings(none)!
			}
		}
		'setStartTime' {
			if number := compact_web_animation_number(value) {
				animation.set_start_time_for_bindings(animations.CSSNumberish(number))!
			} else {
				animation.set_start_time_for_bindings(none)!
			}
		}
		else { return error('Invalid animation operation') }
	}
	if op != 'state' { compact_web_animation_refresh(mut animation, document) }
	return json2.encode(compact_web_animation_state(animation_key, animation))
}

fn compact_web_animations_bootstrap() string {
	return r'
(function(){
 const records=new WeakMap(),wrappers=new Map(),get=WeakMap.prototype.get,set=WeakMap.prototype.set;
 const isObject=value=>value!==null&&(typeof value==="object"||typeof value==="function");
 const string=value=>{if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);};
 function call(key,request){
  try{return __queryElements(key,"webAnimation",JSON.stringify(request),true);}
  catch(error){
   const match=/^(TypeError|SyntaxError|InvalidStateError|NotSupportedError|AbortError):\s*(.*)/.exec(String(error.message));
   if(!match)throw error;
   if(match[1]==="TypeError")throw new TypeError(match[2]);
   throw new DOMException(match[2],match[1]);
  }
 }
 function keyframes(value){
  if(value===null||value===undefined)return [];
  if(!isObject(value))throw new TypeError("Keyframes must be an object");
  const iterator=value[Symbol.iterator];
  if(iterator!==undefined&&iterator!==null){
   if(typeof iterator!=="function")throw new TypeError("Keyframes iterator must be callable");
   const frames=[];
   for(const item of value){
    if(item!==null&&item!==undefined&&!isObject(item))throw new TypeError("Each keyframe must be an object");
    const frame={properties:{}};
    if(item){
     if(item.offset!==undefined&&item.offset!==null){const offset=Number(item.offset);if(!isFinite(offset))throw new TypeError("Keyframe offsets must be finite");frame.offset=offset;}
     if(item.easing!==undefined)frame.easing=string(item.easing);
     if(item.composite!==undefined)frame.composite=string(item.composite);
     for(const name of Object.keys(item))if(name!=="offset"&&name!=="easing"&&name!=="composite"&&item[name]!==undefined)frame.properties[name]=string(item[name]);
    }
    frames.push(frame);
   }
   return frames;
  }
  const list=value=>value===undefined?[]:Array.isArray(value)?value:[value];
  const indexed={offsets:list(value.offset).map(offset=>offset===null?null:Number(offset)),easings:list(value.easing).map(string),composites:list(value.composite).map(string),properties:{}};
  for(const name of Object.keys(value))if(name!=="offset"&&name!=="easing"&&name!=="composite"&&value[name]!==undefined)indexed.properties[name]=list(value[name]).map(string);
  return indexed;
 }
 function options(value){
  if(value===undefined||value===null)return {};
  if(!isObject(value)){const duration=Number(value);if(isNaN(duration)||duration<0)throw new TypeError("Animation duration must be a non-negative number");return {duration};}
  const result={};
  for(const name of ["composite","direction","easing","fill","id","pseudoElement"])if(value[name]!==undefined)result[name]=string(value[name]);
  for(const name of ["delay","endDelay","iterationStart","iterations"])if(value[name]!==undefined){const number=Number(value[name]);if(isNaN(number))throw new TypeError(name+" must be a number");result[name]=number;}
  if(value.duration!==undefined){
   if(typeof value.duration==="string")result.duration=value.duration;
   else{const duration=Number(value.duration);if(isNaN(duration)||duration<0)throw new TypeError("Animation duration must be a non-negative number");result.duration=duration;}
  }
  if(result.iterations!==undefined&&(result.iterations<0))throw new TypeError("iterations must not be negative");
  return result;
 }
 function Animation(){throw new TypeError("Illegal Animation constructor");}
 function KeyframeEffect(){throw new TypeError("Illegal KeyframeEffect constructor");}
 Object.setPrototypeOf(Animation.prototype,EventTarget.prototype);
 function record(receiver){const own=__elementApply(get,records,[receiver]);if(!own)throw new TypeError("Illegal Animation receiver");return own;}
 function wrap(state,target){
  let object=wrappers.get(state.key);
  if(!object){
   object=Object.create(Animation.prototype);
   const effect=Object.create(KeyframeEffect.prototype);
   Object.defineProperty(effect,"target",{value:target,enumerable:true});
   __elementApply(set,records,[object,{key:state.key,target,owner:target.__state?target.__state.bridgeKey:"",effect,state,finished:null}]);
   wrappers.set(state.key,object);
  }
  record(object).state=state;
  return object;
 }
 function operate(receiver,op,value){const own=record(receiver);own.state=call(own.owner,{op,animation:own.key,value});settle(receiver);return own.state;}
 function state(receiver){return operate(receiver,"state");}
 // finished settles when the native play state reaches finished, or rejects
 // with an AbortError when the animation is cancelled while pending.
 function settle(receiver){
  const own=record(receiver),promise=own.finished;
  if(!promise)return;
  if(own.state.playState==="finished"){own.finished=null;promise.resolve(receiver);}
  else if(own.state.playState==="idle"){own.finished=null;promise.reject(new DOMException("The animation was cancelled","AbortError"));}
 }
 function watch(receiver){
  const own=record(receiver);if(!own.finished)return;
  const step=()=>{if(!own.finished)return;state(receiver);if(own.finished)(typeof requestAnimationFrame==="function"?requestAnimationFrame:setTimeout)(step,16);};
  (typeof requestAnimationFrame==="function"?requestAnimationFrame:setTimeout)(step,16);
 }
 const methods={
  play(){operate(this,"play");},pause(){operate(this,"pause");},cancel(){operate(this,"cancel");},
  finish(){operate(this,"finish");},reverse(){operate(this,"reverse");},persist(){operate(this,"persist");},
  updatePlaybackRate(rate){operate(this,"updatePlaybackRate",Number(rate));},commitStyles(){record(this);}
 };
 for(const [name,value] of Object.entries(methods))Object.defineProperty(Animation.prototype,name,{value,writable:true,enumerable:true,configurable:true});
 const time=value=>{if(value===null)return null;const number=Number(value);if(!isFinite(number))throw new TypeError("Animation times must be finite");return number;};
 Object.defineProperties(Animation.prototype,{
  currentTime:{get(){return state(this).currentTime;},set(value){operate(this,"setCurrentTime",time(value));},enumerable:true,configurable:true},
  startTime:{get(){return state(this).startTime;},set(value){operate(this,"setStartTime",time(value));},enumerable:true,configurable:true},
  playbackRate:{get(){return state(this).playbackRate;},set(value){operate(this,"setPlaybackRate",Number(value));},enumerable:true,configurable:true},
  id:{get(){return state(this).id;},set(value){operate(this,"setId",string(value));},enumerable:true,configurable:true},
  playState:{get(){return state(this).playState;},enumerable:true,configurable:true},
  replaceState:{get(){return state(this).replaceState;},enumerable:true,configurable:true},
  pending:{get(){return state(this).pending;},enumerable:true,configurable:true},
  effect:{get(){return record(this).effect;},enumerable:true,configurable:true},
  timeline:{get(){record(this);return document.timeline||null;},enumerable:true,configurable:true},
  ready:{get(){record(this);return Promise.resolve(this);},enumerable:true,configurable:true},
  finished:{get(){
   const own=record(this);
   if(!own.finishedPromise||own.finishedSettled){
    let resolve,reject;const promise=new Promise((yes,no)=>{resolve=yes;reject=no;});
    own.finishedPromise=promise;own.finishedSettled=false;
    own.finished={resolve:value=>{own.finishedSettled=true;resolve(value);},reject:error=>{own.finishedSettled=true;promise.catch(()=>{});reject(error);}};
    settle(this);watch(this);
   }
   return own.finishedPromise;
  },enumerable:true,configurable:true}
 });
 for(const name of ["onfinish","oncancel","onremove"])Object.defineProperty(Animation.prototype,name,{get(){return record(this)[name]||null;},set(value){record(this)[name]=typeof value==="function"?value:null;},enumerable:true,configurable:true});
 for(const [constructor,name] of [[Animation,"Animation"],[KeyframeEffect,"KeyframeEffect"]]){
  Object.defineProperty(constructor,"prototype",{writable:false});
  Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
  Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
 }
 Object.defineProperty(Element.prototype,"animate",{value:function animate(frames,settings){
  const target=__elementApply(__elementRecordGet,__elementRecords,[this]);
  if(!target)throw new TypeError("Illegal Element receiver");
  const created=call(target.bridgeKey,{op:"animate",keyframes:keyframes(frames),options:options(settings)});
  return wrap(created,this);
 },writable:true,enumerable:true,configurable:true});
 // CSS transitions and animations keep one wrapper per native animation.
 function CSSTransition(){throw new TypeError("Illegal CSSTransition constructor");}
 function CSSAnimation(){throw new TypeError("Illegal CSSAnimation constructor");}
 const cssWrappers=new Map(),cssStates=new WeakMap();
 function cssState(receiver){const own=__elementApply(get,cssStates,[receiver]);if(!own)throw new TypeError("Illegal "+(receiver instanceof CSSTransition?"CSSTransition":"CSSAnimation")+" receiver");return own;}
 for(const [constructor,name,member] of [[CSSTransition,"CSSTransition","transitionProperty"],[CSSAnimation,"CSSAnimation","animationName"]]){
  Object.setPrototypeOf(constructor.prototype,Animation.prototype);
  Object.setPrototypeOf(constructor,Animation);
  Object.defineProperty(constructor.prototype,member,{get(){return cssState(this).name;},enumerable:true,configurable:true});
  Object.defineProperties(constructor.prototype,{
   playState:{get(){return cssState(this).playState;},enumerable:true,configurable:true},
   effect:{get(){return cssState(this).effect;},enumerable:true,configurable:true},
   pending:{get(){cssState(this);return false;},enumerable:true,configurable:true},
   id:{get(){cssState(this);return "";},set(value){},enumerable:true,configurable:true}
  });
  Object.defineProperty(constructor,"prototype",{writable:false});
  Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
  Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
 }
 function cssWrap(item){
  let object=cssWrappers.get(item.key),own=object&&cssStates.get(object);
  if(!object){
   object=Object.create((item.transition?CSSTransition:CSSAnimation).prototype);
   const effect=Object.create(KeyframeEffect.prototype);
   Object.defineProperty(effect,"target",{value:__queryElement(item.target),enumerable:true});
   Object.defineProperty(effect,"pseudoElement",{value:item.pseudoElement||null,enumerable:true});
   own={effect};
   __elementApply(set,cssStates,[object,own]);
   cssWrappers.set(item.key,object);
  }
  own.name=item.name;own.playState=item.playState;
  return object;
 }
 function documentAnimations(){
  return call("",{op:"documentList"}).map(item=>item.css?cssWrap(item):wrappers.get(item.key)).filter(Boolean);
 }
 function getAnimations(options){
  if(this===document||(typeof Document==="function"&&this instanceof Document))return documentAnimations();
  const target=__elementApply(__elementRecordGet,__elementRecords,[this]);
  if(!target)throw new TypeError("Illegal Element receiver");
  const subtree=!!(options&&options.subtree);
  const css=documentAnimations().filter(animation=>{
   if(!(animation instanceof CSSTransition||animation instanceof CSSAnimation))return false;
   const effect=animation.effect,owner=effect.target;
   if(owner===this)return subtree||effect.pseudoElement===null;
   return subtree&&owner!==null&&typeof this.contains==="function"&&this.contains(owner);
  });
  return css.concat(call(target.bridgeKey,{op:"list"}).map(item=>wrap(item,this)));
 }
 Object.defineProperty(Element.prototype,"getAnimations",{value:getAnimations,writable:true,enumerable:true,configurable:true});
 Object.defineProperty(document,"getAnimations",{value:getAnimations,writable:true,enumerable:false,configurable:true});
 if(typeof Document==="function"&&Document.prototype&&Document.prototype!==Object.prototype)Object.defineProperty(Document.prototype,"getAnimations",{value:getAnimations,writable:true,enumerable:true,configurable:true});
})();
'
}
