#ifndef VOX_GC_LINUX_H
#define VOX_GC_LINUX_H
#include <gc/gc.h>

/* Older headers hide this declaration when the compiler has an asm barrier. */
GC_API void GC_CALL GC_noop1(GC_word);

/* Current V calls GC_noop1_ptr, while older distribution collectors export
 * only GC_noop1. Keep the pointer reachable using the collector's barrier.
 * A collector that provides GC_noop1_ptr can override this weak fallback. */
__attribute ((weak)) GC_API void GC_CALL GC_noop1_ptr(volatile void* pointer)
{
    GC_noop1((GC_word)pointer);
}
#endif
