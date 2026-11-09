module css

// A recursive child is exactly one value. Keep its immutable header separate
// from the surrounding sum-type variant instead of carrying an array's full
// allocation header in every scalar StyleValue. The slot's child retains the
// existing shallow sharing of a one-element array; public getters still return
// a StyleValue snapshot. The read-only length preserves cardinality guards.
@[heap]
pub struct StyleValueSlot {
pub:
	len int = 1
pub mut:
	value StyleValue
}

fn style_value_slot(value StyleValue) &StyleValueSlot {
	return &StyleValueSlot{value: value}
}
