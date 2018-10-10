module windbg;

/*
	by Laszlo Szeremi
	windbg.d
	(C)2018
	Interfaces to the windbg.h file as much as mago needs it.
*/

public import core.sys.windows.windows;

/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/getname-type?view=vs-2017
 */
enum enum_GETNAME_TYPE {   
   GN_NAME         = 0,  
   GN_FILENAME     = 1,  
   GN_BASENAME     = 2,  
   GN_MONIKERNAME  = 3,  
   GN_URL          = 4,  
   GN_TITLE        = 5,  
   GN_STARTPAGEURL = 6  
}
alias GETNAME_TYPE = DWORD; 
/**
 * From:
 * https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-error-type?view=vs-2017
 * 
 */
enum enum_BP_ERROR_TYPE {   
   BPET_NONE            = 0x00000000,  
   BPET_TYPE_WARNING    = 0x00000001,  
   BPET_TYPE_ERROR      = 0x00000002,  
   BPET_SEV_HIGH        = 0x0F000000,  
   BPET_SEV_GENERAL     = 0x07000000,  
   BPET_SEV_LOW         = 0x01000000,  
   BPET_TYPE_MASK       = 0x0000ffff,  
   BPET_SEV_MASK        = 0xffff0000,  
   BPET_GENERAL_WARNING = BPET_SEV_GENERAL | BPET_TYPE_WARNING,  
   BPET_GENERAL_ERROR   = BPET_SEV_GENERAL | BPET_TYPE_ERROR,  
   BPET_ALL             = 0xffffffff  
}  
alias BP_ERROR_TYPE = DWORD;
/**
 * Reference:
 * https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/pending-bp-state?view=vs-2017
 */
enum enum_PENDING_BP_STATE {   
   PBPS_NONE     = 0x0000,  
   PBPS_DELETED  = 0x0001,  
   PBPS_DISABLED = 0x0002,  
   PBPS_ENABLED  = 0x0003  
};  
alias PENDING_BP_STATE = DWORD;
/**
 * Reference:
 * https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/pending-bp-state-flags?view=vs-2017
 */
 enum enum_PENDING_BP_STATE_FLAGS {   
   PBPSF_NONE        = 0x0000,  
   PBPSF_VIRTUALIZED = 0x0001  
};  
alias PENDING_BP_STATE_FLAGS = DWORD;
/**
 * Reference:
 * https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/pending-bp-state-info?view=vs-2017
 */
struct _tagPENDING_BP_STATE_INFO {   
   PENDING_BP_STATE       state;  
   PENDING_BP_STATE_FLAGS flags;  
}
alias PENDING_BP_STATE_INFO = _tagPENDING_BP_STATE_INFO;
/**
 * Reference:
 * https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-condition?view=vs-2015
 */
struct BP_CONDITION {   
   IDebugThread2* pThread;  
   BP_COND_STYLE  styleCondition;  
   BSTR           bstrContext;  
   BSTR           bstrCondition;  
   UINT           nRadix;  
}
/**
 * Reference:
 * https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/frameinfo-flags?view=vs-2017
 */
enum enum_FRAMEINFO_FLAGS {  
   FIF_FUNCNAME              = 0x00000001,  
   FIF_RETURNTYPE            = 0x00000002,  
   FIF_ARGS                  = 0x00000004,  
   FIF_LANGUAGE              = 0x00000008,  
   FIF_MODULE                = 0x00000010,  
   FIF_STACKRANGE            = 0x00000020,  
   FIF_FRAME                 = 0x00000040,  
   FIF_DEBUGINFO             = 0x00000080,  
   FIF_STALECODE             = 0x00000100,  
   FIF_ANNOTATEDFRAME        = 0x00000200,  
   FIF_DEBUG_MODULEP         = 0x00000400,  
   FIF_FUNCNAME_FORMAT       = 0x00001000,  
   FIF_FUNCNAME_RETURNTYPE   = 0x00002000,  
   FIF_FUNCNAME_ARGS         = 0x00004000,  
   FIF_FUNCNAME_LANGUAGE     = 0x00008000,  
   FIF_FUNCNAME_MODULE       = 0x00010000,  
   FIF_FUNCNAME_LINES        = 0x00020000,  
   FIF_FUNCNAME_OFFSET       = 0x00040000,  
   FIF_FUNCNAME_ARGS_TYPES   = 0x00100000,  
   FIF_FUNCNAME_ARGS_NAMES   = 0x00200000,  
   FIF_FUNCNAME_ARGS_VALUES  = 0x00400000,  
   FIF_FUNCNAME_ARGS_ALL     = 0x00700000,  
   FIF_ARGS_TYPES            = 0x01000000,  
   FIF_ARGS_NAMES            = 0x02000000,  
   FIF_ARGS_VALUES           = 0x04000000,  
   FIF_ARGS_ALL              = 0x07000000,  
   FIF_ARGS_NOFORMAT         = 0x08000000,  
   FIF_ARGS_NO_FUNC_EVAL     = 0x10000000,  
   FIF_FILTER_NON_USER_CODE  = 0x20000000,  
   FIF_ARGS_NO_TOSTRING      = 0x40000000,  
   FIF_DESIGN_TIME_EXPR_EVAL = 0x80000000  
};  
alias FRAMEINFO_FLAGS = DWORD;
/**
 * Reference:
 * https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/frameinfo?view=vs-2017
 */
struct FRAMEINFO {   
   FRAMEINFO_FLAGS    m_dwValidFields;  
   BSTR               m_bstrFuncName;  
   BSTR               m_bstrReturnType;  
   BSTR               m_bstrArgs;  
   BSTR               m_bstrLanguage;  
   BSTR               m_bstrModule;  
   UINT64             m_addrMin;  
   UINT64             m_addrMax;  
   IDebugStackFrame2* m_pFrame;  
   IDebugModule2*     m_pModule;  
   BOOL               m_fHasDebugInfo;  
   BOOL               m_fStaleCode;  
   BOOL               m_fAnnotatedFrame;  
} 
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/ienumdebugframeinfo2?view=vs-2017
 */
extern(C++) interface IEnumDebugFrameInfo2 : IUnknown{
	HRESULT Next(ULONG celt, FRAMEINFO** rgelt, ULONG* pceltFetched);
	HRESULT Skip(ULONG celt);
	HRESULT Reset();
	HRESULT Clone(IEnumDebugFrameInfo2** ppEnum);
	HRESULT GetCount(ULONG* pcelt);
}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/ienumdebugcodecontexts2?view=vs-2017
 */
extern(C++) interface IEnumDebugCodeContexts2 : IUnknown{
	HRESULT Next(ULONG celt, IDebugCodeContext2** rgelt, ULONG* pceltFetched);

}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugdocument2?view=vs-2017
 */
extern(C++) interface IDebugDocument2 : IUnknown{
	HRESULT GetName(GETNAME_TYPE gnType, BSTR* pbstrFileName);
	HRESULT GetDocumentClassID(CLSID* pclsid);
}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugdocumentcontext2?view=vs-2017
 */
extern(C++) interface IDebugDocumentContext2 : IUnknown{
	HRESULT GetDocument(IDebugDocument2** ppDocument);
	HRESULT GetName(GETNAME_TYPE gnType, BSTR* pbstrFileName);
	HRESULT EnumCodeContexts(IEnumDebugCodeContexts2** ppEnumCodeCxts);
}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugcodecontext2?view=vs-2017
 */
extern(C++) interface IDebugCodeContext2 : IDebugMemoryContext2{
	HRESULT GetDocumentContext(IDebugDocumentContext2** ppSrcCxt);
}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugthread2?view=vs-2017
 */
extern(C++) interface IDebugThread2 : IUnknown{
	HRESULT EnumFrameInfo (FRAMEINFO_FLAGS dwFieldSpec, UINT nRadix, IEnumDebugFrameInfo2** ppEnum);
	HRESULT GetName (BSTR* pbstrName);
	HRESULT SetThreadName (LPCOLESTR pszName);
	HRESULT GetProgram (IDebugProgram2** ppProgram);
	HRESULT CanSetNextStatement (IDebugStackFrame2* pStackFrame, IDebugCodeContext2* pCodeContext);

}
/**
 * Reference:
 * https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/ienumdebugthreads2?view=vs-2017
 */
extern(C++) interface IEnumDebugThreads2 : IUnknown{
	HRESULT Next(ULONG celt, IDebugThread2** rgelt, ULONG* pceltFetched);
}
extern(C++) interface IDebugProgram2 : IUnknown{
	HRESULT EnumThreads(IEnumDebugThreads2** ppEnum);
}
/**
 * Reference:
 * https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugthread2?view=vs-2017
 */
extern(C++) interface IDebugThread : IUnknown{
	HRESULT EnumFrameInfo (FRAMEINFO_FLAGS dwFieldSpec, UINT nRadix, IEnumDebugFrameInfo2** ppEnum);
	HRESULT GetName (BSTR* pbstrName);
	HRESULT SetThreadName (LPCOLESTR pszName);
	HRESULT GetProgram (IDebugProgram2** ppProgram);
}

extern(C++) interface IDebugBoundBreakpoint2 : IUnknown{
	
}
/**
 * Reference:
 * https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugpendingbreakpoint2?view=vs-2017
 * Interfaces IDebugPendingBreakpoint2 classes to D with the help of Component Object Model.
 */
extern(C++) interface IDebugPendingBreakpoint2 : IUnknown{
	HRESULT CanBind (IEnumDebugErrorBreakpoints2** ppErrorEnum);
	HRESULT Bind();
	HRESULT GetState(PENDING_BP_STATE_INFO* pState);
	HRESULT GetBreakpointRequest(IDebugBreakpointRequest2** ppBPRequest);
	HRESULT Virtualize(BOOL fVirtualize);
	HRESULT Enable(BOOL fEnable);
	HRESULT SetCondition(BP_CONDITION bpCondition);
	HRESULT EnumBoundBreakpoints(IEnumDebugBoundBreakpoints2** ppEnum);
	HRESULT EnumErrorBreakpoints(BP_ERROR_TYPE bpErrorType, IEnumDebugErrorBreakpoints2** ppEnum);
	HRESULT Delete();
}