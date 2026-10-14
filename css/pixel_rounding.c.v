module css

// The compiler intrinsic uses a fixed rounding direction. nearbyint/rint follow
// the process rounding mode and cannot replace CSS pixel ties-to-even rounding.
fn C.__builtin_roundeven(value f64) f64
