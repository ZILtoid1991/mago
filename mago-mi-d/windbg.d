module windbg;

/*
	by Laszlo Szeremi
	windbg.d
	(C)2018
	Interfaces to the windbg.h file as much as mago needs it.
*/

public import core.sys.windows.windows;

/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-res-data-flags?view=vs-2017
 */
enum enum_BP_RES_DATA_FLAGS {   
   BP_RES_DATA_EMULATED = 0x0001  
}
alias BP_RES_DATA_FLAGS = DWORD;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-type?view=vs-2017
 */
enum enum_BP_TYPE {   
   BPT_NONE    = 0x0000,  
   BPT_CODE    = 0x0001,  
   BPT_DATA    = 0x0002,  
   BPT_SPECIAL = 0x0003  
}
alias BP_TYPE = DWORD;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bpresi-fields?view=vs-2017
 */
enum enum_BPRESI_FIELDS {   
   BPRESI_BPRESLOCATION = 0x0001,  
   BPRESI_PROGRAM       = 0x0002,  
   BPRESI_THREAD        = 0x0004,  
   BPRESI_ALLFIELDS     = 0xffffffff  
}
alias BPRESI_FIELDS = DWORD;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-type?view=vs-2017
 */
enum enum_BP_TYPE {   
   BPT_NONE    = 0x0000,  
   BPT_CODE    = 0x0001,  
   BPT_DATA    = 0x0002,  
   BPT_SPECIAL = 0x0003  
}
alias BP_TYPE = DWORD;
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
 * From: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-error-type?view=vs-2017
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
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/text-position?view=vs-2017
 */
struct _tagTEXT_POSITION  {   
   DWORD dwLine;  
   DWORD dwColumn;  
}
alias TEXT_POSITION = _tagTEXT_POSITION;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/pending-bp-state?view=vs-2017
 */
enum enum_PENDING_BP_STATE {   
   PBPS_NONE     = 0x0000,  
   PBPS_DELETED  = 0x0001,  
   PBPS_DISABLED = 0x0002,  
   PBPS_ENABLED  = 0x0003  
};  
alias PENDING_BP_STATE = DWORD;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/pending-bp-state-flags?view=vs-2017
 */
enum enum_PENDING_BP_STATE_FLAGS {   
   PBPSF_NONE        = 0x0000,  
   PBPSF_VIRTUALIZED = 0x0001  
}
alias PENDING_BP_STATE_FLAGS = DWORD;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/pending-bp-state-info?view=vs-2017
 */
struct _tagPENDING_BP_STATE_INFO {   
   PENDING_BP_STATE       state;  
   PENDING_BP_STATE_FLAGS flags;  
}
alias PENDING_BP_STATE_INFO = _tagPENDING_BP_STATE_INFO;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-condition?view=vs-2015
 */
struct _BP_CONDITION  {   
   IDebugThread2* pThread;  
   BP_COND_STYLE  styleCondition;  
   BSTR           bstrContext;  
   BSTR           bstrCondition;  
   UINT           nRadix;  
}
alias BP_CONDITION = _BP_CONDITION;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-resolution-data?view=vs-2017
 */
struct _BP_RESOLUTION_DATA {   
   BSTR              bstrDataExpr;  
   BSTR              bstrFunc;  
   BSTR              bstrImage;  
   BP_RES_DATA_FLAGS dwFlags;  
}
alias BP_RESOLUTION_DATA = _BP_RESOLUTION_DATA;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-resolution-code?view=vs-2017
 */
struct _BP_RESOLUTION_CODE {   
   IDebugCodeContext2* pCodeContext;  
}
alias BP_RESOLUTION_CODE = _BP_RESOLUTION_CODE;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-resolution-location?view=vs-2017
 */
struct _BP_RESOLUTION_LOCATION {  
   BP_TYPE bpType;  
   union bpResLocation {  
      BP_RESOLUTION_CODE bpresCode;  
      BP_RESOLUTION_DATA bpresData;  
      int                unused;  
   }  
}
alias BP_RESOLUTION_LOCATION = _BP_RESOLUTION_LOCATION;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-resolution-info?view=vs-2017
 */
struct _BP_RESOLUTION_INFO {   
   BPRESI_FIELDS          dwFields;  
   BP_RESOLUTION_LOCATION bpResLocation;  
   IDebugProgram2*        pProgram;  
   IDebugThread2*         pThread;  
}
alias BP_RESOLUTION_INFO = _BP_RESOLUTION_INFO;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-request-info?view=vs-2017
 */
struct _BP_REQUEST_INFO {  
   BPREQI_FIELDS   dwFields;  
   GUID            guidLanguage;  
   BP_LOCATION     bpLocation;  
   IDebugProgram2* pProgram;  
   BSTR            bstrProgramName;  
   IDebugThread2*  pThread;  
   BSTR            bstrThreadName;  
   BP_CONDITION    bpCondition;  
   BP_PASSCOUNT    bpPassCount;  
   BP_FLAGS        dwFlags;  
}
alias BP_REQUEST_INFO = _BP_REQUEST_INFO;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-location-code-file-line?view=vs-2017
 */
struct _BP_LOCATION_CODE_FILE_LINE {   
   BSTR                     bstrContext;  
   IDebugDocumentPosition2* pDocPos;  
}
alias BP_LOCATION_CODE_FILE_LINE = _BP_LOCATION_CODE_FILE_LINE;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-location-code-func-offset?view=vs-2017
 */
struct _BP_LOCATION_CODE_FUNC_OFFSET {   
   BSTR                     bstrContext;  
   IDebugFunctionPosition2* pFuncPos;  
}
alias BP_LOCATION_CODE_FUNC_OFFSET = _BP_LOCATION_CODE_FUNC_OFFSET;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-location-code-context?view=vs-2017
 */
struct _BP_LOCATION_CODE_CONTEXT {   
   IDebugCodeContext2* pCodeContext;  
}
alias BP_LOCATION_CODE_CONTEXT = _BP_LOCATION_CODE_CONTEXT;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-location-code-string?view=vs-2017
 */
struct _BP_LOCATION_CODE_STRING {   
   BSTR bstrContext;  
   BSTR bstrCodeExpr;  
}
alias BP_LOCATION_CODE_STRING = _BP_LOCATION_CODE_STRING;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-location-code-address?view=vs-2017
 */
struct _BP_LOCATION_CODE_ADDRESS {   
   BSTR bstrContext;  
   BSTR bstrModuleUrl;  
   BSTR bstrFunction;  
   BSTR bstrAddress;  
}
alias BP_LOCATION_CODE_ADDRESS = _BP_LOCATION_CODE_ADDRESS;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-location-data-string?view=vs-2017
 */
struct _BP_LOCATION_DATA_STRING {   
   IDebugThread2* pThread;  
   BSTR           bstrContext;  
   BSTR           bstrDataExpr;  
   DWORD          dwNumElements;  
}
alias BP_LOCATION_DATA_STRING = _BP_LOCATION_DATA_STRING;
/**
 *
 */
struct _BP_LOCATION_RESOLUTION {   
   IDebugBreakpointResolution2* pResolution;  
}alias BP_LOCATION_RESOLUTION = _BP_LOCATION_RESOLUTION;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-location?view=vs-2017
 */
struct _BP_LOCATION {  
   BP_LOCATION_TYPE bpLocationType;  
   union bpLocation {  
      BP_LOCATION_CODE_FILE_LINE   bplocCodeFileLine;  
      BP_LOCATION_CODE_FUNC_OFFSET bplocCodeFuncOffset;  
      BP_LOCATION_CODE_CONTEXT     bplocCodeContext;  
      BP_LOCATION_CODE_STRING      bplocCodeString;  
      BP_LOCATION_CODE_ADDRESS     bplocCodeAddress;  
      BP_LOCATION_DATA_STRING      bplocDataString;  
      BP_LOCATION_RESOLUTION       bplocResolution;  
      DWORD                        unused;  
   }   
}
alias BP_LOCATION = _BP_LOCATION;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-passcount-style?view=vs-2017
 */
enum enum_BP_PASSCOUNT_STYLE {   
   BP_PASSCOUNT_NONE             = 0x0000,  
   BP_PASSCOUNT_EQUAL            = 0x0001,  
   BP_PASSCOUNT_EQUAL_OR_GREATER = 0x0002,  
   BP_PASSCOUNT_MOD              = 0x0003  
};  
alias BP_PASSCOUNT_STYLE = DWORD;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-passcount?view=vs-2017
 */
struct _BP_PASSCOUNT {   
   DWORD              dwPassCount;  
   BP_PASSCOUNT_STYLE stylePassCount;  
}
alias BP_PASSCOUNT = _BP_PASSCOUNT;
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
}
alias FRAMEINFO_FLAGS = DWORD;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bpreqi-fields?view=vs-2017
 */
enum enum_BPREQI_FIELDS {   
   BPREQI_BPLOCATION   = 0x0001,  
   BPREQI_LANGUAGE     = 0x0002,  
   BPREQI_PROGRAM      = 0x0004,  
   BPREQI_PROGRAMNAME  = 0x0008,  
   BPREQI_THREAD       = 0x0010,  
   BPREQI_THREADNAME   = 0x0020,  
   BPREQI_PASSCOUNT    = 0x0040,  
   BPREQI_CONDITION    = 0x0080,  
   BPREQI_FLAGS        = 0x0100,  
   BPREQI_ALLOLDFIELDS = 0x01ff,
   BPREQI_VENDOR       = 0x0200,   // BP_REQUEST_INFO2 only  
   BPREQI_CONSTRAINT   = 0x0400,   // BP_REQUEST_INFO2 only  
   BPREQI_TRACEPOINT   = 0x0800,   // BP_REQUEST_INFO2 only  
   BPREQI_ALLFIELDS    = 0x0fff    // BP_REQUEST_INFO2 only  
}
alias BPREQI_FIELDS = DWORD;
/**
 * Reference:
 */
enum enum_PARSEFLAGS {   
   PARSE_EXPRESSION            = 0x0001,  
   PARSE_FUNCTION_AS_ADDRESS   = 0x0002,  
   PARSE_DESIGN_TIME_EXPR_EVAL = 0x1000  
}
alias PARSEFLAGS = DWORD; 
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/attach-reason?view=vs-2017
 */
enum enum_ATTACH_REASON {   
   ATTACH_REASON_LAUNCH = 0x0001,  
   ATTACH_REASON_USER   = 0x0002,  
   ATTACH_REASON_AUTO   = 0x0003  
}
alias ATTACH_REASON = DWORD;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/bp-location-type?view=vs-2017
 */
enum enum_BP_LOCATION_TYPE {   
   BPLT_NONE               = 0x00000000,  
   BPLT_FILE_LINE          = 0x00010000,  
   BPLT_FUNC_OFFSET        = 0x00020000,  
   BPLT_CONTEXT            = 0x00030000,  
   BPLT_STRING             = 0x00040000,  
   BPLT_ADDRESS            = 0x00050000,  
   BPLT_RESOLUTION         = 0x00060000,  
   BPLT_CODE_FILE_LINE     = BPT_CODE | BPLT_FILE_LINE,  
   BPLT_CODE_FUNC_OFFSET   = BPT_CODE | BPLT_FUNC_OFFSET,  
   BPLT_CODE_CONTEXT       = BPT_CODE | BPLT_CONTEXT,  
   BPLT_CODE_STRING        = BPT_CODE | BPLT_STRING,  
   BPLT_CODE_ADDRESS       = BPT_CODE | BPLT_ADDRESS ,  
   BPLT_DATA_STRING        = BPT_DATA | BPLT_STRING,  
   BPLT_TYPE_MASK          = 0x0000FFFF,  
   BPLT_LOCATION_TYPE_MASK = 0xFFFF0000  
}
alias BP_LOCATION_TYPE = DWORD;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/context-info-fields?view=vs-2017
 */
enum enum_CONTEXT_INFO_FIELDS {   
   CIF_MODULEURL =       0x00000001,  
   CIF_FUNCTION =        0x00000002,  
   CIF_FUNCTIONOFFSET =  0x00000004,  
   CIF_ADDRESS =         0x00000008,  
   CIF_ADDRESSOFFSET =   0x00000010,  
   CIF_ADDRESSABSOLUTE = 0x00000020,  
   CIF_ALLFIELDS =       0x0000003f  
}
alias CONTEXT_INFO_FIELDS = DWORD;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/context-info?view=vs-2017
 */
struct _tagCONTEXT_INFO {   
   CONTEXT_INFO_FIELDS dwFields;  
   BSTR                bstrModuleUrl;  
   BSTR                bstrFunction;  
   TEXT_POSITION       posFunctionOffset;  
   BSTR                bstrAddress;  
   BSTR                bstrAddressOffset;  
   BSTR                bstrAddressAbsolute;  
}
alias CONTEXT_INFO = _tagCONTEXT_INFO;
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/frameinfo?view=vs-2017
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
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugbreakpointresolution2?view=vs-2017
 */
extern(C++) interface IDebugBreakpointResolution2 : IUnknown{
	HRESULT GetBreakpointType(BP_TYPE* pBPType);
	HRESULT GetResolutionInfo(BPRESI_FIELDS dwFields, BP_RESOLUTION_INFO* pBPResolutionInfo);
}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugmemorycontext2?view=vs-2017
 */
extern(C++) interface IDebugMemoryContext2 : IUnknown{
	HRESULT GetName(BSTR* pbstrName);
	HRESULT GetInfo(CONTEXT_INFO_FIELDS dwFields, CONTEXT_INFO* pInfo);
	HRESULT Add(UINT64 dwCount, IDebugMemoryContext2** ppMemCxt);
	HRESULT Subtract(UINT64 dwCount, IDebugMemoryContext2** ppMemCxt);
	HRESULT Compare(CONTEXT_COMPARE compare, IDebugMemoryContext2** rgpMemoryContextSet, DWORD dwMemoryContextSetLen, DWORD* pdwMemoryContext);
}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugcodecontext2?view=vs-2017
 */
extern(C++) interface IDebugCodeContext2 : IDebugMemoryContext2{
	HRESULT GetDocumentContext(IDebugDocumentContext2** ppSrcCxt);
	HRESULT GetLanguageInfo(BSTR* pbstrLanguage, GUID* pguidLanguage);
}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugfunctionposition2?view=vs-2017
 */
extern(C++) interface IDebugFunctionPosition2 : IUnknown{
	HRESULT GetFunctionName(BSTR* pbstrFunctionName);
	HRESULT GetOffset(TEXT_POSITION* pPosition);
}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugdocumentposition2?view=vs-2017
 */
extern(C++) interface IDebugDocumentPosition2 : IUnknown{
	HRESULT GetFileName(BSTR* pbstrFileName);
	HRESULT GetDocument(IDebugDocument2** ppDoc);
	HRESULT IsPositionInDocument(IDebugDocument2* pDoc);
	HRESULT GetRange(TEXT_POSITION* pBegPosition, TEXT_POSITION* pEndPosition);
}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugprogramnode2?view=vs-2017
 */
extern(C++) interface IDebugProgramNode2 : IUnknown{
	HRESULT GetProgramName (BSTR* pbstrProgramName);
	HRESULT GetHostName (GETHOSTNAME_TYPE dwHostNameType, BSTR* pbstrHostName);
	HRESULT GetHostPid (AD_PROCESS_ID * pdwHostPid);
	HRESULT GetHostMachineName_V7 (BSTR* pbstrHostMachineName);		///Deprecated!!! Do not use!!!
	HRESULT Attach_V7 (IDebugProgram2* pMDMProgram, IDebugEventCallback2* pCallback, DWORD dwReason);///Deprecated!!! Do not use!!!
	HRESULT GetEngineInfo (BSTR* pbstrEngine, GUID* pguidEngine);
	HRESULT DetachDebugger_V7 ();									///Deprecated!!! Do not use!!!
}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/ienumdebugprograms2?view=vs-2017
 */
extern(C++) interface IEnumDebugPrograms2 : IUnknown{
	HRESULT Next(ULONG celt, IDebugProgram2** rgelt, ULONG* pceltFetched);
	HRESULT Skip(ULONG celt);
	HRESULT Reset();
	HRESULT Clone(IEnumDebugPrograms2** ppEnum);
	HRESULT GetCount(ULONG* pcelt);
	
}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugbreakpointrequest2?view=vs-2017
 */
extern(C++) interface IDebugBreakpointRequest2 : IUnknown{
	HRESULT GetLocationType(BP_LOCATION_TYPE* pBPLocationType);
	HRESULT GetRequestInfo(BPREQI_FIELDS dwFields, BP_REQUEST_INFO* pBPRequestInfo);
}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugengine2?view=vs-2017
 */
extern(C++) interface IDebugEngine2 : IUnknown{
	HRESULT EnumPrograms(IEnumDebugPrograms2** ppEnum);
	HRESULT Attach(IDebugProgram2** pProgram, IDebugProgramNode2** rgpProgramNodes, DWORD celtPrograms, IDebugEventCallback2* pCallback, ATTACH_REASON dwReason);
	HRESULT CreatePendingBreakpoint(IDebugBreakpointRequest2* pBPRequest, IDebugPendingBreakpoint2** ppPendingBP);

}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugeventcallback2?view=vs-2017
 */
extern(C++) interface IDebugEventCallback2 : IUnknown{
	HRESULT Event(IDebugEngine2* pEngine, IDebugProcess2* pProcess, IDebugProgram2* pProgram, IDebugThread2* pThread, IDebugEvent2* pEvent, REFIID riidEvent, DWORD dwAttrib);
}
/**
 * Reference: 
 */
extern(C++) interface IDebugExpression2 : IUnknown{
	HRESULT EvaluateAsync (EVALFLAGS dwFlags, IDebugEventCallback2* pExprCallback);
}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugexpressioncontext2?view=vs-2017
 */
extern(C++) interface IDebugExpressionContext2 : IUnknown{
	HRESULT GetName(BSTR* pbstrName);
	HRESULT ParseText(LPCOLESTR pszCode, PARSEFLAGS dwFlags, UINT nRadix, IDebugExpression2** ppExpr, BSTR* pbstrError, UINT* pichError);
}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugstackframe2?view=vs-2017
 */
extern(C++) interface IDebugStackFrame2 : IUnknown{
	HRESULT GetCodeContext (IDebugCodeContext2** ppCodeCxt);
	HRESULT GetDocumentContext (IDebugDocumentContext2** ppCxt);
	HRESULT GetName (BSTR* pbstrName);
	HRESULT GetInfo (FRAMEINFO_FLAGS dwFieldSpec, UINT nRadix, FRAMEINFO* pFrameInfo);
	HRESULT GetPhysicalStackRange (UINT64* paddrMin, UINT64* paddrMax);
	HRESULT GetExpressionContext (IDebugExpressionContext2** ppExprCxt);
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
	HRESULT Skip(ULONG celt);
	HRESULT Reset();
	HRESULT Clone(IEnumDebugCodeContexts2** ppEnum);
	HRESULT GetCount(ULONG* pcelt);
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
	HRESULT GetLanguageInfo(BSTR* pbstrLanguage, GUID* pguidLanguage);
	HRESULT GetStatementRange(TEXT_POSITION* pBegPosition, TEXT_POSITION* pEndPosition);
	HRESULT GetSourceRange(TEXT_POSITION* pBegPosition, TEXT_POSITION* pEndPosition);
	HRESULT Compare(DOCCONTEXT_COMPARE compare, IDebugDocumentContext2** rgpDocContextSet, DWORD dwDocContextSetLen, DWORD* pdwDocContext);
	HRESULT Seek(int nCount, IDebugDocumentContext2** ppDocContext);
}
/**
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/idebugcodecontext2?view=vs-2017
 */
extern(C++) interface IDebugCodeContext2 : IDebugMemoryContext2{
	HRESULT GetDocumentContext(IDebugDocumentContext2** ppSrcCxt);
	HRESULT GetLanguageInfo(BSTR* pbstrLanguage, GUID* pguidLanguage);
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
 * Reference: https://docs.microsoft.com/en-us/visualstudio/extensibility/debugger/reference/ienumdebugthreads2?view=vs-2017
 */
extern(C++) interface IEnumDebugThreads2 : IUnknown{
	HRESULT Next(ULONG celt, IDebugThread2** rgelt, ULONG* pceltFetched);
}
/**
 * Reference: 
 */
extern(C++) interface IDebugProgram2 : IUnknown{
	HRESULT EnumThreads(IEnumDebugThreads2** ppEnum);
}
/**
 *
 */
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