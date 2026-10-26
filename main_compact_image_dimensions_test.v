module main

import browserjs
import dom
import html
import layout

fn test_compact_image_dimensions_use_live_css_content_size_for_backdrop_canvases() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#photo{width:125.75px;height:73.875px;padding:7px;border:3px solid;transform:scale(1.5)}</style><img id="photo" width="640" height="480">')
	document.set_viewport_rect(dom.Rect{ width: 320, height: 240 })
	document.set_layout_coordinate_scale(2)
	_ = layout.run_document_layout(document, 320, 240) or { panic('missing initial layout') }
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const photo=document.getElementById("photo");
if(photo.width!==125||photo.height!==73)throw new Error("image content size excludes edges and transform: "+photo.width+"x"+photo.height);
const backdrop=document.createElement("canvas");
if(backdrop.width!==300||backdrop.height!==150)throw new Error("canvas defaults");
backdrop.width=photo.width;backdrop.height=photo.height;
if(backdrop.width!==125||backdrop.height!==73)throw new Error("backdrop dimensions");
photo.style.width="211.5px";photo.style.height="93.25px";
if(photo.width!==211||photo.height!==93)throw new Error("pending image style update");
photo.style.boxSizing="border-box";photo.style.width="231.5px";photo.style.height="113.25px";
if(photo.width!==211||photo.height!==93)throw new Error("border-box image content size");
photo.style.display="none";
if(photo.width!==640||photo.height!==480)throw new Error("unrendered image attributes");
photo.width=23;photo.height=31;
if(photo.width!==23||photo.height!==31||photo.getAttribute("width")!=="23"||photo.getAttribute("height")!=="31")throw new Error("image dimension reflection");
photo.removeAttribute("width");photo.removeAttribute("height");
if(photo.width!==0||photo.height!==0)throw new Error("unrendered image without dimensions");
console.log("image content dimensions passed");
'], runtime, mut messages)
	assert messages == ['image content dimensions passed']
}

fn test_compact_created_image_dimensions_follow_insertion_and_style_mutations() {
	mut document := html.parse_document('<!doctype html><style>#host img{width:62.5px;height:41.5px}</style><div id="host"></div>')
	document.set_viewport_rect(dom.Rect{ width: 320, height: 240 })
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const image=new Image();
if(image.width!==0||image.height!==0)throw new Error("detached image defaults");
image.width=17;image.height=29;
if(image.width!==17||image.height!==29)throw new Error("detached image attributes");
host.appendChild(image);
if(image.width!==62||image.height!==41)throw new Error("inserted image dimensions");
image.style.width="80px";image.style.height="48px";
if(image.width!==80||image.height!==48)throw new Error("created image style update");
image.remove();
if(image.width!==17||image.height!==29)throw new Error("removed image attributes");
console.log("created image dimensions passed");
'], runtime, mut messages)
	assert messages == ['created image dimensions passed']
}
