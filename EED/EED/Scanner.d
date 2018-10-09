module EED.Scanner;

import EED.Common;
import EED.Token;
import EED.Keywords;
import EED.NamedChars;
import EED.UniAlpha;
import EED.NameTable;

class Scanner
{
    class TokenNode : Token
    {
        TokenNode Next;

        TokenNode opAssign(ref Token tok)
        {
            memcpy(this, &tok, sizeof(Token));
            return this;
        }
    }

    static immutable int TokenQueueMaxSize = 2;

    enum NUMFLAGS
    {
        FLAGS_decimal = 1, // decimal
        FLAGS_unsigned = 2, // u or U suffix
        FLAGS_long = 4, // l or L suffix
    }

    uint32_t mDVer;
    const wchar_t* mInBuf;
    size_t mBufLen;
    const wchar_t* mCurPtr;
    const wchar_t* mEndPtr;
    Token mTok;
    TokenNode mCurNodes;
    TokenNode mFreeNodes;
    NameTable mNameTable;

public:
    this(const wchar_t* inBuffer, size_t inBufferLen, NameTable nameTable)
    {
        mDVer = 2;
        mInBuf = inBuffer;
        mBufLen = inBufferLen;
        mCurPtr = inBuffer;
        mEndPtr = inBuffer + inBufferLen;
        mCurNodes = null;
        mFreeNodes = null;
        mNameTable = nameTable;
        memset(&mTok, 0, mTok.sizeof);
        mCurNodes = NewNode();
    }

    ~this()
    {
    }

    TOK NextToken()
    {
        if (mCurNodes.Next !is null)
        {
            TokenNode* node = mCurNodes;
            mCurNodes = mCurNodes.Next;

            node.Next = mFreeNodes;
            mFreeNodes = node;

            mTok = *mCurNodes;
        }
        else
        {
            Scan();
            *mCurNodes = mTok;
        }

        static if (SCANNER_DEBUG)
        {
            printf("%d ", mTok.Code);
        }
        return mTok.Code;
    }

    ref const Token PeekToken(int index)
    {
        if ((index > TokenQueueMaxSize) || (index < 0))
            throw 30;

        int n;
        TokenNode* node = mCurNodes;

        for (n = 0; (n < index) && (node.Next !is null); n++)
            node = node.Next;

        for (; n < index; n++)
        {
            Scan();
            node.Next = NewNode();
            node = node.Next;
            *node = mTok;
        }

        return *node;
    }

    const Toke* PeekToken(const Token token)
    {
        assert(token !is null);

        TokenNode* node = cast(TokenNode*) token;

        if (node.Next is null)
        {
            Scan();
            node.Next = NewNode();
            *node.Next = mTok;
        }

        return node.Next;
    }

    ref const Token GetToken()
    {
        return *mCurNodes;
    }

    NameTable GetNameTable()
    {
        return mNameTable;
    }

private:
    void Scan()
    {
        for (;;)
        {
            mTok.TextStartPtr = GetCharPtr();

            switch (GetChar())
            {
            case '\0', 0x001A:
                mTok.Code = TOK.TOKeof;
                return;

            case ' ', '\t', '\v', '\f':
                NextChar();
                break;

            case '\r', '\n', 0x2028, 0x2029:
                NextChar();
                break;

            case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9':
                ScanNumber();
                return;

            case '\'':
                ScanCharLiteral();
                return;

            case '"':
                ScanStringLiteral();
                return;

            case 'q':
                if (PeekChar() == '"')
                {
                    NextChar();
                    ScanDelimitedStringLiteral();
                }
                else if (PeekChar() == '{')
                {
                    NextChar();
                    ScanTokenStringLiteral();
                }
                else
                    goto case_ident;
                return;

            case 'r':
                if (PeekChar() != '"')
                    goto case_ident;
                NextChar();
            case '`':
                ScanWysiwygString();
                return;

            case 'x':
                if (PeekChar() != '"')
                    goto case_ident;
                NextChar();
                ScanHexString();
                return;
                /*static if(DMDV2) {*/
            case 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l',
                    'm', 'n', 'o', 'p', /*'q','r',*/
                    's', 't', 'u', 'v', 'w', /*case L'x':*/ 'y', 'z', 'A',
                    'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
                    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y',
                    'Z', '_':
            case_ident:
                    ScanIdentOrKeyword();
                return;
                /*} else {*/

            }
            case '/':
            NextChar();
            if (GetChar() == '=')
            {
                mTok.Code = TOK.TOKdivass;
                NextChar();
            }
            else
                mTok.Code = TOK.TOKdiv;
            return;

            case '.':
            if (iswdigit(PeekChar()))
            {
                ScanReal();
            }
            else if (PeekChar() == '.')
            {
                NextChar();
                NextChar();
                if (GetChar() == '.')
                {
                    NextChar();
                    mTok.Code = TOK.TOKdotdotdot;
                }
                else
                    mTok.Code = TOK.TOKslice;
            }
            else
            {
                NextChar();
                mTok.Code = TOK.TOKdot;
            }
            return;

            case '&':
            NextChar();
            if (GetChar() == '&')
            {
                NextChar();
                mTok.Code = TOK.TOKandand;
            }
            else if (GetChar() == '=')
            {
                NextChar();
                mTok.Code = TOK.TOKandass;
            }
            else
                mTok.Code = TOK.TOKand;
            return;

            case '|':
            NextChar();
            if (GetChar() == '|')
            {
                NextChar();
                mTok.Code = TOK.TOKoror;
            }
            else if (GetChar() == '=')
            {
                NextChar();
                mTok.Code = TOK.TOKorass;
            }
            else
                mTok.Code = TOK.TOKor;
            return;

            case '-':
            NextChar();
            if (GetChar() == '-')
            {
                NextChar();
                mTok.Code = TOK.TOKminusminus;
            }
            else if (GetChar() == '=')
            {
                NextChar();
                mTok.Code = TOK.TOKminass;
            }
            else if (GetChar() == '>')
            {
                NextChar();
                mTok.Code = TOK.TOKarrow;
            }
            else
                mTok.Code = TOK.TOKmin;
            return;

            case '+':
            NextChar();
            if (GetChar() == '+')
            {
                NextChar();
                mTok.Code = TOK.TOKplusplus;
            }
            else if (GetChar() == '=')
            {
                NextChar();
                mTok.Code = TOK.TOKaddass;
            }
            else
                mTok.Code = TOK.TOKadd;
            return;

            case '<':
            NextChar();
            if (GetChar() == '=')
            {
                NextChar();
                mTok.Code = TOK.TOKle;
            }
            else if (GetChar() == '<')
            {
                NextChar();
                if (GetChar() == '=')
                {
                    NextChar();
                    mTok.Code = TOK.TOKshlass;
                }
                else
                    mTok.Code = TOK.TOKshl;
            }
            else if (GetChar() == '>')
            {
                NextChar();
                if (GetChar() == '=')
                {
                    NextChar();
                    mTok.Code = TOK.TOKleg;
                }
                else
                    mTok.Code = TOK.TOKlg;
            }
            else
                mTok.Code = TOK.TOKlt;
            return;

            case '>':
            NextChar();
            if (GetChar() == '=')
            {
                NextChar();
                mTok.Code = TOK.TOKge;
            }
            else if (GetChar() == '>')
            {
                NextChar();
                if (GetChar() == '=')
                {
                    NextChar();
                    mTok.Code = TOK.TOKshrass;
                }
                else if (GetChar() == '>')
                {
                    NextChar();
                    if (GetChar() == '=')
                    {
                        NextChar();
                        mTok.Code = TOK.TOKushrass;
                    }
                    else
                        mTok.Code = TOK.TOKushr;
                }
                else
                    mTok.Code = TOK.TOKshr;
            }
            else
                mTok.Code = TOK.TOKgt;
            return;

            case '!':
            NextChar();
            if (GetChar() == '=')
            {
                NextChar();
                if ((GetChar() == '=') && (mDVer < 2))
                {
                    NextChar();
                    mTok.Code = TOK.TOKnotidentity;
                }
                else
                    mTok.Code = TOK.TOKnotequal;
            }
            else if (GetChar() == '<')
            {
                NextChar();
                if (GetChar() == '>')
                {
                    NextChar();
                    if (GetChar() == '=')
                    {
                        NextChar();
                        mTok.Code = TOK.TOKunord;
                    }
                    else
                        mTok.Code = TOK.TOKue;
                }
                else if (GetChar() == '=')
                {
                    NextChar();
                    mTok.Code = TOK.TOKug;
                }
                else
                    mTok.Code = TOK.TOKuge;
            }
            else if (GetChar() == '>')
            {
                NextChar();
                if (GetChar() == '=')
                {
                    NextChar();
                    mTok.Code = TOK.TOKul;
                }
                else
                    mTok.Code = TOK.TOKule;
            }
            else
                mTok.Code = TOK.TOKnot;
            return;

            case '(':
            NextChar();
            mTok.Code = TOK.TOKlparen;
            return;

            case ')':
            NextChar();
            mTok.Code = TOK.TOKrparen;
            return;

            case '[':
            NextChar();
            mTok.Code = TOK.TOKlbracket;
            return;

            case ']':
            NextChar();
            mTok.Code = TOK.TOKrbracket;
            return;

            case '{':
            NextChar();
            mTok.Code = TOK.TOKlcurly;
            return;

            case '}':
            NextChar();
            mTok.Code = TOK.TOKrcurly;
            return;

            case '?':
            NextChar();
            mTok.Code = TOK.TOKquestion;
            return;

            case ',':
            NextChar();
            mTok.Code = TOK.TOKcomma;
            return;

            case ';':
            NextChar();
            mTok.Code = TOK.TOKsemicolon;
            return;

            case ':':
            NextChar();
            mTok.Code = TOK.TOKcolon;
            return;

            case '$':
            NextChar();
            mTok.Code = TOK.TOKdollar;
            return;

            case '=':
            NextChar();
            if (GetChar() == '=')
            {
                NextChar();
                if (GetChar() == '=')
                {
                    NextChar();
                    mTok.Code = TOK.TOKidentity;
                }
                else
                    mTok.Code = TOK.TOKequal;
            }
            else
                mTok.Code = TOK.TOKassign;
            return;

            case '*':
            NextChar();
            if (GetChar() == '=')
            {
                NextChar();
                mTok.Code = TOK.TOKmulass;
            }
            else
                mTok.Code = TOK.TOKmul;
            return;

            case '%':
            NextChar();
            if (GetChar() == '=')
            {
                NextChar();
                mTok.Code = TOK.TOKmodass;
            }
            else
                mTok.Code = TOK.TOKmod;
            return;

            case '^':
            NextChar();
            if (GetChar() == '=')
            {
                NextChar();
                mTok.Code = TOK.TOKxorass;
            }
            else if (GetChar() == '^')
            {
                NextChar();
                mTok.Code = TOK.TOKpow;
            }
            else
                mTok.Code = TOK.TOKxor;
            return;

            case '~':
            NextChar();
            if (GetChar() == '=')
            {
                NextChar();
                mTok.Code = TOK.TOKcatass;
            }
            else
                mTok.Code = TOK.TOKtilde;
            return;

            default:
            if (!IsUniAlpha(GetChar()))
                throw  /* SYNTAX ERROR: (558): expected ; instead of 2 */ 2;

            ScanIdentOrKeyword();
            return;
        }
    }
}

void ScanNumber()
{
    // it might be binary, octal, or hexadecimal
    if (hasHexSuffix())
    {
        ScanHex();
    }
    else if (GetChar() == '0')
    {
        wchar_t peekChar = PeekChar();

        if ((peekChar == 'b') || (peekChar == 'B'))
        {
            NextChar();
            NextChar();
            ScanBinary();
        }
        else if ((peekChar == 'x') || (peekChar == 'X'))
        {
            NextChar();
            NextChar();
            ScanHex();
        }
        else if (iswdigit(peekChar) || (peekChar == '_'))
        {
            NextChar();
            ScanOctal();
        }
        else
            ScanZero();
    }
    else if (iswdigit(GetChar()))
    {
        ScanDecimal();
    }
    else
        throw  /* SYNTAX ERROR: (602): expected ; instead of 3 */ 3;
}

void ScanZero()
{
    NUMFLAGS flags = cast(NUMFLAGS) 0;
    const(wchar_t)* start = GetCharPtr();

    NextChar();

    if (((GetChar() == '.') && (PeekChar() != '.')) || (GetChar() == 'i')
            || (GetChar() == 'f') || (GetChar() == 'F') || ((GetChar() == 'L') && (PeekChar() == 'i')))
    {
        Seek(start);
        ScanReal();
        return;
    }

    flags = ScanIntSuffix();

    mTok.UInt64Value = 0;

    if ((flags & FLAGS_long) != 0) // [u]int64
    {
        if ((flags & FLAGS_unsigned) != 0)
            mTok.Code = TOK.TOKuns64v;
        else
            mTok.Code = TOK.TOKint64v;
    }
    else // [u]int32
    {
        if ((flags & FLAGS_unsigned) != 0)
            mTok.Code = TOK.TOKuns32v;
        else
            mTok.Code = TOK.TOKint32v;
    }
}

void ScanDecimal()
{
    std.wstring numStr;
    NUMFLAGS flags = cast(NUMFLAGS) 0;
    const(wchar_t)* start = GetCharPtr();

    for (;; NextChar())
    {
        if (iswdigit(GetChar()))
        {
            numStr.append(1, GetChar());
        }
        else if (GetChar() == '_')
        {
            // ignore it
        }
        else if (((GetChar() == '.') && (PeekChar() != '.')) || (GetChar() == 'i')
                || (GetChar() == 'f') || (GetChar() == 'F') || (GetChar() == 'e')
                || (GetChar() == 'E') || ((GetChar() == 'L') && (PeekChar() == 'i')))
        {
            Seek(start);
            ScanReal();
            return;
        }
        // TODO: should we fail if there's an alpha (uni alpha) right next to the number?
        else
            break;
    }

    flags = ScanIntSuffix();

    ConvertNumberString(numStr.c_str(), 10, cast(NUMFLAGS)(FLAGS_decimal | flags), &mTok);
}

void ScanBinary()
{
    std.wstring numStr;
    NUMFLAGS flags = cast(NUMFLAGS) 0;

    for (;; NextChar())
    {
        if ((GetChar() == '0') || (GetChar() == '1'))
        {
            numStr.append(1, GetChar());
        }
        else if (GetChar() == '_')
        {
            // ignore it
        }
        else if (iswdigit(GetChar()))
            throw  /* SYNTAX ERROR: (692): expected ; instead of 5 */ 5;
        // TODO: should we fail if there's an alpha (uni alpha) right next to the number?
        else
            break;
    }

    flags = ScanIntSuffix();

    ConvertNumberString(numStr.c_str(), 2, flags, &mTok);
}

bool hasHexSuffix()
{
    int i = 0;
    while (IsHexDigit(PeekChar(i)))
        i++;
    if (i <= 0)
        return false;
    return PeekChar(i) == 'h' || PeekChar(i) == 'H';
}

void ScanHex()
{
    std.wstring numStr;
    NUMFLAGS flags = cast(NUMFLAGS) 0;
    const(wchar_t)* start = GetCharPtr();

    for (;; NextChar())
    {
        if (IsHexDigit(GetChar()))
        {
            numStr.append(1, GetChar());
        }
        else if (GetChar() == '_')
        {
            // ignore it
        }
        else if (((GetChar() == '.') && (PeekChar() != '.'))
                || (GetChar() == 'i') || (GetChar() == 'p') || (GetChar() == 'P'))
        {
            Seek(start);
            ScanHexReal();
            return;
        }
        // TODO: should we fail if there's an alpha (uni alpha) right next to the number?
        else
        {
            if (GetChar() == 'h' || GetChar() == 'H')
                NextChar(); // skip suffix
            break;
        }
    }

    flags = ScanIntSuffix();

    ConvertNumberString(numStr.c_str(), 16, flags, &mTok);
}

void ScanOctal()
{
    std.wstring numStr;
    NUMFLAGS flags = cast(NUMFLAGS) 0;
    const(wchar_t)* start = GetCharPtr();
    bool sawNonOctal = false;

    for (;; NextChar())
    {
        if (IsOctalDigit(GetChar()))
        {
            numStr.append(1, GetChar());
        }
        else if (GetChar() == '_')
        {
            // ignore it
        }
        else if (((GetChar() == '.') && (PeekChar() != '.')) || (GetChar() == 'i'))
        {
            Seek(start);
            ScanReal();
            return;
        }
        else if (iswdigit(GetChar()))
        {
            sawNonOctal = true;
            numStr.append(1, GetChar());
        }
        // TODO: should we fail if there's an alpha (uni alpha) right next to the number?
        else
            break;
    }

    if (sawNonOctal)
        throw  /* SYNTAX ERROR: (785): expected ; instead of 6 */ 6; // supposed to be a real

    flags = ScanIntSuffix();

    ConvertNumberString(numStr.c_str(), 8, flags, &mTok);
}

NUMFLAGS ScanIntSuffix()
{
    NUMFLAGS flags = cast(NUMFLAGS) 0;

    for (;; NextChar())
    {
        NUMFLAGS f = cast(NUMFLAGS) 0;

        if (GetChar() == 'L')
            f = FLAGS_long;
        else if ((GetChar() == 'u') || (GetChar() == 'U'))
            f = FLAGS_unsigned;
        // TODO: should we fail if there's an alpha (uni alpha) or number right next to the suffix?
        else
            break;

        if ((flags & f) != 0) // already got this suffix, which is not allowed
            throw  /* SYNTAX ERROR: (809): expected ; instead of 7 */ 7;

        flags = cast(NUMFLAGS)(flags | f);
    }

    return flags;
}

void ConvertNumberString(const(wchar_t)* numStr, int radix, NUMFLAGS flags, Token* token)
{
    _set_errno(0);
    wchar_t* p = null;
    uint64_t n = _wcstoui64(numStr, &p, radix);
    errno_t err = 0;

    if (p == numStr)
        err = EINVAL;
    else
        _get_errno(&err);

    if (err != 0)
        throw  /* SYNTAX ERROR: (830): expected ; instead of 5 */ 5;

    TOK code = TOK.TOKreserved;

    switch (cast(uint32_t) flags)
    {
    case 0:
        /* Octal or Hexadecimal constant.
             * First that fits: int, uint, long, ulong
             */
        if (n & 0x8000000000000000L)
            code = TOK.TOKuns64v;
        else if (n & 0xFFFFFFFF00000000L)
            code = TOK.TOKint64v;
        else if (n & 0x80000000)
            code = TOK.TOKuns32v;
        else
            code = TOK.TOKint32v;
        break;

    case FLAGS_decimal:
        /* First that fits: int, long, long long
             */
        if (n & 0x8000000000000000L)
        {
            throw  /* SYNTAX ERROR: (855): expected ; instead of 6 */ 6;
            //error("signed integer overflow");
            //code = TOKuns64v;
        }
        else if (n & 0xFFFFFFFF80000000L)
            code = TOK.TOKint64v;
        else
            code = TOK.TOKint32v;
        break;

    case FLAGS_unsigned, FLAGS_decimal | FLAGS_unsigned:
        /* First that fits: uint, ulong
             */
        if (n & 0xFFFFFFFF00000000L)
            code = TOK.TOKuns64v;
        else
            code = TOK.TOKuns32v;
        break;

    case FLAGS_decimal | FLAGS_long:
        if (n & 0x8000000000000000L)
        {
            throw  /* SYNTAX ERROR: (878): expected ; instead of 7 */ 7;
            //error("signed integer overflow");
            //code = TOKuns64v;
        }
        else
            code = TOK.TOKint64v;
        break;

    case FLAGS_long:
        if (n & 0x8000000000000000L)
            code = TOK.TOKuns64v;
        else
            code = TOK.TOKint64v;
        break;

    case FLAGS_unsigned | FLAGS_long,
            FLAGS_decimal | FLAGS_unsigned | FLAGS_long:
            code = TOK.TOKuns64v;
        break;

    default:
        assert(false);
    }

    token.UInt64Value = n;
    token.Code = code;
}

void ScanReal()
{
    std.wstring numStr;
    bool sawPoint = false;

    for (;; NextChar())
    {
        if (GetChar() == '_')
            continue;

        if (GetChar() == '.')
        {
            if (sawPoint)
                break;

            sawPoint = true;
        }
        else if (!iswdigit(GetChar()))
            break;

        numStr ~= GetChar();
    }

    if ((GetChar() == 'e') || (GetChar() == 'E'))
    {
        numStr ~= GetChar();
        NextChar();

        if ((GetChar() == '+') || (GetChar() == '-'))
        {
            numStr ~= GetChar();
            NextChar();
        }

        if (!iswdigit(GetChar()))
            throw  /* SYNTAX ERROR: (941): expected ; instead of 6 */ 6;

        for (;; NextChar())
        {
            if (GetChar() == '_')
                continue;
            if (!iswdigit(GetChar()))
                break;

            numStr ~= GetChar();
        }
    }

    TOK tok = ScanGeneralFloatSuffix();

    ConvertRealString(numStr.c_str(), tok, &mTok);
}

void ScanHexReal()
{
    wstring numStr;
    bool sawPoint = false;

    // our conversion function expects "0x" for hex floats
    numStr ~= "0x"w;

    for (;; NextChar())
    {
        if (GetChar() == '_')
            continue;

        if (GetChar() == '.')
        {
            if (sawPoint)
                break;

            sawPoint = true;
        }
        else if (!IsHexDigit(GetChar()))
            break;

        numStr ~= GetChar();
    }

    // binary exponent required
    if ((GetChar() != 'p') && (GetChar() != 'P'))
        throw  /* SYNTAX ERROR: (987): expected ; instead of 5 */ 5;

    numStr.append(1, GetChar());
    NextChar();

    if ((GetChar() == '+') || (GetChar() == '-'))
    {
        numStr.append(1, GetChar());
        NextChar();
    }

    if (!iswdigit(GetChar()))
        throw 6;

    for (;; NextChar())
    {
        if (GetChar() == '_')
            continue;
        if (!iswdigit(GetChar()))
            break;

        numStr.append(1, GetChar());
    }

    TOK tok = ScanGeneralFloatSuffix();

    ConvertRealString(numStr.c_str(), tok, &mTok);
}

void ConvertRealString(const(wchar_t)* numStr, TOK tok, Token* token)
{
    Real10 val;
    errno_t err = 0;
    bool fits = true;

    err = Real10.Parse(numStr, val);
    if (err != 0)
        throw 22;

    if ((tok == TOK.TOKfloat64v) || (tok == TOK.TOKimaginary64v))
        fits = val.FitsInDouble();
    else if ((tok == TOK.TOKfloat32v) || (tok == TOK.TOKimaginary32v))
        fits = val.FitsInFloat();

    if (!fits)
        throw 23;

    token.Code = tok;
    token.Float80Value = val;
}

TOK ScanGeneralFloatSuffix()
{
    TOK tok = TOK.TOKfloat64v;

    switch (GetChar())
    {
    case 'f':
    case 'F':
        NextChar();
        tok = TOK.TOKfloat32v;
        break;

    case 'L':
        NextChar();
        tok = TOK.TOKfloat80v;
        break;
    default:
        break;
    }

    if (GetChar() == 'i')
    {
        NextChar();

        switch (tok)
        {
        case TOK.TOKfloat32v:
            tok = TOK.TOKimaginary32v;
            break;
        case TOK.TOKfloat64v:
            tok = TOK.TOKimaginary64v;
            break;
        case TOK.TOKfloat80v:
            tok = TOK.TOKimaginary80v;
            break;
        default:
            break;
        }
    }

    return tok;
}

void ScanIdentOrKeyword()
{
    const(wchar_t)* startPtr = GetCharPtr();
    size_t len = 0;

    while (IsIdentChar(GetChar()))
    {
        NextChar();
    }

    len = GetCharPtr() - startPtr;

    TOK code = MapToKeyword(startPtr, len);

    if (code == TOK.TOKidentifier)
    {
        mTok.Utf16Str = mNameTable.AddString(startPtr, len);
    }

    mTok.Code = code;
}

void ScanCharLiteral()
{
    TOK tok = TOK.TOKcharv;
    uint32_t c = 0;

    NextChar();
    c = GetChar();

    switch (c)
    {
    case '\\':
        if (PeekChar() == 'u')
            tok = TOK.TOKwcharv;
        else if ((PeekChar() == 'U') || (PeekChar() == '&'))
            tok = TOK.TOKdcharv;
        c = ScanEscapeChar();
        break;

    case '\n', 0x2028, 0x2029, '\r', '\0', 0x001A, '\'':
        throw 8;

    default:
        c = ReadChar32();
        if (c > 0xFFFF)
            tok = TOK.TOKdcharv;
        else if (c >= 0x80)
            tok = TOK.TOKwcharv;
        break;
    }

    if (GetChar() != '\'')
        throw  /* SYNTAX ERROR: (1136): expected ; instead of 10 */ 10;
    NextChar();

    mTok.Code = tok;
    mTok.UInt64Value = c;
}

void ScanStringLiteral()
{
    char[] buf;
    dchar_t c = 0;

    NextChar();

    for (;;)
    {
        if (GetChar() == '"')
            break;
        if ((GetChar() == '\0') || (GetChar() == 0x001A))
            throw 21;
        if (GetChar() == '\r')
        {
            if (PeekChar() == '\n')
                continue;
            NextChar();
            c = '\n';
        }
        else if ((GetChar() == 0x2028) || (GetChar() == 0x2029))
        {
            NextChar();
            c = '\n';
        }
        else if (GetChar() == '\\')
            c = ScanEscapeChar();
        else
            c = ReadChar32();

        AppendChar32(buf, c);
    }

    NextChar();
    wchar_t postfix = ScanStringPostfix();

    buf.push_back(0);
    AllocateStringToken(buf, postfix);
}

void ScanDelimitedStringLiteral()
{
    std.wstring str;

    NextChar(); // skip '"'

    if (iswalpha(GetChar()) || (GetChar() == '_') || IsUniAlpha(GetChar()))
        ScanDelimitedStringLiteralID(str);
    else if (iswspace(GetChar()))
        throw  /* SYNTAX ERROR: (1194): expected ; instead of 16 */ 16;
    else
        ScanDelimitedStringLiteralSeparator(str);

    NextChar(); // skip '"'
    wchar_t postfix = ScanStringPostfix();

    AllocateStringToken(str, postfix);
}

void ScanDelimitedStringLiteralSeparator(ref wstring str)
{
    dchar_t left = '\0';
    dchar_t right = '\0';
    int nestCount = 1;
    bool nesting = true;

    left = ReadChar32();

    if (left == '[')
        right = ']';
    else if (left == '(')
        right = ')';
    else if (left == '<')
        right = '>';
    else if (left == '{')
        right = '}';
    else
    {
        right = left;
        nesting = false;
        nestCount = 0;
    }

    for (;;)
    {
        if ((nestCount == 0) && (GetChar() == '"'))
            break;
        if ((GetChar() == '\0') || (GetChar() == 0x001A))
            throw 21;

        dchar_t c = ReadChar32();

        if (c == '\r')
        {
            if (GetChar() == '\n')
                continue;
            c = '\n';
        }
        else if ((c == 0x2028) || (c == 0x2029))
            c = '\n';

        if (c == right)
        {
            if (nesting)
                nestCount--;
            if ((nestCount == 0) && (GetChar() != '"'))
                throw 12;
            if (nestCount == 0)
                continue;
        }
        else if (c == left)
        {
            if (nesting)
                nestCount++;
        }

        AppendChar32(str, c);
    }
}

void ScanDelimitedStringLiteralID(ref wstring str)
{
    Utf16String* id = null;
    const(wchar_t)* start = null;
    bool atLineBegin = true;

    Scan();

    if (mTok.Code != TOK.TOKidentifier)
        throw 17;
    else
        id = mTok.Utf16Str;

    switch (GetChar())
    {
    case '\r':
        if (PeekChar() == '\n')
            NextChar(); // skip '\r'
        // fall thru
    case '\n', 0x2028, 0x2029:
        NextChar();
        break;
    default:
        throw 18;
    }

    for (;;)
    {
        switch (GetChar())
        {
        case '\r':
            if (PeekChar() == '\n')
                NextChar(); // skip '\r'
            // fall thru
        case '\n', 0x2028, 0x2029:
            atLineBegin = true;
            str.append(1, '\n');
            NextChar();
            continue;
        case '\0', 0x001A:
            throw  /* SYNTAX ERROR: (1310): expected ; instead of 21 */ 21;
        default:
            break;
        }

        if (atLineBegin)
        {
            start = GetCharPtr();
            Scan();
            if ((mTok.Code == TOK.TOKidentifier) && (wcscmp(mTok.Utf16Str.Str, id.Str) == 0))
            {
                if (GetChar() != '"')
                    throw 14;
                break;
            }
            Seek(start);
        }

        dchar_t c = ReadChar32();

        AppendChar32(str, c);
        atLineBegin = false;
    }
}

void ScanTokenStringLiteral()
{
    const(wchar_t)* start = null;
    const(wchar_t)* end = null;
    int nestCount = 1;

    NextChar();
    start = GetCharPtr();
    Scan();

    for (;; Scan())
    {
        if (mTok.Code == TOK.TOKlcurly)
        {
            nestCount++;
        }
        else if (mTok.Code == TOK.TOKrcurly)
        {
            end = GetCharPtr() - 1;
            nestCount--;
            if (nestCount == 0)
                break;
        }
        else if (mTok.Code == TOKeof)
            throw 14;
    }

    wchar_t postfix = ScanStringPostfix();

    size_t len = end - start;
    wstring str;
    str.append(start, len);
    AllocateStringToken(str, postfix);
}

void ScanWysiwygString()
{
    std.wstring str;
    wchar_t quoteChar = GetChar();

    NextChar();

    for (;;)
    {
        switch (GetChar())
        {
        case '\r':
            if (PeekChar() == '\n')
                NextChar();
            str ~= '\n';
            NextChar();
            continue;

        case '\0', 0x001A:
            throw  /* SYNTAX ERROR: (1388): expected ; instead of 7 */ 7;

        case '"', '`':
            if (GetChar() == quoteChar)
            {
                NextChar();
                wchar_t post = ScanStringPostfix();

                AllocateStringToken(str, post);
                return;
            }
            break;
        default:
            break;
        }

        AppendChar32(str, ReadChar32());
    }
}

void ScanHexString()
{
    char[] buf;
    int digitCount = 0;
    uint8_t b = 0;

    NextChar();

    for (; GetChar() != '"'; NextChar())
    {
        if ((GetChar() == '\0') || (GetChar() == 0x001A))
            throw 21;
        if (iswspace(GetChar()))
            continue;

        wchar_t c = GetChar();
        int digit = 0;

        if ((c >= '0') && (c <= '9'))
            digit = c - '0';
        else if ((c >= 'A') && (c <= 'F'))
            digit = c - 'A';
        else if ((c >= 'a') && (c <= 'f'))
            digit = c - 'a';
        else
            throw 11;

        digitCount++;

        if ((digitCount & 1) == 0) // finished a byte
        {
            b |= digit;
            buf.push_back(b);
        }
        else
        {
            b = cast(uint8_t)(digit << 4);
        }
    }

    // has to be even
    if ((digitCount & 1) == 1)
        throw 12;

    NextChar();
    wchar_t postfix = ScanStringPostfix();

    buf.push_back(0);

    AllocateStringToken(buf, postfix);
}

wchar_t ScanStringPostfix()
{
    wchar_t c = 0;

    switch (GetChar())
    {
    case 'c', 'w', 'd':
        c = GetChar();
        NextChar();
        return c;

    default:
        return 0;
    }
}

char* ConvertUtf16To8(const(wchar_t)* utf16Str)
{
    int len = 0;
    int len2 = 0;
    char* utf8Str = null;

    len = Utf16To8(utf16Str, -1, null, 0);
    if ((len == 0) && (GetLastError() == ERROR_NO_UNICODE_TRANSLATION))
        throw  /* SYNTAX ERROR: (1485): expected ; instead of 13 */ 13;
    assert(len > 0);

    // len includes trailing '\0'
    utf8Str = new char[len];
    len2 = Utf16To8(utf16Str, -1, utf8Str, len);
    assert((len2 > 0) && (len2 == len));

    return utf8Str;
}

wchar_t* ConvertUtf8To16(const(char)* utf8Str)
{
    int len = 0;
    int len2 = 0;
    wchar_t* utf16Str = null;

    len = Utf8To16(utf8Str, -1, null, 0);
    if ((len == 0) && (GetLastError() == ERROR_NO_UNICODE_TRANSLATION))
        throw  /* SYNTAX ERROR: (1504): expected ; instead of 13 */ 13;
    _ASSERT(len > 0);

    // len includes trailing '\0'
    utf16Str = new wchar_t[len];
    len2 = Utf8To16(utf8Str, -1, utf16Str, len);
    _ASSERT((len2 > 0) && (len2 == len));

    return utf16Str;
}

dchar_t* ConvertUtf8To32(const(char)* utf8Str, ref size_t length)
{
    int len = 0;
    int len2 = 0;
    dchar_t* utf32Str = null;

    len = Utf8To32(utf8Str, -1, null, 0);
    if ((len == 0) && (GetLastError() == ERROR_NO_UNICODE_TRANSLATION))
        throw  /* SYNTAX ERROR: (1523): expected ; instead of 13 */ 13;
    assert(len > 0);

    // len includes trailing '\0'
    utf32Str = new dchar_t[len];
    len2 = Utf8To32(utf8Str, -1, utf32Str, len);
    assert((len2 > 0) && (len2 == len));

    length = len;
    return utf32Str;
}

dchar_t* ConvertUtf16To32(const(wchar_t)* utf16Str, ref size_t length)
{
    int len = 0;
    int len2 = 0;
    dchar_t* utf32Str = null;

    len = Utf16To32(utf16Str, -1, null, 0);
    if ((len == 0) && (GetLastError() == ERROR_NO_UNICODE_TRANSLATION))
        throw  /* SYNTAX ERROR: (1543): expected ; instead of 13 */ 13;
    assert(len > 0);

    // len includes trailing '\0'
    utf32Str = new dchar_t[len];
    len2 = Utf16To32(utf16Str, -1, utf32Str, len);
    assert((len2 > 0) && (len2 == len));

    length = len;
    return utf32Str;
}

void AllocateStringToken(ref const vector!(char) buf, wchar_t postfix)
{
    if ((postfix == 0) || (postfix == 'c'))
    {
        // when the string is a char[], it doesn't have to be UTF-8
        mTok.ByteStr = mNameTable.AddString(&buf.front(), buf.size() - 1);
        if (postfix == 'c')
            mTok.Code = TOK.TOKcstring;
        else
            mTok.Code = TOK.TOKstring;
    }
    else if (postfix == 'w')
    {
        wchar_t* str = ConvertUtf8To16(&buf.front());
        mTok.Utf16Str = mNameTable.AddString(str, wcslen(str));
        mTok.Code = TOK.TOKwstring;
        free(str);
    }
    else if (postfix == 'd')
    {
        size_t len = 0;
        dchar_t* str = ConvertUtf8To32(&buf.front(), len);
        mTok.Utf32Str = mNameTable.AddString(str, len - 1);
        mTok.Code = TOK.TOKdstring;
        free(str);
    }
    else
        assert(false);
}

void AllocateStringToken(ref const std.wstring str, wchar_t postfix)
{
    if ((postfix == 0) || (postfix == 'c'))
    {
        char* astr = ConvertUtf16To8(str.c_str());
        mTok.ByteStr = mNameTable.AddString(astr, strlen(astr));
        if (postfix == 'c')
            mTok.Code = TOK.TOKcstring;
        else
            mTok.Code = TOK.TOKstring;
        free(astr);
    }
    else if (postfix == 'w')
    {
        mTok.Utf16Str = mNameTable.AddString(str.c_str(), str.size());
        mTok.Code = TOK.TOKwstring;
    }
    else if (postfix == 'd')
    {
        size_t len = 0;
        dchar_t* dstr = ConvertUtf16To32(str.c_str(), len);
        mTok.Utf32Str = mNameTable.AddString(dstr, len - 1);
        mTok.Code = TOK.TOKdstring;
        free(dstr);
    }
    else
        assert(false);
}

dchar_t ScanEscapeChar()
{
    dchar_t c = 0;
    const(wchar_t)* start = null;

    NextChar(); // skip backslash
    c = GetChar();
    start = GetCharPtr();
    NextChar();

    switch (c)
    {
    case '\'':
        c = '\'';
        break;
    case '"':
        c = '"';
        break;
    case '?':
        c = '\?';
        break;
    case '\\':
        c = '\\';
        break;
    case 'a':
        c = '\a';
        break;
    case 'b':
        c = '\b';
        break;
    case 'f':
        c = '\f';
        break;
    case 'n':
        c = '\n';
        break;
    case 'r':
        c = '\r';
        break;
    case 't':
        c = '\t';
        break;
    case 'v':
        c = '\v';
        break;

        // TODO: EndOfFile?
        //case 

    case 'x':
        c = ScanFixedSizeHex(2);
        break;

    case 'u':
        c = ScanFixedSizeHex(4);
        break;

    case 'U':
        c = ScanFixedSizeHex(8);
        break;

    case '&':
        for (;; NextChar())
        {
            if (GetChar() == ';')
            {
                size_t len = GetCharPtr() - start - 1; // not counting '&'
                dchar_t c = MapNamedCharacter(start + 1, len);

                if (c == 0)
                    throw  /* SYNTAX ERROR: (1662): expected ; instead of 20 */ 20;

                NextChar();
                return c;
            }

            if (!iswalpha(GetChar()) && ((GetCharPtr() == (start + 1)) || !iswdigit(GetChar())))
                throw  /* SYNTAX ERROR: (1670): expected ; instead of 21 */ 21;
        }
        break;

    default:
        Seek(start);
        if (!IsOctalDigit(GetChar()))
            throw  /* SYNTAX ERROR: (1677): expected ; instead of 17 */ 17;
        c = 0;
        for (int i = 0; (i < 3) && IsOctalDigit(GetChar()); i++)
        {
            int digit = GetChar() - '0';
            c *= 8;
            c += digit;
            NextChar();
        }
        // D compiler doesn't care if there's an octal char after 3 in escape char
        break;
    }

    return c;
}

uint32_t ScanFixedSizeHex(int length)
{
    uint32_t n = 0;
    uint32_t digit = 0;

    for (int i = 0; i < length; i++)
    {
        if (!IsHexDigit(GetChar()))
            throw 18;

        if (iswdigit(GetChar()))
            digit = GetChar() - '0';
        else if (iswlower(GetChar()))
            digit = GetChar() - 'a' + 10;
        else
            digit = GetChar() - 'A' + 10;

        n *= 16;
        n += digit;
        NextChar();
    }

    if (IsHexDigit(GetChar()))
        throw 19;

    return n;
}

wchar_t GetChar()
{
    if (mCurPtr >= mEndPtr)
        return '\0';

    wchar_t c = *mCurPtr;

    return c;
}

dchar_t ReadChar32()
{
    if (mCurPtr >= mEndPtr)
        return '\0';

    dchar_t c = *mCurPtr;
    mCurPtr++;

    if ((c >= 0xDC00) && (c <= 0xDFFF)) // high surrogate can't be first wchar
        throw 1;
    if ((c >= 0xD800) && (c <= 0xDBFF))
    {
        wchar_t c2 = *mCurPtr;
        mCurPtr++;

        if ((c2 < 0xDC00) || (c2 > 0xDFFF))
            throw 1;

        c &= ~0xD800;
        c2 &= ~0xDC00;
        c = (c2 | (c << 10)) + 0x10000;
    }
    // else c is the whole character

    if (c > 0x10FFFF)
        throw 1;

    return c;
}

wchar_t PeekChar()
{
    if (mCurPtr == '\0')
        return '\0';

    return mCurPtr[1];
}

wchar_t PeekChar(int index)
{
    if ((mCurPtr + index) >= mEndPtr)
        return '\0';

    return mCurPtr[index];
}

const(wchar_t)* GetCharPtr()
{
    return mCurPtr;
}

void Seek(const(wchar_t)* ptr)
{
    assert((ptr >= mInBuf) && (ptr < mEndPtr));

    mCurPtr = ptr;
}

void NextChar()
{
    mCurPtr++;
}

Scanner.TokenNode NewNode()
{
    TokenNode node = null;

    if (mFreeNodes is null)
    {
        node = new TokenNode();
        //node->Prev = NULL;
    }
    else
    {
        node = mFreeNodes;
        mFreeNodes = mFreeNodes.Next;
    }

    node.Next = null;
    return node;
}

