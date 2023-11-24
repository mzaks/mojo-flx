from .data_types import ValueType, is_be
from math.bit import bswap

struct FlxValue:
    var _bytes: DTypePointer[DType.uint8]
    var _byte_width: UInt8
    var _parent_byte_width: UInt8
    var _type: ValueType

    fn __init__(inout self, bytes: DTypePointer[DType.uint8], parent_byte_width: UInt8, packed_type: UInt8):
        self._bytes = bytes
        self._parent_byte_width = parent_byte_width
        self._byte_width = 1 << (packed_type & 3)
        self._type = ValueType(packed_type >> 2)

    fn __init__(inout self, bytes: DTypePointer[DType.uint8], parent_byte_width: UInt8, byte_width: UInt8, type: ValueType):
        self._bytes = bytes
        self._parent_byte_width = parent_byte_width
        self._byte_width = byte_width
        self._type = type

    fn __init__(inout self, bytes: DTypePointer[DType.uint8], length: Int) raises:
        if length < 3:
            raise "Length should be at least 3, was: " + String(length)
        let parent_byte_width = bytes.load(length - 1)
        let packed_type = bytes.load(length - 2)
        let offset = length - parent_byte_width.to_int() - 2
        self._bytes = bytes.offset(offset)
        self._parent_byte_width = parent_byte_width
        self._byte_width = 1 << (packed_type & 3)
        self._type = ValueType(packed_type >> 2)

    fn __moveinit__(inout self, owned other: Self):
        self._bytes = other._bytes
        self._parent_byte_width = other._parent_byte_width
        self._byte_width = other._byte_width
        self._type = other._type

    fn __len__(self) -> Int:
        if self.is_null():
            return 0
        if self.is_vec():
            let p  = jump_to_indirect(self._bytes, self._parent_byte_width)
            return read_uint(p.offset(-self._byte_width.to_int()), self._byte_width) 
                    if not self._type.is_fixed_typed_vector() 
                    else self._type.fixed_typed_vector_element_size()
        if self._type == ValueType.String or self.is_blob() or self.is_map():
            let p = jump_to_indirect(self._bytes, self._parent_byte_width)
            return read_uint(p.offset(-self._byte_width.to_int()), self._byte_width)
        if self._type == ValueType.Key:
            let p = jump_to_indirect(self._bytes, self._parent_byte_width)
            var size = 0
            while p.offset(size).load() != 0:
                size += 1
        return 1

    fn is_null(self) -> Bool:
        return self._type == ValueType.Null
    
    fn is_a[D: DType](self) -> Bool:
        return self._type == ValueType.of[D]()

    fn is_map(self) -> Bool:
        return self._type == ValueType.Map

    fn is_vec(self) -> Bool:
        return self._type.is_a_vector()

    fn is_string(self) -> Bool:
        return self._type == ValueType.String or self._type == ValueType.Key

    fn is_blob(self) -> Bool:
        return self._type == ValueType.Blob

    fn is_int(self) -> Bool:
        return self._type == ValueType.Int 
            or self._type == ValueType.UInt 
            or self._type == ValueType.IndirectInt 
            or self._type == ValueType.IndirectUInt

    fn is_float(self) -> Bool:
        return self._type == ValueType.Float
            or self._type == ValueType.IndirectFloat

    fn is_bool(self) -> Bool:
        return self._type == ValueType.Bool
    
    fn get[D: DType](self) raises -> SIMD[D, 1]:
        if self._type != ValueType.of[D]():
            raise "Value is not of type " + D.__str__() + " type id: " + String(self._type.value)
        if sizeof[D]() != self._byte_width.to_int():
            raise "Value byte width is " + String(self._byte_width) + " which does not conform with " + D.__str__()
        @parameter
        if is_be:
            return bswap(self._bytes.bitcast[D]().load())
        else:    
            return self._bytes.bitcast[D]().load()

    fn int(self) raises -> Int:
        if self._type == ValueType.Int:
            return read_int(self._bytes, self._byte_width)
        if self._type == ValueType.UInt:
            return read_uint(self._bytes, self._byte_width)
        if self._type == ValueType.IndirectInt:
            let p = jump_to_indirect(self._bytes, self._parent_byte_width)
            return read_int(p, self._byte_width)
        if self._type == ValueType.IndirectUInt:
            let p = jump_to_indirect(self._bytes, self._parent_byte_width)
            return read_uint(p, self._byte_width)
        raise "Type is not an int or uint, type id: " + String(self._type.value)

    fn float(self) raises -> Float64:
        if self._type == ValueType.Float:
            return read_float(self._bytes, self._byte_width)
        if self._type == ValueType.IndirectFloat:
            let p = jump_to_indirect(self._bytes, self._parent_byte_width)
            return read_float(p, self._byte_width)
        raise "Type is not a float, type id: " + String(self._type.value)

    fn string(self) raises -> String:
        if self._type == ValueType.String:
            let p = jump_to_indirect(self._bytes, self._parent_byte_width)
            var size = read_uint(p.offset(-self._byte_width.to_int()), self._byte_width)
            var size_width = self._byte_width
            while p.offset(size).load() != 0:
                size_width <<= 1
                size = read_uint(p.offset(-size_width.to_int()), size_width)
            let p1 = Pointer[Int8].alloc(size + 1)
            memcpy(p1, p.bitcast[DType.int8](), size + 1)
            return String(p1, size + 1)
        if self._type == ValueType.Key:
            let p = jump_to_indirect(self._bytes, self._parent_byte_width)
            var size = 0
            while p.offset(size).load() != 0:
                size += 1
            let p1 = Pointer[Int8].alloc(size + 1)
            memcpy(p1, p.bitcast[DType.int8](), size + 1)
            return String(p1, size + 1)
        raise "Type is not convertable to string, type id: " + String(self._type.value)

    fn blob(self) raises -> (DTypePointer[DType.uint8], Int):
        if not self.is_blob():
            raise "Type is not blob, type id: " + String(self._type.value)
        let p = jump_to_indirect(self._bytes, self._parent_byte_width)
        let size = read_uint(p.offset(-self._byte_width.to_int()), self._byte_width)
        return (p, size)

    fn vec(self) raises -> FlxVecValue:
        if not self._type.is_a_vector():
            raise "Value is not a vector. Type id: " + String(self._type.value)
        let p  = jump_to_indirect(self._bytes, self._parent_byte_width)
        let size = read_uint(p.offset(-self._byte_width.to_int()), self._byte_width) 
                    if not self._type.is_fixed_typed_vector() 
                    else self._type.fixed_typed_vector_element_size()
        return FlxVecValue(p, self._byte_width, self._type, size)

    fn map(self) raises -> FlxMapValue:
        if self._type != ValueType.Map:
            raise "Value is not a map. Type id: " + String(self._type.value)
        let p  = jump_to_indirect(self._bytes, self._parent_byte_width)
        let size = read_uint(p.offset(-self._byte_width.to_int()), self._byte_width)
        return FlxMapValue(p, self._byte_width, size)

    fn has_key(self, key: String) raises -> Bool:
        if not self.is_map():
            return False
        return self.map().key_index(key) >= 0

    fn __getitem__(self, index: Int) raises -> FlxValue:
        return self.vec()[index]

    fn __getitem__(self, key: String) raises -> FlxValue:
        return self.map()[key]


struct FlxVecValue:
    var _bytes: DTypePointer[DType.uint8]
    var _byte_width: UInt8
    var _type: ValueType
    var _length: Int

    fn __init__(inout self, bytes: DTypePointer[DType.uint8], byte_width: UInt8, type: ValueType, length: Int):
        self._bytes = bytes
        self._byte_width = byte_width
        self._type = type
        self._length = length
    
    fn __len__(self) -> Int:
        return self._length

    fn __getitem__(self, index: Int) raises -> FlxValue:
        if index < 0 or index >= self._length:
            raise "Bad index: " + String(index) + ". Lenght: " + String(self._length)
        if self._type.is_typed_vector():
            return FlxValue(
                self._bytes.offset(index * self._byte_width.to_int()),
                self._byte_width,
                1,
                self._type.typed_vector_element_type()
            )
        if self._type.is_fixed_typed_vector():
            return FlxValue(
                self._bytes.offset(index * self._byte_width.to_int()),
                self._byte_width,
                1,
                self._type.fixed_typed_vector_element_type()
            )
        if self._type == ValueType.Vector:
            let packed_type = self._bytes.offset(self._length * self._byte_width.to_int() + index).load()
            return FlxValue(
                self._bytes.offset(index * self._byte_width.to_int()),
                self._byte_width,
                packed_type
            )
        raise "Is not an expected vector type. Type id: " + String(self._type.value)

struct FlxMapValue:
    var _bytes: DTypePointer[DType.uint8]
    var _byte_width: UInt8
    var _length: Int

    fn __init__(inout self, bytes: DTypePointer[DType.uint8], byte_width: UInt8, length: Int):
        self._bytes = bytes
        self._byte_width = byte_width
        self._length = length

    fn __len__(self) -> Int:
        return self._length

    fn __getitem__(self, key: String) raises -> FlxValue:
        let index = self.key_index(key)
        if index < 0:
            raise "Key " + key + " could not be found"
        return self.values()[index]

    fn keys(self) -> FlxVecValue:
        let p1 = self._bytes.offset(self._byte_width.to_int() * -3)
        let p2 = jump_to_indirect(p1, self._byte_width)
        let byte_width = read_uint(p1.offset(self._byte_width.to_int()), self._byte_width)
        return FlxVecValue(p2, byte_width, ValueType.VectorKey, self._length)
    
    fn values(self) -> FlxVecValue:
        return FlxVecValue(self._bytes, self._byte_width, ValueType.Vector, self._length)

    fn key_index(self, key: String) raises -> Int:
        let a = DTypePointer[DType.int8](key._buffer.data).bitcast[DType.uint8]()
        let keys = self.keys()
        var low = 0
        var high = self._length - 1
        while low <= high:
            let mid = (low + high) >> 1
            let mid_key = keys[mid]
            let b = jump_to_indirect(mid_key._bytes, mid_key._parent_byte_width)
            let diff = cmp(a, b, len(key) + 1)
            if diff == 0:
                return mid
            if diff < 0:
                high = mid - 1
            else:
                low = mid + 1
        return -1


fn jump_to_indirect(bytes: DTypePointer[DType.uint8], byte_width: UInt8) -> DTypePointer[DType.uint8]:
    return bytes.offset(-read_uint(bytes, byte_width))

fn read_uint(bytes: DTypePointer[DType.uint8], byte_width: UInt8) -> Int:
    if byte_width < 4:
        if byte_width == 1:
            return bytes.load().to_int()
        else:
            @parameter
            if is_be:
                return bswap(bytes.bitcast[DType.uint16]().load()).to_int()
            else:
                return bytes.bitcast[DType.uint16]().load().to_int()
    else:
        if byte_width == 4:
            @parameter
            if is_be:
                return bswap(bytes.bitcast[DType.uint32]().load()).to_int()
            else:
                return bytes.bitcast[DType.uint32]().load().to_int()
        else:
            @parameter
            if is_be:
                return bswap(bytes.bitcast[DType.uint64]().load()).to_int()
            else:
                return bytes.bitcast[DType.uint64]().load().to_int()

fn read_int(bytes: DTypePointer[DType.uint8], byte_width: UInt8) -> Int:
    if byte_width < 4:
        if byte_width == 1:
            return bytes.bitcast[DType.int8]().load().to_int()
        else:
            @parameter
            if is_be:
                return bswap(bytes.bitcast[DType.int16]().load()).to_int()
            else:
                return bytes.bitcast[DType.int16]().load().to_int()
    else:
        if byte_width == 4:
            @parameter
            if is_be:
                return bswap(bytes.bitcast[DType.int32]().load()).to_int()
            else:
                return bytes.bitcast[DType.int32]().load().to_int()
        else:
            @parameter
            if is_be:
                return bswap(bytes.bitcast[DType.int64]().load()).to_int()
            else:
                return bytes.bitcast[DType.int64]().load().to_int()

fn read_float(bytes: DTypePointer[DType.uint8], byte_width: UInt8) raises -> Float64:
    if byte_width == 8:
        @parameter
        if is_be:
            return bswap(bytes.bitcast[DType.float64]().load())
        else:
            return bytes.bitcast[DType.float64]().load()
    if byte_width == 4:
        @parameter
        if is_be:
            return bswap(bytes.bitcast[DType.float32]().load()).cast[DType.float64]()
        else:
            return bytes.bitcast[DType.float32]().load().cast[DType.float64]()
    if byte_width == 2:
        @parameter
        if is_be:
            return bswap(bytes.bitcast[DType.float16]().load()).cast[DType.float64]()
        else:
            return bytes.bitcast[DType.float16]().load().cast[DType.float64]()
    raise "Unexpected byte width: " + String(byte_width)

fn cmp(a: DTypePointer[DType.uint8], b: DTypePointer[DType.uint8], length: Int) -> Int:
    for i in range(length):
        let diff = a.load(i).to_int() - b.load(i).to_int()
        if diff != 0:
            return diff
    return 0
