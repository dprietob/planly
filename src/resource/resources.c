#include <gio/gio.h>

#if defined (__ELF__) && ( __GNUC__ > 2 || (__GNUC__ == 2 && __GNUC_MINOR__ >= 6))
# define SECTION __attribute__ ((section (".gresource."), aligned (sizeof(void *) > 8 ? sizeof(void *) : 8)))
#else
# define SECTION
#endif

static const SECTION union { const guint8 data[1037]; const double alignment; void * const ptr;}  _resource_data = {
  "\107\126\141\162\151\141\156\164\000\000\000\000\000\000\000\000"
  "\030\000\000\000\344\000\000\000\000\000\000\050\007\000\000\000"
  "\000\000\000\000\001\000\000\000\001\000\000\000\002\000\000\000"
  "\003\000\000\000\005\000\000\000\005\000\000\000\305\063\344\164"
  "\004\000\000\000\344\000\000\000\011\000\114\000\360\000\000\000"
  "\364\000\000\000\324\265\002\000\377\377\377\377\364\000\000\000"
  "\001\000\114\000\370\000\000\000\374\000\000\000\302\257\211\013"
  "\001\000\000\000\374\000\000\000\004\000\114\000\000\001\000\000"
  "\004\001\000\000\252\264\013\200\002\000\000\000\004\001\000\000"
  "\011\000\114\000\020\001\000\000\024\001\000\000\064\147\273\015"
  "\005\000\000\000\024\001\000\000\006\000\114\000\034\001\000\000"
  "\040\001\000\000\211\277\221\203\003\000\000\000\040\001\000\000"
  "\007\000\114\000\050\001\000\000\054\001\000\000\067\244\305\205"
  "\000\000\000\000\054\001\000\000\021\000\166\000\100\001\000\000"
  "\014\004\000\000\163\171\155\142\157\154\151\143\057\000\000\000"
  "\006\000\000\000\057\000\000\000\002\000\000\000\143\157\155\057"
  "\003\000\000\000\144\160\162\151\145\164\157\142\057\000\000\000"
  "\005\000\000\000\151\143\157\156\163\057\000\000\000\000\000\000"
  "\160\154\141\156\154\171\057\000\004\000\000\000\142\165\154\142"
  "\055\163\171\155\142\157\154\151\143\056\163\166\147\000\000\000"
  "\274\002\000\000\000\000\000\000\074\163\166\147\040\170\155\154"
  "\156\163\075\042\150\164\164\160\072\057\057\167\167\167\056\167"
  "\063\056\157\162\147\057\062\060\060\060\057\163\166\147\042\040"
  "\167\151\144\164\150\075\042\063\062\042\040\150\145\151\147\150"
  "\164\075\042\063\062\042\040\146\151\154\154\075\042\143\165\162"
  "\162\145\156\164\103\157\154\157\162\042\012\040\040\040\040\166"
  "\151\145\167\102\157\170\075\042\060\040\060\040\062\065\066\040"
  "\062\065\066\042\076\012\040\040\040\040\074\160\141\164\150\012"
  "\040\040\040\040\040\040\040\040\144\075\042\115\061\067\066\054"
  "\062\063\062\141\070\054\070\054\060\054\060\054\061\055\070\054"
  "\070\110\070\070\141\070\054\070\054\060\054\060\054\061\054\060"
  "\055\061\066\150\070\060\101\070\054\070\054\060\054\060\054\061"
  "\054\061\067\066\054\062\063\062\132\155\064\060\055\061\062\070"
  "\141\070\067\056\065\065\054\070\067\056\065\065\054\060\054\060"
  "\054\061\055\063\063\056\066\064\054\066\071\056\062\061\101\061"
  "\066\056\062\064\054\061\066\056\062\064\054\060\054\060\054\060"
  "\054\061\067\066\054\061\070\066\166\066\141\061\066\054\061\066"
  "\054\060\054\060\054\061\055\061\066\054\061\066\110\071\066\141"
  "\061\066\054\061\066\054\060\054\060\054\061\055\061\066\055\061"
  "\066\166\055\066\141\061\066\054\061\066\054\060\054\060\054\060"
  "\055\066\056\062\063\055\061\062\056\066\066\101\070\067\056\065"
  "\071\054\070\067\056\065\071\054\060\054\060\054\061\054\064\060"
  "\054\061\060\064\056\065\103\063\071\056\067\064\054\065\066\056"
  "\070\063\054\067\070\056\062\066\054\061\067\056\061\065\054\061"
  "\062\065\056\070\070\054\061\066\101\070\070\054\070\070\054\060"
  "\054\060\054\061\054\062\061\066\054\061\060\064\132\155\055\061"
  "\066\054\060\141\067\062\054\067\062\054\060\054\060\054\060\055"
  "\067\063\056\067\064\055\067\062\143\055\063\071\054\056\071\062"
  "\055\067\060\056\064\067\054\063\063\056\063\071\055\067\060\056"
  "\062\066\054\067\062\056\063\071\141\067\061\056\066\064\054\067"
  "\061\056\066\064\054\060\054\060\054\060\054\062\067\056\066\064"
  "\054\065\066\056\063\150\060\101\063\062\054\063\062\054\060\054"
  "\060\054\061\054\071\066\054\061\070\066\166\066\150\062\064\126"
  "\061\064\067\056\063\061\114\071\060\056\063\064\054\061\061\067"
  "\056\066\066\141\070\054\070\054\060\054\060\054\061\054\061\061"
  "\056\063\062\055\061\061\056\063\062\114\061\062\070\054\061\063"
  "\062\056\066\071\154\062\066\056\063\064\055\062\066\056\063\065"
  "\141\070\054\070\054\060\054\060\054\061\054\061\061\056\063\062"
  "\054\061\061\056\063\062\114\061\063\066\054\061\064\067\056\063"
  "\061\126\061\071\062\150\062\064\166\055\066\141\063\062\056\061"
  "\062\054\063\062\056\061\062\054\060\054\060\054\061\054\061\062"
  "\056\064\067\055\062\065\056\063\065\101\067\061\056\066\065\054"
  "\067\061\056\066\065\054\060\054\060\054\060\054\062\060\060\054"
  "\061\060\064\132\042\076\074\057\160\141\164\150\076\012\074\057"
  "\163\166\147\076\000\000\050\165\165\141\171\051" };

static GStaticResource static_resource = { _resource_data.data, sizeof (_resource_data.data) - 1 /* nul terminator */, NULL, NULL, NULL };

G_MODULE_EXPORT
GResource *_get_resource (void);
GResource *_get_resource (void)
{
  return g_static_resource_get_resource (&static_resource);
}
/* GLIB - Library of useful routines for C programming
 * Copyright (C) 1995-1997  Peter Mattis, Spencer Kimball and Josh MacDonald
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, see <http://www.gnu.org/licenses/>.
 */

/*
 * Modified by the GLib Team and others 1997-2000.  See the AUTHORS
 * file for a list of people on the GLib Team.  See the ChangeLog
 * files for a list of changes.  These files are distributed with
 * GLib at ftp://ftp.gtk.org/pub/gtk/.
 */

#ifndef __G_CONSTRUCTOR_H__
#define __G_CONSTRUCTOR_H__

/*
  If G_HAS_CONSTRUCTORS is true then the compiler support *both* constructors and
  destructors, in a usable way, including e.g. on library unload. If not you're on
  your own.

  Some compilers need #pragma to handle this, which does not work with macros,
  so the way you need to use this is (for constructors):

  #ifdef G_DEFINE_CONSTRUCTOR_NEEDS_PRAGMA
  #pragma G_DEFINE_CONSTRUCTOR_PRAGMA_ARGS(my_constructor)
  #endif
  G_DEFINE_CONSTRUCTOR(my_constructor)
  static void my_constructor(void) {
   ...
  }

*/

#ifndef __GTK_DOC_IGNORE__

#if  __GNUC__ > 2 || (__GNUC__ == 2 && __GNUC_MINOR__ >= 7)

#define G_HAS_CONSTRUCTORS 1

#define G_DEFINE_CONSTRUCTOR(_func) static void __attribute__((constructor)) _func (void);
#define G_DEFINE_DESTRUCTOR(_func) static void __attribute__((destructor)) _func (void);

#elif defined (_MSC_VER)

/*
 * Only try to include gslist.h if not already included via glib.h,
 * so that items using gconstructor.h outside of GLib (such as
 * GResources) continue to build properly.
 */
#ifndef __G_LIB_H__
#include "gslist.h"
#endif

#include <stdlib.h>

#define G_HAS_CONSTRUCTORS 1

/* We do some weird things to avoid the constructors being optimized
 * away on VS2015 if WholeProgramOptimization is enabled. First we
 * make a reference to the array from the wrapper to make sure its
 * references. Then we use a pragma to make sure the wrapper function
 * symbol is always included at the link stage. Also, the symbols
 * need to be extern (but not dllexport), even though they are not
 * really used from another object file.
 */

/* We need to account for differences between the mangling of symbols
 * for x86 and x64/ARM/ARM64 programs, as symbols on x86 are prefixed
 * with an underscore but symbols on x64/ARM/ARM64 are not.
 */
#ifdef _M_IX86
#define G_MSVC_SYMBOL_PREFIX "_"
#else
#define G_MSVC_SYMBOL_PREFIX ""
#endif

#define G_DEFINE_CONSTRUCTOR(_func) G_MSVC_CTOR (_func, G_MSVC_SYMBOL_PREFIX)
#define G_DEFINE_DESTRUCTOR(_func) G_MSVC_DTOR (_func, G_MSVC_SYMBOL_PREFIX)

#define G_MSVC_CTOR(_func,_sym_prefix) \
  static void _func(void); \
  extern int (* _array ## _func)(void);              \
  int _func ## _wrapper(void);              \
  int _func ## _wrapper(void) { _func(); g_slist_find (NULL,  _array ## _func); return 0; } \
  __pragma(comment(linker,"/include:" _sym_prefix # _func "_wrapper")) \
  __pragma(section(".CRT$XCU",read)) \
  __declspec(allocate(".CRT$XCU")) int (* _array ## _func)(void) = _func ## _wrapper;

#define G_MSVC_DTOR(_func,_sym_prefix) \
  static void _func(void); \
  extern int (* _array ## _func)(void);              \
  int _func ## _constructor(void);              \
  int _func ## _constructor(void) { atexit (_func); g_slist_find (NULL,  _array ## _func); return 0; } \
   __pragma(comment(linker,"/include:" _sym_prefix # _func "_constructor")) \
  __pragma(section(".CRT$XCU",read)) \
  __declspec(allocate(".CRT$XCU")) int (* _array ## _func)(void) = _func ## _constructor;

#elif defined(__SUNPRO_C)

/* This is not tested, but i believe it should work, based on:
 * http://opensource.apple.com/source/OpenSSL098/OpenSSL098-35/src/fips/fips_premain.c
 */

#define G_HAS_CONSTRUCTORS 1

#define G_DEFINE_CONSTRUCTOR_NEEDS_PRAGMA 1
#define G_DEFINE_DESTRUCTOR_NEEDS_PRAGMA 1

#define G_DEFINE_CONSTRUCTOR_PRAGMA_ARGS(_func) \
  init(_func)
#define G_DEFINE_CONSTRUCTOR(_func) \
  static void _func(void);

#define G_DEFINE_DESTRUCTOR_PRAGMA_ARGS(_func) \
  fini(_func)
#define G_DEFINE_DESTRUCTOR(_func) \
  static void _func(void);

#else

/* constructors not supported for this compiler */

#endif

#endif /* __GTK_DOC_IGNORE__ */
#endif /* __G_CONSTRUCTOR_H__ */

#ifdef G_HAS_CONSTRUCTORS

#ifdef G_DEFINE_CONSTRUCTOR_NEEDS_PRAGMA
#pragma G_DEFINE_CONSTRUCTOR_PRAGMA_ARGS(resource_constructor)
#endif
G_DEFINE_CONSTRUCTOR(resource_constructor)
#ifdef G_DEFINE_DESTRUCTOR_NEEDS_PRAGMA
#pragma G_DEFINE_DESTRUCTOR_PRAGMA_ARGS(resource_destructor)
#endif
G_DEFINE_DESTRUCTOR(resource_destructor)

#else
#warning "Constructor not supported on this compiler, linking in resources will not work"
#endif

static void resource_constructor (void)
{
  g_static_resource_init (&static_resource);
}

static void resource_destructor (void)
{
  g_static_resource_fini (&static_resource);
}
