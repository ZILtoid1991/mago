module Log_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import Log;

// #include <stdio.h>


static const(char) *      gEventNames[] = 
[
    "No event",
    "EXCEPTION_DEBUG_EVENT",
    "CREATE_THREAD_DEBUG_EVENT",
    "CREATE_PROCESS_DEBUG_EVENT",
    "EXIT_THREAD_DEBUG_EVENT",
    "EXIT_PROCESS_DEBUG_EVENT",
    "LOAD_DLL_DEBUG_EVENT",
    "UNLOAD_DLL_DEBUG_EVENT",
    "OUTPUT_DEBUG_STRING_EVENT",
    "RIP_EVENT",
];

static if(NDEBUG) {
static  bool  _log_enabled = false;
} else {
static  bool  _log_enabled = true;
}

void  Log.Enable( bool  enabled )
{
    _log_enabled = enabled;
}

void  Log.LogDebugEvent( ref const  DEBUG_EVENT  event )
{
    if (!_log_enabled)
        return;
    if ( event.dwDebugEventCode >= _countof( gEventNames ) )
        return;

    const(char) * eventName = gEventNames[event.dwDebugEventCode];
    char         msg[90] = "";
    char         part[90] = "";

    _snprintf_s( msg, _TRUNCATE, "%s (%d) : PID=%d, TID=%d", 
        eventName, 
        event.dwDebugEventCode, 
        event.dwProcessId, 
        event.dwThreadId );

    if ( event.dwDebugEventCode == EXCEPTION_DEBUG_EVENT )
    {
        _snprintf_s( part, _TRUNCATE, ", exc=%08x at %p", 
            event.u.Exception.ExceptionRecord.ExceptionCode,
            event.u.Exception.ExceptionRecord.ExceptionAddress );
        strncat_s( msg, part, _TRUNCATE );
    }

    printf( "%s\n", msg );

    strncat_s( msg, "\n", _TRUNCATE );
    OutputDebugStringA( msg );
}

void  Log.LogMessage( const(char) * msg )
{
    if (!_log_enabled)
        return;
    OutputDebugStringA( msg );
}
