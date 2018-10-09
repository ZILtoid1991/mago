module SingleDocumentContext_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import SingleDocumentContext;


namespace  Mago
{
    HRESULT  SingleDocumentContext.EnumCodeContexts( 
       IEnumDebugCodeContexts2** ppEnumCodeCxts
    )
    {
        _ASSERT( false );
        UNREFERENCED_PARAMETER( ppEnumCodeCxts );
        return  E_FAIL;
    }

    HRESULT  SingleDocumentContext.Init(
        const(wchar_t) * filename,
        ref TEXT_POSITION  statementBegin,
        ref TEXT_POSITION  statementEnd,
        const(wchar_t) * langName,
        ref const  GUID  langGuid )
    {
        return  DocumentContext.Init( filename, statementBegin, statementEnd, langName, langGuid );
    }

    HRESULT  SingleDocumentContext.Clone( DocumentContext** ppDocContext )
    {
        HRESULT  hr = S_OK;
        RefPtr<SingleDocumentContext>   docContext;

        hr = MakeCComObject( docContext );
        if ( FAILED( hr ) )
            return  hr;

        hr = docContext.Init( mFilename, mStatementBegin, mStatementEnd, mLangName, mLangGuid );
        if ( FAILED( hr ) )
            return  hr;

        *ppDocContext = docContext.Detach();
        return  S_OK;
    }
}
