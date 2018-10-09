module EED.Parser;

import EED.Common;
import EED.EE;
import EED.Scanner;
import EED.Expression;
import EED.NameTable;
import EED.Type;
import EED.TypeUnresolved;
import EED.TypeEnv;
import EED.Declaration;

class Parser
{
    enum DeclIdMode
    {
        DeclId_None,
        DeclId_Optional,
        DeclId_Needed
    }

    Scanner mScanner;
    ITypeEnv mTypeEnv;
    uint32_t mDVer;
    int mBracketCount;

public:
    this(Scanner scanner, ITypeEnv typeEnv)
    {
        mScanner = (scanner);
        mTypeEnv = (typeEnv);
        mDVer = (2);
        assert(scanner !is null);
    }

    Expression ParseExpression()
    {
        // there's no need to accept these in a debugger's expression evaluator
        // so, don't bother, and go straight to the next kind of expression
        return ParseAssignExpr();
    }

    Expression ParseCommaExpr()
    {
        Expression e;
        Expression e2;

        e = ParseAssignExpr();

        while (GetTokenCode() == TOK.TOKcomma)
        {
            NextToken();
            e2 = ParseAssignExpr();
            e = new CommaExpr(e, e2);
        }

        return e;
    }

    Expression ParseAssignExpr()
    {
        Expression e;
        Expression e2;

        e = ParseConditionalExpr();

        for (;;)
        {
            switch (GetTokenCode())
            {
            case TOK.TOKassign:
                NextToken();
                e2 = ParseAssignExpr();
                e = new AssignExpr(e.Get(), e2.Get());
                break;

            case TOK.TOKaddass:
                NextToken();
                e2 = ParseAssignExpr();
                e = new CombinedAssignExpr(new AddExpr(e, e2));
                break;
            case TOK.TOKminass:
                NextToken();
                e2 = ParseAssignExpr();
                e = new CombinedAssignExpr(new MinExpr(e, e2));
                break;
            case TOK.TOKmulass:
                NextToken();
                e2 = ParseAssignExpr();
                e = new CombinedAssignExpr(new MulExpr(e, e2));
                break;
            case TOK.TOKdivass:
                NextToken();
                e2 = ParseAssignExpr();
                e = new CombinedAssignExpr(new DivExpr(e, e2));
                break;
            case TOK.TOKmodass:
                NextToken();
                e2 = ParseAssignExpr();
                e = new CombinedAssignExpr(new ModExpr(e, e2));
                break;
                //case TOKpowas: NextToken(); e2 = ParseAssignExpr(); e = new CombinedAssignExpr( new PowExpr( e, e2.Get() ) ); break;
            case TOK.TOKandass:
                NextToken();
                e2 = ParseAssignExpr();
                e = new CombinedAssignExpr(new AndExpr(e, e2));
                break;
            case TOK.TOKorass:
                NextToken();
                e2 = ParseAssignExpr();
                e = new CombinedAssignExpr(new OrExpr(e, e2));
                break;
            case TOK.TOKxorass:
                NextToken();
                e2 = ParseAssignExpr();
                e = new CombinedAssignExpr(new XorExpr(e, e2));
                break;
            case TOK.TOKshlass:
                NextToken();
                e2 = ParseAssignExpr();
                e = new CombinedAssignExpr(new ShiftLeftExpr(e, e2));
                break;
            case TOK.TOKshrass:
                NextToken();
                e2 = ParseAssignExpr();
                e = new CombinedAssignExpr(new ShiftRightExpr(e, e2));
                break;
            case TOK.TOKushrass:
                NextToken();
                e2 = ParseAssignExpr();
                e = new CombinedAssignExpr(new UShiftRightExpr(e, e2));
                break;
            case TOK.TOKcatass:
                NextToken();
                e2 = ParseAssignExpr();
                e = new CombinedAssignExpr(new CatExpr(e, e2));
                break;
            default:
                goto Done;
            }
        }

    Done:
        return e;
    }

    Expression ParseConditionalExpr()
    {
        Expression e;
        Expression e2;
        Expression e3;

        e = ParseOrOrExpr();

        if (GetTokenCode() == TOK.TOKquestion)
        {
            e2 = ParseExpression();
            ReadToken(TOK.TOKcolon);
            e3 = ParseConditionalExpr();
            e = new ConditionalExpr(e, e2, e3);
        }

        return e;
    }

    Expression ParseOrOrExpr()
    {
        Expression e;
        Expression e2;

        e = ParseAndAndExpr();

        while (GetTokenCode() == TOKoror)
        {
            NextToken();
            e2 = ParseAndAndExpr();
            e = new OrOrExpr(e, e2);
        }

        return e;
    }

    Expression ParseAndAndExpr()
    {
        Expression e;
        Expression e2;

        e = ParseOrExpr();

        while (GetTokenCode() == TOKandand)
        {
            NextToken();
            e2 = ParseOrExpr();
            e = new AndAndExpr(e, e2);
        }

        return e;
    }

    Expression ParseOrExpr()
    {
        Expression e;
        Expression e2;

        e = ParseXorExpr();

        while (GetTokenCode() == TOKor)
        {
            NextToken();
            e2 = ParseXorExpr();
            e = new OrExpr(e, e2);
        }

        return e;
    }

    Expression ParseXorExpr()
    {
        Expression e;
        Expression e2;

        e = ParseAndExpr();

        while (GetTokenCode() == TOKxor)
        {
            NextToken();
            e2 = ParseAndExpr();
            e = new XorExpr(e, e2);
        }

        return e;
    }

    Expression ParseAndExpr()
    {
        Expression e;
        Expression e2;

        // D v1
        if (mDVer < 2)
        {
            e = ParseEqualExpr();

            while (GetTokenCode() == TOK.TOKand)
            {
                NextToken();
                e2 = ParseEqualExpr();
                e = new AndExpr(e, e2);
            }
        }
        else
        {
            e = ParseCmpExpr();

            while (GetTokenCode() == TOK.TOKand)
            {
                NextToken();
                e2 = ParseCmpExpr();
                e = new AndExpr(e, e2);
            }
        }

        return e;
    }

    Expression ParseCmpExpr()
    {
        Expression e;
        Expression e2;

        e = ParseShiftExpr();

        for (;;)
        {
            TOK opCode = GetTokenCode();

            switch (GetTokenCode())
            {
            case TOK.TOKequal:
            case TOK.TOKnotequal:
                NextToken();
                e2 = ParseShiftExpr();
                e = new EqualExpr(opCode, e.Get(), e2.Get());
                break;

            case TOK.TOKis:
                NextToken();
                e2 = ParseShiftExpr();
                e = new IdentityExpr(TOKidentity, e.Get(), e2.Get());
                break;

            case TOK.TOKnot:
                if (PeekTokenCode(1) != TOK.TOKis)
                    break;
                NextToken();
                NextToken();
                e2 = ParseShiftExpr();
                e = new IdentityExpr(TOKnotidentity, e.Get(), e2.Get());
                break;

            case TOK.TOKlt, TOK.TOKle, TOK.TOKgt, TOK.TOKge, TOK.TOKunord,
                    TOK.TOKlg, TOK.TOKleg, TOK.TOKule, TOK.TOKul, TOK.TOKuge,
                    TOK.TOKug, TOK.TOKue:
                    NextToken();
                e2 = ParseShiftExpr();
                // D front end only makes CmpExp, and their RelExp seems deprecated
                // it's the other way around here
                e = new RelExpr(opCode, e, e2);
                break;

            case TOK.TOKin:
                NextToken();
                e2 = ParseShiftExpr();
                e = new InExpr(e, e2);
                break;

            default:
                goto Done;
            }
        }

    Done:
        return e;
    }

    Expression ParseEqualExpr()
    {
        Expression e;
        Expression e2;

        e = ParseRelExpr();

        for (;;)
        {
            TOK opCode = GetTokenCode();

            switch (GetTokenCode())
            {
            case TOKequal, TOKnotequal:
                NextToken();
                e2 = ParseRelExpr();
                e = new EqualExpr(opCode, e, e2);
                break;

            case TOK.TOKidentity, TOK.TOKnotidentity, TOK.TOKis:
                if (opCode == TOK.TOKis)
                    opCode = TOK.TOKidentity;
                NextToken();
                e2 = ParseRelExpr();
                e = new IdentityExpr(opCode, e, e2);
                break;

            case TOKnot:
                if (PeekTokenCode(1) != TOK.TOKis)
                    break;
                NextToken();
                NextToken();
                e2 = ParseRelExpr();
                e = new IdentityExpr(TOKnotidentity, e, e2);
                break;

            default:
                goto Done;
            }
        }

    Done:
        return e;
    }

    Expression ParseRelExpr()
    {
        Expression e;
        Expression e2;

        e = ParseShiftExpr();

        for (;;)
        {
            TOK opCode = GetTokenCode();

            switch (GetTokenCode())
            {
            case TOK.TOKlt, TOK.TOKle, TOK.TOKgt, TOK.TOKge, TOK.TOKunord,
                    TOK.TOKlg, TOK.TOKleg, TOK.TOKule, TOK.TOKul, TOK.TOKuge,
                    TOK.TOKug, TOK.TOKue:
                    NextToken();
                e2 = ParseShiftExpr();
                e = new RelExpr(opCode, e, e2);
                break;

            case TOK.TOKin:
                NextToken();
                e2 = ParseShiftExpr();
                e = new InExpr(e, e2);
                break;

            default:
                goto Done;
            }
        }

    Done:
        return e;
    }

    Expression ParseShiftExpr()
    {
        Expression e;
        Expression e2;

        e = ParseAddExpr();

        for (;;)
        {
            switch (GetTokenCode())
            {
            case TOKshl:
                NextToken();
                e2 = ParseAddExpr();
                e = new ShiftLeftExpr(e, e2);
                break;

            case TOKshr:
                NextToken();
                e2 = ParseAddExpr();
                e = new ShiftRightExpr(e, e2);
                break;

            case TOKushr:
                NextToken();
                e2 = ParseAddExpr();
                e = new UShiftRightExpr(e, e2);
                break;

            default:
                goto Done;
            }
        }

    Done:
        return e;
    }

    Expression ParseAddExpr()
    {
        Expression e;
        Expression e2;

        e = ParseMulExpr();

        for (;;)
        {
            switch (GetTokenCode())
            {
            case TOK.TOKadd:
                NextToken();
                e2 = ParseMulExpr();
                e = new AddExpr(e, e2);
                break;

            case TOK.TOKmin:
                NextToken();
                e2 = ParseMulExpr();
                e = new MinExpr(e, e2);
                break;

            case TOK.TOKtilde:
                NextToken();
                e2 = ParseMulExpr();
                e = new CatExpr(e, e2);
                break;

            default:
                goto Done;
            }
        }

    Done:
        return e;
    }

    Expression ParseMulExpr()
    {
        Expression e;
        Expression e2;

        e = ParseUnaryExpr();

        for (;;)
        {
            switch (GetTokenCode())
            {
            case TOK.TOKmul:
                NextToken();
                e2 = ParseUnaryExpr();
                e = new MulExpr(e, e2);
                break;

            case TOK.TOKdiv:
                NextToken();
                e2 = ParseUnaryExpr();
                e = new DivExpr(e, e2);
                break;

            case TOK.TOKmod:
                NextToken();
                e2 = ParseUnaryExpr();
                e = new ModExpr(e, e2);
                break;

            case TOK.TOKpow:
                NextToken();
                e2 = ParseUnaryExpr();
                e = new PowExpr(e, e2);
                break;

            default:
                goto Done;
            }
        }

    Done:
        return e;
    }

    Expression ParseUnaryExpr()
    {
        Expression e;
        Expression e2;

        switch (GetTokenCode())
        {
        case TOK.TOKand:
            NextToken();
            e = ParseUnaryExpr();
            e = new AddressOfExpr(e.Get());
            break;

        case TOK.TOKplusplus:
            NextToken();
            e = ParseUnaryExpr();
            e2 = new IntExpr(1, mTypeEnv.GetType(Tint32));
            e = new CombinedAssignExpr(new AddExpr(e.Get(), e2.Get()));
            break;

        case TOK.TOKminusminus:
            NextToken();
            e = ParseUnaryExpr();
            e2 = new IntExpr(1, mTypeEnv.GetType(Tint32));
            e = new CombinedAssignExpr(new MinExpr(e.Get(), e2.Get()));
            break;

        case TOK.TOKmul:
            NextToken();
            e = ParseUnaryExpr();
            e = new PointerExpr(e.Get());
            break;

        case TOK.TOKmin:
            NextToken();
            e = ParseUnaryExpr();
            e = new NegateExpr(e.Get());
            break;

        case TOK.TOKadd:
            NextToken();
            e = ParseUnaryExpr();
            e = new UnaryAddExpr(e.Get());
            break;

        case TOK.TOKnot:
            NextToken();
            e = ParseUnaryExpr();
            e = new NotExpr(e.Get());
            break;

        case TOK.TOKtilde:
            NextToken();
            e = ParseUnaryExpr();
            e = new BitNotExpr(e.Get());
            break;

        case TOK.TOKnew:
            throw  /* SYNTAX ERROR: (551): expected ; instead of 15 */ 15;
            break;

        case TOK.TOKdelete:
            NextToken();
            e = ParseUnaryExpr();
            e = new DeleteExpr(e.Get());
            break;

        case TOK.TOKcast:
            {
                MOD flags = MOD - 1;
                // none is also a valid way to cast, so use a value outside MOD's range

                NextToken();
                ReadToken(TOK.TOKlparen);

                if (GetTokenCode() == TOK.TOKrparen)
                    flags = MODnone;
                else if ((GetTokenCode() == TOK.TOKconst) && (PeekTokenCode(1) == TOK.TOKrparen))
                {
                    flags = MODconst;
                    NextToken();
                }
                else if ((GetTokenCode() == TOK.TOKshared) && (PeekTokenCode(1) == TOK.TOKrparen))
                {
                    flags = MODshared;
                    NextToken();
                }
                else if (((GetTokenCode() == TOK.TOKinvariant)
                        || (GetTokenCode() == TOK.TOKimmutable))
                        && (PeekTokenCode(1) == TOK.TOKrparen))
                {
                    flags = MODinvariant;
                    NextToken();
                }
                else if ((((GetTokenCode() == TOK.TOKconst)
                        && (PeekTokenCode(1) == TOK.TOKshared))
                        || ((GetTokenCode() == TOK.TOKshared) && (PeekTokenCode(1) == TOK.TOKconst)))
                        && (PeekTokenCode(2) == TOK.TOKrparen))
                {
                    flags = cast(MOD)(MODconst | MODshared);
                    NextToken();
                    NextToken();
                }

                if (flags >= MODnone)
                {
                    NextToken();
                    e = ParseUnaryExpr();
                    e = new CastExpr(e.Get(), flags);
                }
                else
                {
                    Type type = ParseType();
                    ReadToken(TOKrparen);
                    e = ParseUnaryExpr();
                    e = new CastExpr(e.Get(), type.Get());
                }
                break;
            }

            // don't worry about C-style casts
        default:
            e = ParsePrimaryExpr();
            e = ParsePostfixExpr(e.Get());
            break;
        }

        return e;
    }

    Expression ParsePostfixExpr(Expression child)
    {
        Expression e = child;
        const Token* token;

        for (;;)
        {
            token = &GetToken();
            switch (token.Code)
            {
            case TOK.TOKarrow, // allow "->" just aswell to improve debugging C/C++
                    TOK.TOKdot:
                    NextToken();
                // leave out New expression (instead of ID)
                if (GetTokenCode() == TOK.TOKidentifier)
                {
                    Utf16String id = GetToken().Utf16Str;
                    NextToken();
                    if ((GetTokenCode() == TOK.TOKnot) && (PeekTokenCode(1) != TOK.TOKis))
                    {
                        TemplateInstancePart instance = new TemplateInstancePart(id);
                        const(wchar_t)* startPtr = mScanner.GetToken().TextStartPtr;
                        NextToken();

                        if (GetTokenCode() == TOK.TOKlparen)
                            instance.Params = ParseTemplateArgList();
                        else
                            instance.Params = ParseTemplateArg();

                        // get the template args as a string starting from '!'
                        const(wchar_t)* endPtr = mScanner.GetToken().TextStartPtr;
                        instance.ArgumentString = mScanner.GetNameTable()
                            .AddString(startPtr, (endPtr - startPtr));

                        e = new DotTemplateInstanceExpr(e.Get(), instance.Get());
                    }
                    else
                    {
                        e = new DotExpr(e.Get(), id);
                    }
                }
                else
                    throw  /* SYNTAX ERROR: (662): expected ; instead of 13 */ 13;
                break;

            case TOK.TOKplusplus, TOK.TOKminusminus:
                {
                    Expression e2 = new IntExpr(1, mTypeEnv.GetType(Tint32));
                    CombinableBinExpr e3;
                    if (token.Code == TOK.TOKplusplus)
                        e3 = new AddExpr(e, e2);
                    else
                        e3 = new MinExpr(e, e2);
                    e = new CombinedAssignExpr(e3, true);
                    //e = new PostExpr( e.Get(), token->Code );
                    NextToken();
                }
                break;

            case TOK.TOKlparen:
                {
                    ExpressionList args = ParseCallArguments();
                    e = new CallExpr(e, args);
                }
                break;

            case TOK.TOKlbracket:
                mBracketCount++;

                NextToken();

                if (GetTokenCode() == TOK.TOKrbracket)
                {
                    e = new SliceExpr(e, null, null);
                }
                else
                {
                    Expression index = ParseAssignExpr();

                    if (GetTokenCode() == TOK.TOKslice)
                    {
                        NextToken();

                        Expression limit = ParseAssignExpr();
                        e = new SliceExpr(e, index, limit);
                    }
                    else
                    {
                        ExpressionList args = new ExpressionList();

                        args.List.push_back(index);

                        while (GetTokenCode() == TOK.TOKcomma)
                        {
                            NextToken();

                            Expression arg = ParseAssignExpr();

                            args.List.push_back(arg);
                        }

                        e = new IndexExpr(e, args);
                    }
                }

                ReadToken(TOK.TOKrbracket);
                mBracketCount--;
                break;

            default:
                goto Done;
            }
        }

    Done:
        return e;
    }

    Expression ParsePrimaryExpr()
    {
        const Token* token = &GetToken();
        Expression e;

        switch (token.Code)
        {
        case TOK.TOKint32v:
            e = new IntExpr(token.UInt64Value, mTypeEnv.GetType(Tint32));
            NextToken();
            break;

        case TOK.TOKuns32v:
            e = new IntExpr(token.UInt64Value, mTypeEnv.GetType(Tuns32));
            NextToken();
            break;

        case TOK.TOKint64v:
            e = new IntExpr(token.UInt64Value, mTypeEnv.GetType(Tint64));
            NextToken();
            break;

        case TOK.TOKuns64v:
            e = new IntExpr(token.UInt64Value, mTypeEnv.GetType(Tuns64));
            NextToken();
            break;

        case TOK.TOKfloat32v:
            e = new RealExpr(token.Float80Value, mTypeEnv.GetType(Tfloat32));
            NextToken();
            break;

        case TOK.TOKfloat64v:
            e = new RealExpr(token.Float80Value, mTypeEnv.GetType(Tfloat64));
            NextToken();
            break;

        case TOK.TOKfloat80v:
            e = new RealExpr(token.Float80Value, mTypeEnv.GetType(Tfloat80));
            NextToken();
            break;

        case TOK.TOKimaginary32v:
            e = new RealExpr(token.Float80Value,
                    mTypeEnv.GetType(Timaginary32));
            NextToken();
            break;

        case TOK.TOKimaginary64v:
            e = new RealExpr(token.Float80Value,
                    mTypeEnv.GetType(Timaginary64));
            NextToken();
            break;

        case TOK.TOKimaginary80v:
            e = new RealExpr(token.Float80Value,
                    mTypeEnv.GetType(Timaginary80));
            NextToken();
            break;

        case TOK.TOKcharv:
            e = new IntExpr(token.UInt64Value, mTypeEnv.GetType(Tchar));
            NextToken();
            break;

        case TOK.TOKwcharv:
            e = new IntExpr(token.UInt64Value, mTypeEnv.GetType(Twchar));
            NextToken();
            break;

        case TOK.TOKdcharv:
            e = new IntExpr(token.UInt64Value, mTypeEnv.GetType(Tdchar));
            NextToken();
            break;

        case TOK.TOKstring, TOK.TOKcstring, TOK.TOKwstring, TOK.TOKdstring:
            // TODO: combine strings next to each other
            e = new StringExpr(token.Utf16Str, token.Code != TOKstring);
            NextToken();
            break;

        case TOK.TOKtrue:
            e = new IntExpr(1, mTypeEnv.GetType(Tbool));
            NextToken();
            break;

        case TOK.TOKfalse:
            e = new IntExpr(0, mTypeEnv.GetType(Tbool));
            NextToken();
            break;

        case TOK.TOKnull:
            e = new NullExpr();
            NextToken();
            break;

        case TOK.TOKdollar:
            if (mBracketCount == 0)
                throw 16; //new Exception("16");
            e = new DollarExpr();
            NextToken();
            break;

        case TOK.TOKdot:
            static if (defined(KEEP_GLOBAL_SCOPE_EXPRESSION))
            {
                e = new IdExpr(null);
                // don't eat the dot, because we want PostExpr to handle it
            }
            else
            {
                NextToken();
                if (GetTokenCode() != TOKidentifier)
                    throw 13; //new Exception("13");
                goto Lidentifier;
            }
            break;

        case TOK.TOKthis:
            e = new ThisExpr();
            NextToken();
            break;

        case TOK.TOKsuper:
            e = new SuperExpr();
            NextToken();
            break;

        case TOK.TOKidentifier:
            static if (!defined(KEEP_GLOBAL_SCOPE_EXPRESSION))
            {
        Lidentifier:
            }
            {
                Utf16String id = GetToken().Utf16Str;
                NextToken();
                if ((GetTokenCode() == TOK.TOKnot) && (PeekTokenCode(1) != TOK.TOKis))
                {
                    TemplateInstancePart instance = new TemplateInstancePart(id);
                    const(wchar_t)* startPtr = mScanner.GetToken().TextStartPtr;
                    NextToken();

                    if (GetTokenCode() == TOK.TOKlparen)
                        instance.Params = ParseTemplateArgList();
                    else
                        instance.Params = ParseTemplateArg();

                    // get the template args as a string starting from '!'
                    const(wchar_t)* endPtr = mScanner.GetToken().TextStartPtr;
                    instance.ArgumentString = mScanner.GetNameTable()
                        .AddString(startPtr, (endPtr - startPtr));

                    e = new ScopeExpr(instance.Get());
                }
                else
                {
                    e = new IdExpr(id);
                }
            }
            break;

        case TOK.TOKlparen:
            // leave out delegate starting with params: ( params ) { body }
            NextToken();
            e = ParseExpression();
            ReadToken(TOKrparen);
            break;

        case TOK.TOKtypeof:
            {
                TypeQualified t = ParseTypeof();
                e = new TypeExpr(t.Get());
            }
            break;

        case TOK.TOKtypeof2:
            {
                NextToken();
                ReadToken(TOKlparen);
                Type t = ParseType();
                ReadToken(TOKrparen);
                e = new TypeExpr(t);
            }
            break;

        case TOK.TOKtypeid:
            {
                NextToken();
                ReadToken(TOKlparen);
                Object obj;
                if (IsDeclaration(&GetToken(),
                        MagoEE.Parser.DeclIdMode.DeclId_None, TOK.TOKreserved, null))
                {
                    obj = ParseType().Get();
                }
                else
                {
                    obj = ParseAssignExpr().Get();
                }
                ReadToken(TOK.TOKrparen);
                e = new TypeidExpr(obj.Get());
            }
            break;

        case TOK.TOKis:
            throw 16; //new Exception("16");
            break;

        case TOK.TOKtraits:
            throw 16; //new Exception("16");
            break;

        case TOK.TOKlbracket:
            {
                ExpressionList keys;
                ExpressionList values = new ExpressionList();

                NextToken();

                while (GetTokenCode() != TOK.TOKeof)
                {
                    Expression expr = ParseAssignExpr();

                    if ((GetTokenCode() == TOK.TOKcolon)
                            && ((keys.Get() !is null) || (values.List.size() == 0)))
                    {
                        NextToken();
                        if (keys.Get() is null)
                            keys = new ExpressionList();
                        keys.List.push_back(expr);
                        expr = ParseAssignExpr();
                    }
                    // we have keys, but current element doesn't have a key
                    else if (keys.Get() !is null)
                    {
                        throw new Exception("17");
                    }

                    values.List.push_back(expr);

                    if (GetTokenCode() == TOK.TOKrbracket)
                        break;
                    ReadToken(TOK.TOKcomma);
                }

                ReadToken(TOK.TOKrbracket);

                if (keys.Get() !is null)
                    e = new AssocArrayLiteralExpr(keys.Get(), values.Get());
                else
                    e = new ArrayLiteralExpr(values.Get());
            }
            break;

        case TOK.TOKvoid, TOK.TOKint8, TOK.TOKuns8, TOK.TOKint16, TOK.TOKuns16,
                TOK.TOKint32, TOK.TOKuns32, TOK.TOKint64, TOK.TOKuns64, TOK.TOKfloat32,
                TOK.TOKfloat64, TOK.TOKfloat80, TOK.TOKimaginary32, TOK.TOKimaginary64,
                TOK.TOKimaginary80, TOK.TOKcomplex32, TOK.TOKcomplex64, TOK.TOKcomplex80,
                TOK.TOKbit, TOK.TOKbool, TOK.TOKchar, TOK.TOKwchar, TOK.TOKdchar:
            {
                Type type = FindBasicType(GetTokenCode());
                NextToken();
                Match(TOKdot);
                if (GetTokenCode() != TOKidentifier)
                    throw  /* SYNTAX ERROR: (1037): expected ; instead of 26 */ 26;
                TypeExpr typeExpr = new TypeExpr(type.Get());
                DotExpr dotExpr = new DotExpr(typeExpr.Get(), GetToken().Utf16Str);
                e = dotExpr.Get();
                NextToken();
            }
            break;

        case TOK.TOKfunction, TOK.TOKdelegate, TOK.TOKlcurly, TOK.TOKassert,
                TOK.TOKmixin, TOK.TOKimport:
                throw 12; //throw new Exception("12");
            break;

        default:
            throw 11; //new Exception("11");
        }

        return e;
    }

    ExpressionList ParseCallArguments()
    {
        ExpressionList args = new ExpressionList();

        NextToken();

        while (GetTokenCode() != TOK.TOKrparen)
        {
            Expression arg = ParseAssignExpr();

            args.List.push_back(arg);

            if (GetTokenCode() == TOK.TOKrparen)
                break;

            ReadToken(TOK.TOKcomma);
        }

        ReadToken(TOK.TOKrparen);

        return args;
    }

    TypeQualified ParseTypeof()
    {
        TypeQualified t;

        NextToken();
        ReadToken(TOK.TOKlparen);

        if (GetTokenCode() == TOK.TOKreturn)
        {
            t = new TypeReturn();
        }
        else
        {
            Expression e = ParseExpression();
            t = new TypeTypeof(e.Get());
        }

        ReadToken(TOK.TOKrparen);

        return t;
    }

    Type ParseType()
    {
        Type    type;
        ref const  Token     token = GetToken();

        // first, storage class prefixes that serve as type attributes:
        // const shared, shared const, const, invariant, shared

        if ( token.Code == TOK.TOKconst && PeekTokenCode() == TOK.TOKshared && PeekTokenCode( 2 ) != TOK.TOKlparen ||
            token.Code == TOK.TOKshared && PeekTokenCode() == TOK.TOKconst && PeekTokenCode( 2 ) != TOK.TOKlparen )
        {
            NextToken();
            NextToken();
            /* shared const type
            */
            type = ParseType();
            type = type.MakeSharedConst();
            return  type;
        }
        else  if ( token.Code == TOK.TOKconst && PeekTokenCode() != TOK.TOKlparen )
        {
            NextToken();
            /* const type
            */
            type = ParseType();
            type = type.MakeConst();
            return  type;
        }
        else  if ( (token.Code == TOK.TOKinvariant || token.Code == TOK.TOKimmutable) &&
            PeekTokenCode() != TOK.TOKlparen )
        {
            NextToken();
            /* invariant type
            */
            type = ParseType();
            type = type.MakeInvariant();
            return  type;
        }
        else  if ( token.Code == TOK.TOKshared && PeekTokenCode() != TOK.TOKlparen )
        {
            NextToken();
            /* shared type
            */
            type = ParseType();
            type = type.MakeShared();
            return  type;
        }
        else
             type = ParseBasicType();

        type = ParseDeclarator( type.Get(), null );
        return  type;
    }
    Type ParseBasicType()
    {
        Type            type;
        TypeQualified   tid;

        switch ( GetTokenCode() )
        {
        case  TOK.TOKidentifier:
            tid = ParseTypeName( null );
            type.Attach( tid.Detach() );
            break;

        case  TOK.TOKdot:
            tid = new  TypeIdentifier( mScanner.GetNameTable().GetEmpty() );
            tid = ParseTypeName( tid.Get() );
            type.Attach( tid.Detach() );
            break;

        case  TOK.TOKtypeof:
            tid = ParseTypeof();
            if ( GetTokenCode() == TOK.TOKdot )
            {
                NextToken();
                tid = ParseTypeName( tid.Get() );
            }
            type.Attach( tid.Detach() );
            break;

        case  TOK.TOKconst:
            // const(type)
            NextToken();
            Match( TOK.TOKlparen );
            type = ParseType();
            Match( TOK.TOKrparen );
            if ( type.IsShared() )
                type = type.MakeSharedConst();
            else
                 type = type.MakeConst();
            break;

        case  TOK.TOKinvariant,TOK.TOKimmutable:
            // invariant(type)
            NextToken();
            Match( TOK.TOKlparen );
            type = ParseType();
            Match( TOK.TOKrparen );
            type = type.MakeInvariant();
            break;

        case  TOK.TOKshared:
            // shared(type)
            NextToken();
            Match( TOK.TOKlparen );
            type = ParseType();
            Match( TOK.TOKrparen );
            if ( type.IsConst() )
                type = type.MakeSharedConst();
            else
                 type = type.MakeShared();
            break;

        default:
            type = FindBasicType( GetTokenCode() );
            if ( type  is  null )
                throw  /* SYNTAX ERROR: (615): expected ; instead of 25 */  25;
            NextToken();
            break;
        }

        return  type;
    }
    Type ParseBasicType2(Type type)
    {
        Type    type2 = type;
        int              ptrSize = mTypeEnv.GetVoidPointerType().GetSize();

        for ( ; ; )
        {
            switch ( GetTokenCode() )
            {
            case  TOK.TOKmul:
                type2 = new  TypePointer( type2, ptrSize );
                NextToken();
                break;

            case  TOK.TOKlbracket:
                NextToken();
                if ( GetTokenCode() == TOK.TOKrbracket )
                {
                    Type    newType;
                    HRESULT  hr = mTypeEnv.NewDArray( type2, newType );
                    if ( FAILED( hr ) )
                        throw  /* SYNTAX ERROR: (644): expected ; instead of 90 */  90;
                    NextToken();
                    type2 = newType;
                }
                else  if ( IsDeclaration( &GetToken(), MagoEE.Parser.DeclIdMode.DeclId_None, TOKrbracket, null ) )
                {
                    Type    newType;
                    Type    index = ParseType();
                    HRESULT  hr = mTypeEnv.NewAArray( type2, index, newType );
                    if ( FAILED( hr ) )
                        throw  /* SYNTAX ERROR: (654): expected ; instead of 90 */  90;
                    Match( TOKrbracket );
                    type2 = newType;
                }
                else
                {
                    mBracketCount++;
                    Expression  e = ParseAssignExpr();
                    if ( GetTokenCode() == TOK.TOKslice )
                    {
                        NextToken();
                        Expression  e2 = ParseAssignExpr();
                        type2 = new  TypeSlice( type2, e, e2 );
                    }
                    else
                    {
                        type2 = new  TypeSArrayUnresolved( type2, e );
                    }
                    mBracketCount--;
                    Match( TOKrbracket );
                }
                break;

            case  TOK.TOKfunction,TOK.TOKdelegate:
                {
                    // Handle delegate declaration:
                    //  t delegate(parameter list) nothrow pure
                    //  t function(parameter list) nothrow pure
                    ParameterList   params;
                    TOK  tokCode = GetTokenCode();
                    bool  ispure = false;
                    bool  isnothrow = false;
                    bool  isproperty = false;
                    TRUST  trust = TRUSTdefault;
                    int  varArgs = 0;
                    uint8_t  callConv = 0; // C call

                    NextToken();
                    params = ParseParams( varArgs );
                    for ( ; ; )
                    {
                        TOK  code = GetTokenCode();

                        // Postfixes
                        if ( code == TOK.TOKpure )
                            ispure = true;
                        else  if ( code == TOK.TOKnothrow )
                            isnothrow = true;
                        else  if ( code == TOK.TOKat )
                        {
                            StorageClass  stc = ParseAttribute();
                            switch (cast(uint)(stc >> 32))
                            {
                            case  STC.STCproperty >> 32:
                                isproperty = true;
                                break;
                            case  STC.STCsafe >> 32:
                                trust = TRUSTsafe;
                                break;
                            case  STC.STCsystem >> 32:
                                trust = TRUSTsystem;
                                break;
                            case  STC.STCtrusted >> 32:
                                trust = TRUSTtrusted;
                                break;
                            case  0:
                                break;
                            default:
                                assert( false );
                            }
                        }
                        else
                             break;
                        NextToken();
                    }

                    TypeFunction funcType = new  TypeFunction( params.Get(), type2.Get(), callConv, varArgs );
                    funcType.SetPure( ispure );
                    funcType.SetNoThrow( isnothrow );
                    funcType.SetProperty( isproperty );
                    funcType.SetTrust( trust );
                    if ( tokCode == TOK.TOKdelegate )
                    {
                        TypePointer ptrType = new  TypePointer( funcType, ptrSize );
                        type2 = new  TypeDelegate( ptrType );
                    }
                    else
                         type2 = new  TypePointer( funcType.Get(), ptrSize );  // pointer to function
                }
                break;

            default:
                return  type2;
            }
        }
    }
    Type ParseDeclarator(Type type, ref Utf16String id)
    {
        Type    type2 = ParseBasicType2( type );

        if ( GetTokenCode() == TOK.TOKidentifier )
        {
            if ( id  is  null )
                throw  /* SYNTAX ERROR: (759): expected ; instead of 23 */  23;

            id = GetToken().Utf16Str;
            NextToken();
        }

        return  type2;
    }
    TypeQualified ParseTypeName(TypeQualified typeName)
     {
        TOK                      curTokCode = TOK.TOKreserved;
        Utf16String*            id = null;
        TypeQualified   qualified = typeName;

        do
        {
            if ( GetTokenCode() != TOK.TOKidentifier )
                throw  /* SYNTAX ERROR: (777): expected ; instead of 20 */  20;

            id = GetToken().Utf16Str;
            NextToken();

            if ( GetTokenCode() != TOK.TOKnot )
            {
                if ( qualified  is  null )
                    qualified = new  TypeIdentifier( id );
                else
                     qualified.Parts.push_back( new  IdPart( id ) );
            }
            else
            {
                TemplateInstancePart    instance = new  TemplateInstancePart( id );
                const(wchar_t) *  startPtr = mScanner.GetToken().TextStartPtr;
                NextToken();

                if ( GetTokenCode() == TOKlparen )
                    instance.Params = ParseTemplateArgList();
                else
                     instance.Params = ParseTemplateArg();

                // get the template args as a string starting from '!'
                const(wchar_t) *  endPtr = mScanner.GetToken().TextStartPtr;
                instance.ArgumentString = mScanner.GetNameTable().AddString( startPtr, (endPtr - startPtr) );

                if ( qualified  is  null )
                    qualified = new  TypeInstance( instance.Get() );
                else
                     qualified.Parts.push_back( instance.Get() );
            }

            curTokCode = GetTokenCode();
            if ( curTokCode == TOK.TOKdot )
                // get it ready for looping around again, which expects an ID
                NextToken();
        } while ( curTokCode == TOK.TOKdot );

        return  qualified;
    }
    ObjectList ParseTemplateArg()
    {
        ObjectList  tiArgs = new  ObjectList();
        Type        type;

        switch ( GetTokenCode() )
        {
        case  TOK.TOKidentifier:
            type = new  TypeIdentifier( GetToken().Utf16Str );
            tiArgs.List.push_back( type.Get() );
            NextToken();
            break;

        case  TOK.TOKint32v,TOK.TOKuns32v,TOK.TOKint64v,TOK.TOKuns64v,TOK.TOKfloat32v,TOK.TOKfloat64v,TOK.TOKfloat80v,
                TOK.TOKimaginary32v,TOK.TOKimaginary64v,TOK.TOKimaginary80v,TOK.TOKnull,TOK.TOKtrue,TOK.TOKfalse,
                TOK.TOKcharv,TOK.TOKwcharv,TOK.TOKdcharv,TOK.TOKstring,TOK.TOKfile,TOK.TOKline:
            
                // Template argument is an expression
                Expression  e = ParsePrimaryExpr();
                tiArgs.List.push_back( e.Get() );
                break;
            

        default:
            type = FindBasicType( GetTokenCode() );
            if ( type  is  null )
                throw  /* SYNTAX ERROR: (861): expected ; instead of 25 */  25;
            tiArgs.List.push_back( type.Get() );
            NextToken();
            break;
        }

        if ( GetTokenCode() == TOK.TOKnot )
            throw  /* SYNTAX ERROR: (868): expected ; instead of 21 */  21;

        return  tiArgs;
    }
    ObjectList ParseTemplateArgList()
    {
        ObjectList  tiArgs = new  ObjectList();
        Type        type;

        if ( GetTokenCode() != TOK.TOKlparen )
            throw 22;
        NextToken();

        if ( GetTokenCode() != TOK.TOKrparen )
        {
            for ( ; ; )
            {
                const  Token*    curTok = &GetToken();

                if ( IsDeclaration( curTok, MagoEE.Parser.DeclIdMode.DeclId_None, TOK.TOKreserved, null ) )
                {
                    Type    type = ParseType();
                    tiArgs.List.push_back( type.Get() );
                }
                else
                {
                    Expression  e = ParseAssignExpr();
                    // leave out function literals
                    tiArgs.List.push_back( e.Get() );
                }

                if ( GetTokenCode() != TOKcomma )
                    break;
                NextToken();
            }
        }

        Match( TOK.TOKrparen );

        return  tiArgs;
    }
    StorageClass ParseAttribute()
    {
        NextToken();
        StorageClass  stc = 0;
        Utf16String    id = null;

        if ( GetTokenCode() != TOK.TOKidentifier )
            throw 22;

        id = GetToken().Utf16Str;

        // TODO: constant strings
        if ( wcscmp( id.Str, "property"w ) == 0 )
            stc = STC.STCproperty;
        else  if ( wcscmp( id.Str, "safe"w ) == 0 )
            stc = STC.STCsafe;
        else  if ( wcscmp( id.Str, "trusted"w ) == 0 )
            stc = STC.STCtrusted;
        else  if ( wcscmp( id.Str, "system"w ) == 0 )
            stc = STC.STCsystem;
        else
             throw 23;

        return  stc;
    }
    ParameterList ParseParams(ref int varArgs)
    {
        ParameterList   params = new  ParameterList();

        varArgs = 0;    // TODO: why not bool?
        Match( TOK.TOKlparen );
        
        for ( ; ; )
        {
            Type    type;
            StorageClass     storageClass = 0;
            StorageClass     stc = 0;
            Parameter   param;

            for ( ; ; NextToken() )
            {
                switch ( GetTokenCode() )
                {
                case  TOK.TOKrparen:
                    goto  Done;

                case  TOK.TOKdotdotdot:
                    varArgs = 1;
                    NextToken();
                    goto  Done;

                case  TOK.TOKconst:
                    if ( PeekTokenCode() == TOK.TOKlparen )
                        goto  LDefault;
                    stc = STC.STCconst;
                    goto  L2;

                case  TOK.TOKinvariant,TOK.TOKimmutable:
                    if ( PeekTokenCode() == TOK.TOKlparen )
                        goto  LDefault;
                    stc = STC.STCimmutable;
                    goto  L2;

                case  TOK.TOKshared:
                    if ( PeekTokenCode() == TOK.TOKlparen )
                        goto  LDefault;
                    stc = STC.STCshared;
                    goto  L2;

                case  TOK.TOKin:     stc = STC.STCin;    goto  L2;
                case  TOK.TOKout:    stc = STC.STCout;   goto  L2;
                case  TOK.TOKinout,TOK.TOKref:    stc = STC.STCref;   goto  L2;
                case  TOK.TOKlazy:   stc = STC.STClazy;  goto  L2;
                case  TOK.TOKscope:  stc = STC.STCscope; goto  L2;
                case  TOK.TOKfinal:  stc = STC.STCfinal; goto  L2;
L2:
                    if ( storageClass & stc ||
                        (storageClass & STC.STCin && stc & (STC.STCconst | STC.STCscope)) ||
                        (stc & STC.STCin && storageClass & (STC.STCconst | STC.STCscope))
                        )
                        //error("redundant storage class %s", Token::toChars(token.value));
                        throw  /* SYNTAX ERROR: (995): expected ; instead of 23 */  23;
                    storageClass |= stc;
                    CheckStorageClass( storageClass );
                    break;

                default:
LDefault:
                    stc = storageClass & (STC.STCin | STC.STCout | STC.STCref | STC.STClazy);
                    if (stc & (stc - 1))    // if stc is not a power of 2
                        //error("incompatible parameter storage classes");
                        throw  /* SYNTAX ERROR: (1005): expected ; instead of 24 */  24;
                    if ((storageClass & (STC.STCconst | STC.STCout)) == (STC.STCconst | STC.STCout))
                        //error("out cannot be const");
                        throw  /* SYNTAX ERROR: (1008): expected ; instead of 24 */  24;
                    if ((storageClass & (STC.STCimmutable | STC.STCout)) == (STC.STCimmutable | STC.STCout))
                        //error("out cannot be immutable");
                        throw  /* SYNTAX ERROR: (1011): expected ; instead of 24 */  24;
                    if ((storageClass & STC.STCscope) &&
                        (storageClass & (STC.STCref | STC.STCout)))
                        //error("scope cannot be ref or out");
                        throw  /* SYNTAX ERROR: (1015): expected ; instead of 24 */  24;
                    type = ParseType();
                    if ( GetTokenCode() == TOK.TOKdotdotdot )
                    {
                        /* This is:
                        *   at ai ...
                        */

                        if ( storageClass & (STC.STCout | STC.STCref) )
                            //error("variadic argument cannot be out or ref");
                            throw  /* SYNTAX ERROR: (1025): expected ; instead of 24 */  24;
                        varArgs = 2;
                        param = new  Parameter( storageClass, type.Get() );
                        params.List.push_back( param );
                        NextToken();
                        goto  Done;
                    }
                    param = new  Parameter( storageClass, type.Get() );
                    params.List.push_back( param );
                    if ( GetTokenCode() == TOK.TOKcomma )
                    {
                        NextToken();
                        goto  LNextParam;
                    }
                }
            }
LNextParam: ;
        }
Done:
        
        Match( TOK.TOKrparen );
        return  params;
    }

    bool IsDeclaration(const Token* curToken, DeclIdMode idMode, TOK endCode,
            const Token** endToken)
    {
        bool haveId = false;

        if (((t.Code == TOKconst) || (t.Code == TOKinvariant)
                || (t.Code == TOKimmutable) || (t.Code == TOKshared))
                && (PeekToken(t).Code != TOKlparen))
        {
            t = PeekToken(t);
        }

        if (!IsBasicType(&t))
            return false;

        if (!IsDeclarator(&t, haveId, endCode))
            return false;

        if ((idMode == DeclId_Optional) || ((idMode == DeclId_None) && !haveId)
                || ((idMode == DeclId_Needed) && haveId))
        {
            if (endToken != NULL)
                *endToken = t;

            return true;
        }

        return false;
    }

    bool IsBasicType(const Token** curToken)
    {
        const Token* t = *curToken;

        if (IsPrimitiveType(t.Code))
        {
            t = PeekToken(t);
        }
        else if ((t.Code == TOKconst) || (t.Code == TOKinvariant)
                || (t.Code == TOKimmutable) || (t.Code == TOKshared))
        {
            // const(type)  or  immutable(type)  or  shared(type)
            t = PeekToken(t);
            if (t.Code != TOKlparen)
                return false;
            t = PeekToken(t);
            if (!IsDeclaration(t, MagoEE.Parser.DeclIdMode.DeclId_None, TOKrparen, &t))
                return false;
            t = PeekToken(t);
        }
        else if (t.Code == TOKdot)
        {
            t = PeekToken(t);
            if (!IsTypeNameIdSequence(t, &t))
                return false;
        }
        else if (t.Code == TOKtypeof)
        {
            t = PeekToken(t);
            if (t.Code != TOKlparen)
                return false;
            if (!SkipParens(t, &t))
                return false;
            if (t.Code == TOKdot)
            {
                t = PeekToken(t);
                if (!IsTypeNameIdSequence(t, &t))
                    return false;
            }
        }
        else
        {
            if (!IsTypeNameIdSequence(t, &t))
                return false;
        }

        *curToken = t;

        return true;
    }

    bool IsDeclarator(const Token** curToken, ref bool haveId, TOK endCode)
    {
        const Token* t = *curToken;

        haveId = false;

        if (t.Code == TOKassign)
            return false;

        for (;;)
        {
            switch (t.Code)
            {
            case TOK.TOKmul:
                t = PeekToken(t);
                continue;

            case TOK.TOKlbracket:
                t = PeekToken(t);
                if (t.Code == TOK.TOKrbracket)
                {
                    t = PeekToken(t);
                }
                else if ((t.Code == TOK.TOKnew) && (PeekToken(t).Code == TOK.TOKrbracket))
                {
                    t = PeekToken(t);
                    t = PeekToken(t);
                }
                else if (IsDeclaration(t, MagoEE.Parser.DeclIdMode.DeclId_None,
                        TOK.TOKrbracket, &t))
                {
                    // associative array
                    t = PeekToken(t);
                }
                else
                {
                    if (!IsExpression(&t))
                        return false;
                    if (t.Code == TOK.TOKslice)
                    {
                        t = PeekToken(t);
                        if (!IsExpression(&t))
                            return false;
                    }
                    if (t.Code != TOK.TOKrbracket)
                        return false;
                    t = PeekToken(t);
                }
                continue;

            case TOK.TOKidentifier:
                t = PeekToken(t);
                haveId = true;
                break;

            case TOK.TOKlparen:
                // leave out C-style function pointers
                return false;

            case TOK.TOKdelegate, TOK.TOKfunction:
                t = PeekToken(t);
                if (!IsParameters(&t))
                    return false;
                continue;
            default:
                break;
            }
            break;
        }

        switch (t.Code)
        {
            // Valid tokens that follow a declaration
        case TOK.TOKrparen, TOK.TOKrbracket, TOK.TOKassign, TOK.TOKcomma,
                TOK.TOKsemicolon, TOK.TOKlcurly, TOK.TOKin:
                if ((endCode == TOK.TOKreserved) || (endCode == t.Code))
            {
                *curToken = t;
                return true;
            }
            break;
        default:
            break;
        }

        return false;
    }

    bool IsPrimitiveType(TOK code)
    {
        switch (code)
        {
        case TOK.TOKvoid, TOK.TOKint8, TOK.TOKuns8, TOK.TOKint16, TOK.TOKuns16,
                TOK.TOKint32, TOK.TOKuns32, TOK.TOKint64, TOK.TOKuns64,
                TOK.TOKfloat32,
                TOK.TOKfloat64, TOK.TOKfloat80, TOK.TOKimaginary32, TOK.TOKimaginary64,
                TOK.TOKimaginary80, TOK.TOKcomplex32, TOK.TOKcomplex64, TOK.TOKcomplex80,
                TOK.TOKchar, TOK.TOKwchar, TOK.TOKdchar, TOK.TOKbit, TOK.TOKbool : return true;
        default:
            return false;
        }
    }

    bool IsBasicLiteral(TOK code)
    {
        switch (code)
        {
        case TOK.TOKint32v, TOK.TOKuns32v, TOK.TOKint64v, TOK.TOKuns64v,
                TOK.TOKfloat32v, TOK.TOKfloat64v, TOK.TOKfloat80v, TOK.TOKimaginary32v,
                TOK.TOKimaginary64v, TOK.TOKimaginary80v, TOK.TOKnull, TOK.TOKtrue,
                TOK.TOKfalse, TOK.TOKcharv, TOK.TOKwcharv, TOK.TOKdcharv,
                TOK.TOKstring, TOK.TOKfile, TOK.TOKline:
                return true;
        default:
            return false;
        }

    }

    bool IsTypeNameIdSequence(const Token* curToken, const Token** endToken)
    {
        const Token* t = curToken;

        for (;;)
        {
            if (t.Code != TOK.TOKidentifier)
                return false;
            t = PeekToken(t); // skip ID

            if (t.Code == TOK.TOKdot)
            {
                t = PeekToken(t);
            }
            else if (t.Code == TOK.TOKnot)
            {
                t = PeekToken(t);

                if (t.Code == TOK.TOKlparen)
                {
                    if (!SkipParens(t, &t))
                        return false;
                }
                else if (IsPrimitiveType(t.Code) || IsBasicLiteral(t.Code))
                {
                    t = PeekToken(t);
                }
                else
                    continue;

                if (t.Code == TOK.TOKdot)
                {
                    t = PeekToken(t);
                }
                else
                    break;
            }
            else
                break;
        }

        if (endToken !is null)
            *endToken = t;

        return true;
    }

    bool IsExpression(const Token** curToken)
    {
        const  Token*    t = *curToken;
        int  bracketNest = 0;
        int  parenNest = 0;
        int  curlyNest = 0;

        for ( ; ; t = PeekToken( t ) )
        {
            switch ( t.Code )
            {
            case  TOK.TOKlbracket:
                bracketNest++;
                continue;

            case  TOK.TOKrbracket:
                bracketNest--;
                if ( bracketNest >= 0 )
                    continue;
                break;

            case  TOK.TOKlparen:
                parenNest++;
                continue;

            case  TOK.TOKcomma:
                if ( (bracketNest > 0) || (parenNest > 0) )
                    continue;
                break;

            case  TOK.TOKrparen:
                parenNest--;
                if ( parenNest >= 0 )
                    continue;
                break;

            case  TOK.TOKlcurly:
                curlyNest++;
                continue;

            case  TOK.TOKrcurly:
                curlyNest--;
                if ( curlyNest >= 0 )
                    continue;
                return  false;

            case  TOK.TOKslice:
                if ( bracketNest > 0 )
                    continue;
                break;

            case  TOK.TOKsemicolon:
                if ( curlyNest > 0 )
                    continue;
                return  false;

            case  TOK.TOKeof:
                return  false;

            default:
                continue;
            }
            break;
        }

        *curToken = t;
        return  true;
    }
    bool IsParameters(const Token** curToken)
    {
        const  Token*    t = *curToken;

        if ( t.Code != TOK.TOKlparen )
            return  false;
        t = PeekToken( t );

        for ( ; ; t = PeekToken( t ) )
        {
            switch ( t.Code )
            {
            case  TOK.TOKrparen:
                goto  Done;

            case  TOK.TOKdotdotdot:
                t = PeekToken( t );
                goto  Done;

            case  TOK.TOKin,TOK.TOKout,TOK.TOKinout,TOK.TOKref,TOK.TOKlazy,TOK.TOKfinal:
                continue;

            case  TOK.TOKconst,TOK.TOKinvariant,TOK.TOKimmutable,TOK.TOKshared:
                if ( PeekToken( t ).Code == TOK.TOKlparen )
                {
                    t = PeekToken( t );
                    t = PeekToken( t );
                    if ( !IsDeclaration( t, MagoEE.Parser.DeclIdMode.DeclId_None, TOKrparen, &t ) )
                        return  false;
                    t = PeekToken( t ); // skip past closing ')'
                    break;
                }
                continue;

            default:
                if ( !IsBasicType( &t ) )
                    return  false;
                break;
            }

            bool     haveId;
            if ( (t.Code != TOK.TOKdotdotdot)
                && !IsDeclarator( &t, haveId, TOK.TOKreserved ) )
                return  false;

            if ( t.Code == TOK.TOKassign )
            {
                t = PeekToken( t );
                if ( !IsExpression( &t ) )
                    return  false;
            }
            if ( t.Code == TOK.TOKdotdotdot )
            {
                t = PeekToken( t );
                break;
            }

            if ( t.Code == TOK.TOKcomma )
            {
                if ( PeekToken( t ).Code == TOK.TOKrparen )
                    return  false;
            }
        }
Done:

        if ( t.Code != TOK.TOKrparen )
            return  false;
        t = PeekToken( t );

        *curToken = t;
        return  true;
    }
    bool SkipParens(const Token* curToken, const Token** endToken)
    {
        const Token* t = curToken;
        int parenCount = 0;
        bool done = false;

        for (; !done;)
        {
            switch (t.Code)
            {
            case TOKlparen:
                parenCount++;
                break;

            case TOKrparen:
                parenCount--;
                if (parenCount < 0)
                    return false;
                if (parenCount == 0)
                    done = true;
                break;

            case TOKeof:
            case TOKsemicolon:
                return false;

            default:
                break;
            }

            t = PeekToken(t);
        }

        if (endToken !is null)
            *endToken = t;

        return true;
    }

private:
    void Match(TOK code)
    {
        ReadToken(code);
    }

    void ReadToken(TOK code)
    {
        if (mScanner.GetToken().Code != code)
            throw 13;

        mScanner.NextToken();
    }

    void NextToken()
    {
        mScanner.NextToken();
    }

    ref const Token GetToken()
    {
        return mScanner.GetToken();
    }

    TOK GetTokenCode()
    {
        return mScanner.GetToken().Code;
    }

    TOK PeekTokenCode(int index = 1)
    {
        return mScanner.PeekToken(index).Code;
    }

    const Token* PeekToken(const Token* curToken)
    {
        return mScanner.PeekToken(curToken);
    }

    void CheckStorageClass(StorageClass stc)
    {
        StorageClass  u = stc;
        u &= STC.STCconst | STC.STCimmutable | STC.STCmanifest;
        if ( u & (u - 1) )
            //error("conflicting storage class %s", Token::toChars(token.value));
            throw  /* SYNTAX ERROR: (1056): expected ; instead of 24 */  24;
        u = stc;
        u &= STC.STCgshared | STC.STCshared | STC.STCtls;
        if ( u & (u - 1) )
            //error("conflicting storage class %s", Token::toChars(token.value));
            throw  /* SYNTAX ERROR: (1061): expected ; instead of 24 */  24;
        u = stc;
        u &= STC.STCsafe | STC.STCsystem | STC.STCtrusted;
        if ( u & (u - 1) )
            //error("conflicting attribute @%s", token.toChars());
            throw  /* SYNTAX ERROR: (1066): expected ; instead of 24 */  24;
    }

    Type    FindBasicType( TOK  code )
    {
        ENUMTY   ty = TMAX;

        switch ( code )
        {
        case  TOK.TOKvoid:   ty = ENUMTY.Tvoid; break;
        case  TOK.TOKint8:   ty = ENUMTY.Tint8; break;
        case  TOK.TOKuns8:   ty = ENUMTY.Tuns8; break;
        case  TOK.TOKint16:  ty = ENUMTY.Tint16; break;
        case  TOK.TOKuns16:  ty = ENUMTY.Tuns16; break;
        case  TOK.TOKint32:  ty = ENUMTY.Tint32; break;
        case  TOK.TOKuns32:  ty = ENUMTY.Tuns32; break;
        case  TOK.TOKint64:  ty = ENUMTY.Tint64; break;
        case  TOK.TOKuns64:  ty = ENUMTY.Tuns64; break;
        case  TOK.TOKfloat32:    ty = ENUMTY.Tfloat32; break;
        case  TOK.TOKfloat64:    ty = ENUMTY.Tfloat64; break;
        case  TOK.TOKfloat80:    ty = ENUMTY.Tfloat80; break;
        case  TOK.TOKimaginary32: ty = ENUMTY.Timaginary32; break;
        case  TOK.TOKimaginary64: ty = ENUMTY.Timaginary64; break;
        case  TOK.TOKimaginary80: ty = ENUMTY.Timaginary80; break;
        case  TOK.TOKcomplex32:  ty = ENUMTY.Tcomplex32; break;
        case  TOK.TOKcomplex64:  ty = ENUMTY.Tcomplex64; break;
        case  TOK.TOKcomplex80:  ty = ENUMTY.Tcomplex80; break;
        case  TOK.TOKchar:   ty = ENUMTY.Tchar; break;
        case  TOK.TOKwchar:  ty = ENUMTY.Twchar; break;
        case  TOK.TOKdchar:  ty = ENUMTY.Tdchar; break;
        case  TOK.TOKbit:    ty = ENUMTY.Tbit; break;
        case  TOK.TOKbool:   ty = ENUMTY.Tbool; break;
        default:
            return  null;
        }

        return  mTypeEnv.GetType( ty );
    }
    Type FindBasicType(TOK code);
}
