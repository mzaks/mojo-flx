from flx import FlxMap, FlxVec, FlxValue, flx, flx_blob
from testing import assert_equal, assert_almost_equal

fn test_string() raises:
    let r = flx("Hello world")
    let value = FlxValue(r.get[0, DTypePointer[DType.uint8]](), r.get[1, Int]())
    _ = assert_equal("Hello world", value.string())

fn test_blob() raises:
    let data = DTypePointer[DType.uint8].alloc(1001)
    for i in range(1001):
        data[i] = 5
    
    let r = flx_blob(data, 1001)
    
    let value = FlxValue(r.get[0, DTypePointer[DType.uint8]](), r.get[1, Int]())
    let blob = value.blob()
    _ = assert_equal(blob.get[1, Int](), 1001)
    for i in range(1001):
        _ = assert_equal(blob.get[0, DTypePointer[DType.uint8]]().load(i), 5)

fn test_int() raises:
    var r = flx(12345)
    var value = FlxValue(r.get[0, DTypePointer[DType.uint8]](), r.get[1, Int]())
    _ = assert_equal(value.int(), 12345)

    r = flx[DType.uint32](12345)
    value = FlxValue(r.get[0, DTypePointer[DType.uint8]](), r.get[1, Int]())
    _ = assert_equal(value.int(), 12345)

    r = flx[DType.uint64](12345)
    value = FlxValue(r.get[0, DTypePointer[DType.uint8]](), r.get[1, Int]())
    _ = assert_equal(value.int(), 12345)

    r = flx[DType.int64](12345)
    value = FlxValue(r.get[0, DTypePointer[DType.uint8]](), r.get[1, Int]())
    _ = assert_equal(value.int(), 12345)

    r = flx[DType.int8](12345)
    value = FlxValue(r.get[0, DTypePointer[DType.uint8]](), r.get[1, Int]())
    _ = assert_equal(value.int(), 57)

fn test_float() raises:
    var r = flx[DType.float64](123.45)
    var value = FlxValue(r.get[0, DTypePointer[DType.uint8]](), r.get[1, Int]())
    _ = assert_equal(value.float(), 123.45)

    r = flx[DType.float32](123.45)
    value = FlxValue(r.get[0, DTypePointer[DType.uint8]](), r.get[1, Int]())
    _ = assert_almost_equal(value.float(), 123.45)

    r = flx[DType.float16](123.45)
    value = FlxValue(r.get[0, DTypePointer[DType.uint8]](), r.get[1, Int]())
    _ = assert_almost_equal(value.float(), 123.4375) # Rounding error becuase of 16 bit precision

fn test_vec() raises:
    let r1 = FlxVec().add(1).add(2).add(3).finish()
    var value = FlxValue(r1.get[0, DTypePointer[DType.uint8]](), r1.get[1, Int]())
    _ = assert_equal(value[0].get[DType.int8](), 1)
    _ = assert_equal(value[0].int(), 1)
    _ = assert_equal(value[1].get[DType.int8](), 2)
    _ = assert_equal(value[1].int(), 2)
    _ = assert_equal(value[2].get[DType.int8](), 3)
    _ = assert_equal(value[2].int(), 3)

    let r2 = FlxVec().add("a").vec().add("b").add("c").finish()
    value = FlxValue(r2.get[0, DTypePointer[DType.uint8]](), r2.get[1, Int]())
    _ = assert_equal(value[0].string(), "a")
    _ = assert_equal(value[1][0].string(), "b")
    _ = assert_equal(value[1][1].string(), "c")

    let r3 = FlxVec().add[DType.float16](1.1).add[DType.float32](1.1).add[DType.float64](1.1).finish()
    value = FlxValue(r3.get[0, DTypePointer[DType.uint8]](), r3.get[1, Int]())
    _ = assert_equal(value[0].get[DType.float64](), Float16(1.1))
    _ = assert_equal(value[1].get[DType.float64](), Float32(1.1))
    _ = assert_equal(value[2].get[DType.float64](), 1.1)

    let r4 = FlxVec().add[DType.int8](-13).add[DType.int16](-13).add[DType.int32](-13).add[DType.int64](-13).finish()
    value = FlxValue(r4.get[0, DTypePointer[DType.uint8]](), r4.get[1, Int]())
    _ = assert_equal(value[0].get[DType.int64](), -13)
    _ = assert_equal(value[0].int(), -13)
    _ = assert_equal(value[1].get[DType.int64](), -13)
    _ = assert_equal(value[1].int(), -13)
    _ = assert_equal(value[2].get[DType.int64](), -13)
    _ = assert_equal(value[2].int(), -13)
    _ = assert_equal(value[3].get[DType.int64](), -13)
    _ = assert_equal(value[3].int(), -13)

    var vec = FlxVec()
    for i in range(256):
        vec = vec^.add[DType.bool](i & 1 == 1)
    let r5 = vec^.finish()
    value = FlxValue(r5.get[0, DTypePointer[DType.uint8]](), r5.get[1, Int]())
    _ = assert_equal(256, value.__len__())
    for i in range(256):
        _ = assert_equal(i & 1 == 1, value[i].bool())

    let r6 = FlxVec().add[DType.int32](1234).add("maxim").add[DType.float16](1.5).add[DType.bool](True).finish()
    value = FlxValue(r6.get[0, DTypePointer[DType.uint8]](), r6.get[1, Int]())
    _ = assert_equal(value[0].int(), 1234)
    _ = assert_equal(value[1].string(), "maxim")
    _ = assert_equal(value[2].get[DType.float32](), 1.5)
    _ = assert_equal(value[3].bool(), True)

fn test_map() raises:
    var r1 = FlxMap().add("a", 12).add("b", 45).finish()
    var value = FlxValue(r1.get[0, DTypePointer[DType.uint8]](), r1.get[1, Int]())
    _ = assert_equal(value["a"].get[DType.int8](), 12)
    _ = assert_equal(value["a"].int(), 12)
    _ = assert_equal(value["b"].get[DType.int8](), 45)
    _ = assert_equal(value["b"].int(), 45)

    r1 = FlxMap().add("b", 12).add("a", 45).finish()
    value = FlxValue(r1.get[0, DTypePointer[DType.uint8]](), r1.get[1, Int]())
    _ = assert_equal(value["b"].get[DType.int8](), 12)
    _ = assert_equal(value["a"].get[DType.int8](), 45)

    r1 = FlxMap().add("name", "Maxim").add("age", 42).add[DType.float32]("weight", 72.5).add[DType.bool]("friendly", True).finish()
    value = FlxValue(r1.get[0, DTypePointer[DType.uint8]](), r1.get[1, Int]())
    _ = assert_equal(value["name"].string(), "Maxim")
    _ = assert_equal(value["age"].int(), 42)
    _ = assert_equal(value["weight"].get[DType.float32](), 72.5)
    _ = assert_equal(value["friendly"].bool(), True)

    r1 = FlxMap()
        .add("name", "Maxim")
        .add("age", 42)
        .add[DType.float32]("weight", 72.5)
        .map("address")
            .add("city", "Bla")
            .add("zip", "12345")
            .add("countryCode", "XX")
            .up_to_map()
        .vec("flags")
            .add[DType.bool](True)
            .add[DType.bool](False)
            .add[DType.bool](True)
            .add[DType.bool](True)
        .finish()
    value = FlxValue(r1.get[0, DTypePointer[DType.uint8]](), r1.get[1, Int]())
    _ = assert_equal(value["name"].string(), "Maxim")
    _ = assert_equal(value["age"].get[DType.int32](), 42)
    _ = assert_equal(value["weight"].get[DType.float32](), 72.5)
    _ = assert_equal(value["address"].__len__(), 3)
    _ = assert_equal(value["address"]["city"].string(), "Bla")
    _ = assert_equal(value["address"]["zip"].string(), "12345")
    _ = assert_equal(value["address"]["countryCode"].string(), "XX")
    _ = assert_equal(value["flags"].__len__(), 4)
    _ = assert_equal(value["flags"][0].get[DType.bool](), True)
    _ = assert_equal(value["flags"][1].get[DType.bool](), False)
    _ = assert_equal(value["flags"][2].get[DType.bool](), True)
    _ = assert_equal(value["flags"][3].get[DType.bool](), True)

    r1 = FlxVec()
            .map()
                .add("a", "maxim")
                .add("b", "alex")
                .up_to_vec()
            .map()
                .add("a", "lena")
                .add("c", "daria")
        .finish()
    value = FlxValue(r1.get[0, DTypePointer[DType.uint8]](), r1.get[1, Int]())
    _ = assert_equal(value.__len__(), 2)
    _ = assert_equal(value[0].__len__(), 2)
    _ = assert_equal(value[0]["a"].string(), "maxim")
    _ = assert_equal(value[0]["b"].string(), "alex")
    _ = assert_equal(value[1].__len__(), 2)
    _ = assert_equal(value[1]["a"].string(), "lena")
    _ = assert_equal(value[1]["c"].string(), "daria")

    r1 = FlxVec[dedup_keys_vec=False]()
            .map()
                .add("a", "maxim")
                .add("b", "alex")
                .up_to_vec()
            .map()
                .add("a", "lena")
                .add("b", "daria")
        .finish()
    value = FlxValue(r1.get[0, DTypePointer[DType.uint8]](), r1.get[1, Int]())
    _ = assert_equal(value.__len__(), 2)
    _ = assert_equal(value[0].__len__(), 2)
    _ = assert_equal(value[0]["a"].string(), "maxim")
    _ = assert_equal(value[0]["b"].string(), "alex")
    _ = assert_equal(value[1].__len__(), 2)
    _ = assert_equal(value[1]["a"].string(), "lena")
    _ = assert_equal(value[1]["b"].string(), "daria")


fn test_indirect() raises:
    var r1 = FlxVec().add(1).add_indirect[DType.int32](2333).add(3).finish()
    var value = FlxValue(r1.get[0, DTypePointer[DType.uint8]](), r1.get[1, Int]())
    _ = assert_equal(value.__len__(), 3)
    _ = assert_equal(value[0].int(), 1)
    _ = assert_equal(value[1].int(), 2333)
    _ = assert_equal(value[2].int(), 3)

    r1 = FlxMap().add("a", 1).add_indirect[DType.int32]("b", 2333).add("c", 3).finish()
    value = FlxValue(r1.get[0, DTypePointer[DType.uint8]](), r1.get[1, Int]())
    _ = assert_equal(value.__len__(), 3)
    _ = assert_equal(value["a"].int(), 1)
    _ = assert_equal(value["b"].int(), 2333)
    _ = assert_equal(value["c"].int(), 3)


fn main():
    try:
        test_string()
        test_blob()
        test_vec()
        test_map()
        test_int()
        test_float()
        test_indirect()
    except e:
        print("unexpected error", e)

    print("All done!!!")