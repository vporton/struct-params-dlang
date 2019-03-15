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

import std.traits;
import std.typecons;
import std.range;
import std.meta;

private template FieldInfo(argT, string argName) {
    alias T = argT;
    alias name = argName;
}

private alias processFields() = AliasSeq!();

private alias processFields(T, string name, Fields...) =
    AliasSeq!(FieldInfo!(T, name), processFields!(Fields));

private string structParamsCode(string name, Fields...)() {
    enum regularField(alias f) = f.T.stringof ~ ' ' ~ f.name ~ ';';
    enum fieldWithDefault(alias f) = "Nullable!" ~ f.T.stringof ~ ' ' ~ f.name ~ ';';
    alias fields = processFields!(Fields);
    immutable string regularFields = [staticMap!(regularField, fields)].join('\n');
    immutable string fieldsWithDefaults = [staticMap!(fieldWithDefault, fields)].join('\n');
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
Create
*/
mixin template StructParams(string name, Fields...) {
    mixin(structParamsCode!(name, Fields)());
}

S.Regular combine(S)(S.WithDefaults main, S.Regular default_) {
    S.Regular result = default_;
    static foreach (m; __traits(allMembers, S.Regular)) {
        __traits(getMember, result, m) =
            __traits(getMember, main, m).isNull ? __traits(getMember, default_, m)
                                                : __traits(getMember, main, m).get;
    }
    return result;
}

ReturnType!f callFunctionWithParamsStruct(alias f, S)(S s) {
    return f(s.tupleof);
}

/**
Very unnatural to call member f by string name, but I have not found a better solution.
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
