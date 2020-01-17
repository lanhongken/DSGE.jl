"""
```
measurement{T<:AbstractFloat}(m::SmetsWoutersOrig{T}, TTT::Matrix{T}, RRR::Matrix{T},
                              CCC::Vector{T})
```

Assign measurement equation

```
y_t = ZZ*s_t + DD + u_t
```

where

```
Var(ϵ_t) = QQ
Var(u_t) = EE
Cov(ϵ_t, u_t) = 0
```
"""
function measurement(m::SmetsWoutersOrig{T},
                                       TTT::Matrix{T},
                                       RRR::Matrix{T},
                                       CCC::Vector{T}; regime::Int = 1) where T<:AbstractFloat
    endo      = m.endogenous_states
    endo_addl = m.endogenous_states_augmented
    exo       = m.exogenous_shocks
    obs       = m.observables

    _n_observables = n_observables(m)
    _n_states = n_states_augmented(m)
    _n_shocks_exogenous = n_shocks_exogenous(m)

    ZZ = zeros(_n_observables, _n_states)
    DD = zeros(_n_observables)
    EE = zeros(_n_observables, _n_observables)
    QQ = zeros(_n_shocks_exogenous, _n_shocks_exogenous)

    ## Output growth - Quarterly!
    ZZ[obs[:obs_gdp], endo[:y_t]]       =  1.
    ZZ[obs[:obs_gdp], endo_addl[:y_t1]] = -1.
    DD[obs[:obs_gdp]]                   =  m[:γ].value # unscaled value

    ## Consumption Growth
    ZZ[obs[:obs_consumption], endo[:c_t]]       =  1.
    ZZ[obs[:obs_consumption], endo_addl[:c_t1]] = -1.
    DD[obs[:obs_consumption]]                   =  m[:γ].value # unscaled value

    ## Investment Growth
    ZZ[obs[:obs_investment], endo[:i_t]]       =  1.
    ZZ[obs[:obs_investment], endo_addl[:i_t1]] = -1.
    DD[obs[:obs_investment]]                   =  m[:γ].value # unscaled value

    ## Labor Share/real wage growth
    ZZ[obs[:obs_wages], endo[:w_t]]       =  1.
    ZZ[obs[:obs_wages], endo_addl[:w_t1]] = -1.
    DD[obs[:obs_wages]]                   =  m[:γ].value # unscaled value

    ## Hours growth
    ZZ[obs[:obs_hours], endo[:L_t]] = 1.
    DD[obs[:obs_hours]]             = m[:Lmean]

    ## Inflation (GDP Deflator)
    ZZ[obs[:obs_gdpdeflator], endo[:π_t]] = 1.
    DD[obs[:obs_gdpdeflator]]             = m[:π_star].value # unscaled value

    ## Nominal interest rate
    ZZ[obs[:obs_nominalrate], endo[:R_t]] = 1.0
    DD[obs[:obs_nominalrate]]             = m[:Rstarn]

    # Variance of innovations
    if subspec(m) in ["ss27", "ss28", "ss29", "ss41", "ss42", "ss43", "ss44"] && regime == 2
        QQ[exo[:g_sh], exo[:g_sh]]     = m[:σ_g2]^2
        QQ[exo[:b_sh], exo[:b_sh]]     = m[:σ_b2]^2
        QQ[exo[:μ_sh], exo[:μ_sh]]     = m[:σ_μ2]^2
        QQ[exo[:z_sh], exo[:z_sh]]     = m[:σ_z2]^2
        QQ[exo[:λ_f_sh], exo[:λ_f_sh]] = m[:σ_λ_f2]^2
        QQ[exo[:λ_w_sh], exo[:λ_w_sh]] = m[:σ_λ_w2]^2
        QQ[exo[:rm_sh], exo[:rm_sh]]   = m[:σ_rm2]^2
    else
        QQ[exo[:g_sh], exo[:g_sh]]     = m[:σ_g]^2
        QQ[exo[:b_sh], exo[:b_sh]]     = m[:σ_b]^2
        QQ[exo[:μ_sh], exo[:μ_sh]]     = m[:σ_μ]^2
        QQ[exo[:z_sh], exo[:z_sh]]     = m[:σ_z]^2
        QQ[exo[:λ_f_sh], exo[:λ_f_sh]] = m[:σ_λ_f]^2
        QQ[exo[:λ_w_sh], exo[:λ_w_sh]] = m[:σ_λ_w]^2
        QQ[exo[:rm_sh], exo[:rm_sh]]   = m[:σ_rm]^2
    end
    # These lines set the standard deviations for the anticipated
    # shocks to be equal to the standard deviation for the
    # unanticipated policy shock
    for i = 1:n_anticipated_shocks(m)
        ZZ[obs[Symbol("obs_nominalrate$i")], :] = ZZ[obs[:obs_nominalrate], :]' * (TTT^i)
        DD[obs[Symbol("obs_nominalrate$i")]]    = m[:Rstarn]
        QQ[exo[Symbol("rm_shl$i")], exo[Symbol("rm_shl$i")]] = m[Symbol("σ_rm")]^2 / 16
    end

    # Adjustment to DD because measurement equation assumes CCC is the zero vector
    if any(CCC .!= 0)
        DD += ZZ*((UniformScaling(1) - TTT)\CCC)
    end

    return Measurement(ZZ, DD, QQ, EE)
end