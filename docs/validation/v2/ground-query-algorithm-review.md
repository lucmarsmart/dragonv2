# Ground query algorithm review

Read-only review of `scripts/dragon_wing_contact.gd`, the grounded branch of
`scripts/dragon_controller.gd`, and `/tmp/dragon-ground-query-proposal.gd` on
2026-10-05. No runtime files changed. No Godot, GPU, CPU, or gameplay tests run.
This is an independent algorithm review, not C3 validation. Line numbers refer
to the versions read for this review; concurrent implementation may supersede them.

## Findings established from code and algebra

1. **A floor contact cannot authorize the entire hull query.** Runtime lines
   103–104 skip the hull when `get_rest_info` reports a terrain normal with
   `y >= .985`. That contact may be the floor while the cast reports a different
   obstacle. The proposal correctly separates terrain and props. Preserve both
   masks for every anatomical hull; do not reinstate the body terrain exemption
   at runtime line 79 or the rotation exemption at line 141.

2. **The proposal's props margin remains 25 cm.** This is a preventive clearance
   tradeoff, not a violation of the maximum visible penetration of 5 cm. Its
   effect on natural movement needs observation. Terrain margin zero avoids
   manufactured floor overlaps; using zero for contact witnesses also avoids
   confusing separated geometric points with penetration. Physical body
   clearance above terrain is still required: zero margin cannot repair an
   intersecting pose.

3. **One pass of 3D projections is not a simultaneous solution.** Proposal
   line 30 can violate an earlier plane after satisfying a later one. In a 2D
   example embedded in x/z, normals `(1,0)` and `(-1,1)/sqrt(2)` with incoming
   motion `(-1,-1)` produce `(0,-1)` after the first projection and `(-.5,-.5)`
   after the second. The final motion enters the first plane again. Collect
   constraints across all overlapping hulls/masks before solving them, and check
   every constraint against the final candidate.

4. **Copying projected x/z while discarding projected y invalidates the result.**
   For incoming displacement `(1,0,0)` and outward normal `(-1,1,0)/sqrt(2)`,
   `slide` returns `(.5,.5,0)`. Applying only x/z yields `(.5,0,0)`, which still
   enters the surface. Runtime lines 110–113 have this control-space mismatch.
   Proposal line 35 has the same issue if its return value is applied only to x/z:
   `(f*dx,dy,f*dz)` is not the safely swept segment `f*(dx,dy,dz)` when `dy != 0`.

5. **The controller already sets slope-related y before the constraint.**
   Controller lines 581–594 compute a floor-tangent heading and set
   `velocity.y = heading.y * current_speed - 2`. Runtime line 70 then projects
   the horizontal component onto a potentially different ray normal. That query
   vector is not the velocity passed to `move_and_slide`. Changes to x/z also
   leave the old slope-related y behind. `move_and_slide` and floor snap can
   further alter the actual displacement; an input-velocity cast is therefore
   only a prediction, unless those effects are accounted for.

6. **Later hulls can undo an earlier speed limit.** Runtime lines 107–114
   calculate every limit from the original immutable `look_velocity` and assign
   it to `dragon.velocity`. A .8 safe fraction from a later hull can replace a .2
   fraction from an earlier hull. Test the same final candidate against all
   hulls, aggregate restrictions, and apply once. The subsequent ground braking
   at lines 120–122 also changes that candidate and must precede its final query.

## Minimal strategy

Keep the existing separation of body, neck and wings, and preserve layers 1+2.
Keep grounded prediction at one actual tick and flight's existing full braking
distance. Replace the expensive deepest-contact query with bounded
`collide_shape` contacts only when there is a current overlap. The supplied API
facts are that cast motion ignores existing overlaps and collide shape ignores
motion; contact pairs are query point followed by collider point. Thus normalize
`collider_point - query_point` for the outward direction, with explicit handling
of degenerate pairs.

Solve in the dimensions the controller actually changes. For fixed vertical
displacement `dy`, let `u=(dx,dz)`, `a=(normal.x,normal.z)` and require
`a.dot(u) >= -normal.y*dy` for every current contact. This preserves retreat and
prevents motion farther into every retained contact plane. When `a` is nearly
zero and the inequality fails, horizontal control cannot solve that contact;
silently returning horizontal zero does not make the vertical motion safe.

For these small contact sets, the exact closest feasible 2D point is inexpensive:
consider the desired point, its projections onto each constraint boundary, and
intersections of every pair of boundaries. Reject candidates violating any
constraint and select the closest remaining candidate. A bounded iterative
projection with a final feasibility check is also usable, but do not assume one
pass works. Do not automatically use zero when the affine system is infeasible.

Construct the final 3D displacement using that chosen x/z and the same y that
will be executed. Cast every hull/mask on that candidate. If a cast changes the
candidate, revalidate the resulting candidate; multiplying only x/z by the safe
fraction does not inherit the original cast guarantee. Apply acceleration,
braking and any slope-y recomputation before this last validation. Record
separate reasons for an existing penetration, a newly swept blocker, and an
infeasible fixed-y constraint. No actor-position correction is necessary for
this strategy.

If the intended model is instead movement tangent to the supporting floor,
define that mapping explicitly: for support normal `g` with usable `g.y`,
`dy=-(g.x*dx+g.z*dz)/g.y`. A contact then constrains
`(n.x-n.y*g.x/g.y, n.z-n.y*g.z/g.y).dot(u) >= 0`.
This alternative is valid only if the controller actually executes the same
mapping. A proposed upward component cannot be used to excuse penetration when
it is subsequently discarded and replaced by the controller's vertical state.

## Limits requiring focused validation

- Four reported contact pairs are bounded evidence, not proof that every wall
  of an overlapping compound or concave collider is represented. Once a hull
  overlaps the large terrain shape, a cast can ignore a different terrain wall
  in that same shape. Strict real-pose clearance is the simplest prevention;
  a floor-normal exception does not solve it. Endpoint overlap checks alone
  cannot prove that an ignored intermediate obstacle was not crossed.
- Terrain line 25 in the proposal rejects even tangent travel when any retained
  contact has `dot <= epsilon`. This is conservative, but may freeze a shallow
  pose overlap until the pose is corrected. A permitted retreat must be checked
  against all contacts, not just the first favorable one.
- Rotation bisection assumes an initially clear pose and cannot recover a
  pre-existing overlap; accepting only the end orientation also does not prove
  the entire rotation arc is clear. This review did not quantify the practical
  exposure at the controller's turn rate.
- The algebra above is independent of frame rate. The >=60 FPS requirement
  still needs measured native timings after implementation. No performance
  claim is made from this read-only review.

High-value next step at roughly twice the validation effort: capture the final
executed displacement and per-hull query result in the existing deterministic
repros, then assert all retained contact-plane inequalities on that exact
displacement. This directly catches discarded-y, later-hull overwrite and
post-query braking regressions in the same evidence run.
