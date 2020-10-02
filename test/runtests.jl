using ConcreteStructs
using ConcreteStructs: _parse_head, _parse_struct_def, _parse_line
using ConcreteStructs: _strip_super, _get_subparams, _get_constructor_params
using Suppressor
using Test


# # Unit Tests

# Test setup
line_number_node = LineNumberNode(1)
annotated_var = :(b::B)
struct_name = :(MyStruct)
sub_typed_params = :(MyStruct{T1,T2<:AbstractVector{T1}})
sub_typed = :(MyStruct{D} <: Number)
kitchen_sink = :(MyStruct{T1, T2<:AbstractVector{T1}} <: AbstractVector{T1})


# Run tests
@testset "_parse_line" begin
    @test _parse_line(line_number_node) == (line_number_node, nothing)
    @test _parse_line(annotated_var) == (annotated_var, nothing)

    parsed_sym = _parse_line(:a)
    @test parsed_sym[1].args[2] == parsed_sym[2]
end

@testset "_parse_struct_def" begin
    @test _parse_struct_def(struct_name) == (struct_name, [])
    @test _parse_struct_def(sub_typed_params) == (struct_name, [:T1, :(T2<:AbstractVector{T1})])
end

@testset "_parse_head" begin
    @test _parse_head(struct_name) == (struct_name, [], :Any)
    @test _parse_head(sub_typed) == (struct_name, Any[:D], :Number)
    @test _parse_head(kitchen_sink) == (struct_name, [:T1, :(T2 <: AbstractVector{T1})], :(AbstractVector{T1}))
end

@testset "_strip_super" begin
    @test _strip_super(struct_name) == struct_name
    @test _strip_super(kitchen_sink) == :(MyStruct{T1, T2<:AbstractVector{T1}})
    @test _strip_super([struct_name, sub_typed]) == [struct_name, :(MyStruct{D})]
end

@testset "_get_subparams" begin
    @test _get_subparams(struct_name) == []
    @test _get_subparams([:T1, :(T2<:AbstractArray{T1,N}), :(T3<:Complex{T1})]) == Any[:T1, :N, :T1]
end

@testset "_get_constructor_params" begin
    @test _get_constructor_params([:T, :(A<:AbstractVector{T})], [:A, :B]) == []
    @test _get_constructor_params([:iip, :T, :(A<:AbstractVector{T})], [:A, :B]) == [:iip]
    @test _get_constructor_params([:iip, :T, :(A<:AbstractVector{T}), :B], [:B]) == [:iip, :A]
end



# # End-to-end tests

# Test setup
@concrete struct Plain end
plain = Plain()

@concrete struct Args
    a
    b
end
args = Args(1+im, "hi")

@concrete mutable struct SubtypedMutable <: Number
    a
    b
end
subtyped_mutable = SubtypedMutable(3.0, 4f0)

@concrete struct Partial{A}
    a::A
    b
end
partial = Partial(:yo, 1//2)

@concrete mutable struct ConstructorMutable{iip,C}
    a
    b
    c::C
end
ConstructorMutable(a,b,c) = ConstructorMutable{true}(a,b,eltype(a)(c))
constructor_mutable = ConstructorMutable([1.0+im, 2], 'r', 1.5)
constructor_mutable.b = 'h'

@concrete terse struct TerseSameType{A}
    a::A
    b::A
end
function TerseSameType(a::A, b::B) where {A,B}
    T = promote_type(A, B)
    return TerseSameType{T}(T(a), T(b))
end
terse_same_type = TerseSameType(1+im, 5f0)

@concrete terse struct FullyParameterized{B}
    a::Symbol
    b::B
end
fully_parameterized = FullyParameterized(:sine, sin)

@concrete mutable struct ParameterizedSubtyped{T,N,B<:AbstractArray{T,N}} <: AbstractArray{T,N}
    a
    b::B
    c::T
end
parameterized_subtyped = ParameterizedSubtyped(:🏦, [1, 2, 3], 4)
Base.size(x::ParameterizedSubtyped) = size(x.b)
Base.getindex(x::ParameterizedSubtyped, i...) = x.b[i...]

@concrete terse struct HangingTypeParam{iip}
    a
    b
end
hanging_type_param = HangingTypeParam{true}(1, 2.0)

@concrete terse struct HangingTypeParam2{iip,B}
    a
    b::B
end
hanging_type_param2 = HangingTypeParam2{true}(1, 2.0)


# Run tests
@testset "ConcreteStructs.jl" begin
    @test_throws ErrorException args.a = 2+im
    @test_throws MethodError subtyped_mutable.a = "hi"

    @test typeof(partial) |> isconcretetype
    @test typeof(terse_same_type.a) === typeof(terse_same_type.b)
    @test typeof(fully_parameterized.a) |> isconcretetype
    @test eltype(parameterized_subtyped.b) === typeof(parameterized_subtyped.c)

    @test @capture_out(show(stdout, MIME("text/plain"), typeof(fully_parameterized))) == "FullyParameterized{typeof(sin)}"
    @test @capture_out(show(stdout, hanging_type_param)) == "HangingTypeParam{true}(1, 2.0)"
end