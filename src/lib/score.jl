# thread_score returns a score for determining the top note for purposes of
# calculating the informed probability of the post. It is the probability
# that the user would upvote the post given they were fully informed of the
# critical thread that begins with that note. 
#
# ranking_score returns a score for determining how much attention a post
# should receive -- which is the value of a user considering the note.
#
# These are different values. To understand the difference, suppose we have
# posts A->B->C, P(A|not B, not C) = 10%, P(A|B, not C)=90%, and P(A|B,C) =
# 15%. So C mostly erases the effect of B on A. The effect of B is p=15%
# (fully informed), q=10%(uninformed), and r=90% (partially informed).
# 
# So B, without C, makes users *less* informed! If users only consider B and
# not C, their upvote probability is r=90%, which is further from the
# informed probability p=15% then where we started at q=10%. This means
# considering B and not C only increases cognitive dissonance.
#
# Cognitive dissonance before considering B: 
#
#    relative_entropy(p, q) = relative_entropy(.15, .10) = .0176
#
# Cognitive dissonance after considering B: 
#
#    relative_entropy(p, r) = relative_entropy(.15, .9) = 2.2366
#
# So for purposes of ranking, B has *negative* information value, because
# considering B without considering C actually makes users more uninformed!
# The information value of B (without C) is 
#
#   information_gain(p,r,q) 
#     = information_gain(p, q) - information_gain(p, r) 
#     = -2.2189. 
#
# On the other hand, for purposes of calculating the informed probability of
# A, the most informed thread may be: A->B->C. The relative entropy for the
# thread is:
#
#    relative_entropy(p, q) = .0176
#
# So unless there are threads with higher scores, B might start of the top
# thread, even though B as a post has negative information value.
#
# We multiple thread_score by p_size as a heuristic to deal with duplicates.
# Suppose we have the same posts A->B->C. Before C is submitted, the informed
# probability of A will be close to 90%. However, C will reduce the this
# significantly to 15%.
# 
# At this point, a user could submit a near duplicate of B, B', and before
# somebody submitted a duplicate of note C, C', B' would become the top note
# and the informed probability of A will bounce back up to 90%. 
#
# Multiplying thread_score by p_size is a heuristic that kinds of deals with
# this. We give more weight to notes that have had more attention, and
# therefore have been exposed to more scrutiny and there is therefore a
# greater chance of users responding with a counter argument. So at first,
# even though B' has a high relative_entropy, it has a low score because its
# p_size is low. As its p_size increases, the probability that somebody
# responds with C' increases. 
#
# If people keep on submitting duplicates, users should start to notice and
# start downvoting the duplicates, so that they never receive enough
# attention to become the top note and people don't have to respond to them.

# p =  0.3952
# q = 0.6992
# r = 0.304
# # p = .15
# # q = .1
# # r = .9
# GlobalBrain.information_gain(p,r,q) 
# GlobalBrain.relative_entropy(p, q)
# GlobalBrain.relative_entropy(p, r)


function thread_score(effect::Effect)
    return relative_entropy(effect.p, effect.q) * effect.p_size
end

function effect_score(effect::Effect)::Float64
    return information_gain(effect.p, effect.r, effect.q)
end

function post_score(p)::Float64
    p * (1 + log2(p))
end

# The total ranking score for a post includes the information value of an
# upvote on the post itself, plus the value of reduced cognitive dissonance
# from voting on the post.

function ranking_score(
    effects::Vector{Effect},
    top_note_effect::Union{Effect,Nothing},
    o::Float64,
)::Float64
    p = isnothing(top_note_effect) ? o : top_note_effect.p

    return post_score(p) + sum([effect_score(e) for e in effects])
end
