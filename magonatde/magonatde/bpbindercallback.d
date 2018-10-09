module magonatde.bpbindercallback;

struct Error
{
    BP_ERROR_TYPE Type;
    BP_ERROR_TYPE Sev;
    StringIds StrId;
    // TODO: maybe add an optional string parameter for the formatted string message?

    void PutError(BP_ERROR_TYPE type, BP_ERROR_TYPE sev, StringIds strId)
    {
        if ((type > Type) || ((type == Type) && (sev > Sev)))
        {
            Type = type;
            Sev = sev;
            StrId = strId;
        }
    }
}

abstract class BPBoundBPMaker
{
public:
    abstract HRESULT MakeDocContext(ISession session, uint16_t compIx,
            uint16_t fileIx, const ref LineNumber lineNumber);
    abstract void AddBoundBP(UINT64 address, Module* mod, ModuleBinding binding);
}

abstract class BPBinder
{
public:
    abstract void Bind(Module* mod, ModuleBinding* binding, BPBoundBPMaker* maker, ref Error err);
}

class BPBinderCallback : public ProgramCallback, public ModuleCallback, public BPBoundBPMaker
{
    int mBoundBPCount;
    int mErrorBPCount;
    PendingBreakpoint mPendingBP;
    BPDocumentContext mDocContext;
    CComPtr!IDebugDocumentContext2 mDocContextInterface;
    Program mCurProg;
    CComPtr!IDebugProgram2 mCurProgInterface;
    ErrorBreakpoint mLastErrorBP;
    BPBinder mBinder;
    this( 
        BPBinder binder,
        PendingBreakpoint pendingBP, 
        BPDocumentContext docContext )
    {   mBinder = ( binder );
            mPendingBP = ( pendingBP );
            mDocContext = ( docContext );
            mBoundBPCount = ( 0 );
            mErrorBPCount = ( 0 );
        assert( binder !is  null );
        assert( pendingBP !is  null );

        HRESULT          hr = S_OK;

        if ( docContext !is  null )
        {
            hr = docContext.QueryInterface( __uuidof( IDebugDocumentContext2 ), cast(void **) &mDocContextInterface );
            assert( hr == S_OK );
        }
    }
    int  GetBoundBPCount()
    {
        return  mBoundBPCount;
    }

    int  GetErrorBPCount()
    {
        return  mErrorBPCount;
    }

    bool  GetDocumentContext( ref RefPtr!(BPDocumentContext)  docContext )
    {
        docContext = mDocContext;
        return  docContext.Get() !is  null;
    }

    bool  GetLastErrorBP( ref RefPtr!(ErrorBreakpoint)  errorBP )
    {
        errorBP = mLastErrorBP;
        return  errorBP.Get() !is  null;
    }

    bool  AcceptProgram( Program prog )
    {
        assert( prog !is  null );

        mCurProg = prog;
        prog.QueryInterface( __uuidof( IDebugProgram2 ), cast(void **) &mCurProgInterface );

        prog.ForeachModule( this );

        mCurProg.Release();
        mCurProgInterface.Release();
        return  true;
    }

    HRESULT  BindToModule( Module mod, Program prog )
    {
        assert( mod !is  null );
        assert( prog !is  null );

        mCurProg = prog;
        prog.QueryInterface( __uuidof( IDebugProgram2 ), cast(void **) &mCurProgInterface );

        AcceptModule( mod );

        mCurProg.Release();
        mCurProgInterface.Release();
        return  S_OK;
    }

    bool  AcceptModule( Module mod )
    {
        assert( mod !is  null );

        HRESULT          hr = S_OK;
        ModuleBinding*  binding = mPendingBP.AddOrFindBinding( mod.GetId() );
        Error            err;

        // nothing changed
        if ( binding.BoundBPs.size() > 0 )
            return  true;

        mBinder.Bind( mod, binding, this, err );

        // we got some new bound BPs
        if ( binding.BoundBPs.size() > 0 )
        {
            mBoundBPCount += binding.BoundBPs.size();
            binding.ErrorBP.Release();     // no more error, if there was one
            return  true;
        }

        // we already have an error, see if we have to replace it
        if ( binding.ErrorBP.Get() !is  null )
        {
            CComPtr!IDebugErrorBreakpointResolution2   errRes;
            BP_ERROR_RESOLUTION_INFO     bpErrResInfo = { 0 };
            BP_ERROR_TYPE    errType = BPET_NONE;
            BP_ERROR_TYPE    errSev = BPET_NONE;

            binding.ErrorBP.GetBreakpointResolution( &errRes );
            errRes.GetResolutionInfo( BPERESI_TYPE, &bpErrResInfo );

            errType = bpErrResInfo.dwType & BPET_TYPE_MASK;
            errSev = bpErrResInfo.dwType & BPET_SEV_MASK;

            if ( (err.Type > errType) || ((err.Type == errType) && (err.Sev > errSev)) )
                binding.ErrorBP.Release(); // we're going to replace the error
            else
                 return  true;    // new type/severity is not greater, so nothing to change
        }

        // make an error BP

        hr = MakeErrorBP( err, binding.ErrorBP );
        if ( FAILED( hr ) )
            return  true;

        mErrorBPCount++;
        mLastErrorBP = binding.ErrorBP;

        return  true;
    }

    HRESULT  MakeDocContext( ISession session, uint16_t  compIx, uint16_t  fileIx, ref const  LineNumber  lineNumber )
    {
        assert( session !is  null );
        assert( compIx != 0 );

        HRESULT          hr = S_OK;
        CComBSTR         filename;
        CComBSTR         langName;
        GUID             langGuid;
        TEXT_POSITION    posBegin = { 0 };
        TEXT_POSITION    posEnd = { 0 };
        BPDocumentContext             docCtx;

        // already exists; don't need to make a new one
        if ( mDocContext.Get() !is  null )
            return  S_FALSE;

        MagoST.FileInfo     fileInfo = { 0 };

        hr = session.GetFileInfo( compIx, fileIx, fileInfo );
        if ( FAILED( hr ) )
            return  hr;

        hr = Utf8To16( fileInfo.Name.ptr, fileInfo.Name.length, filename.m_str );
        if ( FAILED( hr ) )
            return  hr;

        // TODO:
        //compiland->get_language();

        posBegin.dwLine = lineNumber.Number;
        posEnd.dwLine = lineNumber.Number; // NumberEnd;?

        // AD7 lines are 0-based, DIA ones are 1-based
        posBegin.dwLine--;
        posEnd.dwLine--;

        hr = MakeCComObject( docCtx );
        if ( FAILED( hr ) )
            return  hr;

        hr = docCtx.Init( mPendingBP, filename, posBegin, posEnd, langName, langGuid );
        if ( FAILED( hr ) )
            return  hr;

        hr = docCtx.QueryInterface( __uuidof( IDebugDocumentContext2 ), cast(void **) &mDocContextInterface );
        assert( hr == S_OK );

        mDocContext = docCtx;

        return  hr;
    }

    HRESULT  MakeErrorBP( ref Error  errDesc, ref ErrorBreakpoint  errorBP )
    {
        HRESULT          hr = S_OK;
        const(wchar_t) *  msg = null;
        BP_ERROR_TYPE    errType = errDesc.Type | errDesc.Sev;
        ErrorBreakpoint                     errBP;
        ErrorBreakpointResolution           errBPRes;
        BpResolutionLocation                         bpResLoc;
        CComPtr!IDebugErrorBreakpointResolution2   errBPResInterface;
        CComPtr!IDebugPendingBreakpoint2           pendBPInterface;

        hr = mPendingBP.QueryInterface( __uuidof( IDebugPendingBreakpoint2 ), cast(void **) &pendBPInterface );
        assert( hr == S_OK );

        hr = MakeCComObject( errBPRes );
        if ( FAILED( hr ) )
            return  true;

        msg = GetString( errDesc.StrId );

        hr = errBPRes.Init( bpResLoc, mCurProgInterface, null, msg, errType );
        if ( FAILED( hr ) )
            return  hr;

        hr = errBPRes.QueryInterface( __uuidof( IDebugErrorBreakpointResolution2 ), cast(void **) &errBPResInterface );
        assert( hr == S_OK );

        hr = MakeCComObject( errBP );
        if ( FAILED( hr ) )
            return  hr;

        errBP.Init( pendBPInterface, errBPResInterface );
        errorBP = errBP;

        return  hr;
    }

    void  AddBoundBP( UINT64  address, Module* mod, ModuleBinding* binding )
    {
        HRESULT  hr = S_OK;
        CodeContext             code;
        BreakpointResolution    res;
        CComPtr!IDebugBreakpointResolution2    breakpointResolution;
        CComPtr!IDebugCodeContext2     codeContext;
        BpResolutionLocation             resLoc;
        BoundBreakpoint         boundBP;
        ArchData*                       archData = null;

        hr = MakeCComObject( code );
        if ( FAILED( hr ) )
            return;

        // TODO: maybe we should be able to customize the code context with things like function and module

        archData = mCurProg.GetCoreProcess().GetArchData();

        hr = code.Init( cast(Address64) address, mod, mDocContextInterface, archData.GetPointerSize() );
        if ( FAILED( hr ) )
            return;

        hr = code.QueryInterface( __uuidof( IDebugCodeContext2 ), cast(void **) &codeContext );
        assert( hr == S_OK );

        hr = MakeCComObject( res );
        if ( FAILED( hr ) )
            return;

        hr = BpResolutionLocation.InitCode( resLoc, codeContext );
        if ( FAILED( hr ) )
            return;

        hr = res.Init( resLoc, mCurProgInterface, null );
        if ( FAILED( hr ) )
            return;

        hr = res.QueryInterface( 
            __uuidof( IDebugBreakpointResolution2 ), cast(void **) &breakpointResolution );
        assert( hr == S_OK );

        hr = MakeCComObject( boundBP );
        if ( FAILED( hr ) )
            return;

        const  DWORD  Id = mPendingBP.GetNextBPId();
        boundBP.Init( 
            Id, cast(Address64) address, mPendingBP, breakpointResolution, mCurProg.Get() );

        binding.BoundBPs.push_back( boundBP );
    }
}