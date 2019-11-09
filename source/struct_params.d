/*
struct-params-dlang - https://github.com/vporton/struct-params-dlang

This file is part of struct-params-dlang.

Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
*/

module struct_params;

import std.meta;
import std.traits;
import std.typecons;
import std.range;

private template FieldInfo(argT, string argName) {
    alias T = argT;
    alias name = argName;
}

private alias processFields() = AliasSeq!();

private alias processFields(T, string name, Fields...) =
    AliasSeq!(FieldInfo!(T, name), processFields!(Fields));

// Needs to be public not to break visibility rules in StructParams template mixin.
public string structParamsImplementation(string name, Fields...)() {
    enum regularField(alias f) = fullyQualifiedName!(f.T) ~ ' ' ~ f.name ~ ';';
    enum fieldWithDefault(alias f) = "Nullable!(" ~ fullyQualifiedName!(f.T) ~ ") " ~ f.name ~ ';';
    alias fields = processFields!(Fields);
    immutable string regularFields = cast(immutable string) [staticMap!(regularField, fields)].join('\n');
    immutable string fieldsWithDefaults = cast(immutable string) [staticMap!(fieldWithDefault, fields)].join('\n');
    return "struct " ~ name ~ " {\n" ~
           "  struct Regular {\n" ~
           "    " ~ regularFields ~ '\n' ~
           "  }\n" ~
           "  struct WithDefaults {\n" ~
           "    " ~ fieldsWithDefaults ~ '\n' ~
           "  }\n" ~
           '}';
}

/**
Example: `mixin StructParams!("S", int, "x", float, "y");` creates
```
struct S {
  struct Regular {
    int x;
    float y;
  }
  struct WithDefaults {
    Nullable!int x;
    Nullable!float y;
  }
}
```
These structures are intended to be used as arguments of `combine` function.
*/
mixin template StructParams(string name, Fields...) {
    import std.typecons : Nullable;
    mixin(structParamsImplementation!(name, Fields)());
}

/**
Creates a "combined" structure from `main` and `default_`. The combined structure contains member
values from `main` whenever `!isNull` for this value and otherwise values from `default_`.

Example:
```
mixin StructParams!("S", int, "x", float, "y");
immutable S.WithDefaults combinedMain = { x: 12 }; // y is default-initialized
immutable S.Regular combinedDefault = { x: 11, y: 3.0 };
immutable combined = combine(combinedMain, combinedDefault);
assert(combined.x == 12 && combined.y == 3.0);
```

Note that we cannot use struct literals like `S.Regular(x: 11, y: 3.0)` in the current version
(v2.084.1) of D, just because current version of D does not have this feature. See DIP71.
*/
deprecated("Use the variant with both arguments *.WithDefaults")
S.Regular combine(S)(S.WithDefaults main, S.Regular default_) {
    S.Regular result;
    static foreach (m; __traits(allMembers, S.Regular)) {
        __traits(getMember, result, m) =
            __traits(getMember, main, m).isNull ? __traits(getMember, default_, m)
                                                : __traits(getMember, main, m).get;
    }
    return result;
}

/**
Creates a "combined" structure from `main` and `default_`. The combined structure contains member
values from `main` whenever `!isNull` for this value and otherwise values from `default_`.
Assertion error if both a member of `main` and of `default_` are null.

Example:
```
mixin StructParams!("S", int, "x", float, "y");
immutable S.WithDefaults combinedMain = { x: 12 }; // y is default-initialized
immutable S.WithDefaults combinedDefault = { x: 11, y: 3.0 };
immutable combined = combine(combinedMain, combinedDefault);
assert(combined.x == 12 && combined.y == 3.0);
```

Note that we cannot use struct literals like `S.Regular(x: 11, y: 3.0)` in the current version
(v2.084.1) of D, just because current version of D does not have this feature. See DIP71.
*/
S.Regular combine(S)(S.WithDefaults main, S.WithDefaults default_) {
    S.Regular result;
    static foreach (m; __traits(allMembers, S.Regular)) {
        assert(!__traits(getMember, main, m).isNull || !__traits(getMember, default_, m).isNull);
        __traits(getMember, result, m) =
            __traits(getMember, main, m).isNull ? __traits(getMember, default_, m)
                                                : __traits(getMember, main, m);
    }
    return result;
}

/**
Example:

Consider function
```
float f(int a, float b) {
    return a + b;
}
```

Then we can call it like `callFunctionWithParamsStruct!f(combined)` where `combined` in
this example may be created by `combine` function. (`callFunctionWithParamsStruct` is intented
mainly to be used together with `combine` function.)

The members from `combined` are passed to the function `f` in the same order as they are defined
in the struct.
*/
ReturnType!f callFunctionWithParamsStruct(alias f, S)(S s) {
    return f(s.tupleof);
}

/**
Example:

Consider:
```
struct Test {
    float f(int a, float b) {
        return a + b;
    }
}
Test t;
```

Then it can be called like `callMemberFunctionWithParamsStruct!(t, "f")(combined)`
(see `callFunctionWithParamsStruct` for the meaning of this).

It is very unnatural to call member f by string name, but I have not found a better solution.

Another variant would be to use
`callFunctionWithParamsStruct!((int a, float b) => t.f(a, b))(combined)`, but this way is
inconvenient as it requires specifying arguments explicitly.
*/
ReturnType!(__traits(getMember, o, f))
callMemberFunctionWithParamsStruct(alias o, string f, S)(S s) {
    return __traits(getMember, o, f)(s.tupleof);
}

unittest {
    mixin StructParams!("S", int, "x", float, "y");
    immutable S.WithDefaults combinedMain = { x: 12 };
    immutable S.Regular combinedDefault = { x: 11, y: 3.0 };
    immutable combined = combine(combinedMain, combinedDefault);
    assert(combined.x == 12 && combined.y == 3.0);
    immutable S.WithDefaults combinedMain2 = { x: 12 };
    immutable S.WithDefaults combinedDefault2 = { x: 11, y: 3.0 };
    immutable combined2 = combine(combinedMain2, combinedDefault2);
    assert(combined2.x == 12 && combined2.y == 3.0);

    float f(int a, float b) {
        return a + b;
    }
    assert(callFunctionWithParamsStruct!f(combined) == combined.x + combined.y);

    struct Test {
        float f(int a, float b) {
            return a + b;
        }
    }
    Test t;
    assert(callMemberFunctionWithParamsStruct!(t, "f")(combined) == combined.x + combined.y);
}
