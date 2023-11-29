from test_builder import print_result
from flx import *

fn main():
    print_result(flx_null())
    print_result(flx(200))
    print_result(flx[DType.float16](2.5))
    print_result(flx[DType.float32](2.5))
    print_result(flx[DType.float64](2.5))
    print_result(flx("Hello 🔥"))
    try:
        var flxb = flx_buffer.FlxBuffer()
        flxb.key("Hello 🔥")
        print_result(flxb^.finish())
        print_result(FlxVec().add(5).add(6).add(7).finish())
        print_result(FlxVec().add[DType.uint8](5).add[DType.uint16](600).add[DType.uint8](7).finish())
        print_result(FlxVec().add[DType.float16](1.1).add[DType.float32](1.1).add[DType.float64](1.1).finish())
        print_result(FlxVec().add_indirect[DType.float16](1.1).add_indirect[DType.float32](1.1).add_indirect[DType.float64](1.1).finish())
        print_result(FlxVec().add("maxim").add("alex").add("daria").finish())
        print_result(FlxVec().add("maxim").add("alex").add("maxim").add("daria").finish())
        print_result(FlxVec[dedup_string=False]().add("maxim").add("alex").add("maxim").add("daria").finish())
        print_result(FlxVec().add[DType.int32](1234).add("maxim").add[DType.float16](1.5).add[DType.bool](True).finish())
        print_result(FlxVec().add_indirect[DType.int32](1234).add("maxim").add_indirect[DType.float16](1.5).add[DType.bool](True).finish())
        print_result(FlxVec().add(7).vec().add(8).add(9).finish())
        print_result(FlxMap().add("a", 7).add("b", 8).finish())
        print_result(FlxMap().add("b", 7).add("a", 8).finish())
        print_result(FlxVec().map().add("a", 7).add("b", 8).up_to_vec().map().add("b", 42).add("a", 43).finish())
        print_result(FlxVec[dedup_keys_vec=False]().map().add("a", 7).add("b", 8).up_to_vec().map().add("b", 42).add("a", 43).finish())
        print_result(FlxVec[dedup_key=False]().map().add("a", 7).add("b", 8).up_to_vec().map().add("b", 42).add("a", 43).finish())
    except e:
        print(e)

    
