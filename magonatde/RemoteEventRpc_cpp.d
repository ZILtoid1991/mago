module RemoteEventRpc_cpp;

/*
   Copyright (c) 2013 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import RemoteEventRpc;
import IRemoteEventCallback;
import MagoRemoteEvent_i;


struct  EventContext
{
    RefPtr!(Mago.IRemoteEventCallback)  Callback;
};


namespace  Mago
{
    IRemoteEventCallback*   mCallback;


    void  SetRemoteEventCallback( IRemoteEventCallback* callback )
    {
        IRemoteEventCallback*   oldCallback = null;

        if ( callback !is  null )
            callback.AddRef();

        oldCallback = cast(IRemoteEventCallback*) 
            InterlockedExchangePointer( cast(void **) &mCallback, callback );

        if ( oldCallback !is  null )
            oldCallback.Release();
    }

    // The interface that's returned still has a reference.
    IRemoteEventCallback* TakeEventCallback()
    {
        return cast(IRemoteEventCallback*) InterlockedExchangePointer( cast(void **) &mCallback, null );
    }
}


// The RPC runtime will call this function, if the connection to the client is lost.
void  /* SYNTAX ERROR: (48): expected ; instead of HCTXEVENT_rundown */ 

    
 /* SYNTAX ERROR: unexpected trailing } */ }

HRESULT  MagoRemoteEvent_Open( 
    /* [in] */ handle_t  hBinding,
    /* [in] */ const  GUID *sessionUuid,
    /* [out] */ HCTXEVENT *phContext)
{
    if ( hBinding  is  null || sessionUuid  is  null || phContext  is  null )
        return  E_INVALIDARG;

    UniquePtr<EventContext> context( new  EventContext() );
    if ( context.Get() is  null )
        return  E_OUTOFMEMORY;

    context.Callback.Attach( Mago.TakeEventCallback() );

    if ( context.Callback.Get() is  null )
        return  E_FAIL;

    if ( context.Callback.GetSessionGuid() != *sessionUuid )
        return  E_FAIL;

    *phContext = context.Detach();

    return  S_OK;
}

void  MagoRemoteEvent_Close( 
    /* [out][in] */ HCTXEVENT *phContext)
{
    if ( phContext  is  null || *phContext  is  null )
        return;

    EventContext*   context = cast(EventContext*) *phContext;
    delete  context;

    *phContext = null;
}

void  MagoRemoteEvent_OnProcessStart( 
    /* [in] */ HCTXEVENT  hContext,
    /* [in] */ uint pid)
{
    if ( hContext  is  null )
        return;

    EventContext*   context = cast(EventContext*) hContext;

    context.Callback.SetEventLogicalThread( true );
    context.Callback.OnProcessStart( pid );
    context.Callback.SetEventLogicalThread( false );
}

void  MagoRemoteEvent_OnProcessExit( 
    /* [in] */ HCTXEVENT  hContext,
    /* [in] */ uint pid,
    /* [in] */ DWORD  exitCode)
{
    if ( hContext  is  null )
        return;

    EventContext*   context = cast(EventContext*) hContext;

    context.Callback.SetEventLogicalThread( true );
    context.Callback.OnProcessExit( pid, exitCode );
    context.Callback.SetEventLogicalThread( false );
}

void  MagoRemoteEvent_OnThreadStart( 
    /* [in] */ HCTXEVENT  hContext,
    /* [in] */ uint pid,
    /* [in] */ MagoRemote_ThreadInfo *threadInfo)
{
    if ( hContext  is  null )
        return;

    EventContext*   context = cast(EventContext*) hContext;

    context.Callback.SetEventLogicalThread( true );
    context.Callback.OnThreadStart( pid, threadInfo );
    context.Callback.SetEventLogicalThread( false );
}

void  MagoRemoteEvent_OnThreadExit( 
    /* [in] */ HCTXEVENT  hContext,
    /* [in] */ uint pid,
    /* [in] */ DWORD  threadId,
    /* [in] */ DWORD  exitCode)
{
    if ( hContext  is  null )
        return;

    EventContext*   context = cast(EventContext*) hContext;

    context.Callback.SetEventLogicalThread( true );
    context.Callback.OnThreadExit( pid, threadId, exitCode );
    context.Callback.SetEventLogicalThread( false );
}

void  MagoRemoteEvent_OnModuleLoad( 
    /* [in] */ HCTXEVENT  hContext,
    /* [in] */ uint pid,
    /* [in] */ MagoRemote_ModuleInfo *modInfo)
{
    if ( hContext  is  null )
        return;

    EventContext*   context = cast(EventContext*) hContext;

    context.Callback.SetEventLogicalThread( true );
    context.Callback.OnModuleLoad( pid, modInfo );
    context.Callback.SetEventLogicalThread( false );
}

void  MagoRemoteEvent_OnModuleUnload( 
    /* [in] */ HCTXEVENT  hContext,
    /* [in] */ uint pid,
    /* [in] */ MagoRemote_Address  baseAddress)
{
    if ( hContext  is  null )
        return;

    EventContext*   context = cast(EventContext*) hContext;

    context.Callback.SetEventLogicalThread( true );
    context.Callback.OnModuleUnload( pid, baseAddress );
    context.Callback.SetEventLogicalThread( false );
}

void  MagoRemoteEvent_OnOutputString( 
    /* [in] */ HCTXEVENT  hContext,
    /* [in] */ uint pid,
    /* [string][in] */ const(wchar_t) *outputString)
{
    if ( hContext  is  null )
        return;

    EventContext*   context = cast(EventContext*) hContext;

    context.Callback.SetEventLogicalThread( true );
    context.Callback.OnOutputString( pid, outputString );
    context.Callback.SetEventLogicalThread( false );
}

void  MagoRemoteEvent_OnLoadComplete( 
    /* [in] */ HCTXEVENT  hContext,
    /* [in] */ uint pid,
    /* [in] */ DWORD  threadId)
{
    if ( hContext  is  null )
        return;

    EventContext*   context = cast(EventContext*) hContext;

    context.Callback.SetEventLogicalThread( true );
    context.Callback.OnLoadComplete( pid, threadId );
    context.Callback.SetEventLogicalThread( false );
}

MagoRemote_RunMode  MagoRemoteEvent_OnException( 
    /* [in] */ HCTXEVENT  hContext,
    /* [in] */ uint pid,
    /* [in] */ DWORD  threadId,
    /* [in] */ boolean  firstChance,
    /* [in] */ uint recordCount,
    /* [in][size_is] */ MagoRemote_ExceptionRecord *exceptRecords)
{
    if ( hContext  is  null )
        return  MagoRemote_RunMode_Run;

    EventContext*   context = cast(EventContext*) hContext;

    context.Callback.SetEventLogicalThread( true );
    MagoRemote_RunMode  mode = context.Callback.OnException( 
        pid, 
        threadId, 
        firstChance ? true : false, 
        recordCount, 
        exceptRecords );
    context.Callback.SetEventLogicalThread( false );

    return  mode;
}

MagoRemote_RunMode  MagoRemoteEvent_OnBreakpoint( 
    /* [in] */ HCTXEVENT  hContext,
    /* [in] */ uint pid,
    /* [in] */ uint threadId,
    /* [in] */ MagoRemote_Address  address,
    /* [in] */ boolean  embedded)
{
    if ( hContext  is  null )
        return  MagoRemote_RunMode_Run;

    EventContext*   context = cast(EventContext*) hContext;

    context.Callback.SetEventLogicalThread( true );
    MagoRemote_RunMode  mode = context.Callback.OnBreakpoint( 
        pid, 
        threadId, 
        address, 
        embedded ? true : false );
    context.Callback.SetEventLogicalThread( false );

    return  mode;
}

void  MagoRemoteEvent_OnStepComplete( 
    /* [in] */ HCTXEVENT  hContext,
    /* [in] */ uint pid,
    /* [in] */ uint threadId)
{
    if ( hContext  is  null )
        return;

    EventContext*   context = cast(EventContext*) hContext;

    context.Callback.SetEventLogicalThread( true );
    context.Callback.OnStepComplete( pid, threadId );
    context.Callback.SetEventLogicalThread( false );
}

void  MagoRemoteEvent_OnAsyncBreak( 
    /* [in] */ HCTXEVENT  hContext,
    /* [in] */ uint pid,
    /* [in] */ uint threadId)
{
    if ( hContext  is  null )
        return;

    EventContext*   context = cast(EventContext*) hContext;

    context.Callback.SetEventLogicalThread( true );
    context.Callback.OnAsyncBreakComplete( pid, threadId );
    context.Callback.SetEventLogicalThread( false );
}

MagoRemote_ProbeRunMode  MagoRemoteEvent_OnCallProbe( 
    /* [in] */ HCTXEVENT  hContext,
    /* [in] */ uint pid,
    /* [in] */ uint threadId,
    /* [in] */ MagoRemote_Address  address,
    /* [out] */ MagoRemote_AddressRange *thunkRange)
{
    if ( hContext  is  null )
        return  MagoRemote_PRunMode_Run;

    EventContext*   context = cast(EventContext*) hContext;

    context.Callback.SetEventLogicalThread( true );
    MagoRemote_ProbeRunMode  mode = context.Callback.OnCallProbe( 
        pid, 
        threadId, 
        address, 
        thunkRange );
    context.Callback.SetEventLogicalThread( false );

    return  mode;
}
