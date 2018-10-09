module EED.Declaration;

interface Declaration
{

	

	public void AddRef();
	public void Release();

	public const wchar_t* GetName();

	public bool GetType(Type type);
	public bool GetAddress(Address addr);
	public bool GetOffset(int offset);
	public bool GetSize(uint32_t size);
	public bool GetBackingTy(ENUMTY ty);
	public bool GetUdtKind(UdtKind kind);
	public bool GetBaseClassOffset(Declaration baseClass, ref int offset);
	public bool GetVTableShape(Declaration  decl);

	public bool IsField();
	public bool IsStaticField();
	public bool IsVar();
	public bool IsConstant();
	public bool IsType();
	public bool IsBaseClass();
	public bool IsRegister();
	public bool IsFunction();
	public bool IsStaticFunction();

	public long FindObject(const wchar_t* name, Declaration decl);
	public bool EnumMembers(ref IEnumDeclarationMembers members);
	public long FindObjectByValue(uint64_t intVal, Declaration* decl);
}

interface IEnumDeclarationMembers
{

	public void AddRef();
	public void Release();

	public uint GetCount();
	public bool Next(MagoEE.Declaration* decl);
	public bool Skip(uint count);
	public bool Reset();
}
