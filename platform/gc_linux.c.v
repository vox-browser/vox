module platform

$if dynamic_boehm ? {
	#include "@DIR/gc_linux.h"
}
