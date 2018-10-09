module MagoNatDE.common;

//#include "resource.h"
import MagoNatDE.resource;
//#include <atlbase.h>
//#include <atlcom.h>
//#include <atlctl.h>
//#include <atlstr.h>

//using namespace ATL;

// C
public import core.stdc.inttypes; //#include <inttypes.h>
//#include <crtdbg.h>

// C++ 					Note: Currently these are left out. If they're needed for interfacing with C++, I'll add them back.
/+#include <string>
#include <map>
#include <vector>
#include <list>
#include <limits>+/

// VS Debug
//#include <msdbg.h>

// Magus
//#include <SmartPtr.h>
//#include <Guard.h>

// Debug Exec
/+#include "..\Exec\Types.h"
#include "..\Exec\Enumerator.h"
#include "..\Exec\Log.h"
#include "..\Exec\Error.h"
#include "..\Exec\Exec.h"
#include "..\Exec\EventCallback.h"
#include "..\Exec\IProcess.h"
#include "..\Exec\Thread.h"
#include "..\Exec\IModule.h"+/

// Debug Symbol Table
//#include <MagoCVSTI.h>

// This project
public import MagoNatDE.utility; //#include "Utility.h"
public import MagoNatDE.config;//#include "Config.h"