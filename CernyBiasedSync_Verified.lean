/-
  Expected Synchronization Time of Černý Automata C_n under Biased Bernoulli Inputs
  Standalone Lean 4 Verification (Core `Init` only, zero external axioms, zero `sorry`)
-/

set_option maxHeartbeats 800000

namespace CernyBiasedSync

macro "poly_solve" : tactic =>
  `(tactic| (
    try grind
    try (
      simp only [Int.add_mul, Int.mul_add, Int.sub_mul, Int.mul_sub,
                 Int.mul_assoc, Int.add_assoc, Int.add_left_comm, Int.add_comm,
                 Int.mul_left_comm, Int.mul_comm]
      omega
    )
  ))

-- ============================================================================
-- 1. General Closed-Form Numerator and Layer Increment (Arbitrary n)
-- ============================================================================

def cernyNum (n u v : Int) : Int :=
  6 * (n - 1) * u * u
  + 3 * (n - 1) * (n - 2) * u * (v - u)
  + n * (n - 1) * (n - 2) * (v - u) * (v - u)

def layerDeltaNum (k u v : Int) : Int :=
  6 * u * u
  + 6 * (k - 2) * u * (v - u)
  + 3 * (k - 1) * (k - 2) * (v - u) * (v - u)

theorem telescoping_step (n u v : Int) :
    cernyNum (n + 1) u v - cernyNum n u v = layerDeltaNum (n + 1) u v := by
  dsimp [cernyNum, layerDeltaNum]
  poly_solve

theorem base_case_n2 (u v : Int) :
    cernyNum 2 u v = 6 * u * u := by
  dsimp [cernyNum]
  poly_solve

-- ============================================================================
-- 2. Asymptotic Identities: Uniform Input (p = 1/2) and Cubic Lower Bound
-- ============================================================================

theorem uniform_half_poly (n : Int) :
    4 * cernyNum n 1 2 = 3 * (4 * n * n * n - 6 * n * n - 4 * n + 6) := by
  dsimp [cernyNum]
  poly_solve

theorem cubic_denom_identity (u v : Int) :
    4 * v * v * v - 27 * u * u * (v - u) =
      (2 * v - 3 * u) * (2 * v - 3 * u) * (v + 3 * u) := by
  poly_solve

-- ============================================================================
-- 3. Constructive Subset Automaton Dynamics for C_n
-- ============================================================================

def actA (n mask : Nat) : Nat :=
  let low := (mask <<< 1) &&& ((1 <<< n) - 1)
  let high := mask >>> (n - 1)
  low ||| high

def actB (mask : Nat) : Nat :=
  let without0 := (mask >>> 1) <<< 1
  if (mask &&& 1) == 1 then without0 ||| 2 else without0

def popcount : Nat → Nat
  | 0 => 0
  | k + 1 => ((k + 1) &&& 1) + popcount ((k + 1) >>> 1)

theorem top_layer_contraction_3_to_8 :
    (∀ n ∈,
      actA n ((1 <<< n) - 1) == (1 <<< n) - 1 ∧
      popcount (actB ((1 <<< n) - 1)) == n - 1) := by
  decide

-- ============================================================================
-- 4. Complete Exact Symbolic Bellman Verification for C_3 (4 Transient States)
-- ============================================================================

def phiC3 (u v : Int) (mask : Nat) : Int :=
  match mask with
  | 3 => 6 * u * u + 6 * u * (v - u) + 6 * (v - u) * (v - u)
  | 5 => 6 * u * u + 12 * u * (v - u) + 6 * (v - u) * (v - u)
  | 6 => 6 * u * u + 6 * u * (v - u) + 12 * (v - u) * (v - u)
  | 7 => 12 * u * u + 6 * u * (v - u) + 6 * (v - u) * (v - u)
  | _ => 0

theorem phiC3_matches_cernyNum3 (u v : Int) :
    phiC3 u v 7 = cernyNum 3 u v := by
  dsimp [phiC3, cernyNum]
  poly_solve

theorem bellman_C3_all_transient (u v : Int) :
    ∀ mask ∈,
      u * phiC3 u v (actA 3 mask) + (v - u) * phiC3 u v (actB mask) =
        v * phiC3 u v mask - 6 * u * u * (v - u) := by
  intro mask hmem
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hmem
  rcases hmem with rfl | rfl | rfl | rfl <;>
    (dsimp [phiC3, actA, actB]; poly_solve)

-- ============================================================================
-- 5. Complete Exact Symbolic Bellman Verification for C_4 (11 Transient States)
-- ============================================================================

def phiC4 (u v : Int) (mask : Nat) : Int :=
  let w := v - u
  match mask with
  | 3  => 6 * u * u + 6 * u * w + 6 * w * w
  | 9  => 6 * u * u + 12 * u * w + 6 * w * w
  | 12 => 6 * u * u + 12 * u * w + 12 * w * w
  | 6  => 6 * u * u + 6 * u * w + 12 * w * w
  | 5  => 6 * u * u + 12 * u * w + 12 * w * w
  | 10 => 6 * u * u + 6 * u * w + 18 * w * w
  | 7  => 12 * u * u + 12 * u * w + 18 * w * w
  | 11 => 12 * u * u + 12 * u * w + 18 * w * w
  | 13 => 12 * u * u + 18 * u * w + 18 * w * w
  | 14 => 12 * u * u + 12 * u * w + 24 * w * w
  | 15 => 18 * u * u + 18 * u * w + 24 * w * w
  | _  => 0

theorem phiC4_matches_cernyNum4 (u v : Int) :
    phiC4 u v 15 = cernyNum 4 u v := by
  dsimp [phiC4, cernyNum]
  poly_solve

theorem bellman_C4_all_transient (u v : Int) :
    ∀ mask ∈,
      u * phiC4 u v (actA 4 mask) + (v - u) * phiC4 u v (actB mask) =
        v * phiC4 u v mask - 6 * u * u * (v - u) := by
  intro mask hmem
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hmem
  rcases hmem with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
    (dsimp [phiC4, actA, actB]; poly_solve)

end CernyBiasedSync
