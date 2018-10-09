module MemoryBytes_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import MemoryBytes;
import CodeContext;
import IDebuggerProxy;
import ICoreProcess;


namespace  Mago
{
    this.MemoryBytes()
    {   mAddr = ( 0 );
            mSize = ( 0 );
            mDebugger = ( null );
    }

    this.~MemoryBytes()
    {
    }


    //////////////////////////////////////////////////////////// 
    // IDebugMemoryBytes2 

    HRESULT  MemoryBytes.ReadAt(
            IDebugMemoryContext2* pStartContext,
            DWORD                  dwCount,
            BYTE*                 rgbMemory,
            DWORD*                pdwRead,
            DWORD*                pdwUnreadable )
    {
        if ( pStartContext  is  null )
            return  E_INVALIDARG;
        if ( (rgbMemory  is  null) || (pdwRead  is  null) )
            return  E_INVALIDARG;

        HRESULT      hr = S_OK;
        Address64    addr = 0;
        uint32_t     lenRead = 0;
        uint32_t     lenUnreadable = 0;
        CComQIPtr<IMagoMemoryContext>   memCxt = pStartContext;

        if ( memCxt  is  null )
            return  E_INVALIDARG;

        memCxt.GetAddress( addr );

        hr = mDebugger.ReadMemory( 
            mProc,
            addr,
            dwCount,
            lenRead,
            lenUnreadable,
            rgbMemory );
        if ( FAILED( hr ) )
            return  hr;

        *pdwRead = lenRead;

        if ( pdwUnreadable !is  null )
            *pdwUnreadable = lenUnreadable;

        return  S_OK;
    }

    HRESULT  MemoryBytes.WriteAt(
            IDebugMemoryContext2* pStartContext,
            DWORD                  dwCount,
            BYTE*                 rgbMemory )
    {
        if ( pStartContext  is  null )
            return  E_INVALIDARG;
        if ( rgbMemory  is  null )
            return  E_INVALIDARG;

        HRESULT      hr = S_OK;
        Address64    addr = 0;
        uint32_t     lenWritten = 0;
        CComQIPtr<IMagoMemoryContext>   memCxt = pStartContext;

        if ( memCxt  is  null )
            return  E_INVALIDARG;

        memCxt.GetAddress( addr );

        hr = mDebugger.WriteMemory( 
            mProc,
            addr,
            dwCount,
            lenWritten,
            rgbMemory );
        if ( FAILED( hr ) )
            return  hr;

        return  S_OK;
    }

    HRESULT  MemoryBytes.GetSize( UINT64* pqwSize )
    {
        if ( pqwSize  is  null )
            return  E_INVALIDARG;

        *pqwSize = mSize;

        return  S_OK;
    }


    //////////////////////////////////////////////////////////// 
    // MemoryBytes

    void  MemoryBytes.Init( Address64  addr, uint64_t  size, IDebuggerProxy* debugger, ICoreProcess* proc )
    {
        _ASSERT( debugger !is  null );
        _ASSERT( proc !is  null );

        mAddr = addr;
        mSize = size;
        mDebugger = debugger;
        mProc = proc;
    }
}
