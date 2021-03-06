using Mill, JSON, BSON, Flux, JsonGrinder, Test

using JsonGrinder: DictEntry, suggestextractor, schema
using Mill: reflectinmodel

@testset "basic behavior testing" begin
	j1 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1},"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
	j2 = JSON.parse("""{"a": 4, "c": { "a": {"a":[2,3],"b":[5,6]}}}""")
	j3 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1}}""")
	j4 = JSON.parse("""{"a": 4, "b": {}}""")
	j5 = JSON.parse("""{"b": {}}""")
	j6 = JSON.parse("""{}""")

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6])

	@test sch[:a].counts == Dict(4 => 4)
	@test sch[:a].updated == 4
	@test sch[:b].updated == 4
	@test sch[:b][:a].updated == 2
	@test sch[:b][:a].l == Dict(3 => 2)
	@test sch[:b][:a].items.counts == Dict(1 => 2, 2 => 2, 3 => 2)
	@test sch[:b][:a].items.updated == 6
	@test sch[:b][:b].counts == Dict(1 => 2)
	@test sch[:b][:b].updated == 2
	@test sch[:c].updated == 2
	@test sch[:c][:a].updated == 2
	@test sch[:c][:a][:a].updated == 2
	@test sch[:c][:a][:a].l == Dict(2 => 1, 3 => 1)
	@test sch[:c][:a][:a].items.counts == Dict(1 => 1, 2 => 2, 3 => 2)
	@test sch[:c][:a][:a].items.updated == 5
	@test sch[:c][:a][:b].updated == 2
	@test sch[:c][:a][:b].l == Dict(2 => 1, 3 => 1)
	@test sch[:c][:a][:b].items.counts == Dict(4 => 1, 5 => 2, 6 => 2)
	@test sch[:c][:a][:b].items.updated == 5

	@test keys(sch[:a]) == [4]
end

@testset "testing empty arrays" begin
	j1 = JSON.parse("""{"a": []}""")
	j2 = JSON.parse("""{"a": [{"a":1},{"b":2}]}""")
	j3 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a" : 1}]}""")
	j4 = JSON.parse("""{"a": [{"a":2,"b":3}]}""")

	sch1 = JsonGrinder.schema([j1])
	sch2 = JsonGrinder.schema([j1,j2,j3])
	sch3 = JsonGrinder.schema([j2,j3,j1])

	@test sch1.updated == 1
	@test sch1[:a].updated == 1
	@test isnothing(sch1[:a].items)

	@test sch2.updated == sch3.updated
	@test sch2[:a].l == sch3[:a].l
	@test sch2[:a].updated == sch3[:a].updated
	@test sch2[:a].items[:a].updated == sch3[:a].items[:a].updated
	@test sch2[:a].items[:a].counts == sch3[:a].items[:a].counts
end

@testset "testing schema merging" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2}]}""")
	j2 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a" : 1}]}""")
	j3 = JSON.parse("""{"a": [{"a":2,"b":3}]}""")
	j4 = JSON.parse("""{"a": []}""")
	j5 = JSON.parse("""{}""")
	j6 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a" : 1}], "b": 1}""")

	# todo: otestovat jak funguje newentry s víceprvkovám polem
	sch1 = JsonGrinder.schema([j1,j2,j3])
	sch2 = JsonGrinder.schema([j4,j5,j6])

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6])
	sch_merged = merge(sch1, sch2)

	@test sch.updated == sch_merged.updated
	@test sch[:a].updated == sch_merged[:a].updated
	@test sch[:a].l == sch_merged[:a].l
	@test sch[:a].items[:a].updated == sch_merged[:a].items[:a].updated
	@test sch[:a].items[:a].counts == sch_merged[:a].items[:a].counts
	@test sch[:a].items[:b].updated == sch_merged[:a].items[:b].updated
	@test sch[:a].items[:b].counts == sch_merged[:a].items[:b].counts
	@test sch[:b].updated == sch_merged[:b].updated
	@test sch[:b].counts == sch_merged[:b].counts
end

@testset "bson and symbol keys testing" begin
	b1 = IOBuffer()
	j1 = BSON.bson(b1, Dict(:a=>4, :b=>Dict(:a=>[1,2,3], :b=>1), :c=>Dict(:a=>Dict(:a=>[1,2,3],:b=>[4,5,6]))))
	b2 = IOBuffer()
	j2 = BSON.bson(b2, Dict(:a=>4,:c=>Dict(:a=>Dict(:a=>[2,3],:b=>[5,6]))))
	b3 = IOBuffer()
	j3 = BSON.bson(b3, Dict(:a=>4,:b=>Dict(:a=>[1,2,3],:b=>1)))
	b4 = IOBuffer()
	j4 = BSON.bson(b4, Dict(:a=>4,:b=>Dict()))
	b5 = IOBuffer()
	j5 = BSON.bson(b5, Dict(:b=>Dict()))
	b6 = IOBuffer()
	j6 = BSON.bson(b6, Dict())
	bs = [(seek(b, 0); BSON.load(b)) for b in [b1,b2,b3,b4,b5,b6]]
	sch = JsonGrinder.schema(bs)

	@test sch[:a].counts == Dict(4 => 4)
	@test sch[:a].updated == 4
	@test sch[:b].updated == 4
	@test sch[:b][:a].updated == 2
	@test sch[:b][:a].l == Dict(3 => 2)
	@test sch[:b][:a].items.counts == Dict(1 => 2, 2 => 2, 3 => 2)
	@test sch[:b][:a].items.updated == 6
	@test sch[:b][:b].counts == Dict(1 => 2)
	@test sch[:b][:b].updated == 2
	@test sch[:c].updated == 2
	@test sch[:c][:a].updated == 2
	@test sch[:c][:a][:a].updated == 2
	@test sch[:c][:a][:a].l == Dict(2 => 1, 3 => 1)
	@test sch[:c][:a][:a].items.counts == Dict(1 => 1, 2 => 2, 3 => 2)
	@test sch[:c][:a][:a].items.updated == 5
	@test sch[:c][:a][:b].updated == 2
	@test sch[:c][:a][:b].l == Dict(2 => 1, 3 => 1)
	@test sch[:c][:a][:b].items.counts == Dict(4 => 1, 5 => 2, 6 => 2)
	@test sch[:c][:a][:b].items.updated == 5
end

@testset "equals and hash test" begin
	j1 = JSON.parse("""{"a": []}""")
	j2 = JSON.parse("""{"a": [{"a":1},{"b":2}]}""")
	j3 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a" : 1}]}""")
	j4 = JSON.parse("""{"a": [{"a":2,"b":3}]}""")

	sch0 = JsonGrinder.DictEntry()
	sch1 = JsonGrinder.schema([j1, j2, j3, j4])
	sch2 = JsonGrinder.schema([j1, j2, j3, j4])
	sch3 = JsonGrinder.schema([j1, j2, j3])

	@test hash(sch1) === hash(sch2)
	@test hash(sch1) !== hash(sch3)
	@test hash(sch1) !== hash(sch0)
	@test hash(sch3) !== hash(sch0)

	@test sch1 == sch2
	@test sch1 != sch3
	@test sch1 != sch0
	@test sch3 != sch0
end

@testset "testing schema merging with max keys" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2}]}""")
	j2 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a":1}]}""")
	j3 = JSON.parse("""{"a": [{"a":2,"b":3}]}""")
	j4 = JSON.parse("""{"a": []}""")
	j5 = JSON.parse("""{}""")
	j6 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a":1}], "b":1}""")
	j7 = JSON.parse("""{"a": [{"a":4,"b":5},{"b":6,"a":7}], "b":2}""")
	j8 = JSON.parse("""{"a": [{"a":9,"b":10},{"b":11,"a":12}], "b":2}""")
	j9 = JSON.parse("""{"a": [{"a":4,"b":3},{"b":2,"a":2}], "b":2}""")
	j10 = JSON.parse("""{"a": [{"a":11,"b":12},{"b":13,"a":14}], "b":2}""")
	j11 = JSON.parse("""{"a": [{"a":7,"b":5},{"b":6,"a":6}], "b":2}""")

	JsonGrinder.updatemaxkeys!(6)
	# todo: otestovat jak funguje newentry s víceprvkovám polem
	sch1 = JsonGrinder.schema([j1,j2,j3,j4,j5,j11])
	sch2 = JsonGrinder.schema([j6,j7,j8,j9,j10])

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6,j7,j8,j9,j10,j11])
	sch_merged = merge(sch1, sch2)

	@test sch == sch_merged
end

@testset "Sample synthetic" begin
	j1 = JSON.parse("""{"a": []}""")
	j2 = JSON.parse("""{"a": [{"a":1},{"b":2}]}""")
	j3 = JSON.parse("""{"a": [{"a":1,"b":3},{"b":2,"a" : 1}]}""")
	j4 = JSON.parse("""{"a": [{"a":2,"b":3}]}""")

	sch1 = JsonGrinder.schema([j1, j2, j3, j4])
	@test JsonGrinder.sample_synthetic(sch1) == Dict(:a=>[Dict(:a=>2,:b=>2), Dict(:a=>2,:b=>2)])
end

@testset "Merge empty lists" begin
	j1 = JSON.parse("""{"a": [{"a":1},{"b":2}], "b": []}""")
	j2 = JSON.parse("""{"a": [{"a":3},{"b":4}], "b": []}""")
	j3 = JSON.parse("""{"a": [{"a":1},{"b":3}], "b": []}""")
	j4 = JSON.parse("""{"a": [{"a":2},{"b":4}], "b": [1]}""")

	sch = JsonGrinder.schema([j1, j2, j3, j4])
	sch123 = JsonGrinder.schema([j1, j2, j3])
	sch12 = JsonGrinder.schema([j1, j2])
	sch3 = JsonGrinder.schema([j3])
	sch4 = JsonGrinder.schema([j4])
	sch_merged123 = merge(sch12, sch3)
	sch_merged1234 = merge(sch12, sch3, sch4)
	@test sch == sch_merged1234
	@test sch123 == sch_merged123
end

@testset "Fail empty bag extractor" begin
	ex = JsonGrinder.newentry([])
	@test isnothing(suggestextractor(ex))
end

@testset "delete in path" begin
	j1 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1},"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
	j2 = JSON.parse("""{"a": 4, "c": { "a": {"a":[2,3],"b":[5,6]}}}""")
	j3 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1}}""")
	j4 = JSON.parse("""{"a": 4, "b": {}}""")
	j5 = JSON.parse("""{"b": {}}""")
	j6 = JSON.parse("""{}""")

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6])
	@test children(sch[:c][:a]) == (a=sch[:c][:a][:a], b=sch[:c][:a][:b])
	delete!(sch, ".c.a", "a")
	@test children(sch[:c][:a]) == (b=sch[:c][:a][:b],)
end

@testset "schema with fail" begin
	j1 = JSON.parse("""{"d": ["ahoj"]}""")
	j2 = JSON.parse("""{"d": 1}""")

	sch = JsonGrinder.schema([j1,j2])
	@test sch[:d].updated == 1
end

@testset "extractor from schema" begin
	j1 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1},"c": { "a": {"a":[1,2,3],"b":[4,5,6]}}}""",inttype=Float64)
	j2 = JSON.parse("""{"a": 4, "c": { "a": {"a":[2,3],"b":[5,6]}}}""")
	j3 = JSON.parse("""{"a": 4, "b": {"a":[1,2,3],"b": 1}}""")
	j4 = JSON.parse("""{"a": 4, "b": {}}""")
	j5 = JSON.parse("""{"b": {}}""")
	j6 = JSON.parse("""{}""")

	sch = JsonGrinder.schema([j1,j2,j3,j4,j5,j6])
	ext = suggestextractor(sch)

	@test ext[:a] isa ExtractScalar{Int64, Float64}
	@test ext[:b][:a] isa ExtractArray{ExtractScalar{Int64,Float64}}
	@test ext[:b][:b] isa ExtractScalar{Int64,Float64}
	@test ext[:c][:a][:a] isa ExtractArray{ExtractScalar{Float64,Float64}}
	@test ext[:c][:a][:b] isa ExtractArray{ExtractScalar{Float64,Float64}}

	e1 = ext(j1)
	@test e1.data.scalars.data[1, 1] == 0
	@test e1.data.b.data.a.data.data == [0. 0.5 1.]
	@test e1.data.b.data.scalars.data[1, 1] == 0.
	@test e1.data.c.data.a.data.data == [0. 0.5 1.]
	@test e1.data.c.data.b.data.data == [0. 0.5 1.]
end
