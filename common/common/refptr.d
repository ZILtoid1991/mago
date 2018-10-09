module common.refptr;

import core.stdc.stdlib;

/**
 * Reimplementation of C++'s RefPtr< X > template.
 */
struct RefPtr(T){
	private T* ptr;
	
	this(T* data){
		this.ptr = data;
	}
	this(const ref RefPtr rPtr){
		this.ptr = rPtr.ptr;
	}
	bool opEquals(RefPtr(t) b) {
		return this.ptr == b.ptr;
	}
	T opIndex(size_t index){
		return ptr[index];
	}
	T opIndexAssign(size_t index, T value){
		return ptr[index] = T;
	}
	RefPtr!(T) opOpAssign(string op)(size_t rhs){
		static if(op == "+"){
			ptr += rhs;
			return this;
		}else static if(op == "-"){
			ptr -= rhs;
			return this;
		}
	}
	RefPtr!(T) opBinary(string op)(size_t rhs){
		static if(op == "+"){
			return RefPtr(ptr + rhs);
		}else static if(op == "-"){
			return RefPtr(ptr - rhs);
		}
	}
	@nogc @property T* getPtr(){
		return ptr;
	}
}