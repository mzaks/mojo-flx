from time import now
from math.limit import max_finite
from math import min
from random import random_ui64, random_float64
from flx import *

fn construct_one_mio_u64_vec() raises:
    var nums = DynamicVector[UInt64](1_000_000)
    for _ in range(1_000_000):
        nums.push_back(random_ui64(0, 1 << 63))
    var size = 0
    var min_duration = max_finite[DType.int64]().to_int()
    for _ in range(20):
        let tik = now()
        let r = flx[DType.uint64](nums.data, len(nums))
        let tok = now()
        size = r.get[1, Int]()
        r.get[0, DTypePointer[DType.uint8]]().free()
        min_duration = min(min_duration, tok - tik)

    print("Constructed a vector of 1 Mio UInt64", size, "bytes in", min_duration / 1_000_000, "ms")


fn construct_one_mio_u8_vec() raises:
    var nums = DynamicVector[UInt8](1_000_000)
    for _ in range(1_000_000):
        nums.push_back(random_ui64(0, 1 << 8).cast[DType.uint8]())
    var size = 0
    var min_duration = max_finite[DType.int64]().to_int()
    for _ in range(20):
        let tik = now()
        let r = flx[DType.uint8](nums.data, len(nums))
        let tok = now()
        size = r.get[1, Int]()
        r.get[0, DTypePointer[DType.uint8]]().free()
        min_duration = min(min_duration, tok - tik)
    # Adding 1 Mio uint8 values is slower, 
    # because FlexBuffers need to repack values (add 3 bytes padding) as length is represented in UInt32 
    print("Constructed a vector of 1 Mio UInt8", size, "bytes in", min_duration / 1_000_000, "ms")

fn construct_one_mio_f64_vec() raises:
    var nums = DynamicVector[Float64](1_000_000)
    for _ in range(1_000_000):
        nums.push_back(random_float64(0, 1 << 63))
    var size = 0
    var min_duration = max_finite[DType.int64]().to_int()
    for _ in range(20):
        let tik = now()
        let r = flx[DType.float64](nums.data, len(nums))
        let tok = now()
        size = r.get[1, Int]()
        r.get[0, DTypePointer[DType.uint8]]().free()
        min_duration = min(min_duration, tok - tik)

    print("Constructed a vector of 1 Mio Float64", size, "bytes in", min_duration / 1_000_000, "ms")

fn construct_one_mio_f16_vec() raises:
    let count = 1_000_000
    var nums = DynamicVector[Float16](count)
    for _ in range(count):
        nums.push_back(random_float64(0, 1 << 16).cast[DType.float16]())
    var size = 0
    var min_duration_create = max_finite[DType.int64]().to_int()
    var min_duration_read = max_finite[DType.int64]().to_int()
    for _ in range(20):
        var tik = now()
        let r = flx[DType.float16](nums.data, len(nums))
        var tok = now()
        min_duration_create = min(min_duration_create, tok - tik)
        size = r.get[1, Int]()
        let bytes = r.get[0, DTypePointer[DType.uint8]]()
        var read_duration = 0
        tik = now()
        let vec = FlxValue(bytes, size)
        tok = now()
        read_duration += tok - tik
        for i in range(count):
            tik = now()
            let v = vec[i].get[DType.float16]()
            tok = now()
            read_duration += tok - tik
            if v != nums[i]:
                print("Error at index:", i)
        min_duration_read = min(min_duration_read, read_duration)
        bytes.free()

    # Adding 1 Mio Float16 values is slower, 
    # because FlexBuffers need to repack values (add 2 bytes padding) as length is represented in UInt32
    print("Constructed a vector of 1 Mio Float16", size, "bytes in", min_duration_create / 1_000_000, "ms")
    print("Read a vector of 1 Mio Float16", size, "bytes in", min_duration_read / 1_000_000, "ms")

fn construct_32k_f16_vec() raises:
    let count = 32_000
    var nums = DynamicVector[Float16](count)
    for _ in range(count):
        nums.push_back(random_float64(0, 1 << 16).cast[DType.float16]())
    var size = 0
    var min_duration_create = max_finite[DType.int64]().to_int()
    var min_duration_read = max_finite[DType.int64]().to_int()
    for _ in range(20):
        var tik = now()
        let r = flx[DType.float16](nums.data, len(nums))
        var tok = now()
        min_duration_create = min(min_duration_create, tok - tik)
        size = r.get[1, Int]()
        let bytes = r.get[0, DTypePointer[DType.uint8]]()
        var read_duration = 0
        tik = now()
        let vec = FlxValue(bytes, size)
        tok = now()
        read_duration += tok - tik
        for i in range(count):
            tik = now()
            let v = vec[i].get[DType.float16]()
            tok = now()
            read_duration += tok - tik
            if v != nums[i]:
                print("Error at index:", i)
        min_duration_read = min(min_duration_read, read_duration)
        bytes.free()

    print("Constructed a vector of 32K Float16", size, "bytes in", min_duration_create / 1_000_000, "ms")
    print("Read a vector of 32K Float16", size, "bytes in", min_duration_read / 1_000_000, "ms")

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
        construct_one_mio_u64_vec()
        construct_one_mio_u8_vec()
        construct_one_mio_f64_vec()
        construct_one_mio_f16_vec()
        construct_32k_f16_vec()
        construct_one_mio_u64_vec_in_10_x_100000_table()
        construct_one_mio_u64_vec_in_100000_x_10_table()
    except e:
        print("Unexpected error:", e)