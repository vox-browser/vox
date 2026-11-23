@[has_globals]
module dom

import sync.stdatomic

const bitmap_dirty_revision = u64(1)

__global bitmap_upload_revisions stdatomic.AtomicVal[u64]

// Mark new or changed pixels for texture upload. Zero is reserved for
// bitmaps whose pixels are not tracked for reuse.
pub fn (mut bitmap Bitmap_) mark_pixels_changed() {
	bitmap.upload_revision_ = bitmap_dirty_revision
}

// Allocate a process-wide revision only when dirty pixels reach replay.
// Texture slots can outlive the bitmap or document that last occupied them.
pub fn (bitmap &Bitmap_) upload_revision() u64 {
	if bitmap.upload_revision_ != bitmap_dirty_revision {
		return bitmap.upload_revision_
	}
	mut mutable_bitmap := unsafe { &Bitmap_(bitmap) }
	for {
		previous := bitmap_upload_revisions.load()
		if previous == u64(0xfffffffffffffffe) {
			mutable_bitmap.upload_revision_ = 0
			return 0
		}
		if bitmap_upload_revisions.compare_and_swap(previous, previous + 1) {
			mutable_bitmap.upload_revision_ = previous + 2
			return previous + 2
		}
	}
	return 0
}
