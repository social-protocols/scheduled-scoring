function score_posts(output_event::Function, posts::Vector{TalliesData})
    effects = Dict{Int,Vector{Effect}}()
    for post in posts
        score_post(output_event, post, effects)
    end
end

function score_post(output_event::Function, post::TalliesData, effects::Dict{Int,Vector{Effect}})
    post_id = post.post_id
    @debug "In score post $post_id"

    if !post.needs_recalculation
        @debug "No recalculation needed for $(post_id). Using existing score"
        return Vector{Score}()
    end

    this_tally = post.tally()

    o = GLOBAL_PRIOR_UPVOTE_PROBABILITY |> (x -> update(x, this_tally))

    @debug "Overall probability in score_post for $post_id is $(o.mean)"

    p = weighted_average_informed_probability(post_id, post, o, effects)

    my_effects::Vector{Effect} = get(effects, post_id, [])
    for e in my_effects
        output_event(e)
    end

    for child in post.children()
        score_post(output_event, child, effects)
    end

    score = Score(
        post_id = post_id,
        o = o.mean,
        o_count = this_tally.count,
        o_size = this_tally.size,
        p = p,
        score = ranking_score(my_effects, p),
    )
    output_event(score)
end

function weighted_average_informed_probability(
    post_id::Int,
    target::TalliesData,
    r::BetaDistribution,
    effects::Dict{Int,Vector{Effect}},
)::Number
    comment_id = target.post_id

    @debug "weighted_average_informed_probability $post_id=>$(comment_id), r=$(r.mean)"

    children = target.children()
    @debug "Got $(length(children)) children for $comment_id"

    @debug "Getting effects of children of $comment_id on $post_id"
    child_effects =
        [calc_thread_effect(post_id, child, r, effects) for child in children] |>
        (x -> filter(effect -> effect.weight > 0, x))

    if length(child_effects) == 0
        return r.mean
    end

    total_weight = sum([effect.weight for effect in child_effects])
    weighted_sum = sum([effect.weight * effect.p for effect in child_effects])

    return weighted_sum / total_weight
end

function calc_thread_effect(
    post_id::Int,
    target::TalliesData,
    prior::BetaDistribution,
    effects,
)::Effect
    if !target.needs_recalculation
        return target.effect(post_id)
    end

    tally = target.conditional_tally(post_id)
    (q, r) = upvote_probabilities(prior, tally)
    p = weighted_average_informed_probability(post_id, target, r, effects)

    @debug "p=$p for $post_id=>$(target.post_id)"

    effect = Effect(
        post_id = post_id,
        comment_id = target.post_id,
        p = p,
        q = q,
        r = r.mean,
        conditional_tally = tally,
    )
    add!(effects, effect)
    return effect
end

function add!(effects::Dict{Int,Vector{Effect}}, new_effect::Effect)
    if !haskey(effects, new_effect.comment_id)
        effects[new_effect.comment_id] = []
    end
    push!(effects[new_effect.comment_id], new_effect)
end
