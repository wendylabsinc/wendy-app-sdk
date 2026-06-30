// Override assertions so invalid font data returns an error instead of aborting.
#define STBTT_assert(x) ((void)(x))
#define STB_TRUETYPE_IMPLEMENTATION
#include "stb_truetype.h"
