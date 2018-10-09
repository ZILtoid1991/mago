module PendingBreakpoint_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import PendingBreakpoint;
import Engine;
import Program;
import BPDocumentContext;
import BoundBreakpoint;
import ErrorBreakpoint;
import ComEnumWithCount;
import Events;
import Module;
import BpResolutionLocation;
import BPBinderCallback;
import BPBinders;

  /* SYNTAX ERROR: (22): expected ; instead of namespace */ 


alias  
     
     /* SYNTAX ERROR: (27): expected <identifier> instead of & */  
     
    
    


alias  
     
     /* SYNTAX ERROR: (35): expected <identifier> instead of & */  
     
    
    


//typedef CComEnumWithCount< 
//    IEnumDebugCodeContexts2, 
//    &IID_IEnumDebugCodeContexts2, 
//    IDebugCodeContext2*, 
//    _CopyInterface<IDebugCodeContext2>, 
//    CComMultiThreadModel
//> EnumDebugCodeContexts;
//
//


namespace  Mago
{
    // PendingBreakpoint

    this.PendingBreakpoint()
    {   mId = ( 0 );
            mDeleted = ( false );
            mSentEvent = ( false );
            mLastBPId = ( 0 );
        mState.flags = PBPSF_NONE;
        mState.state = PBPS_NONE;
    }

    this.~PendingBreakpoint()
    {
    }


    ////////////////////////////////////////////////////////////////////////////// 
    // IDebugPendingBreakpoint2 

    HRESULT  PendingBreakpoint.GetState( PENDING_BP_STATE_INFO* pState )
    {
        if ( pState  is  null )
            return  E_INVALIDARG;

        *pState = mState;
        if ( mDeleted )
            pState.state = PBPS_DELETED;
        return  S_OK;
    }

    HRESULT  PendingBreakpoint.GetBreakpointRequest( IDebugBreakpointRequest2** ppBPRequest )
    {
        if ( ppBPRequest  is  null )
            return  E_INVALIDARG;
        if ( mDeleted )
            return  E_BP_DELETED;

        _ASSERT( mBPRequest !is  null );
        *ppBPRequest = mBPRequest;
        (*ppBPRequest).AddRef();
        return  S_OK; 
    } 

    HRESULT  PendingBreakpoint.Virtualize( BOOL  fVirtualize )
    {
        if ( mDeleted )
            return  E_BP_DELETED;

        if ( fVirtualize )
            mState.flags |= PBPSF_VIRTUALIZED;
        else
             mState.flags &= ~PBPSF_VIRTUALIZED;

        return  S_OK;
    }

    HRESULT  PendingBreakpoint.Enable( BOOL  fEnable )
    {
        if ( mDeleted )
            return  E_BP_DELETED;

        if ( fEnable )
            mState.state = PBPS_ENABLED;
        else
             mState.state = PBPS_DISABLED;

        return  S_OK;
    }

    HRESULT  PendingBreakpoint.SetCondition( BP_CONDITION  bpCondition )
    {
        if ( mDeleted )
            return  E_BP_DELETED;

        return  E_NOTIMPL;
    }

    HRESULT  PendingBreakpoint.SetPassCount( BP_PASSCOUNT  bpPassCount )
    {
        if ( mDeleted )
            return  E_BP_DELETED;

        return  E_NOTIMPL;
    }

    HRESULT  PendingBreakpoint.EnumBoundBreakpoints( IEnumDebugBoundBreakpoints2** ppEnum )
    {
        if ( ppEnum  is  null )
            return  E_INVALIDARG;
        if ( mDeleted )
            return  E_BP_DELETED;

        HRESULT      hr = S_OK;
        size_t       boundBPCount = 0;
        GuardedArea  guard = GuardedArea( mBoundBPGuard );

        for ( BindingMap.iterator  it = mBindings.begin();
            it != mBindings.end();
            it++ )
        {
            ModuleBinding&  bind = it.second;
            boundBPCount += bind.BoundBPs.size();
        }

        InterfaceArray<IDebugBoundBreakpoint2>  array( boundBPCount );
        int  i = 0;

        if ( array.Get() is  null )
            return  E_OUTOFMEMORY;

        for ( BindingMap.iterator  it = mBindings.begin();
            it != mBindings.end();
            it++ )
        {
            ModuleBinding&  bind = it.second;

            for ( ModuleBinding.BPList.iterator  itBind = bind.BoundBPs.begin();
                itBind != bind.BoundBPs.end();
                itBind++, i++ )
            {
                hr = (*itBind).QueryInterface( __uuidof( IDebugBoundBreakpoint2 ), cast(void **) &array[i] );
                _ASSERT( hr == S_OK );
            }
        }

        return  MakeEnumWithCount<EnumDebugBoundBreakpoints>( array, ppEnum );
    }

    HRESULT  PendingBreakpoint.EnumBoundBreakpoints( ModuleBinding* binding, IEnumDebugBoundBreakpoints2** ppEnum )
    {
        _ASSERT( binding !is  null );
        if ( ppEnum  is  null )
            return  E_INVALIDARG;
        if ( mDeleted )
            return  E_BP_DELETED;

        HRESULT      hr = S_OK;
        size_t       boundBPCount = binding.BoundBPs.size();
        GuardedArea  guard = GuardedArea( mBoundBPGuard );

        InterfaceArray<IDebugBoundBreakpoint2>  array( boundBPCount );
        int      i = 0;

        if ( array.Get() is  null )
            return  E_OUTOFMEMORY;

        ModuleBinding&  bind = *binding;

        for ( ModuleBinding.BPList.iterator  itBind = bind.BoundBPs.begin();
            itBind != bind.BoundBPs.end();
            itBind++, i++ )
        {
            hr = (*itBind).QueryInterface( __uuidof( IDebugBoundBreakpoint2 ), cast(void **) &array[i] );
            _ASSERT( hr == S_OK );
        }

        return  MakeEnumWithCount<EnumDebugBoundBreakpoints>( array, ppEnum );
    }

    HRESULT  PendingBreakpoint.EnumErrorBreakpoints( BP_ERROR_TYPE  bpErrorType, 
                                                     IEnumDebugErrorBreakpoints2** ppEnum)
    {
        if ( ppEnum  is  null )
            return  E_INVALIDARG;
        if ( mDeleted )
            return  E_BP_DELETED;

        HRESULT      hr = S_OK;
        size_t       errorBPCount = 0;
        GuardedArea  guard = GuardedArea( mBoundBPGuard );

        for ( BindingMap.iterator  it = mBindings.begin();
            it != mBindings.end();
            it++ )
        {
            ModuleBinding&  bind = it.second;
            if ( bind.ErrorBP.Get() !is  null )
                errorBPCount++;
        }

        InterfaceArray<IDebugErrorBreakpoint2>  array( errorBPCount );
        int  i = 0;

        if ( array.Get() is  null )
            return  E_OUTOFMEMORY;

        for ( BindingMap.iterator  it = mBindings.begin();
            it != mBindings.end();
            it++ )
        {
            ModuleBinding&  bind = it.second;

            if ( bind.ErrorBP.Get() !is  null )
            {
                hr = bind.ErrorBP.QueryInterface( __uuidof( IDebugErrorBreakpoint2 ), cast(void **) &array[i] );
                _ASSERT( hr == S_OK );
                i++;
            }
        }

        return  MakeEnumWithCount<EnumDebugErrorBreakpoints>( array, ppEnum );
    }

    HRESULT  PendingBreakpoint.EnumCodeContexts( IEnumDebugCodeContexts2** ppEnum )
    {
        if ( ppEnum  is  null )
            return  E_INVALIDARG;
        if ( mDeleted )
            return  E_BP_DELETED;

        _ASSERT( false );

        return  E_NOTIMPL;
    }

    HRESULT  PendingBreakpoint.Delete()
    {
        if ( !mDeleted )
        {
            mEngine.OnPendingBPDelete( this );
        }

        // TODO: should we return E_BP_DELETED if already deleted?
        return  S_OK;
    }

    void  PendingBreakpoint.Dispose()
    {
        if ( !mDeleted )
        {
            mDeleted = true;

            mEngine.Release();
            mBPRequest.Release();
            mDocContext.Release();

            GuardedArea  guard = GuardedArea( mBoundBPGuard );

            for ( BindingMap.iterator  it = mBindings.begin();
                it != mBindings.end();
                it++ )
            {
                ModuleBinding&  bind = it.second;

                for ( ModuleBinding.BPList.iterator  itBind = bind.BoundBPs.begin();
                    itBind != bind.BoundBPs.end();
                    itBind++ )
                {
                    (*itBind).Dispose();
                }
            }

            mBindings.clear();
        }
    }

    HRESULT  PendingBreakpoint.CanBind( IEnumDebugErrorBreakpoints2** ppErrorEnum )
    {
        if ( ppErrorEnum  is  null )
            return  E_INVALIDARG;
        if ( mDeleted )
            return  E_BP_DELETED;

        return  E_NOTIMPL;
    }

    HRESULT  PendingBreakpoint.Bind()
    {
        _RPT0( _CRT_WARN, "PendingBreakpoint::Bind Enter\n" );

        mEngine.BeginBindBP();

        // Call BindToAllModules on the poll thread for speed.
        // Long term, we should try to remove the poll thread requirement from 
        // the BP set and remove operations for clarity (with speed built-in).

        HRESULT  hr = BindToAllModules();

        mEngine.EndBindBP();

        _RPT0( _CRT_WARN, "PendingBreakpoint::Bind Leave\n" );

        return  hr;
    }

    HRESULT  MakeBinder( IDebugBreakpointRequest2* bpRequest, ref auto_ptr!(BPBinder)  binder )
    {
        BP_LOCATION_TYPE     locType = 0;

        bpRequest.GetLocationType( &locType );

        if ( locType == BPLT_CODE_FILE_LINE )
        {
            binder.reset( new  BPCodeFileLineBinder( bpRequest ) );
        }
        else  if ( locType == BPLT_CODE_ADDRESS )
        {
            binder.reset( new  BPCodeAddressBinder( bpRequest ) );
        }
        else  if ( locType == BPLT_CODE_CONTEXT )
        {
            binder.reset( new  BPCodeAddressBinder( bpRequest ) );
        }
        else
             return  E_FAIL;

        if ( binder.get() is  null )
            return  E_OUTOFMEMORY;

        return  S_OK;
    }

    // The job of Bind:
    // - Generate bound or error breakpoints
    // - Establish the document context
    // - Enable the bound breakpoints
    // - Send the bound or error events

    HRESULT  PendingBreakpoint.BindToAllModules()
    {
        GuardedArea              guard = GuardedArea( mBoundBPGuard );

        if ( mDeleted )
            return  E_BP_DELETED;

        HRESULT                  hr = S_OK;
        BpRequestInfo            reqInfo;
        auto_ptr<BPBinder>      binder;

        hr = MakeBinder( mBPRequest, binder );
        if ( FAILED( hr ) )
            return  hr;

        // generate bound and error breakpoints
        BPBinderCallback         callback = BPBinderCallback( binder.get(), this, mDocContext.Get() );
        mEngine.ForeachProgram( &callback );

        if ( mDocContext.Get() is  null )
        {
            // set up our document context, since we didn't have one
            callback.GetDocumentContext( mDocContext );
        }

        // enable all bound BPs if we're enabled
        if ( mState.state == PBPS_ENABLED )
        {
            for ( BindingMap.iterator  it = mBindings.begin();
                it != mBindings.end();
                it++ )
            {
                ModuleBinding&  bind = it.second;

                for ( ModuleBinding.BPList.iterator  itBind = bind.BoundBPs.begin();
                    itBind != bind.BoundBPs.end();
                    itBind++ )
                {
                    (*itBind).Enable( TRUE );
                }
            }
        }

        if ( callback.GetBoundBPCount() > 0 )
        {
            // send a bound event

            CComPtr<IEnumDebugBoundBreakpoints2>    enumBPs;

            hr = EnumBoundBreakpoints( &enumBPs );
            if ( FAILED( hr ) )
                return  hr;

            hr = SendBoundEvent( enumBPs );
            mSentEvent = true;
        }
        else  if ( callback.GetErrorBPCount() > 0 )
        {
            // send an error event

            RefPtr<ErrorBreakpoint> errorBP;

            callback.GetLastErrorBP( errorBP );

            hr = SendErrorEvent( errorBP.Get() );
            mSentEvent = true;
        }
        else
        {
            // allow adding this pending BP, even if there are no loaded modules (including program)
            hr = S_OK;
        }

        if ( SUCCEEDED( hr ) )
        {
            hr = mEngine.AddPendingBP( this );
        }

        return  hr;
    }

    HRESULT  PendingBreakpoint.BindToModule( Module* mod, Program* prog )
    {
        GuardedArea              guard = GuardedArea( mBoundBPGuard );

        if ( mDeleted )
            return  E_BP_DELETED;
        if ( (mState.flags & PBPSF_VIRTUALIZED) == 0 )
            return  E_FAIL;

        HRESULT                  hr = S_OK;
        BpRequestInfo            reqInfo;
        auto_ptr<BPBinder>      binder;

        hr = MakeBinder( mBPRequest, binder );
        if ( FAILED( hr ) )
            return  hr;

        // generate bound and error breakpoints
        BPBinderCallback         callback = BPBinderCallback( binder.get(), this, mDocContext.Get() );
        callback.BindToModule( mod, prog );

        if ( mDocContext.Get() is  null )
        {
            // set up our document context, since we didn't have one
            callback.GetDocumentContext( mDocContext );
        }

        ModuleBinding*  binding = GetBinding( mod.GetId() );
        if ( binding  is  null )
            return  E_FAIL;

        // enable all bound BPs if we're enabled
        if ( mState.state == PBPS_ENABLED )
        {
            ModuleBinding&  bind = *binding;

            for ( ModuleBinding.BPList.iterator  itBind = bind.BoundBPs.begin();
                itBind != bind.BoundBPs.end();
                itBind++ )
            {
                (*itBind).Enable( TRUE );
            }
        }

        if ( callback.GetBoundBPCount() > 0 )
        {
            // send a bound event

            CComPtr<IEnumDebugBoundBreakpoints2>    enumBPs;

            hr = EnumBoundBreakpoints( binding, &enumBPs );
            if ( FAILED( hr ) )
                return  hr;

            hr = SendBoundEvent( enumBPs );
            mSentEvent = true;
        }
        else  if ( callback.GetErrorBPCount() > 0 )
        {
            if ( mSentEvent )
            {
                // At the beginning, Bind was called, which bound to all mods at the
                // time. If it sent out a bound BP event, then there can be no error.
                // If it sent out an error BP event, then there's no need to repeat it.
                // If you do send out this unneeded event here, then it slows down mod
                // loading a lot. For ex., with 160 mods, mod loading takes ~10x longer.

                // So, don't send an error event!
                hr = S_OK;
            }
            else
            {
                RefPtr<ErrorBreakpoint> errorBP;

                callback.GetLastErrorBP( errorBP );

                hr = SendErrorEvent( errorBP.Get() );
                mSentEvent = true;
            }
        }
        else
             hr = E_FAIL;

        return  hr;
    }

    HRESULT  PendingBreakpoint.UnbindFromModule( Module* mod, Program* prog )
    {
        GuardedArea      guard = GuardedArea( mBoundBPGuard );

        if ( mDeleted )
            return  E_BP_DELETED;

        HRESULT          hr = S_OK;
        ModuleBinding*  binding = null;
        DWORD            boundBPCount = 0;
        RefPtr<ErrorBreakpoint> lastErrorBP;

        binding = GetBinding( mod.GetId() );
        if ( binding  is  null )
            return  E_FAIL;

        for ( ModuleBinding.BPList.iterator  it = binding.BoundBPs.begin();
            it != binding.BoundBPs.end();
            it++ )
        {
            BoundBreakpoint*    bp = it.Get();

            bp.Dispose();
            SendUnboundEvent( bp, prog );
        }

        mBindings.erase( mod.GetId() );

        for ( BindingMap.iterator  it = mBindings.begin();
            it != mBindings.end();
            it++ )
        {
            ModuleBinding&  bind = it.second;
            boundBPCount += bind.BoundBPs.size();
            if ( bind.ErrorBP.Get() !is  null )
                lastErrorBP = bind.ErrorBP;
        }

        // if there're no more bound BPs, then send an error BP event
        // there should always be at least one error BP, because there should 
        // always be at least one module - the EXE

        if ( (boundBPCount == 0) && (lastErrorBP.Get() !is  null) )
        {
            SendErrorEvent( lastErrorBP.Get() );
        }

        return  hr;
    }


    //----------------------------------------------------------------------------

    void  PendingBreakpoint.Init( 
        DWORD  id,
        Engine* engine,
        IDebugBreakpointRequest2* pBPRequest,
        IDebugEventCallback2* pCallback )
    {
        _ASSERT( id != 0 );
        _ASSERT( engine !is  null );
        _ASSERT( pBPRequest !is  null );
        _ASSERT( pCallback !is  null );

        mId = id;
        mEngine = engine;
        mBPRequest = pBPRequest;
        mCallback = pCallback;
    }

    DWORD  PendingBreakpoint.GetId()
    {
        return  mId;
    }

    // this should be the least frequent operation: individual bound BP deletes
    void  PendingBreakpoint.OnBoundBPDelete( BoundBreakpoint* boundBP )
    {
        _ASSERT( boundBP !is  null );

        const  DWORD  Id = boundBP.GetId();
        GuardedArea  guard = GuardedArea( mBoundBPGuard );

        for ( BindingMap.iterator  it = mBindings.begin();
            it != mBindings.end();
            it++ )
        {
            ModuleBinding&  bind = it.second;

            for ( ModuleBinding.BPList.iterator  itBind = bind.BoundBPs.begin();
                itBind != bind.BoundBPs.end();
                itBind++ )
            {
                if ( (*itBind).GetId() == Id )
                {
                    bind.BoundBPs.erase( itBind );
                    goto  Found;
                }
            }
        }

    Found:
        boundBP.Dispose();
    }

    ModuleBinding*  PendingBreakpoint.GetBinding( DWORD  modId )
    {
        BindingMap.iterator  it = mBindings.find( modId );

        if ( it == mBindings.end() )
            return  null;

        return &it.second;
    }

    ModuleBinding*  PendingBreakpoint.AddOrFindBinding( DWORD  modId )
    {
        BindingMap._Pairib  pib = mBindings.insert( BindingMap.value_type( modId, ModuleBinding() ) );

        // it doesn't matter if it already exists
        return &pib.first.second;
    }

    DWORD  PendingBreakpoint.GetNextBPId()
    {
        mLastBPId++;
        return  mLastBPId;
    }

    HRESULT  PendingBreakpoint.SendBoundEvent( IEnumDebugBoundBreakpoints2* enumBPs )
    {
        HRESULT  hr = S_OK;
        CComPtr<IDebugPendingBreakpoint2>       pendBP;
        CComPtr<IDebugEngine2>                  engine;
        RefPtr<BreakpointBoundEvent>            event;

        hr = QueryInterface( __uuidof( IDebugPendingBreakpoint2 ), cast(void **) &pendBP );
        _ASSERT( hr == S_OK );

        hr = mEngine.QueryInterface( __uuidof( IDebugEngine2 ), cast(void **) &engine );
        _ASSERT( hr == S_OK );

        hr = MakeCComObject( event );
        if ( FAILED( hr ) )
            return  hr;

        event.Init( enumBPs, pendBP );

        return  event.Send( mCallback, engine, null, null );
    }

    HRESULT  PendingBreakpoint.SendErrorEvent( ErrorBreakpoint* errorBP )
    {
        HRESULT  hr = S_OK;
        CComPtr<IDebugEngine2>                  engine;
        CComPtr<IDebugErrorBreakpoint2>         ad7ErrorBP;
        RefPtr<BreakpointErrorEvent>            event;

        hr = errorBP.QueryInterface( __uuidof( IDebugErrorBreakpoint2 ), cast(void **) &ad7ErrorBP );
        _ASSERT( hr == S_OK );

        hr = mEngine.QueryInterface( __uuidof( IDebugEngine2 ), cast(void **) &engine );
        _ASSERT( hr == S_OK );

        hr = MakeCComObject( event );
        if ( FAILED( hr ) )
            return  hr;

        event.Init( ad7ErrorBP );

        return  event.Send( mCallback, engine, null, null );
    }

    HRESULT  PendingBreakpoint.SendUnboundEvent( BoundBreakpoint* boundBP, Program* prog )
    {
        HRESULT  hr = S_OK;
        RefPtr<BreakpointUnboundEvent>  event;
        CComPtr<IDebugBoundBreakpoint2> ad7BP;
        CComPtr<IDebugProgram2>         ad7Prog;
        CComPtr<IDebugEngine2>          engine;

        if ( prog !is  null )
        {
            hr = prog.QueryInterface( __uuidof( IDebugProgram2 ), cast(void **) &ad7Prog );
            _ASSERT( hr == S_OK );
        }

        hr = mEngine.QueryInterface( __uuidof( IDebugEngine2 ), cast(void **) &engine );
        _ASSERT( hr == S_OK );

        hr = boundBP.QueryInterface( __uuidof( IDebugBoundBreakpoint2 ), cast(void **) &ad7BP );
        _ASSERT( hr == S_OK );

        hr = MakeCComObject( event );
        if ( FAILED( hr ) )
            return  hr;

        event.Init( ad7BP, BPUR_CODE_UNLOADED );

        return  event.Send( mCallback, engine, ad7Prog, null );
    }
}
