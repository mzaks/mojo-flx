from flx import *
from testing import assert_equal

fn main() raises:
    _ = assert_equal("null", FlxValue(flx_null()).json())
    _ = assert_equal("123", FlxValue(flx(123)).json())
    _ = assert_equal("12345", FlxValue(flx(12345)).json())
    _ = assert_equal("123.45", FlxValue(flx[DType.float64](123.45)).json())
    _ = assert_equal('"Hello 🔥"', FlxValue(flx("Hello 🔥")).json())
    var v1 = FlxVec().add[DType.int32](1234).add("maxim").add[DType.float16](1.5).add[DType.bool](True).finish()
    _ = assert_equal('[1234,"maxim",1.5,true]', FlxValue(v1).json())
    v1 = FlxVec().map().add("a", 7).add("b", 8).up_to_vec().map().add("b", 42).add("a", 43).finish()
    _ = assert_equal('[{"a":7,"b":8},{"a":43,"b":42}]', FlxValue(v1).json())
    v1 = FlxVec().map().add("a", 7).add("b", 8).up_to_vec().map().add("b", "42").vec("a").add_indirect[DType.float64](1.2).add[DType.bool](False).null().finish()
    _ = assert_equal('[{"a":7,"b":8},{"a":[1.2,false,null],"b":"42"}]', FlxValue(v1).json())

    print("Done!!!")