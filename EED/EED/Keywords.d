module EED.Keywords;

import EED.Common;
import EED.Token;


struct  Keyword
{
    const(wchar_t)*  Name;
    TOK              Code;
    this(const(wchar_t)* name, TOK code){
        this.Name = name;
        this.Code = code;
    }
}


static  Keyword[]  gKeywords = 
[
    Keyword( ""w, TOK.TOKreserved ),
    Keyword( "abstract"w, TOK.TOKabstract ),
    Keyword( "alias"w, TOK.TOKalias ),
    Keyword( "align"w, TOK.TOKalign ),
    Keyword( "asm"w, TOK.TOKasm ),
    Keyword( "assert"w, TOK.TOKassert ),
    Keyword( "auto"w, TOK.TOKauto ),

    Keyword( "body"w, TOK.TOKbody ),
    Keyword( "bool"w, TOK.TOKbool ),
    Keyword( "break"w, TOK.TOKbreak ),
    Keyword( "byte"w, TOK.TOKint8 ),

    Keyword( "case"w, TOK.TOKcase ),
    Keyword( "cast"w, TOK.TOKcast ),
    Keyword( "catch"w, TOK.TOKcatch ),
    Keyword( "cdouble"w, TOK.TOKcomplex64 ),
    Keyword( "cent"w, TOK.TOKcent ),
    Keyword( "cfloat"w, TOK.TOKcomplex32 ),
    Keyword( "char"w, TOK.TOKchar ),
    Keyword( "class"w, TOK.TOKclass ),
    Keyword( "const"w, TOK.TOKconst ),
    Keyword( "continue"w, TOK.TOKcontinue ),
    Keyword( "creal"w, TOK.TOKcomplex80 ),

    Keyword( "dchar"w, TOK.TOKdchar ),
    Keyword( "debug"w, TOK.TOKdebug ),
    Keyword( "default"w, TOK.TOKdefault ),
    Keyword( "delegate"w, TOK.TOKdelegate ),
    Keyword( "delete"w, TOK.TOKdelete ),
    Keyword( "deprecated"w, TOK.TOKdeprecated ),
    Keyword( "do"w, TOK.TOKdo ),
    Keyword( "double"w, TOK.TOKfloat64 ),

    Keyword( "else"w, TOK.TOKelse ),
    Keyword( "enum"w, TOK.TOKenum ),
    Keyword( "export"w, TOK.TOKexport),
    Keyword( "extern"w, TOK.TOKextern ),

    Keyword( "false"w, TOK.TOKfalse ),
    Keyword( "final"w, TOK.TOKfinal ),
    Keyword( "finally"w, TOK.TOKfinally ),
    Keyword( "float"w, TOK.TOKfloat32 ),
    Keyword( "for"w, TOK.TOKfor ),
    Keyword( "foreach"w, TOK.TOKforeach ),
    Keyword( "foreach_reverse"w, TOK.TOKforeach_reverse ),
    Keyword( "function"w, TOK.TOKfunction ),

    Keyword( "goto"w, TOK.TOKgoto ),

    Keyword( "idouble"w, TOK.TOKimaginary64 ),
    Keyword( "if"w, TOK.TOKif ),
    Keyword( "ifloat"w, TOK.TOKimaginary32 ),
    Keyword( "immutable"w, TOK.TOKimmutable ),
    Keyword( "import"w, TOK.TOKimport ),
    Keyword( "in"w, TOK.TOKin ),
    Keyword( "inout"w, TOK.TOKinout ),
    Keyword( "int"w, TOK.TOKint32 ),
    Keyword( "interface"w, TOK.TOKinterface ),
    Keyword( "invariant"w, TOK.TOKinvariant ),
    Keyword( "ireal"w, TOK.TOKimaginary80 ),
    Keyword( "is"w, TOK.TOKis ),

    Keyword( "lazy"w, TOK.TOKlazy ),
    Keyword( "long"w, TOK.TOKint64 ),

    Keyword( "macro"w, TOK.TOKmacro ),
    Keyword( "mixin"w, TOK.TOKmixin ),
    Keyword( "module"w, TOK.TOKmodule ),

    Keyword( "new"w, TOK.TOKnew ),
    Keyword( "nothrow"w, TOK.TOKnothrow ),
    Keyword( "null"w, TOK.TOKnull ),

    Keyword( "out"w, TOK.TOKout ),
    Keyword( "override"w, TOK.TOKoverride ),

    Keyword( "package"w, TOK.TOKpackage ),
    Keyword( "pragma"w, TOK.TOKpragma ),
    Keyword( "private"w, TOK.TOKprivate ),
    Keyword( "protected"w, TOK.TOKprotected ),
    Keyword( "public"w, TOK.TOKpublic ),
    Keyword( "pure"w, TOK.TOKpure ),

    Keyword( "real"w, TOK.TOKfloat80 ),
    Keyword( "ref"w, TOK.TOKref ),
    Keyword( "return"w, TOK.TOKreturn ),

    Keyword( "scope"w, TOK.TOKscope ),
    Keyword( "shared"w, TOK.TOKshared ),
    Keyword( "short"w, TOK.TOKint16 ),
    Keyword( "static"w, TOK.TOKstatic ),
    Keyword( "struct"w, TOK.TOKstruct ),
    Keyword( "super"w, TOK.TOKsuper ),
    Keyword( "switch"w, TOK.TOKswitch ),
    Keyword( "synchronized"w, TOK.TOKsynchronized ),

    Keyword( "template"w, TOK.TOKtemplate ),
    Keyword( "throw"w, TOK.TOKthrow ),
    Keyword( "true"w, TOK.TOKtrue ),
    Keyword( "try"w, TOK.TOKtry ),
    Keyword( "typedef"w, TOK.TOKtypedef ),
    Keyword( "typeid"w, TOK.TOKtypeid ),
    Keyword( "typeof"w, TOK.TOKtypeof ),
    Keyword( "typeof2"w, TOK.TOKtypeof2 ),

    Keyword( "ubyte"w, TOK.TOKuns8 ),
    Keyword( "ucent"w, TOK.TOKucent ),
    Keyword( "uint"w, TOK.TOKuns32 ),
    Keyword( "ulong"w, TOK.TOKuns64 ),
    Keyword( "union"w, TOK.TOKunion ),
    Keyword( "unittest"w, TOK.TOKunittest ),
    Keyword( "ushort"w, TOK.TOKuns16 ),

    Keyword( "version"w, TOK.TOKversion ),
    Keyword( "void"w, TOK.TOKvoid ),
    Keyword( "volatile"w, TOK.TOKvolatile ),

    Keyword( "wchar"w, TOK.TOKwchar ),
    Keyword( "while"w, TOK.TOKwhile ),
    Keyword( "with"w, TOK.TOKwith ),

    Keyword( "__FILE__"w, TOK.TOKfile ),
    Keyword( "__LINE__"w, TOK.TOKline ),
    Keyword( "__gshared"w, TOK.TOKgshared ),
    Keyword( "__thread"w, TOK.TOKtls ),
    Keyword( "__traits"w, TOK.TOKtraits ),
];


TOK  MapToKeyword( const(wchar_t)* id )
{
    return  MapToKeyword( id, wcslen( id ) );
}

TOK  MapToKeyword( const(wchar_t)* id, size_t  len )
{
    for ( int  i = 0; i < _countof( gKeywords ); i++ )
    {
        if ( wcsncmp( gKeywords[i].Name, id, len ) == 0 )
        {
            // they're the same up to our passed in length, 
            // now see if the keyword ends there or is longer
            if ( gKeywords[i].Name[len] == '\0' )
                return  gKeywords[i].Code;
        }
    }

    return  TOK.TOKidentifier;
}