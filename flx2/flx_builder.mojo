from .flx_buffer import FlxBuffer


struct FlxMap[
    dedup_string: Bool = True,
    dedup_key: Bool = True,
    dedup_keys_vec: Bool = True,
](Movable):
    var buffer: FlxBuffer[dedup_string, dedup_key, dedup_keys_vec]
    alias _vec_type = FlxVec[dedup_string, dedup_key, dedup_keys_vec]

    fn __init__(
        inout self,
        owned buffer: FlxBuffer[dedup_string, dedup_key, dedup_keys_vec],
    ):
        self.buffer = buffer^

    fn __init__(inout self):
        self.buffer = FlxBuffer[dedup_string, dedup_key, dedup_keys_vec]()
        self.buffer.start_map()

    fn __moveinit__(inout self, owned other: Self):
        self.buffer = other.buffer^

    # fn __init__(inout self, key: String, owned other: Self._vec_type):
    #     self = Self()
    #     self.buffer.key(key)
    #     self.buffer.add(other.buffer^)

    # fn add(inout self, key: String, values: Self._vec_type):
    #     self.buffer.key(key)
    #     self.buffer.add(values)

    fn add(owned self, key: String, *values: Int) -> Self:
        self.buffer.key(key)
        for i in range(len(values)):
            self.buffer.add(values[i])
        return self^

    fn add[D: DType](owned self, key: String, *values: Scalar[D]) -> Self:
        self.buffer.key(key)
        for i in range(len(values)):
            self.buffer.add(values[i])
        return self^

    fn add_indirect[
        D: DType
    ](owned self, key: String, *values: Scalar[D]) -> Self:
        self.buffer.key(key)
        for i in range(len(values)):
            self.buffer.add_indirect(values[i])
        return self^

    fn add_referenced(owned self, key: String, ref_key: String) raises -> Self:
        self.buffer.key(key)
        self.buffer.add_referenced(ref_key)
        return self^

    fn add(owned self, key: String, *values: String) -> Self:
        self.buffer.key(key)
        for i in range(len(values)):
            self.buffer.add(values[i])
        return self^

    fn add(
        owned self, key: String, value: DTypePointer[DType.uint8], length: Int
    ) -> Self:
        self.buffer.key(key)
        self.buffer.blob(value, length)
        return self^

    fn map(owned self, key: String) -> Self:
        self.buffer.key(key)
        self.buffer.start_map()
        return self^

    fn vec(owned self, key: String) -> Self._vec_type:
        var buffer = self.buffer^
        buffer.key(key)
        buffer.start_vector()
        return Self._vec_type(buffer^)

    fn to_map(owned self, ref_key: String = "") raises -> Self:
        var depth = len(self.buffer._stack_is_vector)
        if depth < 2:
            raise "This map is not nested, please call finish instead"
        self.buffer.end(ref_key)
        if self.buffer._stack_is_vector[depth - 2]:
            raise "This map is nested in a vector, please call to_vec instead"
        return self^

    fn to_vec(owned self, ref_key: String = "") raises -> Self._vec_type:
        var buffer = self.buffer^
        var depth = len(buffer._stack_is_vector)
        if depth < 2:
            raise "This map is not nested, please call finish instead"
        buffer.end(ref_key)
        if not buffer._stack_is_vector[depth - 2]:
            raise "This map is nested in a map, please call to_map instead"
        return Self._vec_type(buffer^)

    fn finish(owned self) raises -> (DTypePointer[DType.uint8], Int):
        return self.buffer._finish()


struct FlxVec[
    dedup_string: Bool = True,
    dedup_key: Bool = True,
    dedup_keys_vec: Bool = True,
](Movable):
    var buffer: FlxBuffer[dedup_string, dedup_key, dedup_keys_vec]

    fn __init__(
        inout self,
        owned buffer: FlxBuffer[dedup_string, dedup_key, dedup_keys_vec],
    ):
        self.buffer = buffer^

    fn __init__(inout self):
        self.buffer = FlxBuffer[dedup_string, dedup_key, dedup_keys_vec]()
        self.buffer.start_vector()

    fn __moveinit__(inout self, owned other: Self):
        self.buffer = other.buffer^

    fn add(owned self, value: Int) -> Self:
        self.buffer.add(value)
        return self^

    fn add[D: DType](owned self, value: SIMD[D, 1]) -> Self:
        self.buffer.add(value)
        return self^

    fn add_indirect[D: DType](owned self, value: SIMD[D, 1]) -> Self:
        self.buffer.add_indirect(value)
        return self^

    fn add_referenced(owned self, ref_key: String) raises -> Self:
        self.buffer.add_referenced(ref_key)
        return self^

    fn add(owned self, value: String) -> Self:
        self.buffer.add(value)
        return self^

    fn add(owned self, value: DTypePointer[DType.uint8], length: Int) -> Self:
        self.buffer.blob(value, length)
        return self^

    fn map(owned self) -> FlxMap[dedup_string, dedup_key, dedup_keys_vec]:
        # TODO: investigate ownership transfer instead of copy
        var buffer = self.buffer
        buffer.start_map()
        return FlxMap[dedup_string, dedup_key, dedup_keys_vec](buffer^)

    fn vec(owned self) -> Self:
        self.buffer.start_vector()
        return self^

    fn null(owned self) -> Self:
        self.buffer.add_null()
        return self^

    fn to_map(
        owned self, ref_key: String = ""
    ) raises -> FlxMap[dedup_string, dedup_key, dedup_keys_vec]:
        var buffer = self.buffer^
        var depth = len(buffer._stack_is_vector)
        if depth < 2:
            raise "This vec is not nested, please call finish instead"
        buffer.end(ref_key)
        if buffer._stack_is_vector[depth - 2]:
            raise "This vec is nested in a vec, please call to_vec instead"
        return FlxMap[dedup_string, dedup_key, dedup_keys_vec](buffer^)

    fn to_vec(owned self, ref_key: String = "") raises -> Self:
        var depth = len(self.buffer._stack_is_vector)
        if depth < 2:
            raise "This vec is not nested, please call finish instead"
        self.buffer.end(ref_key)
        if not self.buffer._stack_is_vector[depth - 2]:
            raise "This vec is nested in a map, please call to_map instead"
        return self^

    fn finish(owned self) raises -> (DTypePointer[DType.uint8], Int):
        return self.buffer._finish()
