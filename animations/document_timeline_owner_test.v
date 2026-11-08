module animations

import dom

fn test_default_animation_timeline_belongs_to_its_document_storage() {
	for _ in 0 .. 12 {
		mut document := dom.Document.create(dom.URL{value: 'https://animation-owner.test/'})
		document.enable_native_storage()
		mut scope := document.enter_native_storage()
		first := document.create_element('div')!
		second := document.create_element('div')!
		mut first_target := Animatable.new(first)
		mut second_target := Animatable.new(second)
		first_animation := first_target.animate_with_duration([]BaseKeyframe{}, 100)!
		second_animation := second_target.animate_with_duration([]BaseKeyframe{}, 100)!
		first_timeline := first_animation.timeline_ or { panic('first timeline') }
		second_timeline := second_animation.timeline_ or { panic('second timeline') }
		assert voidptr(first_timeline) == voidptr(second_timeline)
		owner := first_timeline.associated_document() or { panic('timeline document') }
		assert voidptr(owner) == voidptr(document)
		document.finalize()
		scope.finish()
		document.release_native_storage()
	}
}
