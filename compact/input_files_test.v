module main

import browserjs
import dom
import html
import page

fn test_compact_input_files_uses_native_lists_and_updates_the_file_value_synchronously() {
	url := dom.URL{value: 'https://input-files.test/'}
	owner := page.Page.create(1)!
	mut document := html.create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.enable_native_storage()
	mut allocation := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><body><input id="upload" type="file"><input id="plain"><div id="container"></div></body>')
	allocation.finish()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, url.serialize(), [r'
const issues=[],check=(actual,expected)=>{if(actual!==expected)issues.push(JSON.stringify(actual)+" != "+JSON.stringify(expected))};
const descriptor=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,"files");
check(descriptor.get.name,"get files");check(descriptor.set.name,"set files");check(descriptor.enumerable,true);check(descriptor.configurable,true);
check(upload.files instanceof FileList,true);check(upload.files,upload.files);check(upload.files.length,0);check(plain.files,null);
const data=new DataTransfer(),file=new File(["payload"],"chosen.txt",{type:"text/plain"});data.items.add(file);
const selected=data.files;check(data.files,selected);
upload.files=selected;check(upload.files,selected);check(upload.files[0],selected[0]);check(upload.value,"C:\\fakepath\\chosen.txt");
upload.files=null;check(upload.files,selected);upload.files=undefined;check(upload.files,selected);
for(const invalid of [[],{},file]){let rejected=false;try{upload.files=invalid}catch(error){rejected=error instanceof TypeError}check(rejected,true);check(upload.files,selected)}
for(const receiver of [{},container,Object.create(HTMLInputElement.prototype),document.createElementNS("urn:custom","input")]){
 let rejected=false;try{descriptor.get.call(receiver)}catch(error){rejected=error instanceof TypeError}check(rejected,true);
}
const detached=document.createElement("input");detached.type="file";detached.files=selected;check(detached.value,"C:\\fakepath\\chosen.txt");container.appendChild(detached);check(detached.files,selected);check(detached.value,"C:\\fakepath\\chosen.txt");
upload.value="";check(upload.value,"");check(upload.files.length,0);check(detached.files.length,1);
data.items.add(new File(["second"],"second.txt"));check(data.files,selected);check(selected.length,2);check(detached.files,selected);check(detached.files.length,2);
data.items.remove(0);check(detached.files.length,1);check(detached.value,"C:\\fakepath\\second.txt");
data.items.clear();check(selected.length,0);check(detached.files.length,0);check(detached.value,"");
plain.files=data.files;check(plain.files,null);check(globalThis.__ladybirdInputFiles,undefined);
if(issues.length)throw new Error(issues.join(" | "));
console.log("native input files passed");
'], runtime, mut messages)
	assert messages == ['native input files passed'], messages.join('\n')
}
