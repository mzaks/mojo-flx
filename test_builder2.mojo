from math.bit import bit_length
from flx2 import FlxMap, FlxVec, flx, flx_blob, flx_null
from flx2.flx_buffer import FlxBuffer
from memory.unsafe import bitcast
from testing import assert_equal

fn print_result(r: Tuple[DTypePointer[DType.uint8], Int]):
    var bytes = r.get[0, DTypePointer[DType.uint8]]()
    var length = r.get[1, Int]()
    print("(" +  str(length) +  ")[", end="")
    for i in range(length):
        var end = ", " if i < length - 1 else "]\n"
        print(String(bytes.load(i)), end=end)


fn assert_result(r: Tuple[DTypePointer[DType.uint8], Int], *bytes: UInt8):
    if len(bytes) != r.get[1, Int]():
        print("Error, result contains", r.get[1, Int](), "bytes and you provided", len(bytes))
        print_result(r)
        return 
    var p = r.get[0, DTypePointer[DType.uint8]]()
    for i in range(len(bytes)):
        if p.load(i) != bytes[i]:
            print("Error at index", i, "byte",  p.load(i), "!=", bytes[i])
            print_result(r)
            return

fn vec[D: DType](*values: SIMD[D, 1]) -> List[SIMD[D, 1]]:
    var result = List[SIMD[D, 1]](capacity=len(values))
    for i in range(len(values)):
        result.append(values[i])
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
    assert_result(flx("Maxim"), 20, 77, 97, 120, 105, 109, 0, 7, 20, 1)
    assert_result(flx("hello 😱"), 40, 104, 101, 108, 108, 111, 32, 240, 159, 152, 177, 0, 12, 20, 1)
    assert_result(flx("hello 🔥"), 40, 104, 101, 108, 108, 111, 32, 240, 159, 148, 165, 0, 12, 20, 1)
    var v1 = vec[DType.int8](1, 2, 3)
    assert_result(flx(DTypePointer[DType.int8](v1.data.value), len(v1)), 12, 1, 2, 3, 4, 44, 1)
    _= v1 # needed hack becasue of ASAP descruction policy, will be removed with proper LifeTime feature 
    v1 = vec[DType.int8](-1, 2, 3)
    assert_result(flx(DTypePointer[DType.int8](v1.data.value), len(v1)), 12, 255, 2, 3, 4, 44, 1)
    _= v1 # needed hack becasue of ASAP descruction policy, will be removed with proper LifeTime feature 
    var v2 = vec[DType.int16](1, 555, 3)
    assert_result(flx(DTypePointer[DType.int16](v2.data.value), len(v2)), 12, 0, 1, 0, 43, 2, 3, 0, 8, 45, 1)
    _= v2 # needed hack becasue of ASAP descruction policy, will be removed with proper LifeTime feature 
    var v4 = vec[DType.int32](1, 55500, 3)
    assert_result(
        flx(DTypePointer[DType.int32](v4.data.value), len(v4)), 
        12, 0, 0, 0, 1, 0, 0, 0, 204, 216, 0, 0, 3, 0, 0, 0, 16, 46, 1
    )
    _= v4 # needed hack becasue of ASAP descruction policy, will be removed with proper LifeTime feature 
    var v8 = vec[DType.int64](1, 55555555500, 3)
    assert_result(
        flx(DTypePointer[DType.int64](v8.data.value), len(v8)), 
        12, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 172, 128, 94, 239, 12, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 32, 47, 1
    )
    _= v8 # needed hack becasue of ASAP descruction policy, will be removed with proper LifeTime feature 
    var vb = vec[DType.bool](True, False, True)
    assert_result(flx(DTypePointer[DType.bool](vb.data.value), len(vb)), 12, 1, 0, 1, 4, 144, 1)
    _= vb # needed hack becasue of ASAP descruction policy, will be removed with proper LifeTime feature 

fn test_vec_construction():
    try:
        var flx1 = FlxBuffer()
        flx1.start_vector()
        flx1.add(1)
        flx1.add(2)
        flx1.add(3)
        flx1.end()
        assert_result(flx1^.finish(), 12, 1, 2, 3, 4, 44, 1)

        var flx2 = FlxBuffer()
        flx2.start_vector()
        flx2.add(1)
        flx2.add(555)
        flx2.add(3)
        flx2.end()
        assert_result(flx2^.finish(), 12, 0, 1, 0, 43, 2, 3, 0, 8, 45, 1)

        var flx3 = FlxBuffer()
        flx3.start_vector()
        flx3.add("foo")
        flx3.add("bar")
        flx3.add("baz")
        flx3.end()
        assert_result(flx3^.finish(), 12, 102, 111, 111, 0, 12, 98, 97, 114, 0, 12, 98, 97, 122, 0, 12, 16, 12, 8, 4, 60, 1)

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
            12, 102, 111, 111, 0, 0, 0, 0,
            20, 0, 0, 0, 0, 0, 0, 0, 
            16, 0, 0, 0, 0, 0, 0, 0, 
            1, 0, 0, 0, 0, 0, 0, 0, 
            251, 255, 255, 255, 255, 255, 255, 255, 
            205, 204, 204, 204, 204, 204, 244, 63, 
            1, 0, 0, 0, 0, 0, 0, 0, 
            20, 4, 4, 15, 104, 53, 43, 1
        )

        var flx5 = FlxBuffer()
        flx5.start_vector()
        flx5.key("foo")
        flx5.key("bar")
        flx5.key("baz")
        flx5.end()
        assert_result(flx5^.finish(), 102, 111, 111, 0, 98, 97, 114, 0, 98, 97, 122, 0, 12, 13, 10, 7, 4, 56, 1)
        
        var flx6 = FlxBuffer()
        flx6.start_vector()
        flx6.start_vector()
        flx6.add(61)
        flx6.end()
        flx6.add(64)
        flx6.end()
        assert_result(flx6^.finish(), 4, 61, 8, 3, 64, 44, 4, 5, 40, 1)

    except:
        print("unexpected error")

fn test_map_construction():
    try:
        var flx1 = FlxBuffer()
        flx1.start_map()
        flx1.key("a")
        flx1.add(12)
        flx1.end()
        assert_result(flx1^.finish(), 97, 0, 4, 3, 2, 1, 4, 12, 4, 3, 36, 1)

        var flx2 = FlxBuffer()
        flx2.start_map()
        flx2.key("")
        flx2.add(45)
        flx2.key("a")
        flx2.add(12)
        flx2.end()
        assert_result(flx2^.finish(), 0, 97, 0, 8, 4, 4, 3, 1, 8, 45, 12, 4, 4, 5, 36, 1)

        var flx3 = FlxBuffer()
        flx3.start_map()
        flx3.key("b")
        flx3.add(45)
        flx3.key("a")
        flx3.add(12)
        flx3.end()
        assert_result(
            flx3^.finish(), 
            98, 0, 97, 0, 8, 3, 6, 3, 1, 8, 12, 45, 4, 4, 5, 36, 1
        )
    except:
        print("unexpected error")

fn test_add_referenced() raises:
    var flx = FlxBuffer()
    flx.start_vector()
    flx.start_vector()
    flx.add(1)
    flx.add(2)
    flx.add(3)
    flx.end("v1")
    flx.add_referenced("v1")
    flx.add_referenced("v1")
    flx.add_referenced("v1")
    flx.end()
    assert_result(
        flx^.finish(),
        12, 1, 2, 3, 16, 5, 6, 7, 8, 44, 44, 44, 44, 9, 40, 1,
    )

fn test_map_builder():
    try:
        assert_result(
            FlxMap().add("", 45).add("a", 12).finish(),
            0, 97, 0, 8, 4, 4, 3, 1, 8, 45, 12, 4, 4, 5, 36, 1
        )

        assert_result(
            FlxMap()
                .add("a", 12)
                .map("b")
                    .add("c", 33)
                .up_to_map()
                .add("d", "max")
            .finish(),
            97, 0, 98, 0, 99, 0, 4, 3, 2, 1, 4, 33, 4, 100, 0, 12, 109, 97, 120, 0, 
            12, 21, 20, 10, 4, 1, 12, 12, 18, 14, 4, 36, 20, 7, 36, 1
        )

        assert_result(
            FlxMap()
                .add("a", 12)
                .vec("b")
                    .add(33)
                .up_to_map()
                .add("d", "max")
            .finish(),
            97, 0, 98, 0, 4, 33, 100, 0, 12, 109, 97, 120, 0, 
            12, 14, 13, 10, 4, 1, 12, 12, 17, 14, 4, 44, 20, 7, 36, 1
        )

        assert_result(
            FlxMap().add("a", 1).add_indirect[DType.int32]("b", 2333).add("c", 3).finish(),
            97, 0, 98, 0, 29, 9, 0, 0, 99, 0, 12, 11, 10, 5, 4, 1, 12, 1, 14, 3, 4, 26, 4, 7, 36, 1
        )
    except e:
        print("unexpected error", e)

fn test_vec_builder():
    try:
        assert_result(
            FlxVec().vec().add(61).up_to_vec().add(64).finish(),
            4, 61, 8, 3, 64, 44, 4, 5, 40, 1
        )
        assert_result(
            FlxVec().add(1).add_indirect[DType.int32](2333).add(3).finish(),
            29, 9, 0, 0, 12, 1, 6, 3, 4, 26, 4, 7, 40, 1 
        )
        var vec = FlxVec()
        for i in range(256):
            vec = vec^.add[DType.bool](i & 1 == 1)
        assert_result(
            vec^.finish(),
            1, 4, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
            0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
            0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
            0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
            0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
            0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
            0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
            0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
            0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
            0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
            0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
            0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 2, 1, 144, 2 
        )
    except e:
        print("unexpected error", e)

fn test_blob() raises:
    var data = DTypePointer[DType.uint8].alloc(1001)
    for i in range(1001):
        data[i] = 5
    
    var r = flx_blob(data, 1001)
    var b = r.get[0, DTypePointer[DType.uint8]]()
    var l = r.get[1, Int]()
    _ = assert_equal(l, 1008)
    _ = assert_equal(b.load(0), 165)
    _ = assert_equal(b.load(1), 15)
    for i in range(2, 1002):
        _ = assert_equal(b.load(i), 5)
    # Padding bytes are not zeroed out for now
    # _ = assert_equal(b.load(1003), 0)
    _ = assert_equal(b.load(1004), 236)
    _ = assert_equal(b.load(1005), 3)
    _ = assert_equal(b.load(1006), 101)
    _ = assert_equal(b.load(1007), 2)

fn test_dedup_string():
    try:
        assert_result(
            FlxVec().add("maxim").add("alex").add("maxim").finish(),
            20, 109, 97, 120, 105, 109, 0, 16, 97, 108, 101, 120, 0, 12, 14, 8, 16, 4, 60, 1
        )
        assert_result(
            FlxVec[dedup_string=False]().add("maxim").add("alex").add("maxim").finish(),
            20, 109, 97, 120, 105, 109, 0, 16, 97, 108, 101, 120, 0, 
            20, 109, 97, 120, 105, 109, 0, 12, 21, 15, 10, 4, 60, 1
        )
        assert_result(
            FlxMap().add("a", "maxim").add("b", "alex").add("c", "maxim").finish(),
            97, 0, 20, 109, 97, 120, 105, 109, 0, 98, 0, 16, 97, 108, 101, 120, 0, 99, 0, 
            12, 20, 12, 5, 4, 1, 12, 24, 16, 26, 20, 20, 20, 7, 36, 1
        )
        assert_result(
            FlxMap[dedup_string=False]().add("a", "maxim").add("b", "alex").add("c", "maxim").finish(),
            97, 0, 20, 109, 97, 120, 105, 109, 0, 98, 0, 16, 97, 108, 101, 120, 0, 99, 0, 
            20, 109, 97, 120, 105, 109, 0, 12, 27, 19, 12, 4, 1, 12, 31, 23, 16, 20, 20, 20, 7, 36, 1
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
            97, 0, 20, 109, 97, 120, 105, 109, 0, 98, 0, 16, 97, 108, 101, 120, 0, 
            8, 18, 10, 3, 1, 8, 21, 13, 20, 20, 97, 0, 16, 108, 101, 110, 97, 0, 
            99, 0, 20, 100, 97, 114, 105, 97, 0, 8, 18, 11, 3, 1, 8, 21, 14, 20, 
            20, 8, 33, 7, 36, 36, 5, 40, 1,
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
            97, 0, 20, 109, 97, 120, 105, 109, 0, 98, 0, 16, 97, 108, 101, 120, 0, 
            8, 18, 10, 3, 1, 8, 21, 13, 20, 20, 16, 108, 101, 110, 97, 0, 99, 0, 
            20, 100, 97, 114, 105, 97, 0, 8, 43, 11, 3, 1, 8, 21, 14, 20, 
            20, 8, 31, 7, 36, 36, 5, 40, 1
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
            97, 0, 20, 109, 97, 120, 105, 109, 0, 98, 0, 16, 97, 108, 101, 120, 0, 
            8, 18, 10, 3, 1, 8, 21, 13, 20, 20, 16, 108, 101, 110, 97, 0, 
            20, 100, 97, 114, 105, 97, 0, 23, 1, 8, 16, 11, 20, 
            20, 8, 26, 7, 36, 36, 5, 40, 1,
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
            97, 0, 20, 109, 97, 120, 105, 109, 0, 98, 0, 16, 97, 108, 101, 120, 0, 
            8, 18, 10, 3, 1, 8, 21, 13, 20, 20, 16, 108, 101, 110, 97, 0, 
            20, 100, 97, 114, 105, 97, 0, 8, 41, 33, 3, 1, 8, 19, 14, 20, 
            20, 8, 29, 7, 36, 36, 5, 40, 1,
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
            97, 0, 20, 109, 97, 120, 105, 109, 0, 98, 0, 16, 97, 108, 101, 120, 0, 
            8, 18, 10, 3, 1, 8, 21, 13, 20, 20, 97, 0, 16, 108, 101, 110, 97, 0, 98, 0, 
            20, 100, 97, 114, 105, 97, 0, 8, 18, 11, 3, 1, 8, 21, 14, 20, 
            20, 8, 33, 7, 36, 36, 5, 40, 1,
        )
    except e:
        print("unexpected error", e)

fn main() raises:
    test_single_value_contructor()
    test_vec_construction()
    test_map_construction()
    test_map_builder()
    test_vec_builder()
    test_blob()
    test_dedup_string()
    test_dedup_key()
    test_add_referenced()

    print("All Done!!!")