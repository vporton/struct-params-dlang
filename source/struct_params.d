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

private string ProviderParamsCode(string name, Fields...)()
    if(!all!(t => t.length == 2 && isType!(t[0]) && is(typeof(t[1]) == string))(Fields))
{
    static assert(0, "ProviderParamsCode argument should be like [[int, \"x\"], [float, \"y\"]]");
}

private string ProviderParamsCode(string name, Fields...)() {
    immutable string regularFields =
        map!(f => __traits(identifier, f[0]) ~ ' ' ~ f[1] ~ ';')(Fields).join('\n');
    immutable string fieldsWithDefaults =
        map!(f => "Nullable!" ~ __traits(identifier, f[0]) ~ ' ' ~ f[1] ~ ';')(Fields).join('\n');
    return "struct " ~ name ~ " {\n" ~
           "  struct Regular {\n" ~
           "    " ~ regularFields ~ '\n' ~
           "  }\n" ~
           "  struct WithDefaults {\n" ~
           "    " ~ fieldsWithDefaults ~ '\n' ~
           "  }\n" ~
           '}';
}

mixin template ProviderParams(string name, Fields...) {
    mixin(ProviderParamsCode!(name, Fields)());
}

S.Regular combine(S)(S.WithDefaults main, S.Regular default_) {
    S result = default_;
    static foreach (m; __traits(allMembers, S)) {
        immutable mainMember = __traits(getMember, main, m);
        __traits(getMember, result, m) =
            mainMember.isNull ? __traits(getMember, default_, m) : mainMember.get;
    }
    return result;
}

ReturnType!f callFunctionWithParamsStruct(alias f, S)(S s) {
    return f(map!(m => __traits(getMember, s, m))(__traits(allMembers, S)));
}

/**
Very unnatural to call member f by string name, but I have not found a better solution.
*/
ReturnType!(__traits(getMember, o, f))
callMemberFunctionWithParamsStruct(alias o, string f, S)(S s) {
    return __traits(getMember, o, f)(map!(m => __traits(getMember, s, m))(__traits(allMembers, S)));
}
