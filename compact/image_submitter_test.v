module main

import browserjs
import dom
import html
import layout

fn test_image_submitter_click_coordinates_use_native_content_geometry_without_changing_trust() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#image{position:absolute;left:31px;top:47px;width:200px;height:100px;border:3px solid black;padding:5px;transform-origin:0 0}</style><form id="form"><input id="image" type="image" name="point"></form>')
	document.set_viewport_rect(dom.Rect{ width: 800, height: 600 })
	document.set_layout_coordinate_scale(2)
	_ = layout.run_document_layout(document, 800, 600)?
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const image=document.getElementById("image"),form=document.getElementById("form");
form.addEventListener("submit",event=>event.preventDefault());
function selected(){const data=new FormData(form,image);return [data.get("point.x"),data.get("point.y")].join(",")}
function check(expected){const actual=selected();if(actual!==expected)throw new Error(actual+" != "+expected)}
image.click();check("0,0");
let trusted;image.addEventListener("click",event=>{trusted=event.isTrusted});
image.dispatchEvent(new MouseEvent("click",{clientX:62,clientY:101}));check("23,46");
if(trusted!==false)throw new Error("constructed event gained trust");
image.click();check("23,46");
image.dispatchEvent(new MouseEvent("click",{clientX:37,clientY:53}));check("-2,-2");
image.style.transform="translate(10px,20px) scale(2)";
image.dispatchEvent(new MouseEvent("click",{clientX:103,clientY:175}));check("23,46");
image.disabled=true;image.dispatchEvent(new MouseEvent("click",{clientX:10,clientY:10}));image.disabled=false;check("23,46");
console.log("image submitter coordinates passed");'], runtime, mut messages)
	assert messages == ['image submitter coordinates passed']
}
