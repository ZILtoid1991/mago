module exec.common;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

// stdafx.h : include file for standard system include files,
// or project specific include files that are used frequently, but
// are changed infrequently
//

//#include "targetver.h"

//#define WIN32_LEAN_AND_MEAN             // Exclude rarely-used stuff from Windows headers

// C
public import core.stdc.stdlib;//#include <stdlib.h>
public import core.stdc.inttypes;//#include <inttypes.h>
//#include <crtdbg.h>	TODO: either use DPP or generate a binding for crtdbg

// C++
/*#include <string>
#include <list>
#include <map>
#include <vector>
#include <limits>
#include <type_traits>*/

// Windows
//#include <windows.h>
public import core.sys.windows.windows;
public import core.stdc.wchar_;


// Magus
//#include <SmartPtr.h>


immutable DWORD     NO_DEBUG_EVENT = 0;


// This project
//#include "Types.h"
//#include "Utility.h"
//#include "Log.h"
//#include "Error.h"
public import exec.types;
public import exec.utility;
public import exec.log;
public import exec.error;
