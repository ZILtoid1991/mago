module magonatde.bpbinders;

class BoundBreakpoint : 
        CComObjectRootEx!CComMultiThreadModel,
        IDebugBoundBreakpoint2
    {
        DWORD                                   mId;
        BP_STATE                                mState;
        PendingBreakpoint               mPendingBP;
        CComPtr!IDebugBreakpointResolution2    mBPRes;
        Address64                               mAddr;
        Program                         mProg;
        Guard  }