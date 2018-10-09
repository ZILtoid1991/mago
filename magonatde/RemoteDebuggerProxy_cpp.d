module RemoteDebuggerProxy_cpp;

/*
   Copyright (c) 2013 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import RemoteDebuggerProxy;
import ArchData;
import Config;
import EventCallback;
import MagoRemoteCmd_i;
import MagoRemoteEvent_i;
import RegisterSet;
import RemoteEventRpc;
import RemoteProcess;
import RpcUtil;
// #include <MagoDECommon.h>


enum  AGENT_X64_VALUE =         "Remote_x64"w;


namespace  Mago
{
    HRESULT  StartAgent( const(wchar_t) * sessionGuidStr )
    {
        int                  ret = 0;
        BOOL                 bRet = FALSE;
        STARTUPINFO          startupInfo = { 0 };
        PROCESS_INFORMATION  processInfo = { 0 };
        HandlePtr            hEventPtr;
        std.wstring         cmdLine;
        wchar_t              eventName[AgentStartupEventNameLength + 1] = AGENT_STARTUP_EVENT_PREFIX;
        wchar_t              agentPath[MAX_PATH] = ""w;
        int                  agentPathLen = _countof( agentPath );
        HKEY                 hKey = null;

        startupInfo.cb =  startupInfo.sizeof;

        ret = OpenRootRegKey( false, false, hKey );
        if ( ret != ERROR_SUCCESS )
            return  HRESULT_FROM_WIN32( ret );

        ret = GetRegString( hKey, AGENT_X64_VALUE, agentPath, agentPathLen );
        RegCloseKey( hKey );
        if ( ret != ERROR_SUCCESS )
            return  HRESULT_FROM_WIN32( ret );

        wcscat_s( eventName, sessionGuidStr );

        hEventPtr = CreateEvent( null, TRUE, FALSE, eventName );
        if ( hEventPtr.IsEmpty() )
            return  GetLastHr();

        cmdLine.append( "\""w );
        cmdLine.append( agentPath );
        cmdLine.append( "\" -exclusive "w );
        cmdLine.append( sessionGuidStr );

        bRet = CreateProcess(
            agentPath,
            &cmdLine.at( 0 ),   // not empty, so we can call it
            null,
            null,
            FALSE,
            0,
            null,
            null,
            &startupInfo,
            &processInfo );
        if ( !bRet )
            return  GetLastHr();

        HANDLE  handles[] = [ hEventPtr, processInfo.hProcess ];
        DWORD  waitRet = WaitForMultipleObjects( 
            _countof( handles ), 
            handles, 
            FALSE, 
            AgentStartupTimeoutMillis );

        CloseHandle( processInfo.hProcess );
        CloseHandle( processInfo.hThread );

        if ( waitRet == WAIT_FAILED )
            return  GetLastHr();
        if ( waitRet == WAIT_TIMEOUT )
            return  E_TIMEOUT;
        if ( waitRet == WAIT_OBJECT_0 + 1 )
            return  E_FAIL;

        return  S_OK;
    }

    HRESULT  StartServer( const(wchar_t) * sessionGuidStr )
    {
        HRESULT          hr = S_OK;
        RPC_STATUS       rpcRet = RPC_S_OK;
        bool             registered = false;
        std.wstring     endpoint( AGENT_EVENT_IF_LOCAL_ENDPOINT_PREFIX );

        endpoint.append( sessionGuidStr );

        rpcRet = RpcServerUseProtseqEp(
            AGENT_LOCAL_PROTOCOL_SEQUENCE,
            RPC_C_PROTSEQ_MAX_REQS_DEFAULT,
            cast(RPC_WSTR) endpoint.c_str(),
            null );
        if ( rpcRet != RPC_S_OK )
        {
            hr = HRESULT_FROM_WIN32( rpcRet );
            goto  Error;
        }

        rpcRet = RpcServerRegisterIf2(
            MagoRemoteEvent_v1_0_s_ifspec,
            null,
            null,
            RPC_IF_ALLOW_LOCAL_ONLY,
            RPC_C_LISTEN_MAX_CALLS_DEFAULT,
            cast(uint) -1,
            null );
        if ( rpcRet != RPC_S_OK )
        {
            hr = HRESULT_FROM_WIN32( rpcRet );
            goto  Error;
        }
        registered = true;

        rpcRet = RpcServerListen( 1, RPC_C_LISTEN_MAX_CALLS_DEFAULT, TRUE );
        if( rpcRet == RPC_S_ALREADY_LISTENING )
            rpcRet = RPC_S_OK; // ignore

        if ( rpcRet != RPC_S_OK )
        {
            hr = HRESULT_FROM_WIN32( rpcRet );
            goto  Error;
        }

Error:
        if ( FAILED( hr ) )
        {
            if ( registered )
                RpcServerUnregisterIf( MagoRemoteEvent_v1_0_s_ifspec, null, FALSE );
        }
        return  hr;
    }

    HRESULT  StopServer()
    {
        RpcServerUnregisterIf( MagoRemoteEvent_v1_0_s_ifspec, null, FALSE );
        RpcMgmtStopServerListening( null );
        RpcMgmtWaitServerListen();
        return  S_OK;
    }

    HRESULT  OpenCmdInterface( RPC_BINDING_HANDLE  hBinding, ref const  GUID  sessionGuid, HCTXCMD* hContext )
    {
        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (163): expected ; instead of { */ {
            hr = MagoRemoteCmd_Open( hBinding, &sessionGuid, TRUE, &hContext[0] );
            hr = MagoRemoteCmd_Open( hBinding, &sessionGuid, FALSE, &hContext[1] );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (172): expected <identifier> instead of return */ 
    }

    HRESULT  StartClient( const(wchar_t) * sessionGuidStr, ref const  GUID  sessionGuid, HCTXCMD* hContext )
    {
        HRESULT              hr = S_OK;
        RPC_STATUS           rpcRet = RPC_S_OK;
        RPC_WSTR             strBinding = null;
        RPC_BINDING_HANDLE   hBinding = null;
        std.wstring         endpoint( AGENT_CMD_IF_LOCAL_ENDPOINT_PREFIX );

        endpoint.append( sessionGuidStr );

        rpcRet = RpcStringBindingCompose(
            null,
            AGENT_LOCAL_PROTOCOL_SEQUENCE,
            null,
            cast(RPC_WSTR) endpoint.c_str(),
            null,
            &strBinding );
        if ( rpcRet != RPC_S_OK )
            return  HRESULT_FROM_WIN32( rpcRet );

        rpcRet = RpcBindingFromStringBinding( strBinding, &hBinding );
        RpcStringFree( &strBinding );
        if ( rpcRet != RPC_S_OK )
            return  HRESULT_FROM_WIN32( rpcRet );

        // MSDN recommends letting the RPC runtime resolve the binding, so skip RpcEpResolveBinding

        hr = OpenCmdInterface( hBinding, sessionGuid, hContext );

        // Now that we've connected and gotten a context handle, 
        // we don't need the binding handle anymore.
        RpcBindingFree( &hBinding );

        if ( FAILED( hr ) )
            return  hr;

        return  S_OK;
    }

    HRESULT  StopClient( HCTXCMD* hContext )
    {
        for ( int  i = 0; i < 2; i++ )
        {
            if ( hContext[i] is  null )
                continue;

            try
             /* SYNTAX ERROR: (222): expected ; instead of { */ {
                MagoRemoteCmd_Close( &hContext[i] );
            }
            __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
             /* SYNTAX ERROR: (226): expected ; instead of { */ {
                RpcSsDestroyClientContext( &hContext[i] );
            }
         /* SYNTAX ERROR: unexpected trailing } */ }

         /* SYNTAX ERROR: (231): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }


    //------------------------------------------------------------------------
    // RemoteDebuggerProxy
    //------------------------------------------------------------------------

    this.RemoteDebuggerProxy()
    {   mRefCount = ( 0 );
            mSessionGuid = ( GUID_NULL );
            mEventPhysicalTid = ( 0 );
        mhContext[0] = null;
        mhContext[1] = null;
    }

    this.~RemoteDebuggerProxy()
    {
        Shutdown();
    }

    void  RemoteDebuggerProxy.AddRef()
    {
        InterlockedIncrement( &mRefCount );
    }

    void  RemoteDebuggerProxy.Release()
    {
        int  newRef = InterlockedDecrement( &mRefCount );
        _ASSERT( newRef >= 0 );
        if ( newRef == 0 )
        {
            delete  this;
        }
    }

    HRESULT  RemoteDebuggerProxy.Init( EventCallback* callback )
    {
        _ASSERT( callback !is  null );
        if ( (callback  is  null) )
            return  E_INVALIDARG;

        mCallback = callback;

        return  S_OK;
    }

    HRESULT  RemoteDebuggerProxy.Start()
    {
        if ( mSessionGuid != GUID_NULL )
            return  S_OK;

        HRESULT      hr = S_OK;
        GUID         sessionGuid = { 0 };
        wchar_t      sessionGuidStr[GUID_LENGTH + 1] = ""w;
        int          ret = 0;

        hr = CoCreateGuid( &sessionGuid );
        if ( FAILED( hr ) )
            return  hr;

        ret = StringFromGUID2( sessionGuid, sessionGuidStr, _countof( sessionGuidStr ) );
        _ASSERT( ret > 0 );
        if ( ret == 0 )
            return  E_FAIL;

        mSessionGuid = sessionGuid;

        hr = StartAgent( sessionGuidStr );
        if ( FAILED( hr ) )
            return  hr;

        hr = StartServer( sessionGuidStr );
        if ( FAILED( hr ) )
            return  hr;

        SetRemoteEventCallback( this );
        hr = StartClient( sessionGuidStr, sessionGuid, mhContext );
        SetRemoteEventCallback( null );
        if ( FAILED( hr ) )
        {
            StopServer();
            return  hr;
        }

        return  S_OK;
    }

    void  RemoteDebuggerProxy.Shutdown()
    {
        if ( mSessionGuid != GUID_NULL )
        {
            // When you close the client interface to the remote agent (Cmd), the agent closes its 
            // client interface to the debug engine (Event). To allow that call back, stop the client 
            // before stopping the server.

            StopClient( mhContext );
            StopServer();
        }
    }

    HCTXCMD  RemoteDebuggerProxy.GetContextHandle()
    {
        if ( mEventPhysicalTid == GetCurrentThreadId() )
            return  mhContext[0];

        return  mhContext[1];
    }

    void  RemoteDebuggerProxy.SetEventLogicalThread( bool  beginThread )
    {
        if ( beginThread )
        {
            mEventPhysicalTid = GetCurrentThreadId();
        }
        else
        {
            mEventPhysicalTid = 0;
        }
    }


    //----------------------------------------------------------------------------
    // IDebuggerProxy
    //----------------------------------------------------------------------------

    HRESULT  RemoteDebuggerProxy.Launch( LaunchInfo* launchInfo, ref ICoreProcess*  process )
    {
        _ASSERT( launchInfo !is  null );
        if ( launchInfo  is  null )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;
        RefPtr<RemoteProcess>   coreProc;
        RefPtr<ArchData>        archData;
        MagoRemote_LaunchInfo    cmdLaunchInfo = { 0 };
        MagoRemote_ProcInfo      cmdProcInfo = { 0 };
        uint32_t                 envBstrSize = 0;

        if ( launchInfo.EnvBstr !is  null )
        {
            const(wchar_t) * start = launchInfo.EnvBstr;
            const(wchar_t) * p = start;
            while ( *p != '\0'w )
            {
                p = wcschr( p, '\0'w );
                p++;
            }
            envBstrSize = p - start + 1;
        }

        cmdLaunchInfo.CommandLine = launchInfo.CommandLine;
        cmdLaunchInfo.Dir = launchInfo.Dir;
        cmdLaunchInfo.Exe = launchInfo.Exe;
        cmdLaunchInfo.EnvBstr = launchInfo.EnvBstr;
        cmdLaunchInfo.EnvBstrSize = cast(uint16_t) envBstrSize;
        cmdLaunchInfo.Flags = 0;

        if ( launchInfo.NewConsole )
            cmdLaunchInfo.Flags |= MagoRemote_PFlags_NewConsole;
        if ( launchInfo.Suspend )
            cmdLaunchInfo.Flags |= MagoRemote_PFlags_Suspend;

        coreProc = new  RemoteProcess();
        if ( coreProc.Get() is  null )
            return  E_OUTOFMEMORY;

        hr = LaunchNoException( cmdLaunchInfo, cmdProcInfo );
        if ( FAILED( hr ) )
            return  hr;

        hr = ArchData.MakeArchData( 
            cmdProcInfo.MachineType, 
            cmdProcInfo.MachineFeatures, 
            archData.Ref() );
        if ( FAILED( hr ) )
        {
            MIDL_user_free( cmdProcInfo.ExePath );
            return  hr;
        }

        coreProc.Init( 
            cmdProcInfo.Pid,
            cmdProcInfo.ExePath,
            Create_Launch,
            cmdProcInfo.MachineType,
            archData.Get() );
        process = coreProc.Detach();

        MIDL_user_free( cmdProcInfo.ExePath );

        return  S_OK;
    }

    // Can't use __try in functions that require object unwinding. So, pull the call out.
    HRESULT  RemoteDebuggerProxy.LaunchNoException( 
        ref MagoRemote_LaunchInfo  cmdLaunchInfo, 
        ref MagoRemote_ProcInfo  cmdProcInfo )
    {
        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (434): expected ; instead of { */ {
            hr = MagoRemoteCmd_Launch( 
                GetContextHandle(),
                &cmdLaunchInfo,
                &cmdProcInfo );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (445): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  RemoteDebuggerProxy.Attach( uint32_t  pid, ref ICoreProcess*  process )
    {
        HRESULT  hr = S_OK;
        RefPtr<RemoteProcess>   coreProc;
        RefPtr<ArchData>        archData;
        MagoRemote_ProcInfo      cmdProcInfo = { 0 };

        coreProc = new  RemoteProcess();
        if ( coreProc.Get() is  null )
            return  E_OUTOFMEMORY;

        hr = AttachNoException( pid, cmdProcInfo );
        if ( FAILED( hr ) )
            return  hr;

        hr = ArchData.MakeArchData( 
            cmdProcInfo.MachineType, 
            cmdProcInfo.MachineFeatures, 
            archData.Ref() );
        if ( FAILED( hr ) )
        {
            MIDL_user_free( cmdProcInfo.ExePath );
            return  hr;
        }

        coreProc.Init( 
            cmdProcInfo.Pid,
            cmdProcInfo.ExePath,
            Create_Attach,
            cmdProcInfo.MachineType,
            archData.Get() );
        process = coreProc.Detach();

        MIDL_user_free( cmdProcInfo.ExePath );

        return  S_OK;
    }

    // Can't use __try in functions that require object unwinding. So, pull the call out.
    HRESULT  RemoteDebuggerProxy.AttachNoException( 
        uint32_t  pid, 
        ref MagoRemote_ProcInfo  cmdProcInfo )
    {
        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (494): expected ; instead of { */ {
            hr = MagoRemoteCmd_Attach( 
                GetContextHandle(),
                pid,
                &cmdProcInfo );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (505): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  RemoteDebuggerProxy.Terminate( ICoreProcess* process )
    {
        _ASSERT( process !is  null );
        if ( process  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Remote )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (520): expected ; instead of { */ {
            hr = MagoRemoteCmd_Terminate( 
                GetContextHandle(),
                process.GetPid() );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (530): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  RemoteDebuggerProxy.Detach( ICoreProcess* process )
    {
        _ASSERT( process !is  null );
        if ( process  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Remote )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (545): expected ; instead of { */ {
            hr = MagoRemoteCmd_Detach( 
                GetContextHandle(),
                process.GetPid() );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (555): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  RemoteDebuggerProxy.ResumeLaunchedProcess( ICoreProcess* process )
    {
        _ASSERT( process !is  null );
        if ( process  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Remote )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (570): expected ; instead of { */ {
            hr = MagoRemoteCmd_ResumeProcess( 
                GetContextHandle(),
                process.GetPid() );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (580): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  RemoteDebuggerProxy.ReadMemory( 
        ICoreProcess* process, 
        Address64  address,
        uint32_t  length, 
        ref uint32_t  lengthRead, 
        ref uint32_t  lengthUnreadable, 
        uint8_t* buffer )
    {
        _ASSERT( process !is  null );
        if ( process  is  null || buffer  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Remote )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (601): expected ; instead of { */ {
            hr = MagoRemoteCmd_ReadMemory( 
                GetContextHandle(),
                process.GetPid(),
                address,
                length,
                &lengthRead,
                &lengthUnreadable,
                buffer );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (616): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  RemoteDebuggerProxy.WriteMemory( 
        ICoreProcess* process, 
        Address64  address,
        uint32_t  length, 
        ref uint32_t  lengthWritten, 
        uint8_t* buffer )
    {
        _ASSERT( process !is  null );
        if ( process  is  null || buffer  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Remote )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (636): expected ; instead of { */ {
            hr = MagoRemoteCmd_WriteMemory( 
                GetContextHandle(),
                process.GetPid(),
                address,
                length,
                &lengthWritten,
                buffer );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (650): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  RemoteDebuggerProxy.SetBreakpoint( ICoreProcess* process, Address64  address )
    {
        _ASSERT( process !is  null );
        if ( process  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Remote )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (665): expected ; instead of { */ {
            hr = MagoRemoteCmd_SetBreakpoint( 
                GetContextHandle(),
                process.GetPid(),
                address );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (676): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  RemoteDebuggerProxy.RemoveBreakpoint( ICoreProcess* process, Address64  address )
    {
        _ASSERT( process !is  null );
        if ( process  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Remote )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (691): expected ; instead of { */ {
            hr = MagoRemoteCmd_RemoveBreakpoint( 
                GetContextHandle(),
                process.GetPid(),
                address );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (702): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  RemoteDebuggerProxy.StepOut( ICoreProcess* process, Address64  targetAddr, bool  handleException )
    {
        _ASSERT( process !is  null );
        if ( process  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Remote )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (717): expected ; instead of { */ {
            hr = MagoRemoteCmd_StepOut( 
                GetContextHandle(),
                process.GetPid(),
                targetAddr,
                handleException );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (729): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  RemoteDebuggerProxy.StepInstruction( ICoreProcess* process, bool  stepIn, bool  handleException )
    {
        _ASSERT( process !is  null );
        if ( process  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Remote )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (744): expected ; instead of { */ {
            hr = MagoRemoteCmd_StepInstruction( 
                GetContextHandle(),
                process.GetPid(),
                stepIn,
                handleException );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (756): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  RemoteDebuggerProxy.StepRange( 
        ICoreProcess* process, bool  stepIn, AddressRange64  range, bool  handleException )
    {
        _ASSERT( process !is  null );
        if ( process  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Remote )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (772): expected ; instead of { */ {
            MagoRemote_AddressRange  cmdRange = { range.Begin, range.End } /* SYNTAX ERROR: (773): expected <identifier> instead of ; */ 

            hr = MagoRemoteCmd_StepRange( 
                GetContextHandle(),
                process.GetPid(),
                stepIn,
                cmdRange,
                handleException );
         /* SYNTAX ERROR: unexpected trailing } */ }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (787): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  RemoteDebuggerProxy.Continue( ICoreProcess* process, bool  handleException )
    {
        _ASSERT( process !is  null );
        if ( process  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Remote )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (802): expected ; instead of { */ {
            hr = MagoRemoteCmd_Continue( 
                GetContextHandle(),
                process.GetPid(),
                handleException );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (813): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  RemoteDebuggerProxy.Execute( ICoreProcess* process, bool  handleException )
    {
        _ASSERT( process !is  null );
        if ( process  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Remote )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (828): expected ; instead of { */ {
            hr = MagoRemoteCmd_Execute( 
                GetContextHandle(),
                process.GetPid(),
                handleException );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (839): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  RemoteDebuggerProxy.AsyncBreak( ICoreProcess* process )
    {
        _ASSERT( process !is  null );
        if ( process  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Remote )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (854): expected ; instead of { */ {
            hr = MagoRemoteCmd_AsyncBreak( 
                GetContextHandle(), 
                process.GetPid() );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (864): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  GetThreadContextNoException(
        ICoreProcess* process, 
        ICoreThread* thread, 
        HCTXCMD  hCtx, 
        ref const  ArchThreadContextSpec  spec, 
        BYTE* contextBuf )
    {
        HRESULT  hr = S_OK;

        try
         /* SYNTAX ERROR: (877): expected ; instead of { */ {
            uint32_t     sizeRead = 0;

            hr = MagoRemoteCmd_GetThreadContext(
                hCtx,
                process.GetPid(),
                thread.GetTid(),
                spec.FeatureMask,
                spec.ExtFeatureMask,
                spec.Size,
                &sizeRead,
                cast(byte*) contextBuf );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (895): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  RemoteDebuggerProxy.GetThreadContext( 
        ICoreProcess* process, ICoreThread* thread, ref IRegisterSet*  regSet )
    {
        _ASSERT( process !is  null );
        _ASSERT( thread !is  null );
        if ( process  is  null || thread  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Remote
            || thread.GetProcessType() != CoreProcess_Remote )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;
        ArchData* archData = process.GetArchData();
        ArchThreadContextSpec  contextSpec;
        UniquePtr<BYTE[ /* SYNTAX ERROR: (913): expression expected, not ] */ ]> context;

        archData.GetThreadContextSpec( contextSpec );

        context.Attach( new  BYTE[ contextSpec.Size ] );
        if ( context.IsEmpty() )
            return  E_OUTOFMEMORY;

        hr = GetThreadContextNoException( process, thread, GetContextHandle(), contextSpec, context.Get() );
        if ( FAILED( hr ) )
            return  hr;

        hr = archData.BuildRegisterSet( context.Get(), contextSpec.Size, regSet );
        if ( FAILED( hr ) )
            return  hr;

        return  S_OK;
    }

    HRESULT  RemoteDebuggerProxy.SetThreadContext( 
        ICoreProcess* process, ICoreThread* thread, IRegisterSet* regSet )
    {
        _ASSERT( process !is  null );
        _ASSERT( thread !is  null );
        _ASSERT( regSet !is  null );
        if ( process  is  null || thread  is  null || regSet  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Remote
            || thread.GetProcessType() != CoreProcess_Remote )
            return  E_INVALIDARG;

        HRESULT          hr = S_OK;
        const(void) *     contextBuf = null;
        uint32_t         contextSize = 0;

        if ( !regSet.GetThreadContext( contextBuf, contextSize ) )
            return  E_FAIL;

        try
         /* SYNTAX ERROR: (953): expected ; instead of { */ {
            hr = MagoRemoteCmd_SetThreadContext(
                GetContextHandle(),
                process.GetPid(),
                thread.GetTid(),
                contextSize,
                (byte*) contextBuf );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (966): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }

    HRESULT  RemoteDebuggerProxy.GetPData( 
        ICoreProcess* process, 
        Address64  address, 
        Address64  imageBase, 
        uint32_t  size, 
        ref uint32_t  sizeRead, 
        uint8_t* pdata )
    {
        _ASSERT( process !is  null );
        _ASSERT( pdata !is  null );
        if ( process  is  null || pdata  is  null )
            return  E_INVALIDARG;

        if ( process.GetProcessType() != CoreProcess_Remote )
            return  E_INVALIDARG;

        HRESULT          hr = S_OK;

        try
         /* SYNTAX ERROR: (988): expected ; instead of { */ {
            hr = MagoRemoteCmd_GetPData(
                GetContextHandle(),
                process.GetPid(),
                address,
                imageBase,
                size,
                &sizeRead,
                pdata );
        }
        __except ( CommonRpcExceptionFilter( RpcExceptionCode() ) )
        {
            hr = HRESULT_FROM_WIN32( RpcExceptionCode() );
        }

         /* SYNTAX ERROR: (1003): expected <identifier> instead of return */ 
     /* SYNTAX ERROR: unexpected trailing } */ }


    ref const  GUID  RemoteDebuggerProxy.GetSessionGuid()
    {
        return  mSessionGuid;
    }

    void  RemoteDebuggerProxy.OnProcessStart( uint32_t  pid )
    {
        mCallback.OnProcessStart( pid );
    }

    void  RemoteDebuggerProxy.OnProcessExit( uint32_t  pid, DWORD  exitCode )
    {
        mCallback.OnProcessExit( pid, exitCode );
    }

    void  RemoteDebuggerProxy.OnThreadStart( uint32_t  pid, MagoRemote_ThreadInfo* threadInfo )
    {
        if ( threadInfo  is  null )
            return;

        RefPtr<RemoteThread> coreThread;

        coreThread = new  RemoteThread( 
            threadInfo.Tid, 
            cast(Address64) threadInfo.StartAddr, 
            cast(Address64) threadInfo.TebBase );
        if ( coreThread.Get() is  null )
            return;

        mCallback.OnThreadStart( pid, coreThread );
    }

    void  RemoteDebuggerProxy.OnThreadExit( uint32_t  pid, DWORD  threadId, DWORD  exitCode )
    {
        mCallback.OnThreadExit( pid, threadId, exitCode );
    }

    void  RemoteDebuggerProxy.OnModuleLoad( uint32_t  pid, MagoRemote_ModuleInfo* modInfo )
    {
        if ( modInfo  is  null )
            return;

        RefPtr<RemoteModule> coreModule;

        coreModule = new  RemoteModule( 
            this,
            cast(Address64) modInfo.ImageBase, 
            cast(Address64) modInfo.PreferredImageBase,
            modInfo.Size,
            modInfo.MachineType,
            modInfo.Path );
        if ( coreModule.Get() is  null )
            return;

        mCallback.OnModuleLoad( pid, coreModule );
    }

    void  RemoteDebuggerProxy.OnModuleUnload( uint32_t  pid, MagoRemote_Address  baseAddr )
    {
        mCallback.OnModuleUnload( pid, cast(Address64) baseAddr );
    }

    void  RemoteDebuggerProxy.OnOutputString( uint32_t  pid, const(wchar_t) * outputString )
    {
        if ( outputString  is  null )
            return;

        mCallback.OnOutputString( pid, outputString );
    }

    void  RemoteDebuggerProxy.OnLoadComplete( uint32_t  pid, DWORD  threadId )
    {
        mCallback.OnLoadComplete( pid, threadId );
    }

    MagoRemote_RunMode  RemoteDebuggerProxy.OnException( 
        uint32_t  pid, 
        DWORD  threadId, 
        bool  firstChance, 
        uint recordCount,
        MagoRemote_ExceptionRecord* exceptRecords )
    {
        if ( exceptRecords  is  null )
            return  MagoRemote_RunMode_Run;

        EXCEPTION_RECORD64   exceptRec = { 0 };

        // TODO: more than 1 record
        exceptRec.ExceptionAddress = exceptRecords[0].ExceptionAddress;
        exceptRec.ExceptionCode = exceptRecords[0].ExceptionCode;
        exceptRec.ExceptionFlags = exceptRecords[0].ExceptionFlags;
        exceptRec.ExceptionRecord = null;
        exceptRec.NumberParameters = exceptRecords[0].NumberParameters;

        for ( DWORD  j = 0; j < exceptRec.NumberParameters; j++ )
        {
            exceptRec.ExceptionInformation[j] = exceptRecords[0].ExceptionInformation[j];
        }

        return cast(MagoRemote_RunMode) 
            mCallback.OnException( pid, threadId, firstChance, &exceptRec );
    }

    MagoRemote_RunMode  RemoteDebuggerProxy.OnBreakpoint( 
        uint32_t  pid, uint32_t  threadId, MagoRemote_Address  address, bool  embedded )
    {
        return cast(MagoRemote_RunMode) 
            mCallback.OnBreakpoint( pid, threadId, cast(Address64) address, embedded );
    }

    void  RemoteDebuggerProxy.OnStepComplete( uint32_t  pid, uint32_t  threadId )
    {
        mCallback.OnStepComplete( pid, threadId );
    }

    void  RemoteDebuggerProxy.OnAsyncBreakComplete( uint32_t  pid, uint32_t  threadId )
    {
        mCallback.OnAsyncBreakComplete( pid, threadId );
    }

    MagoRemote_ProbeRunMode  RemoteDebuggerProxy.OnCallProbe( 
        uint32_t  pid, 
        uint32_t  threadId, 
        MagoRemote_Address  address, 
        MagoRemote_AddressRange* thunkRange )
    {
        if ( thunkRange  is  null )
            return  MagoRemote_PRunMode_Run;

        AddressRange64   execThunkRange = { 0 };

        ProbeRunMode  mode = mCallback.OnCallProbe(
            pid,
            threadId, 
            cast(Address64) address,
            execThunkRange );

        thunkRange.Begin = execThunkRange.Begin;
        thunkRange.End = execThunkRange.End;

        return cast(MagoRemote_ProbeRunMode) mode;
    }

    void  RemoteDebuggerProxy.SetSymbolSearchPath( ref const  std.wstring  searchPath )
    {
        mSymbolSearchPath = searchPath;
    }
    ref const  std.wstring  RemoteDebuggerProxy.GetSymbolSearchPath() const
    {
        return  mSymbolSearchPath;
    }
 /* SYNTAX ERROR: unexpected trailing } */ }
