module ui2

fn test_native_visual_reuse_keeps_all_display_inputs_and_excludes_editable_controls() {
	for kind in [Kind.view, .label, .button] {
		base := Element{kind:kind, text:'original', frame:Rect{1,2,30,20},
			text_style:TextStyle{size:13, color:0xff112233}, native_style:true}
		for changed in [
			Element{...base,text:'changed'},
			Element{...base,frame:Rect{2,2,30,20}},
			Element{...base,text_style:TextStyle{size:14,color:0xff112233}},
			Element{...base,text_style:TextStyle{size:13,color:0xff332211}},
			Element{...base,text_style:TextStyle{size:13,color:0xff112233,bold:true}},
			Element{...base,text_style:TextStyle{size:13,color:0xff112233,italic:true}},
			Element{...base,text_style:TextStyle{size:13,color:0xff112233,underline:true}},
			Element{...base,image_path:'replacement.png'},
			Element{...base,native_style:false},
			Element{...base,enabled:false},
		] {
			mut runtime := RuntimeState{}
			assert embedded_native_visual_changed(mut runtime,'control',base)
			assert !embedded_native_visual_changed(mut runtime,'control',base)
			assert embedded_native_visual_changed(mut runtime,'control',changed)
			assert !embedded_native_visual_changed(mut runtime,'control',changed)
			assert embedded_native_visual_changed(mut runtime,'new-key',changed)
		}
	}
	for kind in [Kind.text_field,.checkbox,.slider] {
		mut runtime := RuntimeState{}
		control := Element{kind:kind}
		assert embedded_native_visual_changed(mut runtime,'editable',control)
		assert embedded_native_visual_changed(mut runtime,'editable',control)
		assert runtime.node_visual_inputs.len == 0
	}
}

fn test_native_visual_reuse_leaves_action_and_common_state_to_reconciliation() {
	mut runtime := RuntimeState{}
	base := Element{kind:.button,text:'unchanged'}
	assert embedded_native_visual_changed(mut runtime,'button',base)
	assert !embedded_native_visual_changed(mut runtime,'button',
		Element{...base,action_id:'replacement-action',tooltip:'updated help'})
	runtime.node_visual_inputs.delete('button')
	assert embedded_native_visual_changed(mut runtime,'button',base)
}
