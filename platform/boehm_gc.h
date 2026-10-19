// libgc's declarations for the collector calls Vox makes itself. Current V
// includes no collector header and declares only the libgc functions builtin
// uses, so the rest would be implicit declarations. V 0.5.2 already includes
// this header first, making the include a no-op there. V registers its own
// threads, so keep libgc from redirecting pthread calls.
#ifndef VOX_BOEHM_GC_H
#define VOX_BOEHM_GC_H
#ifndef GC_NO_THREAD_REDIRECTS
#define GC_NO_THREAD_REDIRECTS 1
#endif
#include <gc/gc.h>
#endif
