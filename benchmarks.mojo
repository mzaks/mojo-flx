from time import now
from math.limit import max_finite, min_finite
from math import min
from random import random_ui64, random_float64, random_si64
from flx import *

fn construct_and_read_vec[count: Int, D: DType]() raises:
    var nums = DynamicVector[SIMD[D, 1]](count)
    for _ in range(count):
        @parameter
        if D == DType.uint8 or D == DType.uint16 or D == DType.uint32 or D == DType.uint64:
            nums.push_back(random_ui64(0, 1 << 63).cast[D]())
        elif D == DType.float16 or D == DType.float32 or D == DType.float64:
            nums.push_back(random_float64().cast[D]())
        else:
            nums.push_back(random_si64(min_finite[DType.int64](), max_finite[DType.int64]()).cast[D]())
    var size = 0
    var min_duration_create = max_finite[DType.int64]().to_int()
    var min_duration_read = max_finite[DType.int64]().to_int()
    for _ in range(20):
        var tik = now()
        let r = flx[D](nums.data, len(nums))
        var tok = now()
        min_duration_create = min(min_duration_create, tok - tik)
        size = r.get[1, Int]()
        let bytes = r.get[0, DTypePointer[DType.uint8]]()
        tik = now()
        let vec = FlxValue(bytes, size)
        tok = now()
        var read_duration = tok - tik
        for i in range(count):
            tik = now()
            let v = vec[i].get[D]()
            tok = now()
            read_duration += tok - tik
            if v != nums[i]:
                print("Error at index:", i)
        bytes.free()
        min_duration_read = min(min_duration_read, read_duration)

    print("Constructed a vector of", count, D, ",",  size, "bytes in", min_duration_create / 1_000_000, "ms")
    print("Read a vector of", count, D, ",",  size, "bytes in", min_duration_read / 1_000_000, "ms")

fn construct_one_mio_u64_vec_in_10_x_100000_table() raises:
    var nums = DynamicVector[UInt64](1_000_000)
    for _ in range(1_000_000):
        nums.push_back(random_ui64(0, 1 << 63))
    var size = 0
    var min_duration = max_finite[DType.int64]().to_int()
    for _ in range(20):
        let tik = now()
        var df = FlxVec()
        for i in range(10):
            var row = df^.vec()
            for j in range(100_000):
                row = row^.add[DType.uint64](nums[i + j * 10])
            df = row^.up_to_vec()
        let r = df^.finish()
        let tok = now()
        size = r.get[1, Int]()
        r.get[0, DTypePointer[DType.uint8]]().free()
        min_duration = min(min_duration, tok - tik)

    print("Constructed a table 10x100000 of 1 Mio UInt64", size, "bytes in", min_duration / 1_000_000, "ms")

fn construct_one_mio_u64_vec_in_100000_x_10_table() raises:
    var nums = DynamicVector[UInt64](1_000_000)
    for _ in range(1_000_000):
        nums.push_back(random_ui64(0, 1 << 63))
    var size = 0
    var min_duration = max_finite[DType.int64]().to_int()
    for _ in range(20):
        let tik = now()
        var df = FlxVec()
        for i in range(100_000):
            var row = df^.vec()
            for j in range(10):
                row = row^.add[DType.uint64](nums[i + j * 100_000])
            df = row^.up_to_vec()
        let r = df^.finish()
        let tok = now()
        size = r.get[1, Int]()
        r.get[0, DTypePointer[DType.uint8]]().free()
        min_duration = min(min_duration, tok - tik)

    print("Constructed a table 100000x10 of 1 Mio UInt64", size, "bytes in", min_duration / 1_000_000, "ms")

fn main():
    try:
        construct_and_read_vec[1_000_000, DType.uint64]()
        construct_and_read_vec[1_000_000, DType.uint32]()
        construct_and_read_vec[1_000_000, DType.uint16]()
        construct_and_read_vec[1_000_000, DType.uint8]()
        construct_and_read_vec[1_000_000, DType.int64]()
        construct_and_read_vec[1_000_000, DType.int32]()
        construct_and_read_vec[1_000_000, DType.int16]()
        construct_and_read_vec[1_000_000, DType.int8]()
        construct_and_read_vec[1_000_000, DType.float64]()
        construct_and_read_vec[1_000_000, DType.float32]()
        construct_and_read_vec[1_000_000, DType.float16]()
        construct_and_read_vec[32_000, DType.float16]()
        construct_and_read_vec[16_000, DType.float16]()
        construct_one_mio_u64_vec_in_10_x_100000_table()
        construct_one_mio_u64_vec_in_100000_x_10_table()
    except e:
        print("Unexpected error:", e)