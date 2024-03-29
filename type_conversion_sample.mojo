from random import random_si64
from flx import FlxVec, FlxValue
from memory.unsafe import bitcast

fn convert_dynamic_vector() raises:
    var v = List[Int32]()
    for _ in range(10_000):
        v.append(random_si64(-1_000_000, 1_000_000).cast[DType.int32]())

    var flx_result = FlxVec()
        .add("vec_i32")
        .add(rebind[DTypePointer[DType.int32]](v.data).bitcast[DType.uint8](), len(v) * sizeof[Int32]())
        .finish()
    
    print("Buffer size:", flx_result.get[1, Int]())

    var value = FlxValue(flx_result.get[0, DTypePointer[DType.uint8]](), flx_result.get[1, Int]())
    print(value[0].string())
    var blob = value[1].blob()
    var size = blob.get[1, Int]() / 4
    var bytes = blob.get[0, DTypePointer[DType.uint8]]()
    var bytes32 = bytes.bitcast[DType.int32]()
    var v1 = List[Int32](capacity=size.to_int())
    for i in range(size.to_int()):
        v1.append(bytes32.offset(i).load())

    if len(v) != len(v1):
        print("Error! Lengths are not equal", len(v), len(v1))
        return
    for i in range(len(v)):
        if v[i] != v1[i]:
            print("Error at:", i, v[i], "!=", v1[i])

fn main():
    try:
        convert_dynamic_vector()
    except e:
        print("Unexpected error:", e)