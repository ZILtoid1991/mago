module common.atlcom;

/*
Bindings for atl.h

Copyright 2018 by Laszlo Szeremi
 */

//namespace is ATL
import core.sys.windows.windows;


alias CComConnectionPointContainerImpl = IConnectionPointContainerImpl;
alias CComISupportErrorInfoImpl = ISupportErrorInfoImpl;
alias CComProvideClassInfo2Impl = IProvideClassInfo2Impl;
alias CComDualImpl = IDispatchImpl;
//inlined functions
HRESULT AtlReportError( const ref CLSID clsid,  UINT nID,  const ref IID iid = GUID_NULL,
         HRESULT hRes = 0,  HINSTANCE hInst = _AtlBaseModule.GetResourceInstance())
{
    return AtlSetErrorInfo(clsid, cast(LPCOLESTR) MAKEINTRESOURCE(nID), 0, NULL, iid, hRes, hInst);
}
HRESULT AtlReportError( const ref CLSID clsid,  UINT nID,  DWORD dwHelpID,
        LPCOLESTR lpszHelpFile,  const ref IID iid = GUID_NULL,
         HRESULT hRes = 0,  HINSTANCE hInst = _AtlBaseModule.GetResourceInstance())
{
    return AtlSetErrorInfo(clsid, cast(LPCOLESTR) MAKEINTRESOURCE(nID), dwHelpID,
            lpszHelpFile, iid, hRes, hInst);
}

HRESULT AtlReportError( const ref CLSID clsid, LPCSTR lpszDesc,  DWORD dwHelpID,
        LPCSTR lpszHelpFile,  const ref IID iid = GUID_NULL,  HRESULT hRes = 0)
{
    assert(lpszDesc != NULL);
    if (lpszDesc == NULL)
        return E_POINTER;
    USES_CONVERSION_EX;
    LPCOLESTR pwszDesc = A2COLE_EX(lpszDesc, _ATL_SAFE_ALLOCA_DEF_THRESHOLD);
    if (pwszDesc == NULL)
        return E_OUTOFMEMORY;

    LPCWSTR pwzHelpFile = NULL;
    if (lpszHelpFile != NULL)
    {
        pwzHelpFile = A2CW_EX(lpszHelpFile, _ATL_SAFE_ALLOCA_DEF_THRESHOLD);
        if (pwzHelpFile == NULL)
            return E_OUTOFMEMORY;
    }

    return AtlSetErrorInfo(clsid, pwszDesc, dwHelpID, pwzHelpFile, iid, hRes, NULL);
}

HRESULT AtlReportError( const ref CLSID clsid, LPCSTR lpszDesc,
         const ref IID iid = GUID_NULL,  HRESULT hRes = 0)
{
    return AtlReportError(clsid, lpszDesc, 0, NULL, iid, hRes);
}

HRESULT AtlReportError( const ref CLSID clsid, LPCOLESTR lpszDesc,
         const ref IID iid = GUID_NULL,  HRESULT hRes = 0)
{
    return AtlSetErrorInfo(clsid, lpszDesc, 0, NULL, iid, hRes, NULL);
}

HRESULT AtlReportError( const ref CLSID clsid, LPCOLESTR lpszDesc,  DWORD dwHelpID,
        LPCOLESTR lpszHelpFile,  const ref IID iid = GUID_NULL,  HRESULT hRes = 0)
{
    return AtlSetErrorInfo(clsid, lpszDesc, dwHelpID, lpszHelpFile, iid, hRes, NULL);
}

// Returns the apartment type that the current thread is in. false is returned
// if the thread isn't in an apartment.
//inline _Success_(return  != false) 
bool AtlGetApartmentType(out DWORD * pApartmentType)
{
    HRESULT hr = CoInitialize(NULL);
    if (SUCCEEDED(hr))
        CoUninitialize();

    if (hr == S_FALSE)
    {
         * pApartmentType = COINIT_APARTMENTTHREADED;
        return true;
    }
    else if (hr == RPC_E_CHANGED_MODE)
    {
         * pApartmentType = COINIT_MULTITHREADED;
        return true;
    }

    return false;
}
extern (Windows, ATL):