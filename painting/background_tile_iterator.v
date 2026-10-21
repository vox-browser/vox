module painting

// Synchronous consumers need no materialized tile vector. Each iterator owns
// only its cursor, so nested SVG replay cannot overwrite an outer traversal.
pub struct BackgroundTileIterator {
	plan          BackgroundTilePlan
	clip          Rect
	maximum_tiles int
mut:
	x         f64
	y         f64
	emitted   int
	exhausted bool
}

pub fn background_tile_iterator(plan BackgroundTilePlan, clip Rect,
	maximum_tiles int) BackgroundTileIterator {
	return BackgroundTileIterator{
		plan:          plan
		clip:          clip
		maximum_tiles: maximum_tiles
		x:             plan.first_tile.x
		y:             plan.first_tile.y
		exhausted:     plan.first_tile.width <= 0 || plan.first_tile.height <= 0
			|| !(plan.first_tile.x < clip.right()) || !(plan.first_tile.y < clip.bottom())
	}
}

pub fn (mut iterator BackgroundTileIterator) next() ?Rect {
	for !iterator.exhausted {
		tile := Rect{iterator.x, iterator.y, iterator.plan.first_tile.width, iterator.plan.first_tile.height}
		next_x := iterator.x + iterator.plan.x_step
		if iterator.plan.repeat_x && next_x < iterator.clip.right() {
			iterator.x = next_x
		} else if iterator.plan.repeat_y {
			iterator.x = iterator.plan.first_tile.x
			iterator.y += iterator.plan.y_step
			iterator.exhausted = !(iterator.y < iterator.clip.bottom())
		} else {
			iterator.exhausted = true
		}
		if !tile.intersects(iterator.clip) { continue }
		iterator.emitted++
		if iterator.maximum_tiles > 0 && iterator.emitted >= iterator.maximum_tiles {
			iterator.exhausted = true
		}
		return tile
	}
	return none
}
