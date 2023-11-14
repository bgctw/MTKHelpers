"""
    ODEProblemParSetter(state_names,par_names,popt_names) 
    ODEProblemParSetter(sys::ODESystem, popt_names; strip=false) 

Helps keeping track of a subset of initial states and parameters to be optimized.

# Arguments
- `state_names`: ComponentVector or Axis of all the initial states of the problem
- `par_names`: all the parameters of the problem
- `popt_names`: the parameter/initial states to be optimized.

If all of `state_names`, `par_names`, and `popt_names` are type-inferred Axes,
then also the constructed ODEProblemParSetter is type-inferred.

The states and parameters can be extracted from an `ModelingToolkit.ODESystem`.
If `strip=true`, then namespaces of parameters of a composed system are removed, 
e.g. `subcomp₊p` becomes `p`.
"""
struct ODEProblemParSetter{NS,NP,POPTA <: AbstractAxis,
    SA <: AbstractAxis,
    PA <: AbstractAxis,
} <: AbstractProblemParSetter
    ax_paropt::POPTA
    ax_state::SA
    ax_par::PA
    is_updated_state_i::StaticVector{NS,Bool}
    is_updated_par_i::StaticVector{NP,Bool}
    function ODEProblemParSetter(ax_state::AbstractAxis,
        ax_par::AbstractAxis, ax_paropt::AbstractAxis,
        is_validating::Val{isval}) where {isval}
        if isval
            is_valid, msg = validate_keys_state_par(ax_paropt, ax_state, ax_par)
            !is_valid && error(msg)
        end
        keys_paropt_state = keys(CA.indexmap(ax_paropt)[:state])
        keys_paropt_par = keys(CA.indexmap(ax_paropt)[:par])
        is_updated_state_i = isempty(keys_paropt_state) ?
                             SVector{0,Bool}() :
                             SVector((k ∈ keys_paropt_state for k in keys(ax_state))...)
        is_updated_par_i = isempty(keys_paropt_par) ?
                           SVector{0,Bool}() :
                           SVector((k ∈ keys_paropt_par for k in keys(ax_par))...)
        new{length(is_updated_state_i),length(is_updated_par_i),
            typeof(ax_paropt),typeof(ax_state),typeof(ax_par)}(ax_paropt,
            ax_state, ax_par, is_updated_state_i, is_updated_par_i)
    end
end

function ODEProblemParSetter(state_template, par_template, popt_template; 
    is_validating = Val{true}())
    ax_paropt = _get_axis(popt_template)
    ax_state = _get_axis(state_template)
    ax_par = _get_axis(par_template)
    if !(:state ∈ keys(ax_paropt) || :par ∈ keys(ax_paropt)) 
        ax_paropt = assign_state_par(ax_state, ax_par, ax_paropt)
    end
    ODEProblemParSetter(ax_state, ax_par, ax_paropt, is_validating)
end

function assign_state_par(ax_state, ax_par, ax_paropt)
    state_keys = Vector{Symbol}()
    par_keys = Vector{Symbol}()
    for key in keys(ax_paropt)
        key ∈ keys(ax_state) && push!(state_keys, key)
        key ∈ keys(ax_par) && push!(par_keys, key)
    end
    missing_keys = setdiff(keys(ax_paropt), vcat(state_keys, par_keys))
    length(missing_keys) != 0 && @warn("Expected optimization parameters to be part of " *
        "state or parameters, but did not found parameters " * string(missing_keys) * ".")
    duplicate_keys = intersect(state_keys, par_keys)
    length(duplicate_keys) != 0 && @warn("Expected optimization parameters to be either " *
        " part of state or parameters, but following occur in both " * 
        string(duplicate_keys) * ". Will update those only in state.")
    # assume to refer to state only
    par_keys = setdiff(par_keys, duplicate_keys)
    tmp = attach_axis((1:axis_length(ax_paropt)), ax_paropt) 
    tmp_state = @view tmp[state_keys]
    tmp_par = @view tmp[par_keys]
    tmp2 = CA.ComponentVector(state = tmp_state, par = tmp_par)
    return _get_axis(tmp2)
end



# function _get_axis(x::AbstractArray) 
#     @info("Providing Parameters as Array was deprecated for performance?")
#     # depr?: need a full-fledged axis
#     Axis(Tuple(i for i in symbol_op.(x)))
# end
function _get_axis(x::Tuple)
    Axis(Tuple(i for i in symbol_op.(x)))
end
_get_axis(x::ComponentVector) = first(getaxes(x))
_get_axis(x::AbstractAxis) = x
_get_axis(x::CA.CombinedAxis) = CA._component_axis(x)

function ODEProblemParSetter(sys::ODESystem, paropt; strip = false)
    strip && error("strip in construction of ODEProblemparSetter currently not supported.")
    ODEProblemParSetter(axis_of_nums(states(sys)), axis_of_nums(parameters(sys)), paropt)
end

"""
    strip_deriv_num(num)

Provide a Symbol that omits the derivative part of a Num
- x(t,s) -> :x

E.g. used in `ODEProblemParSetter(system, strip_deriv_num.(popt_names))`
"""
function strip_deriv_num(num)
    num |> string |> (x -> replace(x, r"\(.+\)" => "")) |> Symbol
end

# count_state(::ODEProblemParSetter{N, POPTA, SA, PA}) where {N, POPTA, SA, PA} = length(CA.indexmap(SA))
# count_par(::ODEProblemParSetter{N, POPTA, SA, PA}) where {N, POPTA, SA, PA} = length(CA.indexmap(PA))
# count_paropt(::ODEProblemParSetter{N, POPTA, SA, PA}) where {N, POPTA, SA, PA} = N

# TODO change to length(ax) when this becomes available in ComponentArrays
count_state(pset::ODEProblemParSetter) = axis_length(pset.ax_state)
count_par(pset::ODEProblemParSetter) = axis_length(pset.ax_par)
count_paropt(pset::ODEProblemParSetter) = axis_length(pset.ax_paropt)

# axis_state(::ODEProblemParSetter{POPTA, SA, PA}) where {POPTA, SA, PA} = SA
# axis_par(::ODEProblemParSetter{POPTA, SA, PA}) where {POPTA, SA, PA} = PA
# axis_paropt(::ODEProblemParSetter{POPTA, SA, PA}) where {POPTA, SA, PA} = POPTA

axis_state(ps::ODEProblemParSetter) = ps.ax_state
axis_par(ps::ODEProblemParSetter) = ps.ax_par
axis_paropt(ps::ODEProblemParSetter) = ps.ax_paropt

keys_state(ps::ODEProblemParSetter) = keys(ax_state)
keys_par(ps::ODEProblemParSetter) = keys(ps.ax_par)
function keys_paropt(ps::ODEProblemParSetter) 
    ax = axis_paropt(ps)
    # for each top-key access the subaxis and apply keys
    gen = (getproperty(CA.indexmap(ax), k) |> x -> keys(x) for k in keys(ax))
    tuplejoin(gen...)
end

symbols_state(pset::ODEProblemParSetter) = _ax_symbols_tuple(axis_state(pset))
symbols_par(pset::ODEProblemParSetter) = _ax_symbols_tuple(axis_par(pset))
#symbols_paropt(pset::ODEProblemParSetter) = _ax_symbols_tuple(axis_paropt(pset))
# concatenate the symbols of subaxes
function symbols_paropt(pset::ODEProblemParSetter)
    ax = axis_paropt(pset)
    # for each key access the subaxis and apply _ax_symbols_tuple
    gen = (getproperty(CA.indexmap(ax), k) |> x -> _ax_symbols_tuple(x) for k in keys(ax))
    # concatenate the generator of tuples
    tuplejoin(gen...)
end

# # Using unexported interface of ComponentArrays.axis, one place to change
# "Accessor function for index from ComponentIndex"
# idx(ci::CA.ComponentIndex) = ci.idx

"""
    u0new, pnew = update_statepar(pset::ODEProblemParSetter, popt, u0, p) 

Return an updated problem or updates states and parameters where
values corresponding to positions in `popt` are set.
"""
function update_statepar(pset::ODEProblemParSetter, popt, u0, p)
    poptc = attach_axis(popt, axis_paropt(pset))
    u0c = attach_axis(u0, axis_state(pset)) # no need to copy 
    pc = attach_axis(p, axis_par(pset))
    u0_new = _update_cv_top(u0c, poptc.state, pset.is_updated_state_i)
    p_new = _update_cv_top(pc, poptc.par, pset.is_updated_par_i)
    # if u0 was not a ComponentVector, return then data inside
    return (u0 isa ComponentVector) ? u0_new : getfield(u0_new, :data), 
        (p isa ComponentVector) ? p_new : getfield(p_new, :data)
end

# mutating version does not work with derivatives
# function update_statepar(pset::ODEProblemParSetter, popt, u0, p)
#     poptc = attach_axis(popt, axis_paropt(pset))
#     u0c = attach_axis(copy(u0), axis_state(pset))
#     pc = attach_axis(copy(p), axis_par(pset))
#     for k in keys(poptc.state)
#         u0c[k] = poptc.state[k]
#     end
#     for k in keys(poptc.par)
#         pc[k] = poptc.par[k]
#     end
#     # if u0 was not a ComponentVector, return then data inside
#     return (u0 isa ComponentVector) ? u0c : getfield(u0c, :data), 
#         (p isa ComponentVector) ? pc : getfield(pc, :data)
# end


# struct ODEVectorCreator <: AbstractVectorCreator; end
# function (vc::ODEVectorCreator)(pset, u0, p)
#     ET = promote_type(eltype(u0), eltype(p))
#     Vector{ET}(undef, count_paropt(pset))
# end

# struct ODEMVectorCreator <: AbstractVectorCreator; end
# function (vc::ODEMVectorCreator)(pset, u0, p)
#     ET = promote_type(eltype(u0), eltype(p))
#     N = count_paropt(pset)
#     MVector{N,ET}(undef)
# end


"""
    get_paropt_labeled(pset::ODEProblemParSetter, u0, p)

Returns a ComponentVector filled with corresponding entries from u0 and p.

Underlying type corresponds defaults to Vector. 
It cannot be fully inferred from u0 and p, because their type may hold
additional structure, such as length or names.
For obtaining a StaticVector instead, pass MTKHelpers.ODEMVectorCreator()
as the fourth argument. This method should work with any AbstractVectorCreator
that returns a mutable AbstractVector.
"""
function get_paropt_labeled(pset::ODEProblemParSetter, u0, p, 
    #vec_creator::AbstractVectorCreator=ODEVectorCreator()
    )
    u0c = attach_axis(u0, axis_state(pset))
    pc = attach_axis(p, axis_par(pset))
    ax = axis_paropt(pset)
    k_state = keys(CA.indexmap(ax).state)
    k_par = keys(CA.indexmap(ax).par)
    gen_state = (@view(u0c[KeepIndex(k)]) for k in k_state)
    gen_par = (@view(pc[KeepIndex(k)]) for k in k_par)
    # gen_state = (u0c[k] for k in k_state) # more allocations
    # gen_par = (pc[k] for k in k_par)
    # gen_state = (@view(u0c[k]) for k in k_state) # takes long than with KeepIndex
    # gen_par = (@view(pc[k]) for k in k_par)
    # Main.@infiltrate_main
    # tmp = collect(gen_state)
    # tmp = collect(gen_par)
    _data = vcat(gen_state..., gen_par...)
    T = promote_type(eltype(u0), eltype(p))
    paropt = attach_axis(_data, axis_paropt(pset))::ComponentVector{T, Vector{T}}
    # cv_state = ComponentVector((;zip(k_state,(u0c[k] for k in k_state))...))
    # cv_par = ComponentVector((;zip(k_par,(pc[k] for k in k_par))...))
    # paropt = ComponentVector(state = cv_state, par = cv_par)
    return paropt
end

# mutating version does not work with gradient
# function get_paropt_labeled(pset::ODEProblemParSetter, u0, p, 
#     vec_creator::AbstractVectorCreator=ODEVectorCreator())
#     u0c = attach_axis(u0, axis_state(pset))
#     pc = attach_axis(p, axis_par(pset))
#     #Main.@infiltrate_main
#     data = vec_creator(pset, u0, p)
#     paropt = attach_axis(data, axis_paropt(pset))
#     for k in keys(paropt.state)
#         paropt.state[k] = u0c[k]
#     end
#     for k in keys(paropt.par)
#         paropt.par[k] = pc[k]
#     end
#     return paropt
# end

# docstring in abstractodeproblemparsetter.jl
function get_u_map(names_u, pset::ODEProblemParSetter; do_warn_missing = false)
    names_uprob = symbols_state(pset)
    u_map = map(name_uprob -> findfirst(isequal(name_uprob), names_u), names_uprob)
    do_warn_missing &&
        any(isnothing.(u_map)) &&
        warning("problem states $(names_pprob[findall(isnothing.(u_map))]) not in names_u.")
    SVector(u_map)
end,
function get_p_map(names_p, pset::ODEProblemParSetter; do_warn_missing = false)
    names_pprob = symbols_par(pset)
    p_map = map(name_pprob -> findfirst(isequal(name_pprob), names_p), names_pprob)
    # usually the default parameters, such as u_PlantPmax ~ i_L0 / β_Pi0 - imbalance_P
    # are not part of names_p -> false warning
    do_warn_missing &&
        any(isnothing.(p_map)) &&
        warning("problem parameters $(names_pprob[findall(isnothing.(p_map))]) not " * 
        "in names_p.")
    SVector(p_map)
end

"""
    validate:keys(pset)

Checks whether all components of paropt-Axis are occurring
in corresponding axes.     
"""
function validate_keys(pset::ODEProblemParSetter)
    validate_keys_state_par(axis_paropt(pset), axis_state(pset), axis_par(pset))
end

function validate_keys_state_par(ax_paropt::AbstractAxis, ax_state::AbstractAxis, ax_par::AbstractAxis)
    paropt = attach_axis((1:axis_length(ax_paropt)), ax_paropt)
    :state ∉ keys(paropt) && return (;isvalid=false, 
        msg=String127("Expected paropt to contain state key, but did not."))
    :par ∉ keys(paropt) && return (;isvalid=false, 
         msg=String127("Expected paropt to contain par key, but did not."))
    paropt.state isa CA.ComponentVector ||
        length(paropt.state) == 0 ||  # special case of empty ComponentVector, e.g. 2:1
        return return (; isvalid=false,
            msg=String127("Expected paropt.state <: ComponentVector, but was not."))
    paropt.par isa CA.ComponentVector ||
        length(paropt.par) == 0 ||  # special case of empty ComponentVector
        return return (; isvalid=false,
            msg=String127("Expected paropt.par <: ComponentVector, but was not."))
    u0c = attach_axis((1:axis_length(ax_state)), ax_state)
    for k in keys(paropt.state)
        k ∉ keys(u0c) && return (;isvalid=false, 
            msg=String127("Expected optimined paropt.state.$k to be part of state, " * 
            "but was not."))
        length(paropt.state[k]) != length(u0c[k]) &&  return (;isvalid=false, 
            msg=String127("Expected optimized paropt.state.$k to be of length " *
            "$(length(u0c[k])) but had length $(length(paropt.state[k]))"))
    end
    pc = attach_axis((1:axis_length(ax_par)), ax_par)
    for k in keys(paropt.par)
        k ∉ keys(pc) && return (;isvalid=false, 
            msg=String127("Expected optimined paropt.par.$k to be part of parameters, " * 
            "but was not."))
        length(paropt.par[k]) != length(pc[k]) && return (;isvalid=false, 
            msg=String127("Expected optimized paropt.par.$k to be of length " *
            "$(length(pc[k])) but had length $(length(paropt.par[k]))"))
    end
    return (;isvalid=true, msg=String127(""))
end

