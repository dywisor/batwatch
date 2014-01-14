/*
 * Some macros for compiling batwatch with compilers other than gcc
 *
*/

#ifndef _BATWATCH_GCC_COMPAT_H_
#define _BATWATCH_GCC_COMPAT_H_

#ifdef __GNUC__

/* for functions allocating objects on the heap (and returning them) */
#define ATTRIBUTE_WARN_UNUSED_RESULT __attribute__((warn_unused_result))
#define ATTRIBUTE_NORETURN           __attribute__((noreturn))
#define ATTRIBUTE_UNUSED             __attribute__((unused))

#else

#define ATTRIBUTE_WARN_UNUSED_RESULT
#define ATTRIBUTE_NORETURN
#define ATTRIBUTE_UNUSED

#endif

#endif /* _BATWATCH_GCC_COMPAT_H_ */
