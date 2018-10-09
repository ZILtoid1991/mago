module MachineX86_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import MachineX86;
import Thread;
import ThreadX86;


// Define a set of minimum registers to cache.
// It really only needs to be control registers, but you might as well cache 
// most of the rest, which are often read from the last thread that reported an event.

static if(defined( _WIN64 )) {
enum
{
    MIN_CONTEXT_FLAGS = 
        WOW64_CONTEXT_FULL 
        | WOW64_CONTEXT_FLOATING_POINT 
        | WOW64_CONTEXT_EXTENDED_REGISTERS
};
alias  WOW64_CONTEXT                    CONTEXT_X86;
alias                 WOW64_CONTEXT_i386  CONTEXT_X86_i386;
alias              WOW64_CONTEXT_CONTROL  CONTEXT_X86_CONTROL;
alias              WOW64_CONTEXT_INTEGER  CONTEXT_X86_INTEGER;
alias             WOW64_CONTEXT_SEGMENTS  CONTEXT_X86_SEGMENTS;
alias       WOW64_CONTEXT_FLOATING_POINT  CONTEXT_X86_FLOATING_POINT;
alias      WOW64_CONTEXT_DEBUG_REGISTERS  CONTEXT_X86_DEBUG_REGISTERS;
alias   WOW64_CONTEXT_EXTENDED_REGISTERS  CONTEXT_X86_EXTENDED_REGISTERS;
// #define GetThreadContextX86             ::Wow64GetThreadContext
// #define SetThreadContextX86             ::Wow64SetThreadContext
// #define SuspendThreadX86                ::Wow64SuspendThread
} else {
enum
{ 
    MIN_CONTEXT_FLAGS = 
        CONTEXT_FULL 
        | CONTEXT_FLOATING_POINT 
        | CONTEXT_EXTENDED_REGISTERS
};
alias  CONTEXT                          CONTEXT_X86;
alias                 CONTEXT_i386  CONTEXT_X86_i386;
alias              CONTEXT_CONTROL  CONTEXT_X86_CONTROL;
alias              CONTEXT_INTEGER  CONTEXT_X86_INTEGER;
alias             CONTEXT_SEGMENTS  CONTEXT_X86_SEGMENTS;
alias       CONTEXT_FLOATING_POINT  CONTEXT_X86_FLOATING_POINT;
alias      CONTEXT_DEBUG_REGISTERS  CONTEXT_X86_DEBUG_REGISTERS;
alias   CONTEXT_EXTENDED_REGISTERS  CONTEXT_X86_EXTENDED_REGISTERS;
// #define GetThreadContextX86             ::GetThreadContext
// #define SetThreadContextX86             ::SetThreadContext
// #define SuspendThreadX86                ::SuspendThread
}

const  DWORD  TRACE_FLAG = 0x100;


HRESULT  MakeMachineX86( ref IMachine*  machine )
{
    HRESULT  hr = S_OK;
    RefPtr<MachineX86>          machX86( new  MachineX86() );

    if ( machX86.Get() is  null )
        return  E_OUTOFMEMORY;

    hr = machX86.Init();
    if ( FAILED( hr ) )
        return  hr;

    machine = machX86.Detach();
    return  S_OK;
}

this.MachineX86()
{   mIsContextCached = ( false );
        mEnableSS = ( false );
    memset( &mContext, 0,  mContext.sizeof );
}

bool  MachineX86.Is64Bit()
{
    return  false;
}

HRESULT  MachineX86.CacheThreadContext()
{
    HRESULT  hr = S_OK;
    ThreadX86Base* threadX86 = GetStoppedThread();
    Thread* thread = threadX86.GetExecThread();

    mContext.ContextFlags = MIN_CONTEXT_FLAGS;
    if ( !GetThreadContextX86( thread.GetHandle(), &mContext ) )
    {
        hr = GetLastHr();
        goto  Error;
    }

    mIsContextCached = true;

Error:
    return  hr;
}

HRESULT  MachineX86.FlushThreadContext()
{
    if ( !mIsContextCached )
        return  S_OK;

    HRESULT  hr = S_OK;
    ThreadX86Base* threadX86 = GetStoppedThread();
    Thread* thread = threadX86.GetExecThread();

    if ( mEnableSS )
    {
        mContext.EFlags |= TRACE_FLAG;
        mEnableSS = false;
    }

    if ( !SetThreadContextX86( thread.GetHandle(), &mContext ) )
    {
        hr = GetLastHr();
        goto  Error;
    }

    mIsContextCached = false;

Error:
    return  hr;
}

HRESULT  MachineX86.ChangeCurrentPC( int32_t  byteOffset )
{
    _ASSERT( mIsContextCached );
    if ( !mIsContextCached )
        return  E_FAIL;

    mContext.Eip += byteOffset;
    return  S_OK;
}

HRESULT  MachineX86.SetSingleStep( bool  enable )
{
    _ASSERT( mIsContextCached );
    if ( !mIsContextCached )
        return  E_FAIL;

    mEnableSS = enable;
    return  S_OK;
}

HRESULT  MachineX86.ClearSingleStep()
{
    _ASSERT( mIsContextCached );
    if ( !mIsContextCached )
        return  E_FAIL;

    mContext.EFlags &= ~TRACE_FLAG;

    return  S_OK;
}

HRESULT  MachineX86.GetCurrentPC( ref Address  address )
{
    _ASSERT( mIsContextCached );
    if ( !mIsContextCached )
        return  E_FAIL;

    address = mContext.Eip;
    return  S_OK;
}

// Gets the return address in the newest stack frame.
HRESULT  MachineX86.GetReturnAddress( ref Address  address )
{
    _ASSERT( mIsContextCached );
    if ( !mIsContextCached )
        return  E_FAIL;

    BOOL  bRet = ReadProcessMemory( 
        GetProcessHandle(), 
        cast(void *) mContext.Esp, 
        &address, 
         address.sizeof, 
        null );
    if ( !bRet )
        return  GetLastHr();

    return  S_OK;
}

HRESULT  MachineX86.SuspendThread( Thread* thread )
{
    DWORD    suspendCount = SuspendThreadX86( thread.GetHandle() );

    if ( suspendCount == DWORD -1 )
    {
        HRESULT  hr = GetLastHr();

        // if the thread can't be accessed, then it's probably on the way out
        // and there's nothing we should do about it
        if ( hr == E_ACCESSDENIED )
            return  S_OK;

        return  hr;
    }

    return  S_OK;
}

HRESULT  MachineX86.ResumeThread( Thread* thread )
{
    // there's no Wow64ResumeThread
    DWORD    suspendCount = .ResumeThread( thread.GetHandle() );

    if ( suspendCount == DWORD -1 )
    {
        HRESULT  hr = GetLastHr();

        // if the thread can't be accessed, then it's probably on the way out
        // and there's nothing we should do about it
        if ( hr == E_ACCESSDENIED )
            return  S_OK;

        return  hr;
    }

    return  S_OK;
}

static  void  CopyContext( DWORD  flags, const  CONTEXT_X86* srcContext, CONTEXT_X86* dstContext )
{
    _ASSERT( srcContext !is  null );
    _ASSERT( dstContext !is  null );
    _ASSERT( (flags & ~MIN_CONTEXT_FLAGS) == 0 );

    if ( (flags & CONTEXT_X86_CONTROL) == CONTEXT_X86_CONTROL )
    {
        memcpy( &dstContext.Ebp, &srcContext.Ebp,  DWORD.sizeof * 6 );
    }

    if ( (flags & CONTEXT_X86_INTEGER) == CONTEXT_X86_INTEGER )
    {
        memcpy( &dstContext.Edi, &srcContext.Edi,  DWORD.sizeof * 6 );
    }

    if ( (flags & CONTEXT_X86_SEGMENTS) == CONTEXT_X86_SEGMENTS )
    {
        memcpy( &dstContext.SegGs, &srcContext.SegGs,  DWORD.sizeof * 4 );
    }

    if ( (flags & CONTEXT_X86_FLOATING_POINT) == CONTEXT_X86_FLOATING_POINT )
    {
        dstContext.FloatSave = srcContext.FloatSave;
    }

    if ( (flags & CONTEXT_X86_EXTENDED_REGISTERS) == CONTEXT_X86_EXTENDED_REGISTERS )
    {
        memcpy( 
            dstContext.ExtendedRegisters, 
            srcContext.ExtendedRegisters, 
             dstContext.ExtendedRegisters.sizeof );
    }
}

HRESULT  MachineX86.GetThreadContextWithCache( HANDLE  hThread, void * contextBuf, uint32_t  size )
{
    _ASSERT( hThread !is  null );
    _ASSERT( contextBuf !is  null );
    _ASSERT( size >=  CONTEXT_X86.sizeof );
    _ASSERT( mIsContextCached );
    if ( size <  CONTEXT_X86.sizeof )
        return  E_INVALIDARG;

    // ContextFlags = 0 and CONTEXT_i386 are OK

    CONTEXT_X86* context = cast(CONTEXT_X86*) contextBuf;
    DWORD  callerFlags       = context.ContextFlags & ~CONTEXT_X86_i386;
    DWORD  cacheFlags        = mContext.ContextFlags & ~CONTEXT_X86_i386;
    DWORD  cachedFlags       = callerFlags & cacheFlags;
    DWORD  notCachedFlags    = callerFlags & ~cacheFlags;

    if ( notCachedFlags != 0 )
    {
        // only get from the target what isn't cached
        context.ContextFlags = notCachedFlags | CONTEXT_X86_i386;
        if ( !GetThreadContextX86( hThread, context ) )
            return  GetLastHr();
    }

    if ( cachedFlags != 0 )
    {
        CopyContext( cachedFlags | CONTEXT_X86_i386, &mContext, context );
        context.ContextFlags |= cachedFlags | CONTEXT_X86_i386;
    }

    return  S_OK;
}

HRESULT  MachineX86.SetThreadContextWithCache( HANDLE  hThread, const(void) * contextBuf, uint32_t  size )
{
    _ASSERT( hThread !is  null );
    _ASSERT( contextBuf !is  null );
    _ASSERT( size >=  CONTEXT_X86.sizeof );
    _ASSERT( mIsContextCached );
    if ( size <  CONTEXT_X86.sizeof )
        return  E_INVALIDARG;

    // ContextFlags = 0 and CONTEXT_i386 are OK

    const  CONTEXT_X86* context = cast(const  CONTEXT_X86*) contextBuf;
    DWORD  callerFlags       = context.ContextFlags & ~CONTEXT_X86_i386;
    DWORD  cacheFlags        = mContext.ContextFlags & ~CONTEXT_X86_i386;
    DWORD  cachedFlags       = callerFlags & cacheFlags;
    DWORD  notCachedFlags    = callerFlags & ~cacheFlags;

    if ( notCachedFlags != 0 )
    {
        // set everything, in order to avoid copying the context 
        // or writing restricted flags to the const context
        if ( !SetThreadContextX86( hThread, context ) )
            return  GetLastHr();
    }

    if ( cachedFlags != 0 )
    {
        CopyContext( cachedFlags | CONTEXT_X86_i386, context, &mContext );
    }

    return  S_OK;
}

HRESULT  MachineX86.GetThreadContextInternal( 
    uint32_t  threadId, 
    uint32_t  features, 
    uint64_t  extFeatures, 
    void * contextBuf, 
    uint32_t  size )
{
    UNREFERENCED_PARAMETER( extFeatures );

    if ( size <  CONTEXT_X86.sizeof )
        return  E_INVALIDARG;

    ThreadX86Base* threadX86 = GetStoppedThread();
    Thread* thread = threadX86.GetExecThread();
    CONTEXT_X86* context = cast(CONTEXT_X86*) contextBuf;

    context.ContextFlags = features;

    if ( threadId == thread.GetId() && mIsContextCached )
    {
        return  GetThreadContextWithCache( thread.GetHandle(), context, size );
    }

    HRESULT  hr = S_OK;
    HANDLE   hThread = OpenThread( THREAD_ALL_ACCESS, FALSE, threadId );

    if ( hThread  is  null )
    {
        hr = GetLastHr();
        goto  Error;
    }

    if ( !GetThreadContextX86( hThread, context ) )
    {
        hr = GetLastHr();
        goto  Error;
    }

Error:
    if ( hThread !is  null )
        CloseHandle( hThread );

    return  hr;
}

HRESULT  MachineX86.SetThreadContextInternal( uint32_t  threadId, const(void) * context, uint32_t  size )
{
    if ( size <  CONTEXT_X86.sizeof )
        return  E_INVALIDARG;

    ThreadX86Base* threadX86 = GetStoppedThread();
    Thread* thread = threadX86.GetExecThread();

    if ( threadId == thread.GetId() && mIsContextCached )
    {
        return  SetThreadContextWithCache( thread.GetHandle(), context, size );
    }

    HRESULT  hr = S_OK;
    HANDLE   hThread = OpenThread( THREAD_ALL_ACCESS, FALSE, threadId );

    if ( hThread  is  null )
    {
        hr = GetLastHr();
        goto  Error;
    }

    if ( !SetThreadContextX86( hThread, cast(const  CONTEXT_X86*) context ) )
    {
        hr = GetLastHr();
        goto  Error;
    }

Error:
    if ( hThread !is  null )
        CloseHandle( hThread );

    return  hr;
}

ThreadControlProc  MachineX86.GetWinSuspendThreadProc()
{
    return  SuspendThreadX86;
}
