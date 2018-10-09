module EED.TypeUnresolved;

import EED.Type;
import EED._object;
import EED.Common;
import EED.TypeEnv;
import EED.Declaration;
import EED.NameTable;

import common.stringutil;

class NamePart : _object
{
public:
    this()
    {

    }

    ObjectKind GetObjectKind()
    {
        return ObjectKind_NamePart;
    }

    IdPart AsId()
    {
        return null;
    }

    TemplateInstancePart AsTemplateInstance()
    {
        return null;
    }
}

class IdPart : NamePart
{
public:
    Utf16String Id;

    this(Utf16String str)
    {
        this.Id = str;
    }

    IdPart AsId()
    {
        return this;
    }
}

class TemplateInstancePart : NamePart
{
public:
    Utf16String Id;
    Utf16String ArgumentString;
    ObjectList Params;

    this(Utf16String str)
    {
        super(str);
    }

    TemplateInstancePart AsTemplateInstance()
    {
        return this;
    }
}

class TypeQualified : Type
{
public:
    NameParts[] Parts; //std.vector!( RefPtr!(NamePart) ) Parts;

    this(ENUMTY ty)
    {
        super(ty);
    }

protected:
    Type ResolveTypeChain(Declaration head)
    {
        HRESULT hr = S_OK;
        Declaration curDecl = head;
        Type type;

        foreach (it; Parts)
        {
            Declaration newDecl;

            if (it.AsId() !is null)
            {
                IdPart idPart = it.AsId();

                hr = curDecl.FindObject(idPart.Id.Str, newDecl.Ref());
                if (FAILED(hr))
                    return null;
            }
            else
            {
                TemplateInstancePart templatePart = it.AsTemplateInstance();
                wstring fullId;

                fullId.append(templatePart.Id.Str);
                fullId.append(templatePart.ArgumentString.Str);
                wchar* c_str = toWStingz(fullId);
                hr = curDecl.FindObject(c_str, newDecl.Ref());
                free(c_str);
                if (FAILED(hr))
                    return null;
            }

            curDecl = newDecl;
        }

        if (!curDecl.IsType())
            return null;

        hr = curDecl.GetType(type);
        if (FAILED(hr))
            return null;

        return type;
    }

    Type ResolveNamePath(const(wchar_t)* headName, IValueBinder binder)
    {
        HRESULT hr = S_OK;
        std.wstring fullName;
        Declaration decl;
        Type type;

        fullName.append(headName);

        foreach (it; Parts)
        {
            if (it.AsId() !is null)
            {
                IdPart idPart = it.AsId();

                fullName ~= ".";
                fullName ~= idPart.Id.Str;
            }
            else
            {
                TemplateInstancePart templatePart = (*it).AsTemplateInstance();

                fullName ~= ".";
                fullName ~= templatePart.Id.Str;
                fullName ~= templatePart.ArgumentString.Str;
            }
        }

        hr = binder.FindObject(fullName.c_str(), decl.Ref());
        if (FAILED(hr))
            return null;

        if (!decl.IsType())
            return null;

        hr = decl.GetType(type.Ref());
        if (FAILED(hr))
            return null;

        return type;
    }
}

class TypeInstance : TypeQualified
{
public:
    TemplateInstancePart Instance;

    this(TemplateInstancePart instance)
    {
        super(Tinstance);
        Instance = (instance);
    }

    Type Copy()
    {
        TypeQualified type = new TypeInstance(Instance);
        type.Parts = Parts;
        return type;
    }

    Type Resolve(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( typeEnv );

        HRESULT hr = S_OK;
        Declaration decl;
        Type resolvedType;
        wstring fullId;

        fullId.reserve(Instance.Id.Length + Instance.ArgumentString.Length);
        fullId.append(Instance.Id.Str);
        fullId.append(Instance.ArgumentString.Str);
        wchar* c_str = toWStringZ(fullId);
        resolvedType = ResolveNamePath(c_str, binder);
        if (resolvedType !is null)
        {
            free(c_str);
            return resolvedType;
        }

        hr = binder.FindObject(c_str, decl.Ref());
        free(c_str);
        if (FAILED(hr))
            return null;

        return ResolveTypeChain(decl);
    }

protected:

    void _ToString(ref wstring str)
    {
        // TODO: do we really need to define this method or can we have Type say "unresolved"?
        str ~= "instance"w;
    }
}

class TypeIdentifier : TypeQualified
{
public:
    //RefPtr<IdPart>  Id;
    Utf16String Id;

    this(Utf16String id)
    {
        super(Tident);
        Id = (id);
    }

    Type Copy()
    {
        TypeQualified type = new TypeIdentifier(Id);
        type.Parts = Parts;
        return type;
    }

    Type Resolve(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( typeEnv );

        HRESULT hr = S_OK;
        Declaration decl;
        Type resolvedType;

        resolvedType = ResolveNamePath(Id.Str, binder);
        if (resolvedType !is null)
            return resolvedType;

        hr = binder.FindObject(Id.Str, decl);
        if (FAILED(hr))
            return null;

        return ResolveTypeChain(decl);
    }

protected:
    void _ToString(ref wstring str)
    {
        // TODO: do we really need to define this method or can we have Type say "unresolved"?
        str ~= "identifier"w;
    }
}

class TypeReturn : TypeQualified
{
public:
    this()
    {
        super(Treturn);
    }

    Type Copy()
    {
        TypeQualified type = new TypeReturn();
        type.Parts = Parts;
        return type.Get();
    }

    Type Resolve(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( typeEnv );

        HRESULT hr = S_OK;
        Type retType;

        hr = binder.GetReturnType(retType.Ref());
        if (FAILED(hr))
            return null;

        // TODO: is this the only type that can do this?
        //       is it only inner types that work with typeof( return ).T?
        //       or is it also enum members, or other things?
        if (retType.AsTypeStruct() is null)
        {
            if (Parts.size() == 0)
                return retType;
            else
                return null;
        }

        return ResolveTypeChain(retType.GetDeclaration());
    }

protected:
    void _ToString(ref wstring str)
    {
        // TODO: do we really need to define this method or can we have Type say "unresolved"?
        str ~= "typeof(return)"w;
    }
}

class TypeTypeof : TypeQualified
{
public:
    Expression Expr;

    this(Expression expr)
    {
        {
            super(Ttypeof);
            this.Expr = expr;
        }
    }

    Type Copy()
    {
        TypeQualified type = new TypeTypeof(Expr);
        type.Parts = Parts;
        return type;
    }

    Type Resolve(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;

        hr = Expr.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return null;

        // TODO: is this the only type that can do this?
        if (Expr._Type.AsTypeStruct() is null)
        {
            if (Parts.length == 0)
                return Expr._Type;
            else
                return null;
        }

        return ResolveTypeChain(Expr._Type.GetDeclaration());
    }

protected:
    void _ToString(ref wstring str)
    {
        // TODO: do we really need to define this method or can we have Type say "unresolved"?
        str ~= "typeof()"w;
    }
}

class TypeSArrayUnresolved : TypeNext
{
public:
    Expression Expr;

    this(Type elem, Expression expr)
    {
        super(Tsarray, element);
        Expr = (expr);
    }

    Type Copy()
    {
        Type type = new TypeSArrayUnresolved(Next, Expr);
        return type;
    }

    Type Resolve(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;

        Type resolvedNext = Next.Resolve(evalData, typeEnv, binder);
        if (resolvedNext is null)
            return null;

        hr = Expr.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return null;

        if (!Expr._Type.IsIntegral())
            return null;

        // TODO: we should say that we can only evaluate constants and no variables
        DataObject exprVal = {0};
        hr = Expr.Evaluate(EvalMode_Value, evalData, binder, exprVal);
        if (FAILED(hr))
            return null;

        Type resolvedThis;
        hr = typeEnv.NewSArray(resolvedNext,
                // for now chopping it to 32 bits is OK
                cast(uint32_t) exprVal.Value.UInt64Value, resolvedThis.Ref());
        if (FAILED(hr))
            return null;

        return resolvedThis;
    }

protected:
    void _ToString(ref wstring str)
    {
        // TODO: do we really need to define this method or can we have Type say "unresolved"?
        str ~= "unresolved_Sarray"w;
    }
}

class TypeSlice : TypeNext
{
public:
    Expression ExprLow;
    Expression ExprHigh;

    this(Type elem, Expression exprLow, Expression exprHigh)
    {
        super(Tslice, element);
        ExprLow = (exprLow);
        ExprHigh = (exprHigh);
    }

    Type Copy()
    {
        Type    type = new  TypeSlice( Next, ExprLow, ExprHigh );
        return  type;
    }
    Type Resolve(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( typeEnv );
        //UNREFERENCED_PARAMETER( binder );
        // TODO:
        assert( false );
        return  null;
    }

protected:
    void _ToString(ref std.wstring str)
    {
        // TODO: do we really need to define this method or can we have Type say "unresolved"?
        str ~= "slice"w;
    }
}
