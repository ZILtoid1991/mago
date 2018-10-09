module magonatde.boundbreakpoints;

class BoundBreakpoint : CComObjectRootEx!CComMultiThreadModel, IDebugBoundBreakpoint2
{
    DWORD mId;
    BP_STATE mState;
    PendingBreakpoint mPendingBP;
    CComPtr!IDebugBreakpointResolution2 mBPRes;
    Address64 mAddr;
    Program mProg;
    Guard mStateGuard;
	this()
    {   mId =  0 ;
        mState =  BPS_NONE ;
        mAddr =  0 ;
    }
	////////////////////////////////////////////////////////////////////////////// 
    // IDebugBoundBreakpoint2 

    HRESULT  GetState( BP_STATE* pState )
    {
        if ( pState  is  null )
            return  E_INVALIDARG;

        *pState = mState;
        return  S_OK;
    }

    HRESULT  GetHitCount( DWORD* pdwHitCount )
    { return  E_NOTIMPL; }
    HRESULT  SetHitCount( DWORD  dwHitCount )
    { return  E_NOTIMPL; }
    HRESULT  SetCondition( BP_CONDITION  bpCondition )
    { return  E_NOTIMPL; }
    HRESULT  SetPassCount( BP_PASSCOUNT  bpPassCount )
    { return  E_NOTIMPL; }

    HRESULT  GetPendingBreakpoint( 
        IDebugPendingBreakpoint2** ppPendingBreakpoint )
    {
        if ( ppPendingBreakpoint  is  null )
            return  E_INVALIDARG;

        return  mPendingBP.QueryInterface( __uuidof( IDebugPendingBreakpoint2 ), cast(void **) ppPendingBreakpoint );
    }

    HRESULT  GetBreakpointResolution( 
        IDebugBreakpointResolution2** ppBPResolution )
    {
        if ( ppBPResolution  is  null )
            return  E_INVALIDARG;

        *ppBPResolution = mBPRes;
        (*ppBPResolution).AddRef();
        return  S_OK;
    }

    HRESULT  Delete()
    {
        if ( mState != BPS_DELETED )
        {
            mPendingBP.OnBoundBPDelete( this );
        }

        // TODO: should we return E_BP_DELETED if already deleted?
        return  S_OK;
    }

    void  Dispose()
    {
        GuardedArea  guard = GuardedArea( mStateGuard );

        if ( mState != BPS_DELETED )
        {
            Enable( FALSE );

            mState = BPS_DELETED;
        }
    }

    HRESULT  Enable( BOOL  fEnable )
    {
        GuardedArea  guard = GuardedArea( mStateGuard );

        if ( mState == BPS_DELETED )
            return  E_BP_DELETED;

        HRESULT              hr = S_OK;

        if ( fEnable && (mState != BPS_ENABLED) )
        {
            hr = mProg.SetInternalBreakpoint( mAddr, cast(BPCookie) this );
            if ( FAILED( hr ) )
                return  hr;

            mState = BPS_ENABLED;
        }
        else  if ( !fEnable && (mState != BPS_DISABLED) )
        {
            hr = mProg.RemoveInternalBreakpoint( mAddr, cast(BPCookie) this );
            if ( FAILED( hr ) )
                return  hr;

            mState = BPS_DISABLED;
        }

        return  hr;
    }


    //----------------------------------------------------------------------------

    void  Init( 
            DWORD  id,
            Address64  addr,
            PendingBreakpoint* pendingBreakpoint, 
            IDebugBreakpointResolution2* resolution,
            Program* prog )
    {
        assert( id != 0 );
        assert( pendingBreakpoint !is  null );
        assert( resolution !is  null );
        assert( prog !is  null );

        mId = id;
        mAddr = addr;
        mPendingBP = pendingBreakpoint;
        mBPRes = resolution;
        mProg = prog;
    } 

    DWORD  GetId()
    {
        return  mId;
    }
}
