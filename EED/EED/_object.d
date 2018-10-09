module EED._object;

enum ObjectKind
{
    ObjectKind_None,
    ObjectKind_ObjectList,
    ObjectKind_Expression,
    ObjectKind_ExpressionList,
    ObjectKind_Type,
    ObjectKind_NamePart,
    ObjectKind_Parameter,
    ObjectKind_ParameterList,
};

abstract class _Object
{
    int mRefCount;

public:
    this();

    void AddRef()
    {
        mRefCount++;
    }

    void Release()
    {
        mRefCount--;
        assert(mRefCount >= 0);
        /*if ( mRefCount == 0 )
        {
            delete this;
        }*/
    }

    abstract ObjectKind GetObjectKind();
}

class ObjectList : _Object
{
public:
    _Object[] List; //std.list!(RefPtr!(Object)) List;

    ObjectKind GetObjectKind()
    {
        return ObjectKind_ObjectList;
    }
}
