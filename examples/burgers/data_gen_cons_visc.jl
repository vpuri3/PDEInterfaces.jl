#
using PDEInterfaces
let
    # add dependencies to env stack
    pkgpath = dirname(dirname(pathof(PDEInterfaces)))
    tstpath = joinpath(pkgpath, "test")
    !(tstpath in LOAD_PATH) && push!(LOAD_PATH, tstpath)
    nothing
end

using OrdinaryDiffEq, LinearAlgebra
using CUDA, Random, JLD2

Random.seed!(0)
CUDA.allowscalar(false)

function uIC(space; truncation_frac=N_target/N)
    x = points(space)[1]
    X = truncationOp(space, (truncation_frac,))

    u0 = if x isa CUDA.CuArray
        X * CUDA.rand(size(x)...)
    else
        X * rand(size(x)...)
    end

    u0
end

odecb = begin
    function affect!(int)
        println(int.t)
    end

    DiscreteCallback((u,t,int) -> true, affect!, save_positions=(false,false))
end

function solve_burgers1D(N, ν, p;
                         uIC=uIC,
                         tspan=(0f0, 10f0),
                         nsims=10,
                         nsave=100,
                         odealg=SSPRK43(),
                        )

    """ space discr """
    space = FourierSpace(N) |> gpu
    discr = Collocation()

    (x,) = points(space)

    """ IC """
    u0 = [uIC(space) for i=1:nsims]
    u0 = hcat(u0...)
    space = make_transform(space, u0; p=p)

    """ operators """
    A = diffusionOp(ν, space, discr)

    function burgers!(v, u, p, t)
        copyto!(v, u)
    end

    function forcing!(f, u, p, t)
        lmul!(false, f)
    end

    C = advectionOp((zero(u0),), space, discr; vel_update_funcs=(burgers!,))
    F = -C + forcingOp(zero(u0), space, discr; f_update_func=forcing!)

    A = cache_operator(A, u0)
    F = cache_operator(F, u0)

    """ time discr """
    function Ajac(Jv, v, u, p, t;A=A)
        SciMLOperators.update_coefficients!(A, u, p, t)
        mul!(Jv, A, v)
    end
    odefunc = SplitFunction(A, F; jvp=Ajac)
    #odefunc = cache_operator(A+F, u0)

    tsave = range(tspan...; length=nsave)
    prob = ODEProblem(odefunc, u0, tspan, p; reltol=1f-8, abstol=1f-8)

    @time sol = solve(prob, odealg, saveat=tsave, callback=odecb)

    sol, space
end

function datagen_burgers1D(N, ν, p, N_target, filename; kwargs...)

    sol, space = solve_burgers1D(N, ν, p; kwargs...)

    ## save
    sp_coarse = FourierSpace(N_target)
    sp_dense  = cpu(space)

    u_dense  = Array(sol) |> cpu

    J = begin
        szc  = (N_target, size(u_dense)[2:end]...)
        u_c  = similar(u_dense, szc)
        sp_c = make_transform(sp_coarse, u_c)
        sp_d = make_transform(sp_dense, u_dense)
    
        interpOp(sp_c, sp_d)
    end

    u_coarse = J * u_dense
    t = sol.t |> cpu

    jldsave(filename; sp_coarse, sp_dense, u_coarse, u_dense, t)

    return
end

#########################
N = 1024
ν = 1f-3
p = nothing

N_target = 128

name = "burgers_nu1em3_n1024"
filename = joinpath(@__DIR__, name * ".jld2")

datagen_burgers1D(N, ν, p, N_target, filename)
#
