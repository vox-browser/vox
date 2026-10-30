module layout

import encoding.base64
import html
import math
import painting

fn nested_svg_raster_test_path() PaintCommand {
	return PaintCommand{kind:'draw_svg_path', color:'black', width:24, height:24,
		svg_data:&PaintSVGPathData{path_data:[f32(0),2,2,0,0,0,0,0,0,0,0,0]}}
}

fn nested_svg_raster_test_resource() PaintCommand {
	path := nested_svg_raster_test_path()
	mask := PaintClip{is_svg_content_mask:true, scope_id:7, cache_key:17,
		rect:LayoutRect{width:24,height:24}, mask_luminance:true,
		mask_operations:[PaintMaskOperation{kind:.path, has_fill:true, fill_color:'white',
			path_data:path.svg_data.path_data}]}
	layer := &PaintVisualLayer{kind:.svg_mask, scope_id:7, mask_clip:mask}
	return PaintCommand{kind:'paint_nested_display_list', width:24, height:24,
		nested_viewport_paintable:&painting.NavigableContainerViewportPaintable{
			viewport_rect:painting.Rect{width:24,height:24}},
		nested_viewport_commands:[path,
			PaintCommand{kind:'begin_svg_mask_layer', visual_layer_data:layer}, path,
			PaintCommand{kind:'end_svg_mask_layer', visual_layer_data:layer}]}
}

fn test_nested_svg_vector_masks_keep_the_opacity_group_in_the_parent_scroll_raster() {
	image := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><defs><mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24"><rect width="24" height="24" fill="white"/><path d="M8 8H16V16H8Z" fill="black"/></mask></defs><path d="M2 2H22V22H2Z" fill="blue" mask="url(#m)"/></svg>'
	mut document := html.parse_document('<!doctype html><style>body{margin:0;background:white}
		#scroll{width:164px;height:600px;overflow:auto}#content{position:relative;height:2000px}
		svg{position:absolute;left:8px;top:88px}span{position:absolute;left:34px;top:88px}
		img{position:absolute;left:34px;top:190px}</style><div id="scroll"><div id="content">
		<svg width="18" height="18"><path d="M1 2h12l4 4v9H1z"/>
		<g opacity=".4"><path d="M2 3h12v9H2z"/></g></svg><span>Tags</span>
		<img width="24" height="24" src="data:image/svg+xml;base64,${base64.encode_str(image)}"></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document,800,600)
	commands := display_list_commands(document.record_display_list() or { panic('missing nested paint') })
	plan := chromium_raster_layer_plan(document,commands,1)
	mut owner := -1
	mut resources := 0
	for index, command in commands {
		if command.kind == 'draw_text' && command.text == 'Tags' { owner=plan.command_layers[index] }
		if command.kind == 'paint_nested_display_list' {
			resources++
			assert chromium_nested_svg_raster_supported(&command), command.nested_viewport_commands.map(it.kind).join(',')
		}
	}
	assert resources == 1 && owner > 0
	for index, command in commands {
		if command.kind in ['begin_css_effect_layer','end_css_effect_layer','paint_nested_display_list'] {
			assert plan.command_layers[index] == owner
		}
	}
	assert plan.layers[owner].scroll_contents && !plan.layers[owner].legacy_raster
}

fn test_nested_svg_raster_rejects_external_resources_and_unmatched_masks() {
	resource := nested_svg_raster_test_resource()
	assert chromium_nested_svg_raster_supported(&resource)
	for replacement in [PaintCommand{kind:'draw_text',text:'HTML'},
		PaintCommand{kind:'draw_replaced_image'}, PaintCommand{kind:'begin_css_filter_layer'},
		PaintCommand{kind:'paint_nested_display_list'}] {
		mut children := resource.nested_viewport_commands.clone()
		children[0] = replacement
		changed := PaintCommand{...resource,nested_viewport_commands:children}
		assert !chromium_nested_svg_raster_supported(&changed)
	}
	for count in [1,2,3] {
		changed := PaintCommand{...resource,nested_viewport_commands:resource.nested_viewport_commands[..count]}
		if count == 1 { assert chromium_nested_svg_raster_supported(&changed) }
		else { assert !chromium_nested_svg_raster_supported(&changed) }
	}
	mut children := resource.nested_viewport_commands.clone()
	layer := children[3].visual_layer_data or { panic('missing mask') }
	children[3] = PaintCommand{kind:'end_svg_mask_layer',visual_layer_data:&PaintVisualLayer{
		...*layer,mask_clip:PaintClip{...layer.mask_clip,cache_key:18}}}
	changed := PaintCommand{...resource,nested_viewport_commands:children}
	assert !chromium_nested_svg_raster_supported(&changed)
}

fn test_nested_svg_raster_rejects_image_masks_and_nonfinite_transforms() {
	resource := nested_svg_raster_test_resource()
	layer := resource.nested_viewport_commands[1].visual_layer_data or { panic('missing mask') }
	for operation in [PaintMaskOperation{kind:.image,has_fill:true},
		PaintMaskOperation{kind:.begin_opacity,opacity:.4}] {
		mut children := resource.nested_viewport_commands.clone()
		children[1] = PaintCommand{kind:'begin_svg_mask_layer',visual_layer_data:&PaintVisualLayer{
			...*layer,mask_clip:PaintClip{...layer.mask_clip,mask_operations:[operation]}}}
		changed := PaintCommand{...resource,nested_viewport_commands:children}
		assert !chromium_nested_svg_raster_supported(&changed)
	}
	changed := PaintCommand{...resource,transform:[f64(1),0,0,1,math.inf(1),0]!}
	assert !chromium_nested_svg_raster_supported(&changed)
}
