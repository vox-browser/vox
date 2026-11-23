@[has_globals]
module dom

import sync.stdatomic

const canvas_bitmap_dirty_revision = u64(1)

__global canvas_bitmap_revisions stdatomic.AtomicVal[u64]

// Canvas owners mark pixel writes, including changes to retained bitmaps.
// Zero is reserved for bitmaps without tracked writes.
pub fn (mut bitmap Bitmap_) canvas_pixels_changed() {
	bitmap.canvas_upload_revision_ = canvas_bitmap_dirty_revision
}

// Allocate a process-wide revision only when dirty pixels reach replay.
// Texture slots can outlive the bitmap or document that last occupied them.
pub fn (bitmap &Bitmap_) canvas_upload_revision() u64 {
	if bitmap.canvas_upload_revision_ != canvas_bitmap_dirty_revision {
		return bitmap.canvas_upload_revision_
	}
	mut mutable_bitmap := unsafe { &Bitmap_(bitmap) }
	for {
		previous := canvas_bitmap_revisions.load()
		if previous == u64(0xfffffffffffffffe) {
			mutable_bitmap.canvas_upload_revision_ = 0
			return 0
		}
		if canvas_bitmap_revisions.compare_and_swap(previous, previous + 1) {
			mutable_bitmap.canvas_upload_revision_ = previous + 2
			return previous + 2
		}
	}
	return 0
}
