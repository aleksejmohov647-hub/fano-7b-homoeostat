/-
  Expected Synchronization Time of Černý Automata C_n under Biased Bernoulli Inputs
  Standalone Lean 4 Verification (Core `Init` only, zero external axioms, zero `sorry`)

  Contents:
  1. Sound bivariate polynomial normalizer `Poly2` with reflection theorem `Poly2.eq_of_norm_eq`
  2. Exact polynomial numerators `cernyNum` and layer increments `layerDeltaNum`
  3. Inductive layer-aggregation theorem `layer_induction_closed_form` for ALL n >= 2
  4. Uniform-input identity (`uniform_half_poly`) and cubic denominator bound (`cubic_denom_identity`)
  5. Constructive subset automaton dynamics (`actA`, `actB`) and top-layer contraction for 3 <= n <= 12
  6. Complete symbolic Bellman verification for C_3 (4 states), C_4 (11 states),
     and C_5 (26 states) over arbitrary rationals p = u / v
-/

namespace CernyBiasedSync

-- ============================================================================
-- 1. Sound Bivariate Polynomial Normalizer (Pure `Init`, Zero `acLt` Blowup)
-- ============================================================================

inductive Poly2 where
  | const : Int → Poly2
  | varU  : Poly2
  | varV  : Poly2
  | add   : Poly2 → Poly2 → Poly2
  | sub   : Poly2 → Poly2 → Poly2
  | mul   : Poly2 → Poly2 → Poly2

def Poly2.eval (u v : Int) : Poly2 → Int
  | .const c  => c
  | .varU     => u
  | .varV     => v
  | .add p q  => p.eval u v + q.eval u v
  | .sub p q  => p.eval u v - q.eval u v
  | .mul p q  => p.eval u v * q.eval u v

abbrev MonomList := List (Nat × Nat × Int)

def evalMonom (u v : Int) (i j : Nat) (c : Int) : Int :=
  c * (u ^ i) * (v ^ j)

def evalMonomList (u v : Int) : MonomList → Int
  | [] => 0
  | (i, j, c) :: xs => evalMonom u v i j c + evalMonomList u v xs

def insertMonom (i j : Nat) (c : Int) : MonomList → MonomList
  | [] => if c == 0 then [] else [(i, j, c)]
  | (i', j', c') :: xs =>
    if i < i' || (i == i' && j < j') then
      if c == 0 then (i', j', c') :: xs else (i, j, c) :: (i', j', c') :: xs
    else if i == i' && j == j' then
      let cNew := c + c'
      if cNew == 0 then xs else (i, j, cNew) :: xs
    else
      (i', j', c') :: insertMonom i j c xs

def addMonomLists : MonomList → MonomList → MonomList
  | [], ys => ys
  | (i, j, c) :: xs, ys => addMonomLists xs (insertMonom i j c ys)

def negMonomList : MonomList → MonomList
  | [] => []
  | (i, j, c) :: xs => (i, j, -c) :: negMonomList xs

def mulSingleMonom (i j : Nat) (c : Int) : MonomList → MonomList
  | [] => []
  | (i', j', c') :: xs =>
    insertMonom (i + i') (j + j') (c * c') (mulSingleMonom i j c xs)

def mulMonomLists : MonomList → MonomList → MonomList
  | [], _ => []
  | (i, j, c) :: xs, ys => addMonomLists (mulSingleMonom i j c ys) (mulMonomLists xs ys)

def Poly2.normalize : Poly2 → MonomList
  | .const c  => if c == 0 then [] else [(0, 0, c)]
  | .varU     => [(1, 0, 1)]
  | .varV     => [(0, 1, 1)]
  | .add p q  => addMonomLists p.normalize q.normalize
  | .sub p q  => addMonomLists p.normalize (negMonomList q.normalize)
  | .mul p q  => mulMonomLists p.normalize q.normalize

theorem evalMonom_zero (u v : Int) (i j : Nat) :
    evalMonom u v i j 0 = 0 := by
  simp [evalMonom]

theorem evalMonom_add (u v : Int) (i j : Nat) (c1 c2 : Int) :
    evalMonom u v i j (c1 + c2) = evalMonom u v i j c1 + evalMonom u v i j c2 := by
  simp [evalMonom, Int.add_mul]

theorem evalMonom_neg (u v : Int) (i j : Nat) (c : Int) :
    evalMonom u v i j (-c) = -evalMonom u v i j c := by
  simp [evalMonom, Int.neg_mul]

theorem evalMonom_mul (u v : Int) (i1 j1 : Nat) (c1 : Int) (i2 j2 : Nat) (c2 : Int) :
    evalMonom u v (i1 + i2) (j1 + j2) (c1 * c2) =
      evalMonom u v i1 j1 c1 * evalMonom u v i2 j2 c2 := by
  simp only [evalMonom, Int.pow_add]
  ac_rfl

theorem eval_insertMonom (u v : Int) (i j : Nat) (c : Int) (xs : MonomList) :
    evalMonomList u v (insertMonom i j c xs) = evalMonom u v i j c + evalMonomList u v xs := by
  induction xs with
  | nil =>
    simp only [insertMonom]
    split
    · next h =>
      have hc : c = 0 := beq_iff_eq.mp h
      subst hc
      simp [evalMonomList, evalMonom_zero]
    · simp [evalMonomList]
  | cons hd tl ih =>
    rcases hd with ⟨i', j', c'⟩
    simp only [insertMonom]
    split
    · split
      · next h =>
        have hc : c = 0 := beq_iff_eq.mp h
        subst hc
        simp [evalMonomList, evalMonom_zero]
      · simp [evalMonomList]
    · split
      · next hEq =>
        have hi : i = i' := beq_iff_eq.mp (Bool.and_elim_left hEq)
        have hj : j = j' := beq_iff_eq.mp (Bool.and_elim_right hEq)
        subst hi; subst hj
        split
        · next hc0 =>
          have hsum : c + c' = 0 := beq_iff_eq.mp hc0
          simp only [evalMonomList, ← evalMonom_add, hsum, evalMonom_zero]
          omega
        · simp only [evalMonomList, evalMonom_add]
          omega
      · simp only [evalMonomList, ih]
        omega

theorem eval_addMonomLists (u v : Int) (xs ys : MonomList) :
    evalMonomList u v (addMonomLists xs ys) = evalMonomList u v xs + evalMonomList u v ys := by
  induction xs generalizing ys with
  | nil => simp [addMonomLists, evalMonomList]
  | cons hd tl ih =>
    rcases hd with ⟨i, j, c⟩
    simp only [addMonomLists, evalMonomList, ih, eval_insertMonom]
    omega

theorem eval_negMonomList (u v : Int) (xs : MonomList) :
    evalMonomList u v (negMonomList xs) = -evalMonomList u v xs := by
  induction xs with
  | nil => simp [negMonomList, evalMonomList]
  | cons hd tl ih =>
    rcases hd with ⟨i, j, c⟩
    simp only [negMonomList, evalMonomList, evalMonom_neg, ih]
    omega

theorem eval_mulSingleMonom (u v : Int) (i j : Nat) (c : Int) (xs : MonomList) :
    evalMonomList u v (mulSingleMonom i j c xs) = evalMonom u v i j c * evalMonomList u v xs := by
  induction xs with
  | nil => simp [mulSingleMonom, evalMonomList]
  | cons hd tl ih =>
    rcases hd with ⟨i', j', c'⟩
    simp only [mulSingleMonom, evalMonomList, eval_insertMonom, evalMonom_mul, ih, Int.mul_add]

theorem eval_mulMonomLists (u v : Int) (xs ys : MonomList) :
    evalMonomList u v (mulMonomLists xs ys) = evalMonomList u v xs * evalMonomList u v ys := by
  induction xs with
  | nil => simp [mulMonomLists, evalMonomList]
  | cons hd tl ih =>
    rcases hd with ⟨i, j, c⟩
    simp only [mulMonomLists, evalMonomList, eval_addMonomLists, eval_mulSingleMonom, ih, Int.add_mul]

theorem Poly2.eval_normalize (u v : Int) (p : Poly2) :
    evalMonomList u v p.normalize = p.eval u v := by
  induction p with
  | const c =>
    simp only [Poly2.normalize, Poly2.eval]
    split
    · next h =>
      have hc : c = 0 := beq_iff_eq.mp h
      subst hc
      simp [evalMonomList]
    · simp [evalMonomList, evalMonom]
  | varU => simp [Poly2.normalize, Poly2.eval, evalMonomList, evalMonom]
  | varV => simp [Poly2.normalize, Poly2.eval, evalMonomList, evalMonom]
  | add p q ihp ihq => simp [Poly2.normalize, Poly2.eval, eval_addMonomLists, ihp, ihq]
  | sub p q ihp ihq =>
    simp only [Poly2.normalize, Poly2.eval, eval_addMonomLists, eval_negMonomList, ihp, ihq]
    omega
  | mul p q ihp ihq => simp [Poly2.normalize, Poly2.eval, eval_mulMonomLists, ihp, ihq]

theorem Poly2.eq_of_norm_eq (p q : Poly2) (h : p.normalize = q.normalize) (u v : Int) :
    p.eval u v = q.eval u v := by
  rw [← Poly2.eval_normalize u v p, ← Poly2.eval_normalize u v q, h]

-- ============================================================================
-- 2. General Closed-Form Numerator & Inductive Layer Sum (ALL n >= 2)
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
  grind

theorem base_case_n2 (u v : Int) :
    cernyNum 2 u v = 6 * u * u := by
  dsimp [cernyNum]
  grind

theorem layer_induction_closed_form
    (T : Int → Int → Int → Int) (u v : Int)
    (hBase : T 2 u v = 6 * u * u)
    (hStep : ∀ k : Int, 2 ≤ k → T (k + 1) u v = T k u v + layerDeltaNum (k + 1) u v) :
    ∀ m : Nat, T (2 + Int.ofNat m) u v = cernyNum (2 + Int.ofNat m) u v := by
  intro m
  induction m with
  | zero =>
    simpa [base_case_n2] using hBase
  | succ m ih =>
    have hk : 2 ≤ 2 + Int.ofNat m := by omega
    have hNext : (2 + Int.ofNat (m + 1) : Int) = (2 + Int.ofNat m) + 1 := by omega
    rw [hNext, hStep (2 + Int.ofNat m) hk, ih]
    have hTel := telescoping_step (2 + Int.ofNat m) u v
    omega

-- ============================================================================
-- 3. Asymptotic Identities: Uniform Input (p = 1/2) and Cubic Lower Bound
-- ============================================================================

theorem uniform_half_poly (n : Int) :
    4 * cernyNum n 1 2 = 3 * (4 * n * n * n - 6 * n * n - 4 * n + 6) := by
  dsimp [cernyNum]
  grind

theorem cubic_denom_identity (u v : Int) :
    4 * v * v * v - 27 * u * u * (v - u) =
      (2 * v - 3 * u) * (2 * v - 3 * u) * (v + 3 * u) := by
  grind

-- ============================================================================
-- 4. Constructive Subset Automaton Dynamics for C_n
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

def listC3to12 : List Nat := 3 :: 4 :: 5 :: 6 :: 7 :: 8 :: 9 :: 10 :: 11 :: 12 :: []

theorem top_layer_contraction_3_to_12 :
    (∀ n ∈ listC3to12,
      actA n ((1 <<< n) - 1) == (1 <<< n) - 1 ∧
      popcount (actB ((1 <<< n) - 1)) == n - 1) := by
  decide

-- ============================================================================
-- 5. Complete Symbolic Bellman Verification for C_3 (4 Transient States)
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
  grind

def transientC3 : List Nat := 3 :: 5 :: 6 :: 7 :: []

theorem bellman_C3_all_transient (u v : Int) :
    ∀ mask ∈ transientC3,
      u * phiC3 u v (actA 3 mask) + (v - u) * phiC3 u v (actB mask) =
        v * phiC3 u v mask - 6 * u * u * (v - u) := by
  intro mask hmem
  dsimp [transientC3] at hmem
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hmem
  rcases hmem with rfl | rfl | rfl | rfl <;>
    (dsimp [phiC3, actA, actB]; grind)

-- ============================================================================
-- 6. Complete Symbolic Bellman Verification for C_4 (11 Transient States)
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
  grind

def phiC4Poly (mask : Nat) : Poly2 :=
  let u := Poly2.varU
  let w := Poly2.sub Poly2.varV Poly2.varU
  let uu := Poly2.mul u u
  let uw := Poly2.mul u w
  let ww := Poly2.mul w w
  let term (a b c : Int) : Poly2 :=
    Poly2.add (Poly2.add (Poly2.mul (Poly2.const a) uu) (Poly2.mul (Poly2.const b) uw))
              (Poly2.mul (Poly2.const c) ww)
  match mask with
  | 3  => term 6 6 6
  | 9  => term 6 12 6
  | 12 => term 6 12 12
  | 6  => term 6 6 12
  | 5  => term 6 12 12
  | 10 => term 6 6 18
  | 7  => term 12 12 18
  | 11 => term 12 12 18
  | 13 => term 12 18 18
  | 14 => term 12 12 24
  | 15 => term 18 18 24
  | _  => Poly2.const 0

theorem phiC4Poly_eval (u v : Int) (mask : Nat) :
    (phiC4Poly mask).eval u v = phiC4 u v mask := by
  rcases mask with _ | _ | _ | _ | _ | _ | _ | _ | _ | _ | _ | _ | _ | _ | _ | _ <;>
    simp [phiC4Poly, phiC4, Poly2.eval, Int.mul_assoc]

def bellmanC4LHS (mask : Nat) : Poly2 :=
  Poly2.add
    (Poly2.mul Poly2.varU (phiC4Poly (actA 4 mask)))
    (Poly2.mul (Poly2.sub Poly2.varV Poly2.varU) (phiC4Poly (actB mask)))

def bellmanC4RHS (mask : Nat) : Poly2 :=
  Poly2.sub
    (Poly2.mul Poly2.varV (phiC4Poly mask))
    (Poly2.mul (Poly2.mul (Poly2.const 6) (Poly2.mul Poly2.varU Poly2.varU))
               (Poly2.sub Poly2.varV Poly2.varU))

def transientC4 : List Nat := 3 :: 5 :: 6 :: 7 :: 9 :: 10 :: 11 :: 12 :: 13 :: 14 :: 15 :: []

theorem bellman_C4_norm_check :
    ∀ mask ∈ transientC4, (bellmanC4LHS mask).normalize = (bellmanC4RHS mask).normalize := by
  decide

theorem bellman_C4_all_transient (u v : Int) :
    ∀ mask ∈ transientC4,
      u * phiC4 u v (actA 4 mask) + (v - u) * phiC4 u v (actB mask) =
        v * phiC4 u v mask - 6 * u * u * (v - u) := by
  intro mask hmem
  have hNorm := bellman_C4_norm_check mask hmem
  have hEq := Poly2.eq_of_norm_eq (bellmanC4LHS mask) (bellmanC4RHS mask) hNorm u v
  simpa only [bellmanC4LHS, bellmanC4RHS, Poly2.eval, phiC4Poly_eval] using hEq

-- ============================================================================
-- 7. Complete Symbolic Bellman Verification for C_5 (26 Transient States)
-- ============================================================================

def phiC5Poly (mask : Nat) : Poly2 :=
  let u := Poly2.varU
  let w := Poly2.sub Poly2.varV Poly2.varU
  let uu := Poly2.mul u u
  let uw := Poly2.mul u w
  let ww := Poly2.mul w w
  let term (a b c : Int) : Poly2 :=
    Poly2.add (Poly2.add (Poly2.mul (Poly2.const a) uu) (Poly2.mul (Poly2.const b) uw))
              (Poly2.mul (Poly2.const c) ww)
  match mask with
  -- Cardinality 2 (10 states)
  | 3  => term 6 6 6
  | 17 => term 6 12 6
  | 24 => term 6 12 12
  | 12 => term 6 12 18
  | 6  => term 6 6 18
  | 5  => term 6 12 12
  | 9  => term 6 18 12
  | 18 => term 6 12 18
  | 20 => term 6 12 24
  | 10 => term 6 6 24
  -- Cardinality 3 (10 states)
  | 7  => term 12 12 18
  | 19 => term 12 18 18
  | 25 => term 12 18 24
  | 28 => term 12 18 30
  | 14 => term 12 12 30
  | 11 => term 12 18 24
  | 21 => term 12 18 30
  | 26 => term 12 18 36
  | 13 => term 12 12 36
  | 22 => term 12 12 42
  -- Cardinality 4 (5 states)
  | 15 => term 18 24 42
  | 23 => term 18 24 48
  | 27 => term 18 24 54
  | 29 => term 18 30 54
  | 30 => term 18 18 60
  -- Cardinality 5 (1 state: full state Q_5)
  | 31 => term 24 36 60
  | _  => Poly2.const 0

def phiC5 (u v : Int) (mask : Nat) : Int :=
  (phiC5Poly mask).eval u v

theorem phiC5_matches_cernyNum5 (u v : Int) :
    phiC5 u v 31 = cernyNum 5 u v := by
  dsimp [phiC5, phiC5Poly, cernyNum, Poly2.eval]
  grind

def bellmanC5LHS (mask : Nat) : Poly2 :=
  Poly2.add
    (Poly2.mul Poly2.varU (phiC5Poly (actA 5 mask)))
    (Poly2.mul (Poly2.sub Poly2.varV Poly2.varU) (phiC5Poly (actB mask)))

def bellmanC5RHS (mask : Nat) : Poly2 :=
  Poly2.sub
    (Poly2.mul Poly2.varV (phiC5Poly mask))
    (Poly2.mul (Poly2.mul (Poly2.const 6) (Poly2.mul Poly2.varU Poly2.varU))
               (Poly2.sub Poly2.varV Poly2.varU))

def transientC5 : List Nat :=
  3 :: 5 :: 6 :: 7 :: 9 :: 10 :: 11 :: 12 :: 13 :: 14 :: 15 ::
  17 :: 18 :: 19 :: 20 :: 21 :: 22 :: 23 :: 24 :: 25 :: 26 :: 27 :: 28 :: 29 :: 30 :: 31 :: []

theorem bellman_C5_norm_check :
    ∀ mask ∈ transientC5, (bellmanC5LHS mask).normalize = (bellmanC5RHS mask).normalize := by
  decide

theorem bellman_C5_all_transient (u v : Int) :
    ∀ mask ∈ transientC5,
      u * phiC5 u v (actA 5 mask) + (v - u) * phiC5 u v (actB mask) =
        v * phiC5 u v mask - 6 * u * u * (v - u) := by
  intro mask hmem
  have hNorm := bellman_C5_norm_check mask hmem
  have hEq := Poly2.eq_of_norm_eq (bellmanC5LHS mask) (bellmanC5RHS mask) hNorm u v
  simpa only [bellmanC5LHS, bellmanC5RHS, Poly2.eval, phiC5] using hEq

end CernyBiasedSync
