#
"""
Solve the 2D Burgers equation

∂t(vx) = -(vx*∂x(vx) + vy*∂y(vx)) + ν*Δvx
∂t(vy) = -(vx*∂x(vy) + vy*∂y(vy)) + ν*Δvy
"""

using PDEInterfaces
let
    # add dependencies to env stack
    pkgpath = dirname(dirname(pathof(PDEInterfaces)))
    tstpath = joinpath(pkgpath, "test")
    !(tstpath in LOAD_PATH) && push!(LOAD_PATH, tstpath)
    nothing
end

using OrdinaryDiffEq, Plots
using ComponentArrays, UnPack
using CUDA

nx = 32
ny = 32
ν = 5e-1
p = nothing

#odealg = Tsit5()
odealg = SSPRK43()

""" spatial discr """
space = FourierSpace(nx, ny)
discr = Collocation()
x, y = points(space)

""" IC """
X = truncationOp(space, (1//5, 1//5))
u0 = begin
    vx0 = X * rand(size(x)...)
    vy0 = X * rand(size(x)...)

    ComponentArray(vx=vx0, vy=vy0)
end

ps = ComponentArray(vel=u0)
space = make_transform(space, u0.vx; p=ps)

# GPU
#CUDA.allowscalar(false)
#space = space |> gpu
#x, y = points(space)
#u0 = u0 |> gpu
#ps = ps |> gpu

""" spce ops """
Ax = diffusionOp(ν, space, discr)
Ay = diffusionOp(ν, space, discr)

Cx = advectionOp((zero(x), zero(x)), space, discr;
                 vel_update_funcs=(
                                   (v,u,p,t) -> copy!(v, p.vel.vx),
                                   (v,u,p,t) -> copy!(v, p.vel.vy),
                                  )
                )

Cy = advectionOp((zero(x), zero(x)), space, discr;
                 vel_update_funcs=(
                                   (v,u,p,t) -> copy!(v, p.vel.vx),
                                   (v,u,p,t) -> copy!(v, p.vel.vy),
                                  )
                )

Fx = NullOperator(space)
Fy = NullOperator(space)

Dtx = cache_operator(Ax-Cx+Fx, x)
Dty = cache_operator(Ay-Cy+Fy, x)

function ddt(du, u, p, t)
    ps = ComponentArray(vel=u)

    Dtx(du.vx, u.vx, ps, t)
    Dty(du.vy, u.vy, ps, t)

    du
end

""" time discr """
tspan = (0.0, 10.0)
tsave = range(tspan...; length=10)
prob = ODEProblem(ddt, u0, tspan, p)

function affect!(int)
    println(int.t)
end
cb = DiscreteCallback((u,t,int) -> true, affect!, save_positions=(false,false))

@time sol = solve(prob, odealg, saveat=tsave, p=ps, callback=cb);
@show sol.retcode

pred = Array(sol)
vx = @views pred[:vx, :]
vy = @views pred[:vy, :]

anim = animate(vx, space)
filename = joinpath(dirname(@__FILE__), "burgers_x" * ".gif")
gif(anim, filename, fps=5)

anim = animate(vy, space)
filename = joinpath(dirname(@__FILE__), "burgers_y" * ".gif")
gif(anim, filename, fps=5)
#
