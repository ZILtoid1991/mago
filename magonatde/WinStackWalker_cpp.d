module WinStackWalker_cpp;

/*
   Copyright (c) 2013 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import WinStackWalker;
// #include <DbgHelp.h>


namespace  Mago
{
    this.WindowsStackWalker(
        uint32_t  machineType,
        uint64_t  pc,
        uint64_t  stack,
        uint64_t  frame,
        void * processContext,
        ReadProcessMemory64Proc  readMemProc,
        FunctionTableAccess64Proc  funcTabProc,
        GetModuleBase64Proc  getModBaseProc )
    {   mMachineType = ( machineType );
            mThreadContextSize = ( 0 );
        mProcessContext = processContext;
        mReadMemProc = readMemProc;
        mFuncTabProc = funcTabProc;
        mGetModBaseProc = getModBaseProc;

        memset( &mGenericFrame, 0,  mGenericFrame.sizeof );

        mGenericFrame.AddrPC.Mode = AddrModeFlat;
        mGenericFrame.AddrPC.Offset = pc;
        mGenericFrame.AddrStack.Mode = AddrModeFlat;
        mGenericFrame.AddrStack.Offset = stack;
        mGenericFrame.AddrFrame.Mode = AddrModeFlat;
        mGenericFrame.AddrFrame.Offset = frame;
    }

    HRESULT  WindowsStackWalker.Init( const(void) * threadContext, uint32_t  threadContextSize )
    {
        if ( threadContext  is  null )
            return  E_INVALIDARG;

        mThreadContext.Attach( new  BYTE[threadContextSize] );
        if ( mThreadContext.Get() is  null )
            return  E_OUTOFMEMORY;

        mThreadContextSize = threadContextSize;

        memcpy( mThreadContext.Get(), threadContext, threadContextSize );
        return  S_OK;
    }

    bool  WindowsStackWalker.WalkStack()
    {
        if ( mThreadContext.Get() is  null )
            return  false;

        return  StackWalk64( 
            mMachineType,
            mProcessContext,
            null,
            &mGenericFrame,
            mThreadContext.Get(),
            mReadMemProc,
            mFuncTabProc,
            mGetModBaseProc,
            null ) ? true : false;
    }

    void  WindowsStackWalker.GetThreadContext( ref const(void) *  context, ref uint32_t  contextSize )
    {
        context = mThreadContext.Get();
        contextSize = mThreadContextSize;
    }
}
