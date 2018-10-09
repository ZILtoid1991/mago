module EED.Property;

abstract class StdProperty
{
public:
    abstract bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type);
    abstract bool UsesParentValue();
    abstract bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result);
    abstract bool GetValue(Type parentType, Declaration parentDecl,
            ref const DataValue parentVal, ref DataValue result);
    
}
