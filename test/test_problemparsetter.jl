u1 = (L = 10.0,)
p1 = (k_L = 1.0, k_R = 1/20, m = 2.0)
# make sure that all states go before parameters 
popt = SLVector(L = 10.1, k_L = 1.1, k_R = 1/20.1)

# use allow_missing_opt = false for type stability
ps = @inferred ProblemParSetter(keys(u1),keys(p1),keys(popt), Val(false))


@testset "warning on missing symbols" begin
    state_syms = keys(u1)
    par_syms = keys(p1)
    popt_syms = (:L, :k_L, :M1, :M2)
    NO = length(popt_syms)
    psw = @test_logs (:warn,r"missing optimization parameters") ProblemParSetter(state_syms, par_syms, popt_syms)
end;

@testset "MethodError if missing symbols are not allowed" begin
    @test_throws MethodError ps1 = ProblemParSetter((:x, :RHS), (:τ,), (:RHS, :τ, :M), Val(false))
end;

@testset "access symbols and counts" begin
    @test (@inferred statesyms(ps)) == keys(u1)
    @test (@inferred parsyms(ps)) == keys(p1)
    @test (@inferred paroptsyms(ps)) == keys(popt)
    #
    @test (@inferred count_states(ps)) == length(u1)
    @test (@inferred count_par(ps)) == length(p1)
    @test (@inferred count_paropt(ps)) == length(popt)
end;

# ps.statemap
# ps.optinfo

@testset "label Tuples and SVectors" begin
    # not type stable, because names are not parameters of ps
    @test label_paropt(ps, Tuple(popt)) == NamedTuple(popt)
    @test label_paropt(ps, SVector(popt)) == popt
    @test label_paropt(ps, collect(popt)) == LArray(popt)
    #
    @test label_state(ps, Tuple(u1)) == u1
    @test label_par(ps, Tuple(p1)) == p1
    @test label_state(ps, SVector(Tuple(u1))) == SLVector(u1)
    @test label_par(ps, SVector(Tuple(p1))) == SLVector(p1)
    @test label_state(ps, collect(u1)) == LVector(u1)
    @test label_par(ps, collect(p1)) == LVector(p1)
end;

@testset "update_statepar and get_paropt" begin
    u0o, po = @inferred update_statepar(ps, popt, u1, p1)
    #@btime update_statepar($ps, $popt, $u1, $p1) # zero allocations
    @test collect(u0o) == [10.1]
    @test collect(po) == [1.1,1/20.1,2.0]
    #
    # retrieve popt again
    # using Cthulhu
    # @descend_code_warntype get_paropt(ps, u0o, po)
    popt2 = @inferred get_paropt(ps, u0o, po)
    @test all(popt2 .== popt)
    #using BenchmarkTools
    #@btime get_paropt($ps, $u0o, $po)
    #
    # no @inferred because labelling causes type instability
    popt2n = get_paropt_labeled(ps, u0o, po)
    @test popt2n == NamedTuple(popt)
    #
    popt2m = get_paropt_labeled(ps, collect(u0o), collect(po))
    @test popt2m == LArray(popt)
end;

@testset "update_statepar and get_paropt for Vector" begin
    u1vec = collect(u1)
    p1vec = collect(p1)
    u0o, po = @inferred update_statepar(ps, popt, u1vec, p1vec)
    #@btime update_statepar($ps, $popt, $u1, $p1) # zero allocations
    @test collect(u0o) == [10.1]
    @test collect(po) == [1.1,1/20.1,2.0]
    #
    # retrieve popt again
    #@code_warntype get_paropt(ps, u0o, po)
    popt2 = @inferred get_paropt(ps, u0o, po)
    @test all(popt2 .== popt)
    #using BenchmarkTools
    #@btime get_paropt($ps, $u0o, $po)
    #
    # no @inferred because labelling ist not type stable
    popt2n = get_paropt_labeled(ps, u0o, po)
    @test popt2n == LArray(popt)
end;

@testset "upate_statepar and get_paropt for AxisArray" begin
    # test with AbstractVector different from Vector
    u1vec = AxisArray(collect(u1); row = keys(u1))
    p1vec = collect(p1)
    u0o, po = @inferred update_statepar(ps, popt, u1vec, p1vec)
    #@btime update_statepar($ps, $popt, $u1, $p1) # zero allocations
    @test collect(u0o) == [10.1]
    @test collect(po) == [1.1,1/20.1,2.0]
    #
    # retrieve popt again
    #@code_warntype get_paropt(ps, u0o, po)
    popt2 = @inferred get_paropt(ps, u0o, po)
    @test all(popt2 .== popt)
    #using BenchmarkTools
    #@btime get_paropt($ps, $u0o, $po)
    #
    # no @inferred because labelling ist not type stable
    popt2n = get_paropt_labeled(ps, u0o, po)
    @test popt2n == LArray(popt)
end;

@testset "update_statepar and get_paropt for p only AbstractVector" begin
    p1vec = collect(p1)
    u0o, po = @inferred update_statepar(ps, popt, u1, p1vec)
    #@btime update_statepar($ps, $popt, $u1, $p1) # zero allocations
    @test collect(u0o) == [10.1]
    @test collect(po) == [1.1,1/20.1,2.0]
    #
    # retrieve popt again
    #@code_warntype get_paropt(ps, u0o, po)
    popt2 = @inferred get_paropt(ps, u0o, po)
    @test all(popt2 .== popt)
    #using BenchmarkTools
    #@btime get_paropt($ps, $u0o, $po)
    #
    # no @inferred because labelling ist not type stable
    popt2n = get_paropt_labeled(ps, u0o, po)
    @test popt2n == NamedTuple(popt) #u0o is NamedTuple
end;

@testset "merge: create a mofified popt AbstractVector" begin
    popt3 = @inferred merge(popt, (k_L = 1.2,))
    @test length(popt3) == length(popt)
    @test popt3.k_L == 1.2
    @test popt3.L == popt.L
    @test popt3.k_R == popt.k_R
end;

@testset "merge: create a mofified popt AbstractVector on LVector" begin
    poptlv = LArray(popt)
    popt3 = @inferred merge(poptlv, (k_L = 1.2,))
    @test length(popt3) == length(popt)
    @test popt3.k_L == 1.2
    @test popt3.L == popt.L
    @test popt3.k_R == popt.k_R
end;


@testset "update ODEProblem optimized parameters" begin
    f = (u,p,t) -> p[1]*u
    u0 = (u1=1/2,)
    p = (p1=1.1,p2=2)
    tspan = (0.0,1.0)
    prob = ODEProblem(f,SVector(Tuple(u0)),tspan,SVector(Tuple(p)))
    #sol = solve(prob)
    #sol[end]
    ps = ProblemParSetter(keys(u0),keys(p),(:u1,:p2))
    popt = (u1=1/4, p2=1.2)
    #
    # update_statepar
    prob2 = update_statepar(ps, popt, prob)
    @test prob2.u0[1] == popt.u1
    @test prob2.p[1] == p.p1 # not updated
    @test prob2.p[2] == popt.p2
    #
    # get_paropt
    @test get_paropt(ps, prob2) == collect(popt) #Tuple(popt) # Vector because provided p as SVector <: AbstractVector
    @test get_paropt_labeled(ps, prob2) == LVector(popt) # LVector because provided p as SVector <: AbstractVector
    @test label_par(ps, prob.p) == LVector(p)
end;

@testset "gradient with Tuple" begin
    fcost = (popt) -> begin
        u0, p = update_statepar(ps, popt, u1, p1)
        d = sum(get_paropt(ps, u0, p))
        d*d
    end
    fcost(popt)
    @test typeof(ForwardDiff.gradient(fcost, popt)) == typeof(popt)
end;

@testset "gradient with SVector" begin
    fcost = (popt) -> begin
        u0, p = update_statepar(ps, popt, u1, p1)
        d = sum(get_paropt(ps, u0, p))
        d*d
    end
    poptsv = SVector(popt)
    fcost(poptsv)
    @test typeof(ForwardDiff.gradient(fcost, poptsv)) == typeof(poptsv)
end;

@testset "gradient with AbstractVector" begin
    fcost = (popt) -> begin
        u0, p = update_statepar(ps, popt, u1, p1)
        d = sum(get_paropt(ps, u0, p))
        d*d
    end
    poptv = collect(popt)
    fcost(poptv)
    @test typeof(ForwardDiff.gradient(fcost, poptv)) == typeof(poptv)
end;

@testset "construct from ODESystem" begin
    @named m = samplesystem()
    popt_names = (:RHS, :τ)
    ps1 = ProblemParSetter(m, popt_names)
    @test statesyms(ps1) == (:x, :RHS)
    @test parsyms(ps1) == (:τ,)
    @test paroptsyms(ps1) == popt_names
    ps1 = ProblemParSetter(m, popt_names; strip=true)
    @test statesyms(ps1) == (:x, :RHS)
    @test parsyms(ps1) == (:τ,)
    @test paroptsyms(ps1) == popt_names
end;

@testset "error message on state not in front of parameters" begin
    @named m = samplesystem()
    popt_names = (:τ, :RHS) # note :RHS is a state and should be in fron to :τ
    @test_throws ErrorException ps1 = ProblemParSetter(m, popt_names)
    # @test paroptsyms(ps1) == popt_names # fails too
    #
    # in addition to missing parameters
    popt_names = (:τ, :RHS, :M) # note :RHS is a state and should be in fron to :τ
    @test_throws ErrorException ps1 = ProblemParSetter(m, popt_names)
end;





