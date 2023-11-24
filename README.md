# Mojo-Flx is a FlexBuffer implementation in Mojo

FlexBuffers is a data serialisation format designed by [Wouter van Oortmerssen](https://strlen.com/) as part of the [FlatBuffers](https://flatbuffers.dev/) project.
The format can represent data objects consisting of attribute–value maps and arrays (same as JSON), for more information please consult the supported value types paragraph. 

FlexBuffers format supports random value access and does not need parsing (like JSON, YAML, TOML and other text based formats) nor unpacking (like MsgPack, CBOR and other compact binary formats). Moreover the data in the buffer is aligned and can be read without unnecessary mem copies.

## Supported value types
FlexBuffers support numeric values of type Int, UInt and Float, which are 1, 2, 4 and 8 bytes wide.
The format allows null value (None), boolean values (True / False), string values and a blob (byte string) values. All mentioned values can be stored in a vector or as values in a map. It is allowed to nest maps and vectors without any restriction.

A vector stores its size and allows random value access based on provided index. This works even with heterogeneous types.

A map is based on two vectors, a vector of sorted string keys and a vector of heterogeneous values. Random value acceess is based on a binary search of the given key in the key vector and reading of the value from values vector based on the found key index. This allows value access without unpacking and transient memory allocations.

## Converting Mojo values into a FlexBuffer

By using the convenience function `flx` we can construct a FlexBuffers from a `String`, `Int` and a `SIMD[DType, 1]` value. Calling the `flx` function with a `DTypePointer` and a length (of type Int) will construct a vector. `flx_blob` function produces a FlexBuffer from a `DTypePointer[DType.uint8]` and a length. `flx_null` produces a FlexBuffer representing the `null` value.

Examples:
```
from flx import flx, flx_blob, flx_null

let b0 = flx_null()
let b1 = flx(25)
let b2 = flx("hello world")
let b3 = flx[DType.bool](True)
let b4 = flx[DType.float32](43.1)

var blob = DynamicVector[UInt8](100)
for i in range(100):
    blob.push_back(5)
let b5 = flx_blob(blob.data, len(blob))

var v = DynamicVector[UInt16](1000)
for i in range(1000):
    v.push_back(i) 
let b6 = flx(DTypePointer[DType.uint16](v.data), len(v))
```

### Construct Vectors and Maps
In order to construct vectors and maps user need to use `FlxVec` and `FlxMap` structs.

Below you can find an example, where we produce a column based dataframe with named columns as a map of vectors:

```
from flx import FlxMap

try:
    let df_cb = FlxMap()
                .vec("name")
                    .add("Maxim")
                    .add("Leo")
                    .add("Alex")
                    .up_to_map()
                .vec("age")
                    .add(42)
                    .add(43)
                    .add(28)
                    .up_to_map()
                .vec("friendly")
                    .add[DType.bool](False)
                    .add[DType.bool](True)
                    .add[DType.bool](True)
                .finish()
except e:
    print("Unexpected error", e)        
```

We can construct the same dataframe but row based as a vector of maps:

```
from flx import FlxVec

try:
    let df_rb = FlxVec()
                .map()
                    .add("name", "Maxim")
                    .add("age", 42)
                    .add[DType.bool]("friendly", False)
                    .up_to_vec()
                .map()
                    .add("name", "Leo")
                    .add("age", 43)
                    .add[DType.bool]("friendly", True)
                    .up_to_vec()
                .map()
                    .add("name", "Alex")
                    .add("age", 28)
                    .add[DType.bool]("friendly", True)
                .finish()
except e:
    print("Unexpected error", e)        
```

## Reading values from FlexBuffers
Given a DTypePointer[DType.uint8] which points to the start of the FlexBuffer and the length, we can instantiate a `FlxValue` struct which can be used to access values inside of the buffer. 

User can inspect the type of the `FlxValue` by calling one of the following methods:
- `is_nul`
- `is_a[D: DType]`
- `is_map`
- `is_vec`
- `is_string`
- `is_blob`
- `is_int`
- `is_float`
- `is_bool`

Users can materialise the value with one of the following methods:
- `get[D: DType](self) raises -> SIMD[D, 1]`
- `int(self) raises -> Int`
- `float(self) raises -> Float64`
- `string(self) raises -> String`
- `blob(self) raises -> (DTypePointer[DType.uint8], Int)`

Bellow you can find an example of how to read values from column based dataframe descirbed above:
```
let value = FlxValue(df_cb)
print(value["name"][0].string())                # Maxim
print(value["age"][0].string())                 # 42
print(value["friendly"][0].get[DType.bool]())   # False
```
And here is a snippet for reading a row based dataframe:
```
let value = FlxValue(df_rb)
print(value[0]["name"].string())                # Maxim
print(value[0]["age"].string())                 # 42
print(value[0]["friendly"].get[DType.bool]())   # False
```

> Note: Current implementation of FlxValue does not contain boundary checks, hence can be considered unsafe for reading potentially malicious buffers. We expect to implement a safe variant of the FlxValue in the future.

--- 
The project is in active development, contributions are welcome.