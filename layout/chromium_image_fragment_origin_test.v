module layout

import dom
import html
import painting

fn image_fragment_ancestor_adjustment(parent_style string, outer_style string) ?painting.Point {
 address := dom.URL{value:'https://image-fragment.test/'}
 mut document := html.parse_navigation_document('<!doctype html><style>
 html,body{margin:0}.outer{position:absolute;left:0;top:0;${outer_style}}
 .parent{position:absolute;left:13.375px;top:17.125px;${parent_style}}
 img{position:absolute;left:99.125px;top:58.375px;width:310.625px;height:310.625px;transform:rotate(7deg)}
 </style><div class="outer"><div class="parent"><img id="photo" src="image.png"></div></div>',
 address,address.origin(),none) or {panic(err)}
 defer {document.finalize()}
 document.set_font_rendering_policy(.chromium)
 element := document.get_element_by_id('photo') or {panic('image')}
 mut model := html.html_image_element_model_for_dom_element(unsafe {&dom.HTMLImageElement(element)})
 model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData {
  return html.BitmapDecodedImageData.create([html.BitmapDecodedImageFrame{
   frame:dom.DecodedImageFrame_.create(&dom.Bitmap_{width:500,height:500,pitch:2000,
    data:[]u8{len:1000000,init:255},native_resource_replay_compatible:true})
  }],0,false)
 })
 model.update_the_image_data(false,false)
 _ = layout_document_typed_in_viewport(document,1024,768)
 commands := display_list_commands(document.record_display_list() or {panic('paint')})
 for command in commands {
  if command.kind != 'draw_replaced_image' {continue}
  if command.local_image_data == unsafe {nil} {return none}
  return command.local_image_data.fragment_adjustment
 }
 panic('image paint')
}

fn test_image_fragment_resets_only_the_transform_scale_and_rotate_hints() {
 for hint in ['transform','scale','rotate'] {
  actual := image_fragment_ancestor_adjustment('will-change:${hint}','') or {panic('local image')}
  assert actual == painting.Point{-.375,-.125}
 }
 for hint in ['translate','opacity'] {
  actual := image_fragment_ancestor_adjustment('will-change:${hint}','') or {panic('local image')}
  assert actual == painting.Point{}
 }
}

fn test_image_fragment_resolves_nested_resets_and_suppressed_hints() {
 nested := image_fragment_ancestor_adjustment('will-change:transform;left:3.75px;top:5.5px',
  'will-change:transform;left:9.625px;top:11.625px') or {panic('nested image')}
 assert nested == painting.Point{.625,.875}
 suppressed := image_fragment_ancestor_adjustment('will-change:transform','will-change:contents') or {panic('local image')}
 assert suppressed == painting.Point{}
}

fn test_image_fragment_keeps_complex_ancestor_transforms_on_the_existing_path() {
 for transform in ['rotate(3deg)','scale(2)','translateZ(1px)'] {
  assert image_fragment_ancestor_adjustment('transform:${transform}','') == none
 }
 flat := image_fragment_ancestor_adjustment('transform:translate3d(0,0,0)','') or {panic('flat image')}
 assert flat == painting.Point{}
}
