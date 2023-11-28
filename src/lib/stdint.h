typedef char int8_t;                  // char is always singed 8 bits on a 32-bit platform (rv32)
typedef unsigned char uint8_t;
typedef short int16_t;                // short is always 16 bits regardless of the platform
typedef unsigned short uint16_t;
typedef int int32_t;                  // 32 bits for 32 and 64-bit platforms
typedef unsigned int uint32_t;
typedef long long int64_t;            // always 64 bits
typedef unsigned long long uint64_t;
typedef uint32_t size_t;              // size_t should always be big enough to support the hole memory area and its width is always as big as a pointer
typedef int32_t ssize_t;              // just the signed version of size_t for error returns
