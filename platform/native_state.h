// Storage that a native bridge header shares with the whole program.
//
// V's `-parallel-cc` compiles the generated C as several units, and every unit
// after the first includes the program's native headers again. A `static`
// object in such a header would then exist once per unit, so V compiles a
// program whose headers hold one as a single unit. Declare state that must
// exist once with these macros:
//
//     VOX_NATIVE_STATE pthread_mutex_t vox_lock VOX_NATIVE_STATE_INIT(PTHREAD_MUTEX_INITIALIZER);
//
// In a single-unit build that is the usual `static` definition. In a parallel
// build the first unit (`V_PARALLEL_CC_OUT_0`) defines the object, and the other
// units declare it `extern`, without the initializer.
#ifndef VOX_NATIVE_STATE_H
#define VOX_NATIVE_STATE_H
#if defined(V_PARALLEL_CC) && !defined(V_PARALLEL_CC_OUT_0)
#define VOX_NATIVE_STATE extern
#define VOX_NATIVE_STATE_INIT(...)
#elif defined(V_PARALLEL_CC)
#define VOX_NATIVE_STATE
#define VOX_NATIVE_STATE_INIT(...) = __VA_ARGS__
#else
#define VOX_NATIVE_STATE static
#define VOX_NATIVE_STATE_INIT(...) = __VA_ARGS__
#endif
#endif
