module Program_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import Program;
import IDebuggerProxy;
import Thread;
import Module;
import ComEnumWithCount;

import Engine;
import PendingBreakpoint;

import MemoryBytes;
import CodeContext;
import DisassemblyStream;
import DRuntime;
import ArchData;
import ICoreProcess;
// #include <algorithm>


alias  
     
     /* SYNTAX ERROR: (29): expected <identifier> instead of & */  
     
    
    


alias  
     
     /* SYNTAX ERROR: (37): expected <identifier> instead of & */  
     
    
    


alias  
     
     /* SYNTAX ERROR: (45): expected <identifier> instead of & */  
     
     
    



namespace  Mago
{
    // Program

    this.Program()
    {   mProgId = ( GUID_NULL );
        mAttached = ( false );
        mPassExceptionToDebuggee = ( true );
        mCanPassExceptionToDebuggee = ( true );
        mDebugger = ( null );
        mNextModLoadIndex = ( 0 );
        mEntryPoint = ( 0 );
    }

    this.~Program()
    {
    }


    ////////////////////////////////////////////////////////////////////////////// 
    // IDebugProgram2 methods

    HRESULT  Program.EnumThreads( IEnumDebugThreads2** ppEnum )
    {
        GuardedArea  guard = GuardedArea( mThreadGuard );
        return  MakeEnumWithCount<
            EnumDebugThreads, 
            IEnumDebugThreads2, 
            ThreadMap, 
            IDebugThread2>( mThreadMap, ppEnum );
    }

    HRESULT  Program.GetName( BSTR* pbstrName )
    {
        if ( pbstrName  is  null )
            return  E_INVALIDARG;

        *pbstrName = mName.Copy();
        return *pbstrName !is  null ? S_OK : E_OUTOFMEMORY;
    }

    HRESULT  Program.GetProcess( IDebugProcess2** ppProcess )
    {
        return  mProcess.CopyTo( ppProcess );
    }

    HRESULT  Program.Terminate()
    {
        HRESULT  hr = S_OK;

        hr = mDebugger.Terminate( mCoreProc.Get() );
        _ASSERT( hr == S_OK );

        return  hr;
    }

    HRESULT  Program.Attach( IDebugEventCallback2* pCallback )
    { return  E_NOTIMPL; } 
    HRESULT  Program.Detach()
    { return  E_NOTIMPL; } 
    HRESULT  Program.GetDebugProperty( IDebugProperty2** ppProperty )
    { return  E_NOTIMPL; } 

    HRESULT  Program.CauseBreak()
    {
        HRESULT  hr = S_OK;

        hr = mDebugger.AsyncBreak( mCoreProc.Get() );

        return  hr;
    }

    HRESULT  Program.GetEngineInfo( BSTR* pbstrEngine, GUID* pguidEngine )
    {
        if ( (pbstrEngine  is  null) || (pguidEngine  is  null) )
            return  E_INVALIDARG;

        *pbstrEngine = SysAllocString( .GetEngineName() );
        *pguidEngine = .GetEngineId();
        return *pbstrEngine !is  null ? S_OK : E_OUTOFMEMORY;
    }

    HRESULT  Program.EnumCodeContexts( IDebugDocumentPosition2* pDocPos, 
                                       IEnumDebugCodeContexts2** ppEnum )
    {
        if ( (pDocPos  is  null) || (ppEnum  is  null) )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;
        CComBSTR                 bstrFileName;
        CAutoVectorPtr<char>    u8FileName;
        size_t                   u8FileNameLen = 0;
        TEXT_POSITION            startPos = { 0 };
        TEXT_POSITION            endPos = { 0 };
        std.list<AddressBinding>   bindings;
        ArchData*               archData = null;
        uint32_t                 ptrSize = 0;

        archData = mCoreProc.GetArchData();
        ptrSize = archData.GetPointerSize();

        hr = pDocPos.GetFileName( &bstrFileName );
        if ( FAILED( hr ) )
            return  hr;

        hr = pDocPos.GetRange( &startPos, &endPos );
        if ( FAILED( hr ) )
            return  hr;

        // AD7 lines are 0-based, DIA/CV ones are 1-based
        startPos.dwLine++;
        endPos.dwLine++;

        hr = Utf16To8( bstrFileName, bstrFileName.Length(), u8FileName.m_p, u8FileNameLen );
        if ( FAILED( hr ) )
            return  hr;

        bool     foundExact = BindCodeContextsToFile( 
            true, 
            u8FileName, 
            u8FileNameLen, 
            cast(uint16_t) startPos.dwLine, 
            cast(uint16_t) endPos.dwLine, 
            bindings );

        if ( !foundExact )
            foundExact = BindCodeContextsToFile( 
            false, 
            u8FileName, 
            u8FileNameLen, 
            cast(uint16_t) startPos.dwLine, 
            cast(uint16_t) endPos.dwLine, 
            bindings );

        InterfaceArray<IDebugCodeContext2>  codeContextArray( bindings.size() );
        int  i = 0;

        if ( codeContextArray.Get() is  null )
            return  E_OUTOFMEMORY;

        for ( std.list<AddressBinding>.iterator  /* SYNTAX ERROR: (193): expected ; instead of it */  it = bindings.begin();
            it != bindings.end();
            it++, i++ )
        {
            RefPtr<CodeContext> codeContext;

            hr = MakeCComObject( codeContext );
            if ( FAILED( hr ) )
                return  hr;

            hr = codeContext.Init( cast(Address64) it.Addr, it.Mod, null, ptrSize );
            if ( FAILED( hr ) )
                return  hr;

            codeContext.QueryInterface( __uuidof( IDebugCodeContext2 ), cast(void **) &codeContextArray[i] );
        }

        return  MakeEnumWithCount<EnumDebugCodeContexts>( codeContextArray, ppEnum );
    }

    bool  Program.BindCodeContextsToFile( 
        bool  exactMatch, 
        const(char) * fileName, 
        size_t  fileNameLen, 
        uint16_t  reqLineStart, 
        uint16_t  reqLineEnd,
        ref std.list!(AddressBinding)  bindings )
    {
        GuardedArea  guard = GuardedArea( mModGuard );

        for ( ModuleMap.iterator  it = mModMap.begin();
            it != mModMap.end();
            it++ )
        {
            RefPtr<MagoST.ISession>    session;
            Module*                     mod = it.second;

            if ( !mod.GetSymbolSession( session ) )
                continue;

            std.list<MagoST.LineNumber> lines;
            if( !session.FindLines( exactMatch, fileName, fileNameLen, reqLineStart, reqLineEnd, lines ) )
                continue;

            for( std.list<MagoST.LineNumber>.iterator  /* SYNTAX ERROR: (237): expected ; instead of it */  it = lines.begin(); it != lines.end(); ++it )
            {
                MagoEE.Address  addr = session.GetVAFromSecOffset( it.Section, it.Offset );
                if ( addr == 0 )
                    continue;
                bindings.push_back( AddressBinding() );
                bindings.back().Addr = addr;
                bindings.back().Mod = mod;
            }
        }

        return  bindings.size() > 0;
    }

    HRESULT  Program.GetMemoryBytes( IDebugMemoryBytes2** ppMemoryBytes )
    {
        if ( ppMemoryBytes  is  null )
            return  E_INVALIDARG;
        if ( mProgMod  is  null )
            return  E_FAIL;

        HRESULT  hr = S_OK;
        Address64    addr = mProgMod.GetAddress();
        DWORD    size = mProgMod.GetSize();
        RefPtr<MemoryBytes> memBytes;

        hr = MakeCComObject( memBytes );
        if ( FAILED( hr ) )
            return  hr;

        memBytes.Init( addr, size, mDebugger, mCoreProc );

        *ppMemoryBytes = memBytes.Detach();
        return  S_OK;
    }

    HRESULT  Program.GetDisassemblyStream( DISASSEMBLY_STREAM_SCOPE  dwScope, 
                                           IDebugCodeContext2* pCodeContext, 
                                           IDebugDisassemblyStream2** ppDisassemblyStream )
    {
        if ( (pCodeContext  is  null) || (ppDisassemblyStream  is  null) )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;
        Address64                        addr = 0;
        RefPtr<DisassemblyStream>       stream;
        RefPtr<Module>                  mod;
        CComQIPtr<IMagoMemoryContext>   magoMem = pCodeContext;

        if ( magoMem  is  null )
            return  E_INVALIDARG;

        magoMem.GetAddress( addr );

        _RPT2( _CRT_WARN, "Program::GetDisassemblyStream: addr=%08X scope=%X\n", addr, dwScope );

        if ( !FindModuleContainingAddress( addr, mod ) )
            return  HRESULT_FROM_WIN32( ERROR_MOD_NOT_FOUND );

        hr = MakeCComObject( stream );
        if ( FAILED( hr ) )
            return  hr;

        hr = stream.Init( dwScope, addr, this, mDebugger );
        if ( FAILED( hr ) )
            return  hr;

        *ppDisassemblyStream = stream.Detach();
        return  S_OK;
    }

    HRESULT  Program.EnumModules( IEnumDebugModules2** ppEnum )
    {
        GuardedArea  guard = GuardedArea( mModGuard );
        return  MakeEnumWithCount<
            EnumDebugModules, 
            IEnumDebugModules2, 
            ModuleMap, 
            IDebugModule2>( mModMap, ppEnum );
    }

    HRESULT  Program.GetENCUpdate( IDebugENCUpdate** ppUpdate )
    { return  E_NOTIMPL; } 
    HRESULT  Program.EnumCodePaths( LPCOLESTR  pszHint, 
                                    IDebugCodeContext2* pStart, 
                                    IDebugStackFrame2* pFrame, 
                                    BOOL  fSource, 
                                    IEnumCodePaths2** ppEnum, 
                                    IDebugCodeContext2** ppSafety )
    { return  E_NOTIMPL; } 
    HRESULT  Program.WriteDump( DUMPTYPE  DumpType,LPCOLESTR  pszCrashDumpUrl )
    { return  E_NOTIMPL; } 
    HRESULT  Program.CanDetach()
    { return  E_NOTIMPL; } 

    HRESULT  Program.GetProgramId( GUID* pguidProgramId )
    {
        if ( pguidProgramId  is  null )
            return  E_INVALIDARG;

        *pguidProgramId = mProgId;
        return  S_OK; 
    } 

    HRESULT  Program.Execute()
    {
        return  mDebugger.Execute( GetCoreProcess(), !mPassExceptionToDebuggee );
    }

    HRESULT  Program.Continue( IDebugThread2 *pThread )
    {
        return  mDebugger.Continue( GetCoreProcess(), !mPassExceptionToDebuggee );
    }

    HRESULT  Program.Step( IDebugThread2 *pThread, STEPKIND  sk, STEPUNIT  step )
    {
        if ( pThread  is  null )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;

        hr = StepInternal( pThread, sk, step );
        if ( FAILED( hr ) )
        {
            hr = mDebugger.Execute( GetCoreProcess(), !mPassExceptionToDebuggee );
        }

        return  hr;
    }

    HRESULT  Program.StepInternal( IDebugThread2* pThread, STEPKIND  sk, STEPUNIT  step )
    {
        _ASSERT( pThread !is  null );

        HRESULT          hr = S_OK;
        DWORD            threadId = 0;
        RefPtr<Thread>  thread;

        // another way to do this is to use a private interface
        hr = pThread.GetThreadId( &threadId );
        if ( FAILED( hr ) )
            return  hr;

        if ( !FindThread( threadId, thread ) )
            return  E_NOT_FOUND;

        hr = thread.Step( mCoreProc.Get(), sk, step, !mPassExceptionToDebuggee );

        return  hr;
    }


    //----------------------------------------------------------------------------

    void  Program.Dispose()
    {
        mThreadMap.clear();

        for ( ModuleMap.iterator  it = mModMap.begin(); it != mModMap.end(); it++ )
        {
            it.second.Dispose();
        }

        mModMap.clear();

        mProgThread.Release();
        mProgMod.Release();
        mEngine.Release();
    }

    void         Program.SetEngine( Engine* engine )
    {
        mEngine = engine;
    }

    ICoreProcess*   Program.GetCoreProcess()
    {
        return  mCoreProc.Get();
    }

    void         Program.GetCoreProcess( ref ICoreProcess*  proc )
    {
        proc = mCoreProc.Get();
        proc.AddRef();
    }

    void  Program.SetCoreProcess( ICoreProcess* proc )
    {
        mCoreProc = proc;
    }

    void  Program.SetProcess( IDebugProcess2* proc )
    {
        mProcess = proc;

        proc.GetName( GN_NAME, &mName );
    }

    IDebugEventCallback2*   Program.GetCallback()
    {
        return  mCallback;
    }

    void  Program.SetCallback( IDebugEventCallback2* callback )
    {
        mCallback = callback;
    }

    void  Program.SetPortSettings( IDebugProgram2* portProgram )
    {
        HRESULT  hr = S_OK;

        hr = portProgram.GetProgramId( &mProgId );
        _ASSERT( hr == S_OK );
    }

    IDebuggerProxy* Program.GetDebuggerProxy()
    {
        return  mDebugger;
    }

    void  Program.SetDebuggerProxy( IDebuggerProxy* debugger )
    {
        mDebugger = debugger;
    }

    DRuntime* Program.GetDRuntime()
    {
        return  mDRuntime.Get();
    }

    bool  FindGlobalSymbolAddress( Module* mainMod, const(char) * symbol, ref Address64  symaddr );

    void  Program.SetDRuntime( ref UniquePtr!(DRuntime)  druntime )
    {
        mDRuntime.Attach( null );
        mDRuntime.Swap( druntime );

        if ( mDRuntime && mDebugger && mCoreProc )
        {
            GuardedArea  guard = GuardedArea( mModGuard );

            for ( ModuleMap.iterator  it = mModMap.begin(); it != mModMap.end(); it++ )
                UpdateAAVersion( it.second );
        }
    }

    void  Program.UpdateAAVersion( Module* mod )
    {
        if ( mDRuntime && mDebugger && mCoreProc )
        {
            Address64  addr;
            uint32_t  read, unreadable, ver;
            if ( FindGlobalSymbolAddress( mod, "__aaVersion", addr ) )
            {
                if ( mDebugger.ReadMemory( mCoreProc, addr, 4, read, unreadable, cast(uint8_t*) &ver ) == S_OK )
                    mDRuntime.SetAAVersion( ver );
            }
            else  if ( FindGlobalSymbolAddress( mod, "_D2rt3aaA11fakeEntryTIFxC8TypeInfoxC8TypeInfoZC15TypeInfo_Struct", addr ) )
                mDRuntime.SetAAVersion( 1 );

            if ( FindGlobalSymbolAddress( mod, "_D14TypeInfo_Class6__vtblZ", addr ) )
                mDRuntime.SetClassInfoVtblAddr( addr );
        }
    }

    bool  Program.GetAttached()
    {
        return  mAttached;
    }

    void  Program.SetAttached()
    {
        mAttached = true;
    }

    void  Program.SetPassExceptionToDebuggee( bool  value )
    {
        if ( mCanPassExceptionToDebuggee )
            mPassExceptionToDebuggee = value;
    }

    bool  Program.CanPassExceptionToDebuggee()
    {
        return  mCanPassExceptionToDebuggee;
    }

    void  Program.NotifyException( bool  firstChance, const  EXCEPTION_RECORD64* exceptRec )
    {
        if ( exceptRec.ExceptionCode == EXCEPTION_BREAKPOINT )
        {
            mCanPassExceptionToDebuggee = false;
            mPassExceptionToDebuggee = false;
        }
        else
        {
            mCanPassExceptionToDebuggee = firstChance;
            mPassExceptionToDebuggee = firstChance;
        }
    }

    HRESULT  Program.CreateThread( ICoreThread* coreThread, ref RefPtr!(Thread)  thread )
    {
        HRESULT  hr = S_OK;

        hr = MakeCComObject( thread );
        if ( FAILED( hr ) )
            return  hr;

        thread.SetCoreThread( coreThread );

        return  hr;
    }

    HRESULT  Program.AddThread( Thread* thread )
    {
        GuardedArea  guard = GuardedArea( mThreadGuard );
        DWORD    id = 0;

        thread.GetThreadId( &id );
        if ( id == 0 )
            return  E_FAIL;

        if ( mProgThread  is  null )
            mProgThread = thread;

        ThreadMap.iterator  it = mThreadMap.find( id );

        if ( it != mThreadMap.end() )
            return  E_FAIL;

        thread.SetProgram( this, mDebugger );

        mThreadMap.insert( ThreadMap.value_type( id, thread ) );

        return  S_OK;
    }

    bool     Program.FindThread( DWORD  threadId, ref RefPtr!(Thread)  thread )
    {
        GuardedArea  guard = GuardedArea( mThreadGuard );
        ThreadMap.iterator  it = mThreadMap.find( threadId );

        if ( it == mThreadMap.end() )
            return  false;

        thread = it.second;
        return  true;
    }

    void  Program.DeleteThread( Thread* thread )
    {
        GuardedArea  guard = GuardedArea( mThreadGuard );
        mThreadMap.erase( thread.GetCoreThread().GetTid() );
    }

    Address64  Program.FindEntryPoint()
    {
        if ( mProgThread  is  null )
            return  0;

        return  mProgThread.GetCoreThread().GetStartAddr();
    }

    HRESULT  Program.CreateModule( ICoreModule* coreModule, ref RefPtr!(Module)  mod )
    {
        HRESULT  hr = S_OK;

        hr = MakeCComObject( mod );
        if ( FAILED( hr ) )
            return  hr;

        mod.SetId( mEngine.GetNextModuleId() );
        mod.SetCoreModule( coreModule );

        return  hr;
    }

    HRESULT  Program.AddModule( Module* mod )
    {
        GuardedArea  guard = GuardedArea( mModGuard );
        Address64  addr = 0;

        addr = mod.GetAddress();
        if ( addr == 0 )
            return  E_FAIL;

        if ( mProgMod  is  null )
            mProgMod = mod;

        ModuleMap.iterator  it = mModMap.find( addr );

        if ( it != mModMap.end() )
            return  E_FAIL;

        mModMap.insert( ModuleMap.value_type( addr, mod ) );

        DWORD    index = mNextModLoadIndex++;

        mod.SetLoadIndex( index );

        return  S_OK;
    }

    bool     Program.FindModule( Address64  addr, ref RefPtr!(Module)  mod )
    {
        GuardedArea  guard = GuardedArea( mModGuard );
        ModuleMap.iterator  it = mModMap.find( addr );

        if ( it == mModMap.end() )
            return  false;

        mod = it.second;
        return  true;
    }

    bool     Program.FindModuleContainingAddress( Address64  address, ref RefPtr!(Module)  refMod )
    {
        GuardedArea  guard = GuardedArea( mModGuard );

        for ( ModuleMap.iterator  it = mModMap.begin();
            it != mModMap.end();
            it++ )
        {
            Module*         mod = it.second.Get();
            Address64        base = mod.GetAddress();
            Address64        limit = base + mod.GetSize();

            if ( (base <= address) && (limit > address) )
            {
                refMod = mod;
                return  true;
            }
        }

        return  false;
    }

    void  Program.DeleteModule( Module* mod )
    {
        GuardedArea  guard = GuardedArea( mModGuard );

        // no need to decrement the load index of all modules after that deleted one

        mModMap.erase( mod.GetAddress() );

        mod.Dispose();
    }

    void  Program.ForeachModule( ModuleCallback* callback )
    {
        GuardedArea  guard = GuardedArea( mModGuard );

        for ( ModuleMap.iterator  it = mModMap.begin();
            it != mModMap.end();
            it++ )
        {
            if ( !callback.AcceptModule( it.second.Get() ) )
                break;
        }
    }


    HRESULT  Program.SetInternalBreakpoint( Address64  address, BPCookie  cookie )
    {
        HRESULT  hr = S_OK;

        {
            GuardedArea  guard = GuardedArea( mBPGuard );

            BPMap.iterator  itVec = mBPMap.find( address );

            if ( itVec != mBPMap.end() )
            {
                // There's at least one cookie for this address already.
                // So, add this one if needed, and leave, because the BP is already set.
                CookieVec& vec = itVec.second;
                CookieVec.iterator  itCookie = std.find( vec.begin(), vec.end(), cookie );
                if ( itCookie == vec.end() )
                    vec.push_back( cookie );

                return  S_OK;
            }
        }

        // You can deadlock with the event callback, if you set a BP while the BP table is locked.
        hr = mDebugger.SetBreakpoint( mCoreProc, address );
        if ( FAILED( hr ) )
            return  hr;

        // check everything again, in case anything changed since the last time we locked the table
        {
            GuardedArea  guard = GuardedArea( mBPGuard );

            BPMap.iterator  itVec = mBPMap.find( address );

            if ( itVec == mBPMap.end() )
            {
                std.pair<BPMap.iterator, bool> pair =
                    mBPMap.insert( BPMap.value_type( address, std.vector<BPCookie>( /* SYNTAX ERROR: (736): expression expected, not ) */ ) ) );

                itVec = pair.first;
                itVec.second.push_back( cookie );
            }
            else
            {
                CookieVec& vec = itVec.second;
                CookieVec.iterator  itCookie = std.find( vec.begin(), vec.end(), cookie );
                if ( itCookie == vec.end() )
                    vec.push_back( cookie );
            }
        }

        return  S_OK;
    }

    HRESULT  Program.RemoveInternalBreakpoint( Address64  address, BPCookie  cookie )
    {
        HRESULT  hr = S_OK;

        {
            GuardedArea  guard = GuardedArea( mBPGuard );

            BPMap.iterator  itVec = mBPMap.find( address );
            if ( itVec == mBPMap.end() )
                return  S_OK;

            CookieVec& vec = itVec.second;
            CookieVec.iterator  itCookie = std.find( vec.begin(), vec.end(), cookie );
            if ( itCookie == vec.end() )
                return  S_OK;

            // Clear the BP only when all cookies are gone. There are others, so remove this one only.
            if ( vec.size() > 1 )
            {
                vec.erase( itCookie );
                return  S_OK;
            }
        }

        // You can deadlock with the event callback, if you clear a BP while the BP table is locked.
        hr = mDebugger.RemoveBreakpoint( mCoreProc, address );
        if ( FAILED( hr ) )
            return  hr;

        // check everything again, in case anything changed since the last time we locked the table
        {
            GuardedArea  guard = GuardedArea( mBPGuard );

            BPMap.iterator  itVec = mBPMap.find( address );
            if ( itVec == mBPMap.end() )
                return  S_OK;

            CookieVec& vec = itVec.second;
            CookieVec.iterator  itCookie = std.find( vec.begin(), vec.end(), cookie );
            if ( itCookie == vec.end() )
                return  S_OK;

            vec.erase( itCookie );

            if ( vec.size() == 0 )
            {
                mBPMap.erase( itVec );
            }
        }

        return  S_OK;
    }

    HRESULT  Program.EnumBPCookies( Address64  address, ref std.vector!( BPCookie )  iter )
    {
        GuardedArea  guard = GuardedArea( mBPGuard );

        iter.clear();

        BPMap.iterator  itVec = mBPMap.find( address );
        if ( itVec == mBPMap.end() )
            return  S_OK;

        CookieVec& vec = itVec.second;
        iter.reserve( vec.size() );

        for ( CookieVec.iterator  it = vec.begin(); it != vec.end(); it++ )
        {
            iter.push_back( *it );
        }

        return  S_OK;
    }

    Address64  Program.GetEntryPoint()
    {
        return  mEntryPoint;
    }

    void  Program.SetEntryPoint( Address64  address )
    {
        mEntryPoint = address;
    }
}
