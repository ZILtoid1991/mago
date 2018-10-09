module exec.enumerator;


interface Enumerator(T)
{
public:
    //virtual ~Enumerator() { }

    void    Release();
    int     GetCount();
    T       GetCurrent();
    bool    MoveNext();
    void    Reset();
}