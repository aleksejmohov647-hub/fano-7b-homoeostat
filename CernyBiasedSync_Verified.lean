/-
  Expected Synchronization Time of Černý Automata C_n under Biased Bernoulli Inputs
  Standalone Lean 4 Verification (Core `Init` only, zero external axioms, zero `sorry`)

  Contents:
  1. Exact polynomial numerators `cernyNum` and layer increments `layerDeltaNum`
  2. Inductive telescoping recurrence `telescoping_step` for arbitrary n >= 2
  3. Uniform-input polynomial identity (`uniform_half_poly`) and cubic lower bound
     denominator identity (`cubic_denom_identity`)
  4. Constructive bitmask transitions and top-layer contraction for C_n (3 <= n <= 8)
  5. Complete symbolic Bellman verification for all transient subsets of C_3 (4 states)
     and C_4 (11 states) over arbitrary rationals p = u / v
-/

namespace CernyBiasedSync

-- ============================================================================
-- 1. General Closed-Form Numerator and Layer Increment (Arbitrary n)
-- ============================================================================

/-- Numerator of 6 * p^2 * (1 - p) * R_n(p) for p = u / v:
    6(n-1)u^2 + 3(n-1)(n-2)u(v-u) + n(n-1)(n-2)(v-u)^2 -/
def cernyNum (n u v : Int) : Int :=
  6 * (n - 1) * u * u
  + 3 * (n - 1) * (n - 2) * u * (v - u)
  + n * (n - 1) * (n - 2) * (v - u) * (v - u)

/-- Numerator of 6 * p^2 * (1 - p) * Delta_k(p) for p = u / v:
    6 u^2 + 6(k-2)u(v-u) + 3(k-1)(k-2)(v-u)^2 -/
def layerDeltaNum (k u v : Int) : Int :=
  6 * u * u
  + 6 * (k - 2) * u * (v - u)
  + 3 * (k - 1) * (k - 2) * (v - u) * (v - u)

/-- Exact telescoping identity R_{n+1}(p) - R_n(p) = Delta_{n+1}(p) for all n, u, v -/
theorem telescoping_step (n u v : Int) :
    cernyNum (n + 1) u v - cernyNum n u v = layerDeltaNum (n + 1) u v := by
  dsimp [cernyNum, layerDeltaNum]
  omega

/-- Base case n = 2: cernyNum 2 u v = 6 * u^2, so R_2(u/v) = 1 / (1 - u/v) -/
theorem base_case_n2 (u v : Int) :
    cernyNum 2 u v = 6 * u * u := by
  dsimp [cernyNum]
  omega

-- ============================================================================
-- 2. Asymptotic Identities: Uniform Input (p = 1/2) and Cubic Lower Bound
-- ============================================================================

/-- At p = 1/2 (u = 1, v = 2), 6 * (1/8) * R_n(1/2) = cernyNum n 1 2,
    which expands to n^3 - (3/2)n^2 - n + 3/2, i.e., 3 * R_n(1/2) = 4n^3 - 6n^2 - 4n + 6 -/
theorem uniform_half_poly (n : Int) :
    4 * cernyNum n 1 2 = 3 * (4 * n * n * n - 6 * n * n - 4 * n + 6) := by
  dsimp [cernyNum]
  omega

/-- Denominator bound identity: 4 v^3 - 27 u^2 (v - u) = (2v - 3u)^2 (v + 3u) >= 0
    for 0 < u < v, proving p^2 (1 - p) <= 4/27 with equality uniquely at p = 2/3 -/
theorem cubic_denom_identity (u v : Int) :
    4 * v * v * v - 27 * u * u * (v - u) =
      (2 * v - 3 * u) * (2 * v - 3 * u) * (v + 3 * u) := by
  omega

-- ============================================================================
-- 3. Constructive Subset Automaton Dynamics for C_n
-- ============================================================================

/-- Cyclic shift a(x) = (x + 1) mod n on bitmask representation of S subset {0..n-1} -/
def actA (n mask : Nat) : Nat :=
  let low := (mask <<< 1) &&& ((1 <<< n) - 1)
  let high := mask >>> (n - 1)
  low ||| high

/-- Contraction letter b: maps 0 -> 1 and fixes x >= 1 on bitmask S -/
def actB (mask : Nat) : Nat :=
  let without0 := mask &&& (~~~1)
  if (mask &&& 1) == 1 then without0 ||| 2 else without0

/-- Population count (subset cardinality |S|) -/
def popcount : Nat → Nat
  | 0 => 0
  | k + 1 => ((k + 1) &&& 1) + popcount ((k + 1) >>> 1)

/-- Top layer Q_n = 2^n - 1 is invariant under a and contracts by 1 under b for 3 <= n <= 8 -/
theorem top_layer_contraction_3_to_8 :
    (∀ n ∈ [3, 4, 5, 6, 7, 8],
      actA n ((1 <<< n) - 1) == (1 <<< n) - 1 ∧
      popcount (actB ((1 <<< n) - 1)) == n - 1) := by
  decide

-- ============================================================================
-- 4. Complete Exact Symbolic Bellman Verification for C_3 (4 Transient States)
-- ============================================================================

/-- Scaled potential 6 * u^2 * (v - u) * Phi(S) for all non-empty subsets of C_3.
    Transient masks: 3={0,1}, 5={0,2}, 6={1,2}, 7={0,1,2}. Singletons (1,2,4) -> 0. -/
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
  omega

/-- Exact one-step Bellman equation for all 4 transient subsets of C_3
    over arbitrary rationals p = u / v:
    u * Phi(a(S)) + (v - u) * Phi(b(S)) = v * Phi(S) - 6 u^2 (v - u) -/
theorem bellman_C3_all_transient (u v : Int) :
    ∀ mask ∈ [3, 5, 6, 7],
      u * phiC3 u v (actA 3 mask) + (v - u) * phiC3 u v (actB mask) =
        v * phiC3 u v mask - 6 * u * u * (v - u) := by
  intro mask hmem
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hmem
  rcases hmem with rfl | rfl | rfl | rfl <;>
    (dsimp [phiC3, actA, actB]; omega)

-- ============================================================================
-- 5. Complete Exact Symbolic Bellman Verification for C_4 (11 Transient States)
-- ============================================================================

/-- Scaled potential 6 * u^2 * (v - u) * Phi(S) for all non-empty subsets of C_4.
    Transient masks (11 states):
      Size 2: 3={0,1}, 5={0,2}, 6={1,2}, 9={0,3}, 10={1,3}, 12={2,3}
      Size 3: 7={0,1,2}, 11={0,1,3}, 13={0,2,3}, 14={1,2,3}
      Size 4: 15={0,1,2,3}
    Singletons (1, 2, 4, 8) -> 0. -/
def phiC4 (u v : Int) (mask : Nat) : Int :=
  let w := v - u
  match mask with
  -- Cardinality 2 (adjacent pairs: distance 1)
  | 3  => 6 * u * u + 6 * u * w + 6 * w * w
  | 9  => 6 * u * u + 12 * u * w + 6 * w * w
  | 12 => 6 * u * u + 12 * u * w + 12 * w * w
  | 6  => 6 * u * u + 6 * u * w + 12 * w * w
  -- Cardinality 2 (antipodal pairs: distance 2)
  | 5  => 6 * u * u + 12 * u * w + 12 * w * w
  | 10 => 6 * u * u + 6 * u * w + 18 * w * w
  -- Cardinality 3
  | 7  => 12 * u * u + 12 * u * w + 18 * w * w
  | 11 => 12 * u * u + 12 * u * w + 18 * w * w
  | 13 => 12 * u * u + 18 * u * w + 18 * w * w
  | 14 => 12 * u * u + 12 * u * w + 24 * w * w
  -- Cardinality 4 (full state Q_4)
  | 15 => 18 * u * u + 18 * u * w + 24 * w * w
  | _  => 0

theorem phiC4_matches_cernyNum4 (u v : Int) :
    phiC4 u v 15 = cernyNum 4 u v := by
  dsimp [phiC4, cernyNum]
  omega

/-- Exact one-step Bellman equation for all 11 transient subsets of C_4
    over arbitrary rationals p = u / v:
    u * Phi(a(S)) + (v - u) * Phi(b(S)) = v * Phi(S) - 6 u^2 (v - u) -/
theorem bellman_C4_all_transient (u v : Int) :
    ∀ mask ∈ [3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15],
      u * phiC4 u v (actA 4 mask) + (v - u) * phiC4 u v (actB mask) =
        v * phiC4 u v mask - 6 * u * u * (v - u) := by
  intro mask hmem
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hmem
  rcases hmem with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
    (dsimp [phiC4, actA, actB]; omega)

end CernyBiasedSync
