"""
    ProblemParSetterComp1Comp(state_names,par_names,popt_names) 
    ProblemParSetterComp1Comp(sys::ODESystem, popt_names; strip=false) 

Helps keeping track of a subset of initial states and paraemters to be optimized.

# Arguments
- `state_names`: Tuple or AbstractVector of all the initial states of the problem
- `par_names`: all the parameters of the problem
- `popt_names`: the parameter/initial states to be optimized.

The states and parameters can be extracted from an `ModelingToolkit.ODESystem`.
If `strip=true`, then namespaces of parameteres of a composed system are removed, 
e.g. `subcomp₊p` becomes `p`.
"""
struct ProblemParSetterComp1{NOPT, POPTA <: AbstractAxis, SA <: AbstractAxis, PA <: AbstractAxis} <: AbstractProblemParSetter
    # u0_opt::NTuple{NS, Symbol}
    # p_opt::NTuple{NP, Symbol}
    ax_paropt::POPTA
    ax_state::SA
    ax_par::PA
    is_state::NTuple{NOPT, Bool}
    is_p::NTuple{NOPT, Bool}
end

function ProblemParSetterComp1(ax_state::AbstractAxis, ax_par::AbstractAxis, ax_paropt::AbstractAxis) 
    popt_names = keys(CA.indexmap(ax_paropt))
    state_names = keys(CA.indexmap(ax_state))
    par_names = keys(CA.indexmap(ax_par))
    NOPT = length(CA.indexmap(ax_paropt))
    is_state = ntuple(i -> popt_names[i] ∈ state_names, NOPT)
    is_p = ntuple(i -> popt_names[i] ∈ par_names, NOPT)
    is_u0_or_p = is_state .| is_p
    all(is_u0_or_p) || @warn(
        "missing optimization parameters in system: " * join(popt_names[collect(.!is_u0_or_p)],", "))
    is_u0_and_p = is_state .& is_p
    any(is_u0_and_p) && @warn(
        "expted parameter names and state names to be distinct, but occured in both: " * join(popt_names[collect(is_u0_and_p)],", "))
    ProblemParSetterComp1{NOPT, typeof(ax_paropt),typeof(ax_state), typeof(ax_par)}(ax_paropt, ax_state, ax_par, is_state, is_p)
end

# function ProblemParSetterComp1(state_names::NTuple{NS, Symbol}, par_names::NTuple{NP, Symbol}, popt_names::NTuple{NOPT, Symbol}) where {NS, NP, NOPT} 
#     # not type stable
#     ProblemParSetterComp1(Axis(state_names), Axis(par_names), Axis(popt_names))
# end

function ProblemParSetterComp1(state_names,par_names,popt_names) 
    # not type-stable
    ProblemParSetterComp1(
        _get_axis(state_names),
        _get_axis(par_names),
        _get_axis(popt_names),
    )
end

function _get_axis(x::Union{Tuple, AbstractArray}) 
    Axis(Tuple(i for i in symbol.(x)))
end
_get_axis(x::ComponentVector) = first(getaxes(x))


function ProblemParSetterComp1(sys::ODESystem,popt_names; strip=false) 
    ft = strip ? strip_namespace : identity
    state_names = ft.(symbol.(states(sys)))
    par_names = ft.(symbol.(parameters(sys)))
    ProblemParSetterComp1(Axis(state_names), Axis(par_names), _get_axis(popt_names))
end

# count_state(::ProblemParSetterComp1{N, POPTA, SA, PA}) where {N, POPTA, SA, PA} = length(CA.indexmap(SA))
# count_par(::ProblemParSetterComp1{N, POPTA, SA, PA}) where {N, POPTA, SA, PA} = length(CA.indexmap(PA))
# count_paropt(::ProblemParSetterComp1{N, POPTA, SA, PA}) where {N, POPTA, SA, PA} = N

count_state(pset::ProblemParSetterComp1) = CA.last_index(pset.ax_state)
count_par(pset::ProblemParSetterComp1) = CA.last_index(pset.ax_par)
count_paropt(pset::ProblemParSetterComp1) = CA.last_index(pset.ax_paropt)


# axis_state(::ProblemParSetterComp1{N, POPTA, SA, PA}) where {N, POPTA, SA, PA} = SA
# axis_par(::ProblemParSetterComp1{N, POPTA, SA, PA}) where {N, POPTA, SA, PA} = PA
# axis_paropt(::ProblemParSetterComp1{N, POPTA, SA, PA}) where {N, POPTA, SA, PA} = POPTA

axis_state(ps::ProblemParSetterComp1) = ps.ax_state
axis_par(ps::ProblemParSetterComp1) = ps.ax_par
axis_paropt(ps::ProblemParSetterComp1) = ps.ax_paropt


function _ax_symbols(ax::Union{AbstractAxis, CA.CombinedAxis}; prefix="₊") 
    # strip the first prefix, convert to symbol and retun generator
    (i for i in _ax_string_prefixed(ax; prefix) .|> (x -> x[(sizeof(prefix)+1):end]) .|> Symbol)
end
function _ax_symbols_tuple(ax::Union{AbstractAxis, CA.CombinedAxis}; kwargs...) 
    Tuple(_ax_symbols(ax; kwargs...))::NTuple{CA.last_index(ax), Symbol}
end
function _ax_symbols_vector(ax::Union{AbstractAxis, CA.CombinedAxis}; kwargs...) 
    # strip the first prefix, convert to symbol and collect into tuple
    collect(_ax_symbols(ax; kwargs...))::Vector{Symbol}
end




symbols_state(pset::ProblemParSetterComp1) = _ax_symbols_tuple(axis_state(pset))
symbols_par(pset::ProblemParSetterComp1) = _ax_symbols_tuple(axis_par(pset))
symbols_paropt(pset::ProblemParSetterComp1) = _ax_symbols_tuple(axis_paropt(pset))
 
# Using unexported interface of ComponentArrays.axis, one place to change
"Accessor function for index from ComponentIndex"
idx(ci::CA.ComponentIndex) = ci.idx
    
"""
    prob_new = update_statepar(pset::ProblemParSetterComp1, popt, prob::ODEProblem) 
    u0new, pnew = update_statepar(pset::ProblemParSetterComp1, popt, u0, p) 

Return an updated problem or updates states and parameters where
values corresponding to positions in `popt` are set.
"""
# function update_statepar(pset::ProblemParSetterComp1, popt, prob::ODEProblem) 
#     u0,p = update_statepar(pset, popt, prob.u0, prob.p)
#     remake(prob; u0, p)
# end


function update_statepar(pset::ProblemParSetterComp1, popt, u0::TU, p::TP) where {TU,TP}
    popt_state, popt_p = _separate_state_p(pset, popt)
    u0new = _update_cv(label_state(pset, u0), popt_state)
    pnew = _update_cv(label_par(pset,p), popt_p)
    # TODO care for different type of popt
    u0new = convert(TU, getdata(u0new))::TU
    pnew = convert(TP, getdata(pnew))::TP
    (u0new, pnew)
end

# extract p and state components of popt into separate ComponentVectors
function _separate_state_p(pset, popt)
    popt_l = label_paropt(pset, popt)
    popt_state = _get_index_axis(popt_l, Axis(
        Tuple(k for (i,k) in enumerate(keys(popt_l)) if pset.is_state[i])))
    #popt_p = popt_l[Axis( # WAIT use proper indexing when supported with ComponentArrays
    popt_p = _get_index_axis(popt_l, Axis(
            Tuple(k for (i,k) in enumerate(keys(popt_l)) if pset.is_p[i])))
    popt_state, popt_p
end
    




# function typed_from_generator(type::Type, v0, vgen) where T 
#     if type <: AbstractArray
#     end
#     typeof(v0)(vgen)
# end
# # AbstractVector{T} is not more specific than ::Type, need to support all used concrete
# #typed_from_generator(::Type{AbstractVector{T}}, v0, vgen) where T = convert(typeof(v0), v0 .+ vgen)::typeof(v0)
# typed_from_generator(::Type{Vector{T}}, v0, vgen) where T = convert(typeof(v0), v0 .+ vgen)::typeof(v0)


# typed_from_generator(v0, vgen) = typeof(v0)(vgen)
# function typed_from_generator(v0::AbstractVector, vgen) 
#     # convert to std vector, because typeof(v0) does not contain all entries
#     T = Vector{eltype(v0)}  
#     convert(T, v0 .+ vgen)::T
# end

# type piracy - try to get into CompponentArrays
# Base.getindex(cv::ComponentVector, ax::AbstractAxis) = _get_index_axis(cv,ax)
# Base.getindex(cv::ComponentVector, cv_template::ComponentVector) = _get_index_axis(
#     cv,first(getaxes(cv_template)))


function get_paropt_labeled(pset::ProblemParSetterComp1, u0, p) 
    ax = axis_paropt(pset)
    keys_ax = keys(ax)
    u0l = label_state(pset, u0)
    pl = label_par(pset, p)
    (i,k) = first(enumerate(keys_ax))
    #(i,k) = (2, keys_ax[2])
    tmp = map(enumerate(keys_ax)) do (i,k)
        #local u0k =  # inferred Any
        cvs = pset.is_state[i] ? getproperty(u0l,k) : (pset.is_p[i] ? getproperty(pl,k) : missing) 
        cvs isa ComponentVector || return(cvs)
        axs = ax[k].ax
        #@show cvs, axs, typeof(cvs)
        # TODO replace by cvs[axs] when _get_index was merged
        _get_index_axis(cvs, axs)
    end
    T = promote_type(eltype(u0), eltype(p))
    res = ComponentVector(NamedTuple{keys_ax}(tmp))::ComponentVector{T, Vector{T}}
    label_paropt(pset, res) # reattach axis for type inference
end

# attach type in
# type piracy I - until get this into ComponentArrays
@inline CA.getdata(x::ComponentArray{T,N,A}) where {T,N,A} = getfield(x, :data)::A
@inline CA.getdata(x::ComponentVector{T,A}) where {T,A} = getfield(x, :data)::A



# # extends Base.merge to work on SVector
# # ?type piracy
# merge(x::T, y::NamedTuple) where T<:SLArray = T(merge(NamedTuple(x),y)...)

# # and on Labelled Arrays
# function merge(x::T, y::NamedTuple) where T<:LArray
#     xnew = deepcopy(x)
#     for (key,val) in pairs(y)
#         xnew[key] = val
#     end
#     xnew
# end



