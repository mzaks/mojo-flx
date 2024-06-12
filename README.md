# Mojo-Flx is a FlexBuffer implementation in Mojo

FlexBuffers is a data serialisation format designed by [Wouter van Oortmerssen](https://strlen.com/) as part of the [FlatBuffers](https://flatbuffers.dev/) project.
The format can represent data objects consisting of key/value maps and vectors (same as JSON), for more information please consult the supported value types paragraph. 

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

var b0 = flx_null()
var b1 = flx(25)
var b2 = flx("hello world")
var b3 = flx[DType.bool](True)
var b4 = flx[DType.float32](43.1)

var blob = DynamicVector[UInt8](100)
for i in range(100):
    blob.push_back(5)
var b5 = flx_blob(blob.data, len(blob))

var v = DynamicVector[UInt16](1000)
for i in range(1000):
    v.push_back(i) 
var b6 = flx(DTypePointer[DType.uint16](v.data), len(v))
```

### Construct Vectors and Maps
In order to construct vectors and maps user need to use `FlxVec` and `FlxMap` structs.

Below you can find an example, where we produce a column based dataframe with named columns as a map of vectors:

```
from flx import FlxMap

try:
    var df_cb = FlxMap()
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
    var df_rb = FlxVec()
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
- `is_null`
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
var value = FlxValue(df_cb)
print(value["name"][0].string())                # Maxim
print(value["age"][0].string())                 # 42
print(value["friendly"][0].get[DType.bool]())   # False
```
And here is a snippet for reading a row based dataframe:
```
var value = FlxValue(df_rb)
print(value[0]["name"].string())                # Maxim
print(value[0]["age"].string())                 # 42
print(value[0]["friendly"].get[DType.bool]())   # False
```

> Note: Current implementation of FlxValue does not contain boundary checks, hence can be considered unsafe for reading potentially malicious buffers. We expect to implement a safe variant of the FlxValue in the future.

## Anatomy of the FlexBuffers format
This section is a deep dive into the binary format. It is intended for folks who are interested in the details and who wants to understand the strengths and weaknesses of the format.

FlexBuffers is a self describing binary data serialisation format. Values are stored with the type information, which is a packed uint8 value. First two bits of the value contain the value width encoded as:
- 0b00 is 1 byte
- 0b01 is 2 bytes
- 0b10 is 4 bytes
- 0b11 is 8 bytes

the other 6 bits represent the type of which there are 27 (see `ValueType` struct for more details).

Values of type Null, Bool, Int, UInt and Float are considered inline types.

### Examples of FlexBuffers containing just one inline type
`flx_null()` results in `[0, 0, 1]` binary string.

`flx(1)` results in `[1, 4, 1]`

`flx(-1)` results in `[255, 4, 1]`

`flx(200)` results in `[200, 0, 5, 2]`, where `flx[DType.uint8](200)` results in `[200, 8, 1]`

`flx[DType.float16](2.5)` results in `[0, 65, 13, 2]` 

`flx[DType.float32](2.5)` results in `[0, 0, 32, 64, 14, 4]`

`flx[DType.float64](2.5)` results in `[0, 0, 0, 0, 0, 0, 4, 64, 15, 8]`

As we can see the binary representation of the inline value is stored first, following by the packed type information and ending with the byte width which is represented as 1, 2, 4 and 8. For inline types the byte width value is redundant as we already encode same information in the packed type info, but it will be necessary for other more complex types.

> Note: FlexBuffers uses little endian byte ordering

### Storing a string value

FlexBuffers stores string as a zero terminated UTF-8 encoded byte array with a prepanded byte length and a pointer to the start of the string.

`flx("Hello 🔥")` results in `[10, 72, 101, 108, 108, 111, 32, 240, 159, 148, 165, 0, 11, 20, 1]`

The first byte represents the length (10 bytes) of the UTF-8 encoded "Hello 🔥". Then comes the actual 10 bytes string and a `0` byte as a string terminator. `11` is the pointer (number of bytes we need to jump to the left to find the start of the string), `20` is the packed type of the String and the last byte is the byte width of the string pointer.

Generally it is best to read FlexBuffers byte string from the back, as the meta information (packed type and byte width) of the root value is stored at the end.

You might be wondering why FlexBuffers stores the string indirectly (with a pointer), this is due to the fact that we want to have random value access for vectors and maps. We can only have a random value access for vectors if the vector elements are symetrical (have same width). Strings have a varible length, so they are likely to be asymetrical to each other. We could pad all string in a vector based on the longest, but it would be quite wasteful. Instead we store the strings in the buffers as they come and the vector of strings contains just the pointers to the actual string normalised by the widest pointer in the vector. Moreover becuase the string values in vectors and maps are stored as pointers, we can perform string deduplication (enabled by default in mojo-flx), which means that we store the actual string just once and reference it as different vector or map element.

Before we proceed to vectors, I wanted to mention that there is another way how we can store strings in FlexBuffers. It is possible to store string without the length prefix, this type is called a Key.

```
    try:
        var flxb = flx_buffer.FlxBuffer()
        flxb.key("Hello 🔥")
        var result = flxb^.finish()
    except e:
        print(e)
```

The result is `[72, 101, 108, 108, 111, 32, 240, 159, 148, 165, 0, 11, 16, 1]`

If you compare it with the result for the string type you can see that its almost identical. We are missing the first byte `10` representing the string length. And the second to the last byte, which represents the packed type info, is `16` for Key instead of `20` for String.

Key type is mainly used to represent the keys in the map. The keys in the map are rarely materialised as Strings, hence the length, which is needed to know how much memory needs to be allocated, is omitted. Key type can be considered an internal type, however users are free to use it as regular value type if they like.

> Note: Storing a BLOB (binary string) is very similar to storing string hence I will ommit an in-depth description.

### Storing typed vector

Lets start with a simple exmaple:

`FlxVec().add(5).add(6).add(7).finish()` results in `[3, 5, 6, 7, 3, 44, 1]`

Lets analyse the byte string from the back. 
Last byte `1` is the byte width. 
Second to last byte`44` is `ValueType.VectorInt` packed with `ValueBitWidth.width8`
Third to last byte `3` is the pointer to the start of the vector.
And the first four bytes `3, 5, 6, 7` is the length of the vector and the elements.

Lets take another example where the values of the vector are of the same type, but not of the same byte width:

`FlxVec().add(5).add(600).add(7).finish()` results in `[3, 0, 5, 0, 88, 2, 7, 0, 6, 45, 1]`

The last byte did not change, as it identifies the byte width of the pointer to the vector start, but the packed type info has changed from `44` to `45`, which means it is a `ValueType.VectorInt` packed with `ValueBitWidth.width16`.

We can also see that the size and the elements of the vector are 2 bytes wide. This happened because the vector values need to be symetrical for a random value access to work. It will happen even if we specify the smaller input values to be of `DType.uint8`:

`FlxVec().add[DType.uint8](5).add[DType.uint16](600).add[DType.uint8](7).finish()` results in `[3, 0, 5, 0, 88, 2, 7, 0, 6, 45, 1]`

FlexBuffers will still perform a conversion to a 2 byte wide representation for us. This fact is even more promenent when we store floats:

`FlxVec().add[DType.float16](1.1).add[DType.float32](1.1).add[DType.float64](1.1).finish()`

results in 

`[3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 152, 241, 63, 0, 0, 0, 160, 153, 153, 241, 63, 154, 153, 153, 153, 153, 153, 241, 63, 24, 55, 1, ]`

As the widest vector element needs 8 bytes, all the others will also be converted to 8 byte float numbers. However as we can see the literal `1.1` resulted in 3 different byte strings:

- `0, 0, 0, 0, 0, 152, 241, 63`
- `0, 0, 0, 160, 153, 153, 241, 63`
- `154, 153, 153, 153, 153, 153, 241, 63`

This is due to the fact that the first `1.1` was added with half precision and second with single precision. Then the values where converted to double precision which makes the representation wider, but still propagates the precision error.

> Note: See how we can store different precision float numbers in a more efficient way (inderectly) in storing untyped vector section

A carefull reader might observe another pitfall, when it comes to typed vectors. The width of the vector elements and the width of the vecor length needs to be symetrical. This means that if we add more then `2^16 - 1` elements of `Float16` values to a vector, FlexBuffers will have to upcast those values to `Float32`. This is specifically unfortunate for serialisation performance, when we call `fn flx[D: DType](v: SIMD[D, 1]) -> (DTypePointer[DType.uint8], Int):` function. If the width of the length value is smaller or equal to the width of `D`, we have a super fast serialisation, as we can just memcopy the full content under the DTypePointer, but if it is not the case we need to add value by value and perform the upcasting for every element of the vector. The function does it automatically for us, but it takes significantly more memory and compute time.

#### Storing vector of strings
`VectorKey` and `VectorString` are also considered typed vectors. `VectorKey` is used internally for the vector of keys in a map. `VectorString` can be constructed as following:

`FlxVec().add("maxim").add("alex").add("daria").finish()`

and results in:

`[5, 109, 97, 120, 105, 109, 0, 4, 97, 108, 101, 120, 0, 5, 100, 97, 114, 105, 97, 0, 3, 20, 14, 9, 3, 60, 1]`

If we go through the bytes string we see:
- `5, 109, 97, 120, 105, 109, 0` is "maxim"
- `4, 97, 108, 101, 120, 0` is "alex"
- `5, 100, 97, 114, 105, 97, 0` is "daria"
- `3, 20, 14, 9` is the size of the vector and a list of pointers to the actual strings
- `3, 60, 1` is pointer to the start of the vector, packed type, and byte width of the pointer to the vector

Lets check out another example where we have the string "maxim" twice in the vector:

`FlxVec().add("maxim").add("alex").add("maxim").add("daria").finish()`

results in:

`[5, 109, 97, 120, 105, 109, 0, 4, 97, 108, 101, 120, 0, 5, 100, 97, 114, 105, 97, 0, 4, 20, 14, 22, 10, 4, 60, 1]`

If you compare it with the the byte string for 3 string elements, you can see that this byte string is just one byte longer. This is thanks to the string deduplication. We see that the string "maxim" occures only once in the buffer and the vector part:
- `4, 20, 14, 22, 10` is stating that we have `4` elements, where `20` and `22` point to the "maxim" string (the pointers are number of bytes we need to jump to the left)

In fact we can turn off the string deduplication feature as following:

`FlxVec[dedup_string=False]().add("maxim").add("alex").add("maxim").add("daria").finish()`

which results in 

`5, 109, 97, 120, 105, 109, 0, 4, 97, 108, 101, 120, 0, 5, 109, 97, 120, 105, 109, 0, 5, 100, 97, 114, 105, 97, 0, 4, 27, 21, 16, 10, 4, 60, 1]`

and now we can see that the byte string `5, 109, 97, 120, 105, 109, 0` appears twice in the buffer.

### Storing untyped vector
An untyped vector has a heterogeneous elements.

For example:

`FlxVec().add[DType.int32](1234).add("maxim").add[DType.float16](1.5).add[DType.bool](True).finish()`

results in:

`[5, 109, 97, 120, 105, 109, 0, 0, 4, 0, 0, 0, 210, 4, 0, 0, 15, 0, 0, 0, 0, 0, 192, 63, 1, 0, 0, 0, 6, 20, 13, 104, 20, 42, 1]`

Lets have a quick walkthrough again:
- `5, 109, 97, 120, 105, 109, 0` is the string "maxim"
- `0` is a padding byte, the string before is 7 bytes long, next actual value is 4 bytes long so FlexBuffers adds a padding byte to avoid missaligned reads
- `4, 0, 0, 0` is the length of the vector (4 as UInt32)
- `210, 4, 0, 0` is the Int32 value 1234
- `15, 0, 0, 0` is the pointer to "maxim" string
- `0, 0, 192, 63` is Float16 value 1.5 upcasted to Float32
- `1, 0, 0, 0` is `True` value widened to 4 bytes
- `6, 20, 13, 104` are the packed types for each value: Int, String, Float, Bool, the width part of the type information is not important as the width from the vector type will take precedens
- `20, 42, 1` are pointer to the start of the vector, packed type `ValueType.Vector` + `ValueBitWidth.width32` and the byte width of the vector pointer

We can see in the example above, all values including the length of the vector need to be widened to the widest value which in this case is the 4 byte Int32. There is however a feature in FlexBuffers which allows to mitigate this:

`FlxVec().add_indirect[DType.int32](1234).add("maxim").add_indirect[DType.float16](1.5).add[DType.bool](True).finish()`

results in:

`[210, 4, 0, 0, 5, 109, 97, 120, 105, 109, 0, 0, 0, 62, 4, 15, 11, 5, 1, 26, 20, 33, 104, 8, 40, 1]`

We directly see that this buffer is smaller then the previous one. Lets go through its parts:
- `210, 4, 0, 0` is the `1234` value of type `Int32`, which we stored in the vector indirectly. Indirectly means that we store the value outside of the vector and store a pointer to the value in the vector itself
- `5, 109, 97, 120, 105, 109, 0` is "maxim"
- `0` is the padding byte, same as in previous example
- `0, 62` is the `1.5` value of type `Float16` also stored indirectly
- `4, 15, 11, 5, 1` is the length of the vector, pointer to `1234`, pointer to "maxim", pointer to `1.5` and the `True` value
- `26, 20, 33, 104` are the vector element types, IndirectInt, String, IndirectFloat and Bool
- `8, 40, 1` are the pointer to the vector, packed type `ValueType.Vector` + `ValueBitWidth.width8` and the byte width of the vector pointer

Vector elements in an untyped vector can be of any type, vector and map included. Lets follow a simple example (`[7, [8, 9]]`) to understand how it works:

`FlxVec().add(7).vec().add(8).add(9).finish()`

results in:

`[2, 8, 9, 2, 7, 4, 4, 44, 4, 40, 1]`

- `2, 8, 9` is the inner vector, length is `2`, first element is `8`, second element is `9`
- `2, 7, 4` is the outer vector, length is `2`, first element is `7`, second element is pointer to inner vector which is `4` bytes to the left
- `4, 44` are the packed type information of the first element `Int` and second element `VectorInt`
- `4, 40, 1` is the pointer to the outer vector, packed typed `Vector` + `width8` and the byte width of the pointer 

### Storing a key/value map
FlexBuffers implements a key/value map with two vectors, a vector of keys and an untyped vector for values. The key and value elements are added to the respective vectors at the same time, so when we find the expected key, we use its index to lookup the corresponding value. In order to speedup the lookup, the vectors are sorted based on the key values and the lookup is done through a binary search.

Lets have a look at a simple key/value map example:

`FlxMap().add("a", 7).add("b", 8).finish()`

results in:

`[97, 0, 98, 0, 2, 5, 4, 2, 1, 2, 7, 8, 4, 4, 4, 36, 1]`

- `97, 0` is "a" (as described above a key string is zero terminated but does not carry its length)
- `98, 0` is "b"
- `2, 5, 4` is the keys vector, `2` is length, `5` is pointer to "a", `4` is pointer to "b"
- `2, 1` is the pointer to the kes vector, `2` is the pointer to the keys vector and `1` is the pointer byte width, this will make more sense when we will discusss keys and keys vector deduplication
- `2, 7, 8, 4, 4` is the values vector, `2` is the length, `7` and `8` are the values and `4` and `4` are the packet type informations of the value, which is `Int`
- `4, 36, 1` is the information about the root object, `4` is the poniter to the values vector, `36` is the packed type representation of `ValueType.Map` + `ValueBitWidth.width8` and `1` is the byte width of the pointer

To make the vector sorting a bit more clear lets have a look at an example where we flip the order:

`FlxMap().add("b", 7).add("a", 8).finish()`

results in:

`[98, 0, 97, 0, 2, 3, 6, 2, 1, 2, 8, 7, 4, 4, 4, 36, 1]`

- `98, 0` is "b", it comes before "a" now because we flipped the order of adding the key/values
- `97, 0` is "a"
- `2, 3, 6` is the keys vector where we still have length `2` and the pointers are still pointing to "a" and "b", but this time "a" is only `3` bytes to the left and "b" is `6` bytes to the left, meaning that we don't sort the strings, we sort the pointers to the key strings
- `2, 1` is the pinters to the keys vector, which did not change
- `2, 8, 7, 4, 4` is the values vector, we see that the values where sorted, because they are inline types
- `4, 36, 1` is the information about the root object, which did not change

Now lets talk about nesting maps in vector and key / keys vector deduplication.

Lets consider an example where we have a vector of maps, where map has the same keys:

```
FlxVec()
    .map()
        .add("a", 7)
        .add("b", 8)
        .up_to_vec()
    .map()
        .add("b", 7)
        .add("a", 8)
    .finish()
```

this results in:

`[97, 0, 98, 0, 2, 5, 4, 2, 1, 2, 7, 8, 4, 4, 9, 1, 2, 43, 42, 4, 4, 2, 12, 6, 36, 36, 4, 40, 1]`

- `97, 0` is "a"
- `98, 0` is "b"
- `2, 5, 4` is the keys vector
- `2, 1` is the pointer to the keys vector, for the first map
- `2, 7, 8, 4, 4` is the values vector for the first map, where we have `7` and `8` as values
- `9, 1` is the pointer to the vector for the second map, the keys vector is now `9` bytes to the right
- `2, 43, 42, 4, 4` is the values vector for the second map, where we have `43` and `42` as values
- `2, 12, 6, 36, 36` is the root untyped vector which holds the maps, lenght is `2`, first map is `12` bytes to the left, second map is `6` bytes to the left, the packed typed infomration for the maps is in both cases `36`
- `4, 40, 1` is the information about the root object which is `4` bytes to the left, is an untyped vector and the pointer byte width is 1

As we can see FlexBuffers is able to reuse the same key strings and even the keys vector for both key/value maps. Lets disable the deduplication of the keys vector to see how it will impact the resulting buffer:

```
FlxVec[dedup_keys_vec=False]()
    .map()
        .add("a", 7)
        .add("b", 8)
        .up_to_vec()
    .map()
        .add("b", 7)
        .add("a", 8)
    .finish()
```

results in:

`[97, 0, 98, 0, 2, 5, 4, 2, 1, 2, 7, 8, 4, 4, 2, 15, 14, 2, 1, 2, 43, 42, 4, 4, 2, 15, 6, 36, 36, 4, 40, 1]`

The result is 3 bytes longer:
- `97, 0, 98, 0, 2, 5, 4, 2, 1, 2, 7, 8, 4, 4` is same as in previous result, it encodes the keys "a" and "b" and the first inner map
- `2, 15, 14` is the keys vector for the second map, which points to "a" and "b" keys, which are `15` and `14` bytes to ahead
- `2, 1` is the pointer to the second keys vector
- `2, 43, 42, 4, 4` is the second values vector
- `2, 15, 6, 36, 36` is the root vector
- `4, 40, 1` is the information about the root object

Now we can desiable the deduplication of the keys, by doing that we also disable the keys vector deduplication, because it is imposible to have keys vector deduplication without keys deduplication.

```
FlxVec[dedup_key=False]()
    .map()
        .add("a", 7)
        .add("b", 8)
        .up_to_vec()
    .map()
        .add("b", 7)
        .add("a", 8)
    .finish()
```

results in:

`[97, 0, 98, 0, 2, 5, 4, 2, 1, 2, 7, 8, 4, 4, 98, 0, 97, 0, 2, 3, 6, 2, 1, 2, 43, 42, 4, 4, 2, 19, 6, 36, 36, 4, 40, 1]`

As you might have expected, the result is 4 bytes longer than the one with `dedup_keys_vec=False` and 7 bytes longer when all the deduplication turned on. We can break down the resulting buffer as following:

- `97, 0, 98, 0, 2, 5, 4, 2, 1, 2, 7 , 8 , 4, 4` is the first map
- `98, 0, 97, 0, 2, 3, 6, 2, 1, 2, 43, 42, 4, 4` is the second map
- `2, 19, 6, 36, 36` is the root vector
- `4, 40, 1` is the information about the root object

Generally we can say that deduplication reduces the buffer size at the cost of slower serialisation, so the user might decide, which is more important for them.

--- 

> Final note: The project is in active development, contributions are welcome.
