module css

import dom
import platform

fn test_retired_animation_target_lists_transfer_their_original_backing_storage() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.oldest_live_paint_scene_generation = 2
	mut storage := AnimationSampleStorage{}
	mut targets := []AnimationSampleTarget{cap:1024}
	backing := targets.data
	capacity := targets.cap
	for _ in 0 .. 32 {
		storage.retiring << RetiringAnimationSamples{
			arena: platform.new_arena('animation target storage test')
			targets: targets
			holders_cleared: true
		}
		storage.retire_unreachable(document)
		assert storage.retiring.len == 0
		assert storage.spare_target_lists.len == 1
		assert storage.spare_target_lists[0].items.data == backing
		assert storage.spare_target_lists[0].items.cap == capacity
		targets = storage.spare_target_lists.pop().items
	}
	storage.dispose()
	document.finalize()
}
