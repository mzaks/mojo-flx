
from math.bit import bit_length
from flx import FlxMap, FlxVec, flx, flx_blob, flx_null
from flx.flx_buffer import FlxBuffer
from memory.unsafe import bitcast
from testing import assert_equal

fn print_result(r: Tuple[DTypePointer[DType.uint8], Int]):
    let bytes = r.get[0, DTypePointer[DType.uint8]]()
    let length = r.get[1, Int]()
    print_no_newline("(", length, ")", "[")
    for i in range(length):
        print_no_newline(String(bytes.load(i)) + ", ")
    print("]")


fn assert_result(r: Tuple[DTypePointer[DType.uint8], Int], *bytes: UInt8):
    if len(bytes) != r.get[1, Int]():
        print("Error, result contains", r.get[1, Int](), "bytes and you provided", len(bytes))
        print_result(r)
        return 
    let p = r.get[0, DTypePointer[DType.uint8]]()
    for i in range(len(bytes)):
        if p.load(i) != bytes[i]:
            print("Error at index", i, "byte",  p.load(i), "!=", bytes[i])
            print_result(r)
            return

fn vec[D: DType](*values: SIMD[D, 1]) -> DynamicVector[SIMD[D, 1]]:
    var result = DynamicVector[SIMD[D, 1]](len(values))
    for i in range(len(values)):
        result.push_back(values[i])
    return result

fn test_single_value_contructor():
    assert_result(flx_null(), 0, 0, 1)
    assert_result(flx(25), 25, 4, 1)
    assert_result(flx(-25), 231, 4, 1)
    assert_result(flx(230), 230, 0, 5, 2)
    assert_result(flx(-230), 26, 255, 5, 2)
    assert_result(flx[DType.uint8](230), 230, 8, 1)
    assert_result(flx[DType.uint16](230), 230, 0, 9, 2)
    assert_result(flx[DType.uint32](230), 230, 0, 0, 0, 10, 4)
    assert_result(flx[DType.uint64](230), 230, 0, 0, 0, 0, 0, 0, 0, 11, 8)
    assert_result(flx[DType.bool](True), 1, 104, 1)
    assert_result(flx[DType.bool](False), 0, 104, 1)
    assert_result(flx[DType.float16](4.5), 128, 68, 13, 2)
    assert_result(flx[DType.float32](4.5), 0, 0, 144, 64, 14, 4)
    assert_result(flx[DType.float32](0.1), 205, 204, 204, 61, 14, 4)
    assert_result(flx("Maxim"), 5, 77, 97, 120, 105, 109, 0, 6, 20, 1)
    assert_result(flx("hello 😱"), 10, 104, 101, 108, 108, 111, 32, 240, 159, 152, 177, 0, 11, 20, 1)
    assert_result(flx("hello 🔥"), 10, 104, 101, 108, 108, 111, 32, 240, 159, 148, 165, 0, 11, 20, 1)
    var v1 = vec[DType.int8](1, 2, 3)
    assert_result(flx(DTypePointer[DType.int8](v1.data), len(v1)), 3, 1, 2, 3, 3, 44, 1)
    v1 = vec[DType.int8](-1, 2, 3)
    assert_result(flx(DTypePointer[DType.int8](v1.data), len(v1)), 3, 255, 2, 3, 3, 44, 1)
    let v2 = vec[DType.int16](1, 555, 3)
    assert_result(flx(DTypePointer[DType.int16](v2.data), len(v2)), 3, 0, 1, 0, 43, 2, 3, 0, 6, 45, 1)
    let v4 = vec[DType.int32](1, 55500, 3)
    assert_result(
        flx(DTypePointer[DType.int32](v4.data), len(v4)), 
        3, 0, 0, 0, 1, 0, 0, 0, 204, 216, 0, 0, 3, 0, 0, 0, 12, 46, 1
    )
    let v8 = vec[DType.int64](1, 55555555500, 3)
    assert_result(
        flx(DTypePointer[DType.int64](v8.data), len(v8)), 
        3, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 172, 128, 94, 239, 12, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 24, 47, 1
    )
    let vb = vec[DType.bool](True, False, True)
    assert_result(flx(DTypePointer[DType.bool](vb.data), len(vb)), 3, 1, 0, 1, 3, 144, 1)

fn test_vec_construction():
    try:
        var flx1 = FlxBuffer()
        flx1.start_vector()
        flx1.add(1)
        flx1.add(2)
        flx1.add(3)
        flx1.end()
        assert_result(flx1^.finish(), 3, 1, 2, 3, 3, 44, 1)

        var flx2 = FlxBuffer()
        flx2.start_vector()
        flx2.add(1)
        flx2.add(555)
        flx2.add(3)
        flx2.end()
        assert_result(flx2^.finish(), 3, 0, 1, 0, 43, 2, 3, 0, 6, 45, 1)

        var flx3 = FlxBuffer()
        flx3.start_vector()
        flx3.add("foo")
        flx3.add("bar")
        flx3.add("baz")
        flx3.end()
        assert_result(flx3^.finish(), 3, 102, 111, 111, 0, 3, 98, 97, 114, 0, 3, 98, 97, 122, 0, 3, 15, 11, 7, 3, 60, 1)

        var flx4 = FlxBuffer()
        flx4.start_vector()
        flx4.add("foo")
        flx4.add(1)
        flx4.add(-5)
        flx4.add[DType.float64](1.3)
        flx4.add[DType.bool](True)
        flx4.end()
        assert_result(
            flx4^.finish(), 
            3, 102, 111, 111, 0, 0, 0, 0,
            5, 0, 0, 0, 0, 0, 0, 0, 
            15, 0, 0, 0, 0, 0, 0, 0, 
            1, 0, 0, 0, 0, 0, 0, 0, 
            251, 255, 255, 255, 255, 255, 255, 255, 
            205, 204, 204, 204, 204, 204, 244, 63, 
            1, 0, 0, 0, 0, 0, 0, 0, 
            20, 4, 4, 15, 104, 45, 43, 1
        )

        var flx5 = FlxBuffer()
        flx5.start_vector()
        flx5.key("foo")
        flx5.key("bar")
        flx5.key("baz")
        flx5.end()
        assert_result(flx5^.finish(), 102, 111, 111, 0, 98, 97, 114, 0, 98, 97, 122, 0, 3, 13, 10, 7, 3, 56, 1)
        
        var flx6 = FlxBuffer()
        flx6.start_vector()
        flx6.start_vector()
        flx6.add(61)
        flx6.end()
        flx6.add(64)
        flx6.end()
        assert_result(flx6^.finish(), 1, 61, 2, 2, 64, 44, 4, 4, 40, 1)

    except:
        print("unexpected error")

fn test_map_construction():
    try:
        var flx1 = FlxBuffer()
        flx1.start_map()
        flx1.key("a")
        flx1.add(12)
        flx1.end()
        assert_result(flx1^.finish(), 97, 0, 1, 3, 1, 1, 1, 12, 4, 2, 36, 1)

        var flx2 = FlxBuffer()
        flx2.start_map()
        flx2.key("")
        flx2.add(45)
        flx2.key("a")
        flx2.add(12)
        flx2.end()
        assert_result(flx2^.finish(), 0, 97, 0, 2, 4, 4, 2, 1, 2, 45, 12, 4, 4, 4, 36, 1)

        var flx3 = FlxBuffer()
        flx3.start_map()
        flx3.key("b")
        flx3.add(45)
        flx3.key("a")
        flx3.add(12)
        flx3.end()
        assert_result(
            flx3^.finish(), 
            98, 0, 97, 0, 2, 3, 6, 2, 1, 2, 12, 45, 4, 4, 4, 36, 1
        )
    except:
        print("unexpected error")

fn test_map_builder():
    try:
        assert_result(
            FlxMap().add("", 45).add("a", 12).finish(),
            0, 97, 0, 2, 4, 4, 2, 1, 2, 45, 12, 4, 4, 4, 36, 1
        )

        assert_result(
            FlxMap()
                .add("a", 12)
                .map("b")
                    .add("c", 33)
                .up_to_map()
                .add("d", "max")
            .finish(),
            0x61, 0x00, 0x62, 0x00, 0x63, 0x00, 0x01, 0x03, 0x01, 0x01, 0x01, 0x21, 0x04, 0x64, 0x00, 0x03, 
            0x6d, 0x61, 0x78, 0x00, 0x03, 0x15, 0x14, 0x0a, 0x03, 0x01, 0x03, 0x0c, 0x11, 0x0d, 0x04, 0x24, 
            0x14, 0x06, 0x24, 0x01
        )

        assert_result(
            FlxMap()
                .add("a", 12)
                .vec("b")
                    .add(33)
                .up_to_map()
                .add("d", "max")
            .finish(),
            0x61, 0x00, 0x62, 0x00, 0x01, 0x21, 0x64, 0x00, 0x03, 0x6d, 0x61, 0x78, 0x00, 0x03, 0x0e, 0x0d, 
            0x0a, 0x03, 0x01, 0x03, 0x0c, 0x10, 0x0d, 0x04, 0x2c, 0x14, 0x06, 0x24, 0x01
        )

        assert_result(
            FlxMap().add("a", 1).add_indirect[DType.int32]("b", 2333).add("c", 3).finish(),
            97, 0, 98, 0, 29, 9, 0, 0, 99, 0, 3, 11, 10, 5, 3, 1, 3, 1, 14, 3, 4, 26, 4, 6, 36, 1
        )
    except e:
        print("unexpected error", e)

fn test_vec_builder():
    try:
        # assert_result(
        #     FlxVec().vec().add(61).up_to_vec().add(64).finish(),
        #     1, 61, 2, 2, 64, 44, 4, 4, 40, 1
        # )
        # assert_result(
        #     FlxVec().add(1).add_indirect[DType.int32](2333).add(3).finish(),
        #     29, 9, 0, 0, 3, 1, 6, 3, 4, 26, 4, 6, 40, 1 
        # )
        var vec = FlxVec()
        for i in range(256):
            vec = vec^.add[DType.bool](i & 1 == 1)
        assert_result(
            vec^.finish(),
            0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 
            0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 
            1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 
            0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 
            1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 
            0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 
            1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 
            0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 
            1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 
            0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 
            1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 
            0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 
            1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 
            0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 
            1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 
            0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 
            1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 
            0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 
            1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 
            0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 2, 145, 2, 
        )
    except e:
        print("unexpected error", e)

fn test_blob():
    var data = DynamicVector[UInt8](1001)
    for i in range(1001):
        data.push_back(5)
    
    let r = flx_blob(data.data, 1001)
    let b = r.get[0, DTypePointer[DType.uint8]]()
    let l = r.get[1, Int]()
    _ = assert_equal(l, 1008)
    _ = assert_equal(b.load(0), 233)
    _ = assert_equal(b.load(1), 3)
    for i in range(2, 1002):
        _ = assert_equal(b.load(i), 5)
    # Padding bytes are not zeroed out for now
    # _ = assert_equal(b.load(1003), 0)
    _ = assert_equal(b.load(1004), 234)
    _ = assert_equal(b.load(1005), 3)
    _ = assert_equal(b.load(1006), 101)
    _ = assert_equal(b.load(1007), 2)

fn test_dedup_string():
    try:
        assert_result(
            FlxVec().add("maxim").add("alex").add("maxim").finish(),
            5, 109, 97, 120, 105, 109, 0, 4, 97, 108, 101, 120, 0, 3, 13, 7, 15, 3, 60, 1
        )
        assert_result(
            FlxVec[dedup_string=False]().add("maxim").add("alex").add("maxim").finish(),
            5, 109, 97, 120, 105, 109, 0, 4, 97, 108, 101, 120, 0, 
            5, 109, 97, 120, 105, 109, 0, 3, 20, 14, 9, 3, 60, 1
        )
        assert_result(
            FlxMap().add("a", "maxim").add("b", "alex").add("c", "maxim").finish(),
            97, 0, 5, 109, 97, 120, 105, 109, 0, 98, 0, 4, 97, 108, 101, 120, 0, 99, 0, 
            3, 20, 12, 5, 3, 1, 3, 23, 15, 25, 20, 20, 20, 6, 36, 1
        )
        assert_result(
            FlxMap[dedup_string=False]().add("a", "maxim").add("b", "alex").add("c", "maxim").finish(),
            97, 0, 5, 109, 97, 120, 105, 109, 0, 98, 0, 4, 97, 108, 101, 120, 0, 99, 0, 
            5, 109, 97, 120, 105, 109, 0, 3, 27, 19, 12, 3, 1, 3, 30, 22, 15, 20, 20, 20, 6, 36, 1
        )
    except e:
        print("unexpected error", e)

fn test_dedup_key():
    try:
        assert_result(
            FlxVec[dedup_key=False]()
                .map()
                    .add("a", "maxim")
                    .add("b", "alex")
                    .up_to_vec()
                .map()
                    .add("a", "lena")
                    .add("c", "daria")
            .finish(),
            97, 0, 5, 109, 97, 120, 105, 109, 0, 98, 0, 4, 97, 108, 101, 120, 0, 
            2, 18, 10, 2, 1, 2, 20, 12, 20, 20, 97, 0, 4, 108, 101, 110, 97, 0, 
            99, 0, 5, 100, 97, 114, 105, 97, 0, 2, 18, 11, 2, 1, 2, 20, 13, 20, 
            20, 2, 32, 6, 36, 36, 4, 40, 1,
        )
        assert_result(
            FlxVec()
                .map()
                    .add("a", "maxim")
                    .add("b", "alex")
                    .up_to_vec()
                .map()
                    .add("a", "lena")
                    .add("c", "daria")
            .finish(),
            97, 0, 5, 109, 97, 120, 105, 109, 0, 98, 0, 4, 97, 108, 101, 120, 0, 
            2, 18, 10, 2, 1, 2, 20, 12, 20, 20, 4, 108, 101, 110, 97, 0, 99, 0, 
            5, 100, 97, 114, 105, 97, 0, 2, 43, 11, 2, 1, 2, 20, 13, 20, 
            20, 2, 30, 6, 36, 36, 4, 40, 1
        )
        assert_result(
            FlxVec()
                .map()
                    .add("a", "maxim")
                    .add("b", "alex")
                    .up_to_vec()
                .map()
                    .add("a", "lena")
                    .add("b", "daria")
            .finish(),
            97, 0, 5, 109, 97, 120, 105, 109, 0, 98, 0, 4, 97, 108, 101, 120, 0, 
            2, 18, 10, 2, 1, 2, 20, 12, 20, 20, 4, 108, 101, 110, 97, 0, 
            5, 100, 97, 114, 105, 97, 0, 22, 1, 2, 15, 10, 20, 
            20, 2, 25, 6, 36, 36, 4, 40, 1,
        )
        assert_result(
            FlxVec[dedup_keys_vec=False]()
                .map()
                    .add("a", "maxim")
                    .add("b", "alex")
                    .up_to_vec()
                .map()
                    .add("a", "lena")
                    .add("b", "daria")
            .finish(),
            97, 0, 5, 109, 97, 120, 105, 109, 0, 98, 0, 4, 97, 108, 101, 120, 0, 
            2, 18, 10, 2, 1, 2, 20, 12, 20, 20, 4, 108, 101, 110, 97, 0, 
            5, 100, 97, 114, 105, 97, 0, 2, 41, 33, 2, 1, 2, 18, 13, 20, 
            20, 2, 28, 6, 36, 36, 4, 40, 1,
        )
        assert_result(
            FlxVec[dedup_key=False]()
                .map()
                    .add("a", "maxim")
                    .add("b", "alex")
                    .up_to_vec()
                .map()
                    .add("a", "lena")
                    .add("b", "daria")
            .finish(),
            97, 0, 5, 109, 97, 120, 105, 109, 0, 98, 0, 4, 97, 108, 101, 120, 0, 
            2, 18, 10, 2, 1, 2, 20, 12, 20, 20, 97, 0, 4, 108, 101, 110, 97, 0, 98, 0, 
            5, 100, 97, 114, 105, 97, 0, 2, 18, 11, 2, 1, 2, 20, 13, 20, 
            20, 2, 32, 6, 36, 36, 4, 40, 1,
        )
    except e:
        print("unexpected error", e)

fn main():
    # test_single_value_contructor()
    # test_vec_construction()
    # test_map_construction()
    # test_map_builder()
    test_vec_builder()
    # test_blob()
    # test_dedup_string()
    # test_dedup_key()


    var v = DynamicVector[UInt16](1000)
    for i in range(1000):
        v.push_back(i) 

    let b6 = flx(DTypePointer[DType.uint16](v.data), len(v))
    print("All Done!!!")