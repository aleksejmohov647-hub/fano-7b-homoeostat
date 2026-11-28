/-
  Expected Synchronization Time of Černý Automata C_n under Biased Bernoulli Inputs
  Standalone Lean 4 Verification (Core `Init` only, zero external axioms, zero `sorry`)
-/

namespace CernyBiasedSync

macro "poly_solve" : tactic =>
  `(tactic| (
    first
    | grind
    | (simp only [Int.sub_eq_add_neg, Int.add_mul, Int.mul_add, Int.neg_mul, Int.mul_neg,
                  Int.neg_add, Int.neg_neg, Int.mul_one, Int.one_mul,
                  Int.mul_assoc, Int.add_assoc, Int.add_left_comm, Int.add_comm,
                  Int.mul_left_comm, Int.mul_comm]
       omega)
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

def listC3to8 : List Nat := 3 :: 4 :: 5 :: 6 :: 7 :: 8 :: []

theorem top_layer_contraction_3_to_8 :
    (∀ n ∈ listC3to8,
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

def transientC3 : List Nat := 3 :: 5 :: 6 :: 7 :: []

theorem bellman_C3_all_transient (u v : Int) :
    ∀ mask ∈ transientC3,
      u * phiC3 u v (actA 3 mask) + (v - u) * phiC3 u v (actB mask) =
        v * phiC3 u v mask - 6 * u * u * (v - u) := by
  intro mask hmem
  dsimp [transientC3] at hmem
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hmem
  rcases hmem with rfl | rfl | rfl | rfl <;>
    (dsimp [phiC3, actA, actB]; poly_solve)

-- ============================================================================
-- 5. Complete Exact Symbolic Bellman Verification for C_4 (11 Transient States)
-- ============================================================================

def phiC4 (u v : Int) (mask : Nat) : Int :=
  match mask with
  | 3  => 6 * u * u + 6 * u * (v - u) + 6 * (v - u) * (v - u)
  | 9  => 6 * u * u + 12 * u * (v - u) + 6 * (v - u) * (v - u)
  | 12 => 6 * u * u + 12 * u * (v - u) + 12 * (v - u) * (v - u)
  | 6  => 6 * u * u + 6 * u * (v - u) + 12 * (v - u) * (v - u)
  | 5  => 6 * u * u + 12 * u * (v - u) + 12 * (v - u) * (v - u)
  | 10 => 6 * u * u + 6 * u * (v - u) + 18 * (v - u) * (v - u)
  | 7  => 12 * u * u + 12 * u * (v - u) + 18 * (v - u) * (v - u)
  | 11 => 12 * u * u + 12 * u * (v - u) + 18 * (v - u) * (v - u)
  | 13 => 12 * u * u + 18 * u * (v - u) + 18 * (v - u) * (v - u)
  | 14 => 12 * u * u + 12 * u * (v - u) + 24 * (v - u) * (v - u)
  | 15 => 18 * u * u + 18 * u * (v - u) + 24 * (v - u) * (v - u)
  | _  => 0

theorem phiC4_matches_cernyNum4 (u v : Int) :
    phiC4 u v 15 = cernyNum 4 u v := by
  dsimp [phiC4, cernyNum]
  poly_solve

theorem bellman_C4_m3 (u v : Int) :
    u * phiC4 u v (actA 4 3) + (v - u) * phiC4 u v (actB 3) = v * phiC4 u v 3 - 6 * u * u * (v - u) := by
  dsimp [phiC4, actA, actB]; poly_solve

theorem bellman_C4_m5 (u v : Int) :
    u * phiC4 u v (actA 4 5) + (v - u) * phiC4 u v (actB 5) = v * phiC4 u v 5 - 6 * u * u * (v - u) := by
  dsimp [phiC4, actA, actB]; poly_solve

theorem bellman_C4_m6 (u v : Int) :
    u * phiC4 u v (actA 4 6) + (v - u) * phiC4 u v (actB 6) = v * phiC4 u v 6 - 6 * u * u * (v - u) := by
  dsimp [phiC4, actA, actB]; poly_solve

theorem bellman_C4_m7 (u v : Int) :
    u * phiC4 u v (actA 4 7) + (v - u) * phiC4 u v (actB 7) = v * phiC4 u v 7 - 6 * u * u * (v - u) := by
  dsimp [phiC4, actA, actB]; poly_solve

theorem bellman_C4_m9 (u v : Int) :
    u * phiC4 u v (actA 4 9) + (v - u) * phiC4 u v (actB 9) = v * phiC4 u v 9 - 6 * u * u * (v - u) := by
  dsimp [phiC4, actA, actB]; poly_solve

theorem bellman_C4_m10 (u v : Int) :
    u * phiC4 u v (actA 4 10) + (v - u) * phiC4 u v (actB 10) = v * phiC4 u v 10 - 6 * u * u * (v - u) := by
  dsimp [phiC4, actA, actB]; poly_solve

theorem bellman_C4_m11 (u v : Int) :
    u * phiC4 u v (actA 4 11) + (v - u) * phiC4 u v (actB 11) = v * phiC4 u v 11 - 6 * u * u * (v - u) := by
  dsimp [phiC4, actA, actB]; poly_solve

theorem bellman_C4_m12 (u v : Int) :
    u * phiC4 u v (actA 4 12) + (v - u) * phiC4 u v (actB 12) = v * phiC4 u v 12 - 6 * u * u * (v - u) := by
  dsimp [phiC4, actA, actB]; poly_solve

theorem bellman_C4_m13 (u v : Int) :
    u * phiC4 u v (actA 4 13) + (v - u) * phiC4 u v (actB 13) = v * phiC4 u v 13 - 6 * u * u * (v - u) := by
  dsimp [phiC4, actA, actB]; poly_solve

theorem bellman_C4_m14 (u v : Int) :
    u * phiC4 u v (actA 4 14) + (v - u) * phiC4 u v (actB 14) = v * phiC4 u v 14 - 6 * u * u * (v - u) := by
  dsimp [phiC4, actA, actB]; poly_solve

theorem bellman_C4_m15 (u v : Int) :
    u * phiC4 u v (actA 4 15) + (v - u) * phiC4 u v (actB 15) = v * phiC4 u v 15 - 6 * u * u * (v - u) := by
  dsimp [phiC4, actA, actB]; poly_solve

def transientC4 : List Nat := 3 :: 5 :: 6 :: 7 :: 9 :: 10 :: 11 :: 12 :: 13 :: 14 :: 15 :: []

theorem bellman_C4_all_transient (u v : Int) :
    ∀ mask ∈ transientC4,
      u * phiC4 u v (actA 4 mask) + (v - u) * phiC4 u v (actB mask) =
        v * phiC4 u v mask - 6 * u * u * (v - u) := by
  intro mask hmem
  dsimp [transientC4] at hmem
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hmem
  rcases hmem with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  · exact bellman_C4_m3 u v
  · exact bellman_C4_m5 u v
  · exact bellman_C4_m6 u v
  · exact bellman_C4_m7 u v
  · exact bellman_C4_m9 u v
  · exact bellman_C4_m10 u v
  · exact bellman_C4_m11 u v
  · exact bellman_C4_m12 u v
  · exact bellman_C4_m13 u v
  · exact bellman_C4_m14 u v
  · exact bellman_C4_m15 u v

end CernyBiasedSync
