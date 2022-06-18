"""
Function Space Interface
"""
module Spaces

# TODO
#   - figure out interplay between Space and Discretization
#       1. space is how you represent functions (with basis)
#       2. discretization is how you compute vector calculus operations
#       3. have (space + discretization) --> calculus

using LinearAlgebra
using SciMLOperators
import SciMLOperators: ⊗, IdentityOperator
import NNlib: gather, scatter
import UnPack: @unpack
import Plots

using Reexport
include("../Domains/Domains.jl")
@reexport using Domains

# overload
import Base: eltype, length, size
import Base: summary, display, show
import Domains: dims, deform
import Plots: plot, plot!

""" Function space in D-Dimensional space """
abstract type AbstractSpace{T,D} end

include("utils.jl")
include("interface.jl")
include("vectorcalculus.jl")
include("gatherscatter.jl")

# Concrete Spaces
include("LagrangePolynomials/LagrangePolynomialSpace.jl")
include("TrigonometricPolynomials/Fourier.jl")

include("tensor.jl")
include("deform.jl")

export
       # interface
       grid, domain,

       # operators
       gradOp, massOp, laplaceOp, advectionOp, divergenceOp,

       # lagrange polynomial space
       LagrangePolynomialSpace,
       GaussLobattoLegendre, GaussLegendre, GaussChebychev,

       interpOp,

       deform

end
#