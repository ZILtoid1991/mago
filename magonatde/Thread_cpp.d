module Thread_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import Thread;
import Program;
import Module;
import StackFrame;
import CodeContext;
import EnumFrameInfo;
import IDebuggerProxy;
import RegisterSet;
import ArchData;
import ICoreProcess;


namespace  Mago
{

struct  PdataCache
{
    alias  AddressRange64  MapKey;

    alias  bool(*RangePred)( ref const  MapKey  left, ref const  MapKey  right );
    static  bool  RangeLess( ref const  MapKey  left, ref const  MapKey  right );

    alias  std.vector!(BYTE) PdataBuffer;
    alias  std.map!(MapKey, int, RangePred) PdataMap;

    PdataBuffer  mBuffer;
    PdataMap     mMap;
    int          mEntrySize;

public:
    this( int  pdataSize );
    void * Find( Address64  address );
    void * Add( Address64  begin, Address64  end, void * pdata );
};

this.PdataCache( int  pdataSize )
{   mMap = ( RangeLess );
        mEntrySize = ( pdataSize );
}

bool  PdataCache.RangeLess( ref const  MapKey  left, ref const  MapKey  right )
{
    return  left.End < right.Begin;
}

void * PdataCache.Find( Address64  address )
{
    MapKey  range = { address, address };

    PdataMap.iterator  it = mMap.find( range );
    if ( it == mMap.end() )
        return  null;

    return &mBuffer[it.second];
}

void * PdataCache.Add( Address64  begin, Address64  end, void * pdata )
{
    size_t  origSize = mBuffer.size();
    mBuffer.resize( mBuffer.size() + mEntrySize );

    memcpy( &mBuffer[origSize], pdata, mEntrySize );

    MapKey  range = { begin, end };
    mMap.insert( PdataMap.value_type( range, origSize ) );
    return &mBuffer[origSize];
}

}


namespace  Mago
{
    struct  WalkContext
    {
        Mago.Thread*       Thread;
        PdataCache*         Cache;
        UniquePtr!(BYTE[])   TempEntry;
    };


    this.Thread()
    {   mDebugger = ( null );
            mCurPC = ( 0 );
            mCallerPC = ( 0 );
    }

    this.~Thread()
    {
    }


    ////////////////////////////////////////////////////////////////////////////// 
    // IDebugThread2 methods 

    HRESULT  Thread.SetThreadName( LPCOLESTR  pszName )
    { return  E_NOTIMPL;}
    HRESULT  Thread.GetName( BSTR* pbstrName )
    { return  E_NOTIMPL;} 

    HRESULT  Thread.GetProgram( IDebugProgram2** ppProgram )
    {
        if ( ppProgram  is  null )
            return  E_INVALIDARG;

        _ASSERT( mProg.Get() !is  null );
        return  mProg.QueryInterface( __uuidof( IDebugProgram2 ), cast(void **) ppProgram );
    }

    HRESULT  Thread.CanSetNextStatement( IDebugStackFrame2* pStackFrame, 
                                         IDebugCodeContext2* pCodeContext )
    {
        if ( pCodeContext  is  null )
            return  E_INVALIDARG;

        CComQIPtr<IMagoMemoryContext> magoMem = pCodeContext;
        if ( magoMem  is  null )
            return  E_INVALIDARG;

        return  S_OK;
    } 
    HRESULT  Thread.SetNextStatement( IDebugStackFrame2* pStackFrame, 
                                      IDebugCodeContext2* pCodeContext )
    {
        if ( pCodeContext  is  null )
            return  E_INVALIDARG;

        CComQIPtr<IMagoMemoryContext> magoMem = pCodeContext;
        if ( magoMem  is  null )
            return  E_INVALIDARG;

        Address64  addr = 0;
        magoMem.GetAddress( addr );
        if ( addr == mCurPC )
            return  S_OK;

        RefPtr<IRegisterSet>    topRegSet;

        HRESULT  hr = mDebugger.GetThreadContext( mProg.GetCoreProcess(), mCoreThread, topRegSet.Ref() );
        if ( FAILED( hr ) )
            return  hr;
        hr = topRegSet.SetPC( addr );
        if ( FAILED( hr ) )
            return  hr;

        hr = mDebugger.SetThreadContext( mProg.GetCoreProcess(), mCoreThread, topRegSet );
        return  hr;
    }

    HRESULT  Thread.Suspend( DWORD* pdwSuspendCount )
    { return  E_NOTIMPL;} 
    HRESULT  Thread.Resume( DWORD* pdwSuspendCount )
    { return  E_NOTIMPL;} 

    HRESULT  Thread.GetThreadProperties( THREADPROPERTY_FIELDS  dwFields, 
                                          THREADPROPERTIES* ptp )
    {
        if ( ptp  is  null )
            return  E_INVALIDARG;

        ptp.dwFields = 0;

        if ( (dwFields & TPF_ID) != 0 )
        {
            if ( mCoreThread.Get() !is  null )
            {
                ptp.dwThreadId = mCoreThread.GetTid();
                ptp.dwFields |= TPF_ID;
            }
        }

        if ( (dwFields & TPF_SUSPENDCOUNT) != 0 )
        {
        }

        if ( (dwFields & TPF_STATE) != 0 )
        {
        }

        if ( (dwFields & TPF_PRIORITY) != 0 )
        {
        }

        if ( (dwFields & TPF_NAME) != 0 )
        {
        }

        if ( (dwFields & TPF_LOCATION) != 0 )
        {
        }

        return  S_OK;
    }

    HRESULT  Thread.GetLogicalThread( IDebugStackFrame2* pStackFrame, 
                                       IDebugLogicalThread2** ppLogicalThread )
    {
        UNREFERENCED_PARAMETER( pStackFrame );
        UNREFERENCED_PARAMETER( ppLogicalThread );
        return  E_NOTIMPL;
    }

    HRESULT  Thread.GetThreadId( DWORD* pdwThreadId )
    {
        if ( pdwThreadId  is  null )
            return  E_INVALIDARG;

        if ( mCoreThread.Get() is  null )
            return  E_FAIL;

        *pdwThreadId = mCoreThread.GetTid();
        return  S_OK;
    }

    HRESULT  Thread.EnumFrameInfo( FRAMEINFO_FLAGS  dwFieldSpec, 
                                    UINT  nRadix, 
                                    IEnumDebugFrameInfo2** ppEnum )
    {
        if ( ppEnum  is  null )
            return  E_INVALIDARG;
        if ( dwFieldSpec == 0 )
            return  E_INVALIDARG;
        if ( nRadix == 0 )
            return  E_INVALIDARG;

        HRESULT                  hr = S_OK;
        Callstack                callstack;
        RefPtr<IRegisterSet>    topRegSet;

        hr = mDebugger.GetThreadContext( mProg.GetCoreProcess(), mCoreThread, topRegSet.Ref() );
        if ( FAILED( hr ) )
            return  hr;

        mCurPC = cast(Address64) topRegSet.GetPC();
        // in case we can't get the return address of top frame, 
        // make sure our StepOut method knows that we don't know the caller's PC
        mCallerPC = 0;

        hr = BuildCallstack( topRegSet, callstack );
        if ( FAILED( hr ) )
            return  hr;

        hr = MakeEnumFrameInfoFromCallstack( callstack, dwFieldSpec, nRadix, ppEnum );

        return  hr;
    }


    //------------------------------------------------------------------------

    ICoreThread* Thread.GetCoreThread()
    {
        return  mCoreThread.Get();
    }

    void  Thread.SetCoreThread( ICoreThread* thread )
    {
        mCoreThread = thread;
    }

    Program*    Thread.GetProgram()
    {
        return  mProg;
    }

    void  Thread.SetProgram( Program* prog, IDebuggerProxy* pollThread )
    {
        mProg = prog;
        mDebugger = pollThread;
    }

    ICoreProcess*   Thread.GetCoreProcess()
    {
        return  mProg.GetCoreProcess();
    }

    IDebuggerProxy* Thread.GetDebuggerProxy()
    {
        return  mDebugger;
    }

    HRESULT  Thread.Step( ICoreProcess* coreProc, STEPKIND  sk, STEPUNIT  step, bool  handleException )
    {
        _RPT1( _CRT_WARN, "Thread::Step (%d)\n", mCoreThread.GetTid() );

        if ( sk == STEP_BACKWARDS )
            return  E_NOTIMPL;

        // works for statements and instructions
        if ( sk == STEP_OUT )
            return  StepOut( coreProc, handleException );

        if ( step == STEP_INSTRUCTION )
            return  StepInstruction( coreProc, sk, handleException );

        if ( (step == STEP_STATEMENT) || (step == STEP_LINE) )
            return  StepStatement( coreProc, sk, handleException );

        return  E_NOTIMPL;
    }

    HRESULT  Thread.StepStatement( ICoreProcess* coreProc, STEPKIND  sk, bool  handleException )
    {
        _ASSERT( (sk == STEP_OVER) || (sk == STEP_INTO) );
        if ( (sk != STEP_OVER) && (sk != STEP_INTO) )
            return  E_NOTIMPL;

        HRESULT  hr = S_OK;
        bool     stepIn = (sk == STEP_INTO);
        RefPtr<Module>          mod;
        RefPtr<MagoST.ISession>    session;
        AddressRange64               addrRange = { 0 };
        MagoST.LineNumber       line;

        if ( !mProg.FindModuleContainingAddress( mCurPC, mod ) )
            return  E_NOT_FOUND;

        if ( !mod.GetSymbolSession( session ) )
            return  E_NOT_FOUND;

        uint16_t     sec = 0;
        uint32_t     offset = 0;
        sec = session.GetSecOffsetFromVA( mCurPC, offset );
        if ( sec == 0 )
            return  E_FAIL;

        if ( !session.FindLine( sec, offset, line ) )
            return  E_FAIL;

        UINT64   addrBegin = 0;
        DWORD    len = 0;

        addrBegin = session.GetVAFromSecOffset( sec, line.Offset );
        if( addrBegin == 0 )
            return  E_FAIL;
        len = line.Length;

        addrRange.Begin = cast(Address64) addrBegin;
        addrRange.End = cast(Address64) (addrBegin + len - 1);

        hr = mDebugger.StepRange( coreProc, stepIn, addrRange, handleException );

        return  hr;
    }

    HRESULT  Thread.StepInstruction( ICoreProcess* coreProc, STEPKIND  sk, bool  handleException )
    {
        _ASSERT( (sk == STEP_OVER) || (sk == STEP_INTO) );
        if ( (sk != STEP_OVER) && (sk != STEP_INTO) )
            return  E_NOTIMPL;

        HRESULT  hr = S_OK;
        bool     stepIn = (sk == STEP_INTO);

        hr = mDebugger.StepInstruction( coreProc, stepIn, handleException );

        return  hr;
    }

    HRESULT  Thread.StepOut( ICoreProcess* coreProc, bool  handleException )
    {
        HRESULT  hr = S_OK;
        Address64  targetAddr = mCallerPC;

        if ( targetAddr == 0 )
            return  E_FAIL;

        hr = mDebugger.StepOut( coreProc, targetAddr, handleException );

        return  hr;
    }


    //------------------------------------------------------------------------

    HRESULT  Thread.BuildCallstack( IRegisterSet* topRegSet, ref Callstack  callstack )
    {
        Log.LogMessage( "Thread::BuildCallstack\n" );

        HRESULT              hr = S_OK;
        int                  frameIndex = 0;
        ArchData*           archData = null;
        StackWalker*        pWalker = null;
        UniquePtr<StackWalker> walker;
        WalkContext          walkContext;
        int                  pdataSize = 0;

        archData = mProg.GetCoreProcess().GetArchData();
        pdataSize = archData.GetPDataSize();

        PdataCache           pdataCache = PdataCache( pdataSize );

        walkContext.Thread = this;
        walkContext.Cache = &pdataCache;
        walkContext.TempEntry.Attach( new  BYTE[pdataSize] );

        if ( walkContext.TempEntry.IsEmpty() )
            return  E_OUTOFMEMORY;

        hr = AddCallstackFrame( topRegSet, callstack );
        if ( FAILED( hr ) )
            return  hr;

        hr = archData.BeginWalkStack( 
            topRegSet,
            &walkContext,
            ReadProcessMemory64,
            FunctionTableAccess64,
            GetModuleBase64,
            pWalker );
        if ( FAILED( hr ) )
            return  hr;

        walker.Attach( pWalker );
        // walk past the first frame, because we have it already
        walker.WalkStack();

        while ( walker.WalkStack() )
        {
            RefPtr<IRegisterSet> regSet;
            UINT64               addr = 0;
            const(void) *         context = null;
            uint32_t             contextSize = 0;

            walker.GetThreadContext( context, contextSize );

            if ( frameIndex == 0 )
                hr = archData.BuildRegisterSet( context, contextSize, regSet.Ref() );
            else
                 hr = archData.BuildTinyRegisterSet( context, contextSize, regSet.Ref() );

            if ( FAILED( hr ) )
                return  hr;

            addr = regSet.GetPC();

            // if we haven't gotten the first return address, then do so now
            if ( frameIndex == 0 )
                mCallerPC = cast(Address64) addr;

            hr = AddCallstackFrame( regSet, callstack );
            if ( FAILED( hr ) )
                return  hr;

            frameIndex++;
        }

        return  S_OK;
    }

    BOOL  Thread.ReadProcessMemory64(
      HANDLE  hProcess,
      DWORD64  lpBaseAddress,
      PVOID  lpBuffer,
      DWORD  nSize,
      LPDWORD  lpNumberOfBytesRead
    )
    {
        _ASSERT( hProcess !is  null );
        WalkContext*    walkContext = cast(WalkContext*) hProcess;
        Thread*         pThis = walkContext.Thread;

        HRESULT      hr = S_OK;
        uint32_t     lenRead = 0;
        uint32_t     lenUnreadable = 0;
        RefPtr<ICoreProcess>    proc;

        pThis.mProg.GetCoreProcess( proc.Ref() );

        hr = pThis.mDebugger.ReadMemory( 
            proc.Get(), 
            cast(Address64) lpBaseAddress, 
            nSize, 
            lenRead, 
            lenUnreadable, 
            cast(uint8_t*) lpBuffer );
        if ( FAILED( hr ) )
            return  FALSE;

        *lpNumberOfBytesRead = lenRead;

        return  TRUE;
    }

    PVOID  Thread.FunctionTableAccess64(
      HANDLE  hProcess,
      DWORD64  addrBase
    )
    {
        _ASSERT( hProcess !is  null );

        HRESULT          hr = S_OK;
        WalkContext*    walkContext = cast(WalkContext*) hProcess;
        Thread*         pThis = walkContext.Thread;
        ArchData*       archData = pThis.GetCoreProcess().GetArchData();
        uint32_t         size = 0;
        int              pdataSize = archData.GetPDataSize();
        void *           pdata = null;

        if ( pdataSize == 0 )
            return  null;

        pdata = walkContext.Cache.Find( addrBase );
        if ( pdata !is  null )
            return  pdata;

        RefPtr<Module>      mod;

        if ( !pThis.mProg.FindModuleContainingAddress( cast(Address64) addrBase, mod ) )
            return  null;

        IDebuggerProxy* debugger = pThis.GetDebuggerProxy();

        hr = debugger.GetPData( 
            pThis.GetCoreProcess(), addrBase, mod.GetAddress(), pdataSize, size, 
            walkContext.TempEntry.Get() );
        if ( hr != S_OK )
            return  null;

        Address64    begin;
        Address64    end;

        pThis.GetCoreProcess().GetArchData().GetPDataRange( 
            mod.GetAddress(), walkContext.TempEntry.Get(), begin, end );

        pdata = walkContext.Cache.Add( begin, end, walkContext.TempEntry.Get() );
        return  pdata;
    }

    DWORD64  Thread.GetModuleBase64(
      HANDLE  hProcess,
      DWORD64  address
    )
    {
        _ASSERT( hProcess !is  null );
        WalkContext*    walkContext = cast(WalkContext*) hProcess;
        Thread*         pThis = walkContext.Thread;

        RefPtr<Module>      mod;

        if ( !pThis.mProg.FindModuleContainingAddress( cast(Address64) address, mod ) )
            return  0;

        return  mod.GetAddress();
    }

    HRESULT  Thread.AddCallstackFrame( IRegisterSet* regSet, ref Callstack  callstack )
    {
        HRESULT              hr = S_OK;
        const  Address64      addr = cast(Address64) regSet.GetPC();
        RefPtr<Module>      mod;
        RefPtr<StackFrame>  stackFrame;
        ArchData*           archData = null;

        mProg.FindModuleContainingAddress( addr, mod );

        hr = MakeCComObject( stackFrame );
        if ( FAILED( hr ) )
            return  hr;

        archData = mProg.GetCoreProcess().GetArchData();

        stackFrame.Init( addr, regSet, this, mod.Get(), archData.GetPointerSize() );

        callstack.push_back( stackFrame );

        return  hr;
    }

    HRESULT  Thread.MakeEnumFrameInfoFromCallstack( 
        ref const  Callstack  callstack,
        FRAMEINFO_FLAGS  dwFieldSpec, 
        UINT  nRadix, 
        IEnumDebugFrameInfo2** ppEnum )
    {
        _ASSERT( ppEnum !is  null );
        _ASSERT( dwFieldSpec != 0 );
        _ASSERT( nRadix != 0 );

        HRESULT  hr = S_OK;
        FrameInfoArray   array = FrameInfoArray( callstack.size() );
        RefPtr<EnumDebugFrameInfo>  enumFrameInfo;
        int  i = 0;

        for ( Callstack.const_iterator  it = callstack.begin();
            it != callstack.end();
            it++, i++ )
        {
            hr = (*it).GetInfo( dwFieldSpec, nRadix, &array[i] );
            if ( FAILED( hr ) )
                return  hr;
        }

        hr = MakeCComObject( enumFrameInfo );
        if ( FAILED( hr ) )
            return  hr;

        hr = enumFrameInfo.Init( array.Get(), array.Get() + array.GetLength(), null, AtlFlagTakeOwnership );
        if ( FAILED( hr ) )
            return  hr;

        array.Detach();
        return  enumFrameInfo.QueryInterface( __uuidof( IEnumDebugFrameInfo2 ), cast(void **) ppEnum );
    }
}
