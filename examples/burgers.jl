#
# add dependencies to env stack
pkgpath = dirname(dirname(@__FILE__))
tstpath = joinpath(pkgpath, "test")
!(tstpath in LOAD_PATH) && push!(LOAD_PATH, tstpath)

using PDEInterfaces
using OrdinaryDiffEq, LinearSolve
using Plots

N = 1024
ν = 5e-3
p = ()

""" space discr """
space = FourierSpace(N)
discr = Collocation()

(x,) = points(space)
tr = space.transforms
k = modes(space)

#u0 = @. sin(2x) + sin(3x)

u0 = rand(ComplexF64, size(k))
u0[20:end] .= 0
u0 = tr \ u0

A = diffusionOp(ν, space, discr)

function burgers!(L, u, p, t)
    L.diag .= u
    L
end

v = @. x*0 + 1
f = @. x*0 #+ ν
C = advectionOp((v,), space, discr; vel_update_func=burgers!)

F = AffineOperator(C, f)

A = cache_operator(A, x)
F = cache_operator(F, x)

""" time discr """
tspan = (0.0, 10.0)
tsave = range(tspan...; length=10)
odealg = Rodas5(autodiff=false)
prob = SplitODEProblem(A, F, u0, tspan, p)

@time sol = solve(prob, odealg, saveat=tsave)

plt = plot()
for i=1:length(sol.u)
    plot!(plt, x, sol.u[i], legend=false)
end
plt
