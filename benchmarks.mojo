from time import now
from math.limit import max_finite, min_finite
from math import min
from random import random_ui64, random_float64, random_si64
from flx import *

fn construct_and_read_vec[count: Int, DW: DType, DR: DType = DW]() raises:
    let nums = DTypePointer[DW].alloc(count)
    for i in range(count):
        @parameter
        if DW == DType.uint8 or DW == DType.uint16 or DW == DType.uint32 or DW == DType.uint64:
            nums[i] = (random_ui64(0, 1 << 63).cast[DW]())
        elif DW == DType.float16 or DW == DType.float32 or DW == DType.float64:
            nums[i] = (random_float64().cast[DW]())
        else:
            nums[i] = (random_si64(min_finite[DType.int64](), max_finite[DType.int64]()).cast[DW]())
    var size = 0
    var min_duration_create = max_finite[DType.int64]().to_int()
    var min_duration_read = max_finite[DType.int64]().to_int()
    for _ in range(20):
        var tik = now()
        let r = flx[DW](nums, count)
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
            let v = vec[i].get[DR]()
            tok = now()
            read_duration += tok - tik
            if v != nums[i].cast[DR]():
                print("Error at index:", i)
        bytes.free()
        min_duration_read = min(min_duration_read, read_duration)

    print("Constructed a vector of", count, DW, ",",  size, "bytes in", min_duration_create / 1_000_000, "ms")
    print("Read a vector of", count, DW, ",",  size, "bytes in", min_duration_read / 1_000_000, "ms")

fn construct_and_read_table[columns: Int, rows: Int, DW: DType, DR: DType = DW]() raises:
    let counts = columns * rows
    var nums = DynamicVector[SIMD[DW, 1]](capacity=counts)
    for _ in range(counts):
        @parameter
        if DW == DType.uint8 or DW == DType.uint16 or DW == DType.uint32 or DW == DType.uint64:
            nums.push_back(random_ui64(0, 1 << 63).cast[DW]())
        elif DW == DType.float16 or DW == DType.float32 or DW == DType.float64:
            nums.push_back(random_float64().cast[DW]())
        else:
            nums.push_back(random_si64(min_finite[DType.int64](), max_finite[DType.int64]()).cast[DW]())
    var size = 0
    var min_duration_create = max_finite[DType.int64]().to_int()
    var min_duration_read = max_finite[DType.int64]().to_int()
    for _ in range(20):
        var tik = now()
        var df = FlxVec()
        for i in range(rows):
            var row = df^.vec()
            for j in range(columns):
                row = row^.add[DW](nums[j + i * columns])
            df = row^.up_to_vec()
        let r = df^.finish()
        var tok = now()
        min_duration_create = min(min_duration_create, tok - tik)
        size = r.get[1, Int]()
        let bytes = r.get[0, DTypePointer[DType.uint8]]()
        tik = now()
        let vec = FlxValue(bytes, size)
        tok = now()
        var read_duration = tok - tik
        for i in range(rows):
            for j in range(columns):
                tik = now()
                let v = vec[i][j].get[DR]()
                tok = now()
                read_duration += tok - tik
                if v != nums[j + i * columns].cast[DR]():
                    print("Error at row:", i, "column:", j)
        bytes.free()
        min_duration_read = min(min_duration_read, read_duration)

    print("Constructed a table", "rows:", rows, "columns:", columns, DW, ",", size, "bytes in", min_duration_create / 1_000_000, "ms")
    print("Read a table", "rows:", rows, "columns:", columns, DW, ",", size, "bytes in", min_duration_read / 1_000_000, "ms")


fn main():
    try:
        construct_and_read_vec[1_000_000, DType.uint64]()
        construct_and_read_vec[1_000_000, DType.uint32]()
        construct_and_read_vec[2_000_000, DType.uint32]()
        construct_and_read_vec[1_000_000, DType.uint16, DType.uint32]()
        construct_and_read_vec[2_000_000, DType.uint16, DType.uint32]()
        construct_and_read_vec[1_000_000, DType.uint8, DType.uint32]()
        construct_and_read_vec[2_000_000, DType.uint8, DType.uint32]()
        construct_and_read_vec[4_000_000, DType.uint8, DType.uint32]()
        construct_and_read_vec[1_000_000, DType.int64]()
        construct_and_read_vec[1_000_000, DType.int32]()
        construct_and_read_vec[1_000_000, DType.int16, DType.int32]()
        construct_and_read_vec[1_000_000, DType.int8, DType.int32]()
        construct_and_read_vec[1_000_000, DType.float64]()
        construct_and_read_vec[1_000_000, DType.float32]()
        construct_and_read_vec[1_000_000, DType.float16, DType.float32]()
        construct_and_read_vec[32_000, DType.float16]()
        construct_and_read_vec[16_000, DType.float16]()
        construct_and_read_table[10, 100_000, DType.uint64]()
        construct_and_read_table[100_000, 10, DType.uint64]()
        construct_and_read_table[10, 100_000, DType.float16]()
        construct_and_read_table[100_000, 10, DType.float16, DType.float32]()
    except e:
        print("Unexpected error:", e)
