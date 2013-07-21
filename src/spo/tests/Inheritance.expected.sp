#include "../core/memory.sp"
#include "../core/oo.sp"

#define _SPO_Data_iTableSize	    3

// This grows at n^2 rate. Where n is the # of classes
static _SPO_iTable[_SPO_Data_iTableSize][_SPO_Data_iTableSize] = { // const too?
	{0, _SPO_Const_iNotRelated, 0},
	{_SPO_Const_iNotRelated, 0, 1},
	{_SPO_Const_iNotRelated, _SPO_Const_iNotRelated, 0}
};

// Scrapping the enums for the new version since they cause way, way too many tag mismatches...
#define Class_A__SPO_Id     0       // Id of the class
#define Class_A__SPO_Size   2       // Size of the class
#define Class_A_a           1       // Position of this member in the class, NB index 0 is always occupied by the meta field.

Class_A_ctor() {
    new this = _SPO_Alloc(Class_A__SPO_Size);
    _SPO_Heap[this] = Class_A__SPO_Id;
    // BEGIN USER
    // END USER
    return this;
}

Class_A_dtor(this) {
    // BEGIN USER
    // END USER
    _SPO_Free(this);
}

Class_A_f(this, x) {
    return _SPO_Heap[this + Class_A_a + _SPO_iGet(Class_A__SPO_Id, _SPO_Heap[this])] + x;
}

#define Class_B__SPO_Id     1
#define Class_B__SPO_Size   2
#define Class_B_b           1

Class_B_ctor() {
    new this = _SPO_Alloc(Class_B__SPO_Size);
    _SPO_Heap[this] = Class_B__SPO_Id;
    // BEGIN USER
    // END USER
    return this;
}

Class_B_dtor(this) {
    // BEGIN USER
    // END USER
    _SPO_Free(this);
}

Class_B_f(this, x) {
    return _SPO_Heap[this + Class_B_b + _SPO_iGet(Class_B__SPO_Id, _SPO_Heap[this])] * x;
}

#define Class_AB__SPO_Id    2
#define Class_AB__SPO_Size  4
#define Class_AB_a          1
#define Class_AB_b          2
#define Class_AB_c          3

Class_AB_ctor() {
    new this = _SPO_Alloc(Class_AB__SPO_Size);
    _SPO_Heap[this] = Class_AB__SPO_Id;
    // BEGIN USER
    _SPO_Heap[this + Class_AB_a + _SPO_iGet(Class_AB__SPO_Id, _SPO_Heap[this])] = 1330;
    _SPO_Heap[this + Class_AB_c + _SPO_iGet(Class_AB__SPO_Id, _SPO_Heap[this])] = 3;
    // END USER
    return this;
}

Class_AB_dtor(this) {
    // BEGIN USER
    _SPO_Heap[this + Class_AB_a + _SPO_iGet(Class_AB__SPO_Id, _SPO_Heap[this])] = 0;
    _SPO_Heap[this + Class_AB_c + _SPO_iGet(Class_AB__SPO_Id, _SPO_Heap[this])] = 0;
    // END USER
    _SPO_Free(this);
}

Class_AB_g(this, x) {
    return _SPO_Heap[this + Class_AB_c + _SPO_iGet(Class_AB__SPO_Id, _SPO_Heap[this])] % (
        Class_A_f(this, x) +
        Class_B_f(this, x)
    );
}

public OnPluginStart() {
    new myA = Class_A_ctor();
    _SPO_Heap[myA + Class_A_a + _SPO_iGet(Class_A__SPO_Id, _SPO_Heap[myA])] = 10;
    new Bool:shouldBe12 = Class_A_f(myA, 2) == 12;
    PrintToServer("myA.f(2) == 12 => %b", shouldBe12);
    Class_A_dtor(myA);
    
    new myB = Class_B_ctor();
    _SPO_Heap[myB + Class_B_b + _SPO_iGet(Class_B__SPO_Id, _SPO_Heap[myB])] = 5;
    new Bool:shouldBe10 = Class_B_f(myB, 2) == 10;
    PrintToServer("myB.f(2) == 10 => %b", shouldBe10);
    Class_B_dtor(myB);
    
    new myAB = Class_AB_ctor();
    new Bool:shouldBe3 = Class_AB_g(myAB, 2) == 3;
    PrintToServer("myAB.g(2) == 3 => %b", shouldBe3);
    
    myA = myAB;
    new Bool:shouldBe1337 = Class_A_f(myA, 7) == 1337;
    PrintToServer("myA = myAB", shouldBe1337);
    PrintToServer("myA.f(7) == 1337 => %b", shouldBe1337);
    Class_AB_dtor(myAB);
}