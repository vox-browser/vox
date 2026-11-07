module main

import dom
import html

// HTMLSelectElement.selectedIndex for a script. Like compact_select_value(), a
// single-line select without a selected option reports the option the
// selectedness setting algorithm would select, without changing the document.
fn compact_select_selected_index(select_element &dom.HTMLSelectElement) i32 {
	selected := html.html_select_element_selected_index(select_element)
	element := unsafe { &dom.Element(select_element) }
	if selected >= 0 || element.has_attribute('multiple')
		|| html.html_select_element_display_size(select_element) != 1 {
		return selected
	}
	for index, option in html.html_select_element_list_of_options(select_element) {
		if !html.html_option_element_disabled(option) {
			return i32(index)
		}
	}
	return -1
}

// HTMLSelectElement.selectedIndex and options on compact select facades. The
// live select's options own the selection; 4chan's catalog shows its saved
// settings by assigning selectedIndex.
fn compact_select_bootstrap() string {
	return r'
function __compactSelect(o,s){
 Object.defineProperty(o,"value",{configurable:true,enumerable:true,get:function(){
  return __queryElements(s.bridgeKey,"selectValue","");
 },set:function(value){
  if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
  __queryElements(s.bridgeKey,"setSelectValue",String(value));
 }});
 Object.defineProperty(o,"selectedIndex",{configurable:true,enumerable:true,get:function(){
  if(s.created&&!s.parentKey)return -1;
  return __queryElements(s.bridgeKey,"selectedIndex","");
 },set:function(value){
  if(s.created&&!s.parentKey)return;
  __queryElements(s.bridgeKey,"setSelectedIndex",String(value|0));
 }});
 let options=null;
 Object.defineProperty(o,"options",{configurable:true,enumerable:true,get:function(){
  if(!options)options=__classCollection(s.bridgeKey,"",function(){
   if(s.created&&!s.parentKey)return [];
   return __queryElements(s.bridgeKey,"querySelectorAll","option");
  });
  return options;
 }});
}
// HTMLOptionElement.selected sets the option selectedness and runs the
// selectedness algorithm of its select; jQuery val() on a select assigns it on
// every option. A detached script-created option keeps a local value.
const __detachedOptionSelected=new WeakMap();
function __compactOption(o,s){
 Object.defineProperty(o,"selected",{configurable:true,enumerable:true,get:function(){
  if(s.created&&!s.parentKey)return __detachedOptionSelected.get(s)===true;
  return __queryElements(s.bridgeKey,"optionSelected","",true);
 },set:function(value){
  if(s.created&&!s.parentKey){__detachedOptionSelected.set(s,!!value);return;}
  __queryElements(s.bridgeKey,"setOptionSelected",value?"true":"false",true);
 }});
}
'
}
