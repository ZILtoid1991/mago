module DebuggerProxy_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import DebuggerProxy;
import ArchDataX86;
import RegisterSet;
import __.Exec.DebuggerProxy;
import EventCallback;
import LocalProcess;


namespace  Mago
{
    this.DebuggerProxy()
    {
    }

    this.~DebuggerProxy()
    {
        Shutdown();
    }

    HRESULT  DebuggerProxy.Init( EventCallback* callback )
    {
        _ASSERT( callback !is  null );
        if ( (callback  is  null) )
            return  E_INVALIDARG;

        HRESULT      hr = S_OK;

        mCallback = callback;

        hr = CacheSystemInfo();
        if ( FAILED( hr ) )
            return  hr;

        hr = mExecThread.Init( this );
        if ( FAILED( hr ) )
            return  hr;

        return  S_OK;
    }

    HRESULT  DebuggerProxy.Start()
    {
        return  mExecThread.Start();
    }

    void  DebuggerProxy.Shutdown()
    {
        mExecThread.Shutdown();
    }

    HRESULT  DebuggerProxy.CacheSystemInfo()
    {
        mArch = new  ArchDataX86();
        if ( mArch.Get() is  null )
            return  E_OUTOFMEMORY;

        return  S_OK;
    }


//----------------------------------------------------------------------------
// Commands
//----------------------------------------------------------------------------

    HRESULT  DebuggerProxy.Launch( LaunchInfo* launchInfo, ref ICoreProcess*  process )
    {
        HRESULT                  hr = S_OK;
        RefPtr<IProcess>        execProc;
        RefPtr<LocalProcess>    coreProc;

        coreProc = new  LocalProcess( mArch );
        if ( coreProc.Get() is  null )
            return  E_OUTOFMEMORY;

        hr = mExecThread.Launch( launchInfo, execProc.Ref() );
        if ( FAILED( hr ) )
            return  hr;

        coreProc.Init( execProc );
        process = coreProc.Detach();

        return  S_OK;
    }

    HRESULT  DebuggerProxy.Attach( uint32_t  id, ref ICoreProcess*  process )
    {
        HRESULT                  hr = S_OK;
        RefPtr<IProcess>        execProc;
        RefPtr<LocalProcess>    coreProc;

        coreProc = new  LocalProcess( mArch );
        if ( coreProc.Get() is  null )
            return  E_OUTOFMEMORY;

        hr = mExecThread.Attach( id, execProc.Ref() );
        if ( FAILED( hr ) )
            return  hr;

        coreProc.Init( execProc );
        process = coreProc.Detach();

        return  S_OK;
    }

    HRESULT  DebuggerProxy.Terminate( ICoreProcess* process )
    {
        if ( process.GetProcessType() != CoreProcess_Local )
            return  E_FAIL;

        IProcess* execProc = (cast(LocalProcess*) process).GetExecProcess();

        return  mExecThread.Terminate( execProc );
    }

    HRESULT  DebuggerProxy.Detach( ICoreProcess* process )
    {
        if ( process.GetProcessType() != CoreProcess_Local )
            return  E_FAIL;

        IProcess* execProc = (cast(LocalProcess*) process).GetExecProcess();

        return  mExecThread.Detach( execProc );
    }

    HRESULT  DebuggerProxy.ResumeLaunchedProcess( ICoreProcess* process )
    {
        if ( process.GetProcessType() != CoreProcess_Local )
            return  E_FAIL;

        IProcess* execProc = (cast(LocalProcess*) process).GetExecProcess();

        return  mExecThread.ResumeLaunchedProcess( execProc );
    }

    HRESULT  DebuggerProxy.ReadMemory( 
        ICoreProcess* process, 
        Address64  address,
        uint32_t  length, 
        ref uint32_t  lengthRead, 
        ref uint32_t  lengthUnreadable, 
        uint8_t* buffer )
    {
        if ( process.GetProcessType() != CoreProcess_Local )
            return  E_FAIL;

        IProcess* execProc = (cast(LocalProcess*) process).GetExecProcess();

        return  mExecThread.ReadMemory( 
            execProc, 
            cast(Address) address, 
            length, 
            lengthRead, 
            lengthUnreadable, 
            buffer );
    }

    HRESULT  DebuggerProxy.WriteMemory( 
        ICoreProcess* process, 
        Address64  address,
        uint32_t  length, 
        ref uint32_t  lengthWritten, 
        uint8_t* buffer )
    {
        if ( process.GetProcessType() != CoreProcess_Local )
            return  E_FAIL;

        IProcess* execProc = (cast(LocalProcess*) process).GetExecProcess();

        return  mExecThread.WriteMemory( 
            execProc, 
            cast(Address) address, 
            length, 
            lengthWritten, 
            buffer );
    }

    HRESULT  DebuggerProxy.SetBreakpoint( ICoreProcess* process, Address64  address )
    {
        if ( process.GetProcessType() != CoreProcess_Local )
            return  E_FAIL;

        IProcess* execProc = (cast(LocalProcess*) process).GetExecProcess();

        return  mExecThread.SetBreakpoint( execProc, cast(Address) address );
    }

    HRESULT  DebuggerProxy.RemoveBreakpoint( ICoreProcess* process, Address64  address )
    {
        if ( process.GetProcessType() != CoreProcess_Local )
            return  E_FAIL;

        IProcess* execProc = (cast(LocalProcess*) process).GetExecProcess();

        return  mExecThread.RemoveBreakpoint( execProc, cast(Address) address );
    }

    HRESULT  DebuggerProxy.StepOut( ICoreProcess* process, Address64  targetAddr, bool  handleException )
    {
        if ( process.GetProcessType() != CoreProcess_Local )
            return  E_FAIL;

        IProcess* execProc = (cast(LocalProcess*) process).GetExecProcess();

        return  mExecThread.StepOut( execProc, cast(Address) targetAddr, handleException );
    }

    HRESULT  DebuggerProxy.StepInstruction( ICoreProcess* process, bool  stepIn, bool  handleException )
    {
        if ( process.GetProcessType() != CoreProcess_Local )
            return  E_FAIL;

        IProcess* execProc = (cast(LocalProcess*) process).GetExecProcess();

        return  mExecThread.StepInstruction( execProc, stepIn, handleException );
    }

    HRESULT  DebuggerProxy.StepRange( 
        ICoreProcess* process, bool  stepIn, AddressRange64  range, bool  handleException )
    {
        if ( process.GetProcessType() != CoreProcess_Local )
            return  E_FAIL;

        IProcess* execProc = (cast(LocalProcess*) process).GetExecProcess();
        AddressRange         range32 = { cast(Address) range.Begin, cast(Address) range.End };

        return  mExecThread.StepRange( execProc, stepIn, range32, handleException );
    }

    HRESULT  DebuggerProxy.Continue( ICoreProcess* process, bool  handleException )
    {
        if ( process.GetProcessType() != CoreProcess_Local )
            return  E_FAIL;

        IProcess* execProc = (cast(LocalProcess*) process).GetExecProcess();

        return  mExecThread.Continue( execProc, handleException );
    }

    HRESULT  DebuggerProxy.Execute( ICoreProcess* process, bool  handleException )
    {
        if ( process.GetProcessType() != CoreProcess_Local )
            return  E_FAIL;

        IProcess* execProc = (cast(LocalProcess*) process).GetExecProcess();

        return  mExecThread.Execute( execProc, handleException );
    }

    HRESULT  DebuggerProxy.AsyncBreak( ICoreProcess* process )
    {
        if ( process.GetProcessType() != CoreProcess_Local )
            return  E_FAIL;

        IProcess* execProc = (cast(LocalProcess*) process).GetExecProcess();

        return  mExecThread.AsyncBreak( execProc );
    }

    HRESULT  DebuggerProxy.GetThreadContext( 
        ICoreProcess* process, ICoreThread* thread, ref IRegisterSet*  regSet )
    {
        _ASSERT( process !is  null );
        _ASSERT( thread !is  null );
        if ( process  is  null || thread  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Local
            || thread.GetProcessType() != CoreProcess_Local )
            return  E_FAIL;

        IProcess* execProc = (cast(LocalProcess*) process).GetExecProcess();
        .Thread* execThread = (cast(LocalThread*) thread).GetExecThread();

        HRESULT  hr = S_OK;
        ArchThreadContextSpec  contextSpec;
        UniquePtr<BYTE[ /* SYNTAX ERROR: (284): expression expected, not ] */ ]> context;

        mArch.GetThreadContextSpec( contextSpec );

        context.Attach( new  BYTE[ contextSpec.Size ] );
        if ( context.IsEmpty() )
            return  E_OUTOFMEMORY;

        hr = mExecThread.GetThreadContext( 
            execProc, 
            execThread.GetId(), 
            contextSpec.FeatureMask,
            contextSpec.ExtFeatureMask,
            context.Get(), 
            contextSpec.Size );
        if ( FAILED( hr ) )
            return  hr;

        hr = mArch.BuildRegisterSet( context.Get(), contextSpec.Size, regSet );
        if ( FAILED( hr ) )
            return  hr;

        return  S_OK;
    }

    HRESULT  DebuggerProxy.SetThreadContext( 
        ICoreProcess* process, ICoreThread* thread, IRegisterSet* regSet )
    {
        _ASSERT( process !is  null );
        _ASSERT( thread !is  null );
        _ASSERT( regSet !is  null );
        if ( process  is  null || thread  is  null || regSet  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Local
            || thread.GetProcessType() != CoreProcess_Local )
            return  E_FAIL;

        IProcess* execProc = (cast(LocalProcess*) process).GetExecProcess();
        .Thread* execThread = (cast(LocalThread*) thread).GetExecThread();

        HRESULT          hr = S_OK;
        const(void) *     contextBuf = null;
        uint32_t         contextSize = 0;

        if ( !regSet.GetThreadContext( contextBuf, contextSize ) )
            return  E_FAIL;

        hr = mExecThread.SetThreadContext( execProc, execThread.GetId(), contextBuf, contextSize );
        if ( FAILED( hr ) )
            return  hr;

        return  S_OK;
    }

    HRESULT  DebuggerProxy.GetPData( 
        ICoreProcess* process, 
        Address64  address, 
        Address64  imageBase, 
        uint32_t  size, 
        ref uint32_t  sizeRead, 
        uint8_t* pdata )
    {
        if ( process.GetProcessType() != CoreProcess_Local )
            return  E_FAIL;

        IProcess* execProc = (cast(LocalProcess*) process).GetExecProcess();

        return  mExecThread.GetPData( 
            execProc, cast(Address) address, cast(Address) imageBase, size, sizeRead, pdata );
    }


    //------------------------------------------------------------------------
    // IEventCallback
    //------------------------------------------------------------------------

    void  DebuggerProxy.AddRef()
    {
        // There's nothing to do, because this will be allocated as part of the engine.
    }

    void  DebuggerProxy.Release()
    {
        // There's nothing to do, because this will be allocated as part of the engine.
    }

    void  DebuggerProxy.OnProcessStart( IProcess* process )
    {
        mCallback.OnProcessStart( process.GetId() );
    }

    void  DebuggerProxy.OnProcessExit( IProcess* process, DWORD  exitCode )
    {
        mCallback.OnProcessExit( process.GetId(), exitCode );
    }

    void  DebuggerProxy.OnThreadStart( IProcess* process, .Thread* thread )
    {
        RefPtr<LocalThread> coreThread;

        coreThread = new  LocalThread( thread );

        mCallback.OnThreadStart( process.GetId(), coreThread );
    }

    void  DebuggerProxy.OnThreadExit( IProcess* process, DWORD  threadId, DWORD  exitCode )
    {
        mCallback.OnThreadExit( process.GetId(), threadId, exitCode );
    }

    void  DebuggerProxy.OnModuleLoad( IProcess* process, IModule* module )
    {
        RefPtr<LocalModule> coreModule;

        coreModule = new  LocalModule( module );

        mCallback.OnModuleLoad( process.GetId(), coreModule );
    }

    void  DebuggerProxy.OnModuleUnload( IProcess* process, Address  baseAddr )
    {
        mCallback.OnModuleUnload( process.GetId(), baseAddr );
    }

    void  DebuggerProxy.OnOutputString( IProcess* process, const(wchar_t) * outputString )
    {
        mCallback.OnOutputString( process.GetId(), outputString );
    }

    void  DebuggerProxy.OnLoadComplete( IProcess* process, DWORD  threadId )
    {
        mCallback.OnLoadComplete( process.GetId(), threadId );
    }

    RunMode  DebuggerProxy.OnException( IProcess* process, DWORD  threadId, bool  firstChance, const  EXCEPTION_RECORD* exceptRec )
    {
        EXCEPTION_RECORD64  exceptRec64;

        exceptRec64.ExceptionCode = exceptRec.ExceptionCode;
        exceptRec64.ExceptionAddress = cast(DWORD64) exceptRec.ExceptionAddress;
        exceptRec64.ExceptionFlags = exceptRec.ExceptionFlags;
        exceptRec64.NumberParameters = exceptRec.NumberParameters;
        exceptRec64.ExceptionRecord = 0;

        for ( DWORD  i = 0; i < exceptRec.NumberParameters; i++ )
        {
            exceptRec64.ExceptionInformation[i] = exceptRec.ExceptionInformation[i];
        }

        return  mCallback.OnException( process.GetId(), threadId, firstChance, &exceptRec64 );
    }

    RunMode  DebuggerProxy.OnBreakpoint( IProcess* process, uint32_t  threadId, Address  address, bool  embedded )
    {
        return  mCallback.OnBreakpoint( process.GetId(), threadId, address, embedded );
    }

    void  DebuggerProxy.OnStepComplete( IProcess* process, uint32_t  threadId )
    {
        mCallback.OnStepComplete( process.GetId(), threadId );
    }

    void  DebuggerProxy.OnAsyncBreakComplete( IProcess* process, uint32_t  threadId )
    {
        mCallback.OnAsyncBreakComplete( process.GetId(), threadId );
    }

    void  DebuggerProxy.OnError( IProcess* process, HRESULT  hrErr, EventCode  event )
    {
        mCallback.OnError( process.GetId(), hrErr, event );
    }

    ProbeRunMode  DebuggerProxy.OnCallProbe( 
        IProcess* process, uint32_t  threadId, Address  address, ref AddressRange  thunkRange )
    {
        AddressRange64  thunkRange64 = { 0 };

        ProbeRunMode  mode = mCallback.OnCallProbe( process.GetId(), threadId, address, thunkRange64 );

        thunkRange.Begin = cast(Address) thunkRange64.Begin;
        thunkRange.End = cast(Address) thunkRange64.End;

        return  mode;
    }

    void  DebuggerProxy.SetSymbolSearchPath( ref const  std.wstring  searchPath )
    {
        mExecThread.SetSymbolSearchPath( searchPath );
    }
    ref const  std.wstring  DebuggerProxy.GetSymbolSearchPath() const
    {
        return  mExecThread.GetSymbolSearchPath();
    }
}
