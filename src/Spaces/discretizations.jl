#

"""
Weighted residual method
"""
struct Galerkin <: AbstractDiscretization end
_transp(a, ::Galerkin) = adjoint(a)

function laplaceOp(space::AbstractSpace, discr::Galerkin)
    D = dims(space)

    M  = massOp(space, space)
    MM = Diagonal([M for i=1:D])

    DD = gradOp(space, discr)

    - DD' * MM * DD
end

function laplaceOp(space1::AbstractSpace{<:Any,D},
                   space2::AbstractSpace{<:Any,D},
                   ::Galerkin;
                   J = nothing,
                  ) where{D}
    J12 = J !== nothing ? J : interpOp(space1, space2)
    #J21 = _transp(J12) # or interpOp(space2, space1) # TODO

    M2  = massOp(space2, discr)
    MM2 = Diagonal([M2 for i=1:D])

    DD1  = gradOp(space1, discr)
    JDD  = J12 .* DD1

    - JDD' * MM2 * JDD
end

function diffusionOp(ν::AbstractVector, space::AbstractSpace, ::Galerkin)
    D = dims(space)
    ν = DiagonalOperator(ν)
    DD = gradOp(space)
    M  = massOp(space)
    Mν = ν * M
    MMν = Diagonal([Mν for i=1:D])

    - DD' * MMν * DD
end

"""
Collocation
"""
struct Collocation <: AbstractDiscretization end
_transp(a, ::Collocation) = _reshape(a, (1, length(a),),)

function massOp(space::AbstractSpace, discr::Collocation)
    N = length(space)
    IdentityOperator{N}()
end

function laplaceOp(space::AbstractSpace, discr::Collocation)
    DD2 = hessianOp(space, discr)
    sum(DD2)
end

#
