module EED.Common;

public import core.stdc.inttypes;
public import core.stdc.stdlib;
public import core.stdc.string;
public import core.sys.windows.windows;
///replaces std::min
public T min(T)(T a, T b){
	return a > b ? b : a;
}