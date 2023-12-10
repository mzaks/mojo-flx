from memory import memset_zero, memcpy
from .data_types import StackValue

@value
struct Key(CollectionElement):
    var pointer: DTypePointer[DType.uint8]
    var size: Int

    fn __init__(inout self, pointer: DTypePointer[DType.uint8], size: Int):
        let cp = DTypePointer[DType.uint8].alloc(size)
        memcpy(cp, pointer, size)
        self.pointer = cp
        self.size = size

# alias Key = (DTypePointer[DType.uint8], Int)
alias Keys = DynamicVector[Key]
alias Values = DynamicVector[StackValue]

struct Cache(Movable, Copyable):
    var keys: Keys
    var values: Values
    var key_map: DTypePointer[DType.uint32]
    var count: Int
    var capacity: Int

    fn __init__(inout self):
        self.count = 0
        self.capacity = 16
        self.keys = Keys(self.capacity)
        self.values = Values(self.capacity)
        self.key_map = DTypePointer[DType.uint32].alloc(self.capacity)
        memset_zero(self.key_map, self.capacity)
    
    fn __moveinit__(inout self, owned other: Self):
        self.count = other.count^
        self.capacity = other.capacity^
        self.values = other.values^
        self.key_map = other.key_map^
        self.keys = other.keys^

    fn __copyinit__(inout self, other: Self):
        self.count = other.count
        self.capacity = other.capacity
        let keys_count = len(other.keys)
        
        self.key_map = DTypePointer[DType.uint32].alloc(self.capacity)
        memcpy(self.key_map, other.key_map, self.capacity)
        self.keys = Keys(keys_count)
        self.values = Values(keys_count)
        for i in range(keys_count):
            let key = other.keys[i]
            let p = key.pointer
            let size = key.size
            let cp = DTypePointer[DType.uint8].alloc(size)
            memcpy(cp, p, size)
            let new_key = Key(cp, size)
            self.keys.push_back(new_key)
            self.values.push_back(other.values[i])

    fn __del__(owned self):
        self.key_map.free()
        for i in range(len(self.keys)):
            let key = self.keys[i]
            key.pointer.free()

    fn put(inout self, key: Key, value: StackValue):
        if self.count / self.capacity >= 0.8:
            self._rehash()
        self._put(key, value, -1)
    
    fn _rehash(inout self):
        let old_mask_capacity = self.capacity >> 3
        self.key_map.free()
        self.capacity <<= 1
        let mask_capacity = self.capacity >> 3
        self.key_map = DTypePointer[DType.uint32].alloc(self.capacity)
        memset_zero(self.key_map, self.capacity)
        
        for i in range(len(self.keys)):
            self._put(self.keys[i], self.values[i], i + 1)

    fn _put(inout self, key: Key, value: StackValue, rehash_index: Int):
        let key_hash = self._hash(key)
        let modulo_mask = self.capacity - 1
        var key_map_index = (key_hash & modulo_mask).to_int()
        while True:
            let key_index = self.key_map.offset(key_map_index).load().to_int()
            if key_index == 0:
                let new_key_index: Int
                if rehash_index == -1:
                    self.keys.push_back(key)
                    self.values.push_back(value)
                    self.count += 1
                    new_key_index = len(self.keys)
                else:
                    new_key_index = rehash_index
                self.key_map.offset(key_map_index).store(UInt32(new_key_index))
                return

            let other_key = self.keys[key_index - 1]
            if self._eq(other_key, key):
                self.values[key_index - 1] = value
                return
            
            key_map_index = (key_map_index + 1) & modulo_mask

    fn _hash(self, key: Key) -> UInt32:
        var hash: UInt32 = 0
        var bytes = key.pointer
        var count = key.size
        while count >= 4:
            let c = bytes.bitcast[DType.uint32]().load()
            hash = _hash_word32(hash, c)
            bytes = bytes.offset(4)
            count -= 4
        if count >= 2:
            let c = bytes.bitcast[DType.uint16]().load().cast[DType.uint32]()
            hash = _hash_word32(hash, c)
            bytes = bytes.offset(2)
            count -= 2
        if count > 0:
            let c = bytes.load().cast[DType.uint32]()
            hash = _hash_word32(hash, c)
        return hash

    fn _eq(self, a: Key, b: Key) -> Bool:
        var bytes_a = a.pointer
        var bytes_b = b.pointer
        let count_a = a.size
        let count_b = b.size
        if count_a != count_b:
            return False
        var count = count_a
        while count >= 4:
            if bytes_a.bitcast[DType.uint32]().load() != bytes_b.bitcast[DType.uint32]().load():
                return False
            bytes_a = bytes_a.offset(4)
            bytes_b = bytes_b.offset(4)
            count -= 4
        if count >= 2:
            if bytes_a.bitcast[DType.uint16]().load() != bytes_b.bitcast[DType.uint16]().load():
                return False
            bytes_a = bytes_a.offset(2)
            bytes_b = bytes_b.offset(2)
            count -= 2
        if count > 0:
            return bytes_a.load() == bytes_b.load()
        return True

    fn get(self, key: Key, default: StackValue) -> StackValue:
        let key_hash = self._hash(key)
        let modulo_mask = self.capacity - 1
        var key_map_index = (key_hash & modulo_mask).to_int()
        while True:
            let key_index = self.key_map.offset(key_map_index).load().to_int()
            if key_index == 0:
                return default
            let other_key = self.keys[key_index - 1]
            if self._eq(other_key, key):
                return self.values[key_index - 1]
            key_map_index = (key_map_index + 1) & modulo_mask

from math.math import rotate_bits_left

alias ROTATE = 5
alias SEED32 = 0x9e_37_79_b9

@always_inline
fn _hash_word32(value: UInt32, word: UInt32) -> UInt32:
    return (rotate_bits_left[ROTATE](value) ^ word) * SEED32

fn _key_string(key: Key) -> String:
    let bytes = key.pointer
    let count = key.size
    var result: String = ""
    for i in range(count):
        result += chr(bytes.load(i).to_int())
    return result

fn _key_int_string(key: Key) -> String:
    let bytes = key.pointer
    let count = key.size
    var result: String = ""
    for i in range(count):
        result += String(bytes.load(i).to_int())
    return result
