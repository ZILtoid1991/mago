module Config_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import Config;
import MagoNatDE_i;

import __.MagoNatEE.Common;

enum  MAGO_SUBKEY =             "SOFTWARE\\MagoDebugger"w;

// {B9D303A5-4EC7-4444-A7F8-6BFA4C7977EF}
static  const  GUID  gGuidDLang = 
{ 0xb9d303a5, 0x4ec7, 0x4444, { 0xa7, 0xf8, 0x6b, 0xfa, 0x4c, 0x79, 0x77, 0xef } };

// {3B476D35-A401-11D2-AAD4-00C04F990171}
static  const  GUID  gGuidWin32ExceptionType = 
{ 0x3B476D35, 0xA401, 0x11D2, { 0xAA, 0xD4, 0x00, 0xC0, 0x4F, 0x99, 0x01, 0x71 } };

static const(wchar_t) *   gStrings[] = 
[
    null,

    "No symbols have been loaded for this document."w,
    "No executable code is associated with this line."w,
    "This is an invalid address."w,

    "CPU"w,
    "CPU Segments"w,
    "Floating Point"w,
    "Flags"w,
    "MMX"w,
    "SSE"w,
    "SSE2"w,

    "Line"w,
    "bytes"w,

    "%1$s has triggered a breakpoint."w,
    "First-chance exception: %1$s"w,
    "Unhandled exception: %1$s"w,
];


ref const  GUID  GetEngineId()
{
    return  __uuidof( MagoNativeEngine );
}

const(wchar_t) * GetEngineName()
{
    return "Mago Native"w;
}

ref const  GUID  GetDLanguageId()
{
    return  gGuidDLang;
}

ref const  GUID  GetDExceptionType()
{
    // we use the engine ID as the guid type for D exceptions
    return  __uuidof( MagoNativeEngine );
}

ref const  GUID  GetWin32ExceptionType()
{
    return  gGuidWin32ExceptionType;
}

const(wchar_t) * GetRootDExceptionName()
{
    return "D Exceptions"w;
}

const(wchar_t) * GetRootWin32ExceptionName()
{
    return "Win32 Exceptions"w;
}

const(wchar_t) * GetString( DWORD  strId )
{
    if ( strId >= _countof( gStrings ) )
        return  null;

    return  gStrings[strId];
}

bool  GetString( DWORD  strId, ref CString  str )
{
    const(wchar_t) *  s = GetString( strId );

    if ( s  is  null )
        return  false;

    str = s;
    return  true;
}

LSTATUS  OpenRootRegKey( bool  user, bool  readWrite, ref HKEY  hKey )
{
    REGSAM  samDesired = readWrite ? (KEY_READ | KEY_WRITE) : KEY_READ;
    HKEY  hive = user ? HKEY_CURRENT_USER : HKEY_LOCAL_MACHINE;
    return  RegOpenKeyEx( hive, MAGO_SUBKEY, 0, samDesired, &hKey );
}

LSTATUS  GetRegString( HKEY  hKey, const(wchar_t) * valueName, wchar_t * charBuf, ref int  charLen )
{
    if ( charBuf  is  null || charLen < 0 )
        return  ERROR_INVALID_PARAMETER;

    DWORD    regType = 0;
    DWORD    bufLen = charLen *  wchar_t.sizeof;
    DWORD    bytesRead= bufLen;
    LSTATUS  ret = 0;

    ret = RegQueryValueEx(
        hKey,
        valueName,
        null,
        &regType,
        cast(BYTE*) charBuf,
        &bytesRead );
    if ( ret != ERROR_SUCCESS )
        return  ret;

    if ( regType != REG_SZ || (bytesRead %  wchar_t.sizeof) != 0 )
        return  ERROR_UNSUPPORTED_TYPE;

    int  charsRead = bytesRead /  wchar_t.sizeof;

    if ( charsRead == 0 || charBuf[charsRead - 1] != '\0'w )
    {
        // there's no more room to add a null
        if ( charsRead == charLen )
            return  ERROR_MORE_DATA;

        charBuf[charsRead] = '\0'w;
        charLen = charsRead + 1;
    }
    else
    {
        // the string we read already ends in null
        charLen = charsRead;
    }

    return  ERROR_SUCCESS;
}

LSTATUS  GetRegValue( HKEY  hKey, const(wchar_t) * valueName, DWORD* pValue )
{
    if ( pValue  is  null )
        return  ERROR_INVALID_PARAMETER;

    DWORD    regType = 0;
    DWORD    bytesRead = ( *pValue).sizeof;
    LSTATUS  ret = 0;

    ret = RegQueryValueEx(
        hKey,
        valueName,
        null,
        &regType,
        cast(BYTE*) pValue,
        &bytesRead );
    if ( ret != ERROR_SUCCESS )
        return  ret;

    if ( regType != REG_DWORD )
        return  ERROR_UNSUPPORTED_TYPE;

    return  ERROR_SUCCESS;
}

MagoOptions  gOptions;

bool  readMagoOptions()
{
    HKEY  hKey;
    LSTATUS  hr = OpenRootRegKey( true, false, hKey );
    if( hr != S_OK )
        return  false;

    DWORD  val;
    if( GetRegValue( hKey, "hideInternalNames"w, &val ) == S_OK )
        gOptions.hideInternalNames = val != 0;
    else
         gOptions.hideInternalNames = false;

    if( GetRegValue( hKey, "showStaticsInAggr"w, &val ) == S_OK )
        gOptions.showStaticsInAggr = val != 0;
    else
         gOptions.showStaticsInAggr = false;

    if( GetRegValue( hKey, "showVTable"w, &val ) == S_OK )
        gOptions.showVTable = val != 0;
    else
         gOptions.showVTable = true;

    MagoEE.gShowVTable = gOptions.showVTable;

    RegCloseKey( hKey );
    return  true;
}

static  bool  initMagoOption = readMagoOptions();
