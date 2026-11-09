module layout

import css

// Partition fixed-point free space cumulatively. Independent truncation of
// every gap or auto margin loses the remainder and moves the final item.
fn flex_fractional_share(total CSSPixels, index int, count int) CSSPixels {
	if count <= 0 { return CSSPixels.new(0) }
	return CSSPixels.from_raw(int(i64(total.raw_value())*i64(index+1)/i64(count)
		-i64(total.raw_value())*i64(index)/i64(count)))
}

fn flex_distributed_position(justify css.JustifyContent, free CSSPixels, count int, index int) CSSPixels {
	if free.raw_value() <= 0 || count <= 0 { return CSSPixels.new(0) }
	raw := i64(free.raw_value())
	return CSSPixels.from_raw(int(match justify {
		.space_between { if count > 1 { raw*i64(index)/i64(count-1) } else { i64(0) } }
		.space_around { raw*i64(2*index+1)/i64(2*count) }
		.space_evenly { raw*i64(index+1)/i64(count+1) }
		else { i64(0) }
	}))
}

fn flex_distribution_remainder(justify css.JustifyContent, free CSSPixels, count int, index int, nominal CSSPixels) CSSPixels {
	if justify !in [.space_between,.space_around,.space_evenly] { return CSSPixels.new(0) }
	return flex_distributed_position(justify,free,count,index+1)
		.minus(flex_distributed_position(justify,free,count,index)).minus(nominal)
}
