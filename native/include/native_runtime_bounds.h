#ifndef VOX_NATIVE_RUNTIME_BOUNDS_H
#define VOX_NATIVE_RUNTIME_BOUNDS_H

// V3 emits these definitions as inline, but their panic formatting makes them
// too large for Clang's normal inlining budget. In particular, even constant
// indexes in fixed-array iteration otherwise make out-of-line calls. Keep the
// runtime's complete checks and panic implementation, and expose each check
// to the caller's optimizer so proven in-range indexes can be folded away.
// __v_int and these signatures belong to V3, not the compatibility compiler.
#if defined(CUSTOM_DEFINE_v3_c_extern_declarations) && \
    (defined(__clang__) || defined(__GNUC__))
__attribute__((always_inline)) __v_int v_fixed_index(__v_int index, __v_int length);
__attribute__((always_inline)) __v_int v_fixed_index_i64(i64 index, __v_int length);
__attribute__((always_inline)) __v_int v_fixed_index_u64(u64 index, __v_int length);
__attribute__((always_inline)) __v_int v_fixed_index_ni(__v_int index, __v_int length);
#endif

#endif
