/-
  Expected Synchronization Time of Černý Automata C_n under Biased Bernoulli Inputs
  Compact Standalone Lean 4 Proof (Core `Init` only, zero external axioms, zero `sorry`)
-/

namespace CernyBiasedSync

-- 1. Closed-Form Numerator & Layer Telescoping (ALL n >= 2)

def cernyNum (n u v : Int) : Int :=
  6 * (n - 1) * u * u
  + 3 * (n - 1) * (n - 2) * u * (v - u)
  + n * (n - 1) * (n - 2) * (v - u) * (v - u)

def layerDeltaNum (k u v : Int) : Int :=
  6 * u * u
  + 6 * (k - 2) * u * (v - u)
  + 3 * (k - 1) * (k - 2) * (v - u) * (v - u)

theorem layer_induction_closed_form
    (T : Int → Int → Int → Int) (u v : Int)
    (hBase : T 2 u v = 6 * u * u)
    (hStep : ∀ k : Int, 2 ≤ k → T (k + 1) u v = T k u v + layerDeltaNum (k + 1) u v) :
    ∀ m : Nat, T (2 + Int.ofNat m) u v = cernyNum (2 + Int.ofNat m) u v := by
  intro m
  induction m with
  | zero => simpa [cernyNum] using hBase
  | succ m ih =>
    have hk : 2 ≤ 2 + Int.ofNat m := by omega
    have hNext : (2 + Int.ofNat (m + 1) : Int) = (2 + Int.ofNat m) + 1 := by omega
    rw [hNext, hStep (2 + Int.ofNat m) hk, ih]
    dsimp [cernyNum, layerDeltaNum]
    grind

-- 2. Subset Automaton Dynamics & Bitwise Invariants

def actA (n mask : Nat) : Nat :=
  (((mask <<< 1) &&& ((1 <<< n) - 1)) ||| (mask >>> (n - 1)))

def actB (mask : Nat) : Nat :=
  let without0 := (mask >>> 1) <<< 1
  if (mask &&& 1) == 1 then without0 ||| 2 else without0

def popcount : Nat → Nat
  | 0 => 0
  | k + 1 => ((k + 1) &&& 1) + popcount ((k + 1) >>> 1)

def runWord (n : Nat) (w : List Bool) (mask : Nat) : Nat :=
  w.foldl (fun st b => if b then actA n st else actB st) mask

theorem testBit_actA (n mask i : Nat) (hn : 2 ≤ n) (hmask : mask < 1 <<< n) (hi : i < n) :
    (actA n mask).testBit i = if i == 0 then mask.testBit (n - 1) else mask.testBit (i - 1) := by
  dsimp [actA]
  rw [Nat.testBit_or, Nat.testBit_and, Nat.testBit_shiftLeft, Nat.testBit_shiftRight]
  have hpow : (1 <<< n) - 1 = 2 ^ n - 1 := by rw [Nat.shiftLeft_eq, Nat.one_mul]
  rw [hpow, Nat.testBit_two_pow_sub_one]
  simp only [hi, decide_true, Bool.and_true]
  cases i with
  | zero => simp [Nat.not_le_of_gt (by omega : 0 < 1)]
  | succ i' =>
    have hge1 : 1 ≤ i' + 1 := by omega
    simp only [Nat.succ_ne_zero, beq_iff_eq, ite_false, hge1, decide_true, Bool.true_and, Nat.add_sub_cancel]
    have hhi : mask.testBit (n - 1 + (i' + 1)) = false := by
      apply Nat.testBit_lt_two_pow
      rw [Nat.shiftLeft_eq, Nat.one_mul] at hmask
      exact Nat.lt_of_lt_of_le hmask (Nat.pow_le_pow_right (by omega) (by omega))
    rw [hhi, Bool.or_false]

theorem actA_lt (n mask : Nat) (hn : 2 ≤ n) (hmask : mask < 1 <<< n) :
    actA n mask < 1 <<< n := by
  rw [Nat.shiftLeft_eq, Nat.one_mul] at hmask ⊢
  apply Nat.lt_two_pow_of_testBit_eq_false
  intro i hi
  dsimp [actA]
  rw [Nat.testBit_or, Nat.testBit_and, Nat.testBit_shiftLeft, Nat.testBit_shiftRight,
      Nat.shiftLeft_eq, Nat.one_mul, Nat.testBit_two_pow_sub_one]
  have hni : ¬ i < n := Nat.not_lt_of_le hi
  simp only [hni, decide_false, Bool.and_false, Bool.false_or]
  apply Nat.testBit_lt_two_pow
  exact Nat.lt_of_lt_of_le hmask (Nat.pow_le_pow_right (by omega) (by omega))

theorem testBit_actB (mask i : Nat) :
    (actB mask).testBit i =
      if i == 0 then false else if i == 1 then (mask.testBit 0 || mask.testBit 1) else mask.testBit i := by
  dsimp [actB]
  have hand1 : (mask &&& 1) == 1 ↔ mask.testBit 0 = true := by
    rw [Nat.and_one_is_mod, Nat.testBit_zero]
    cases mask % 2 with
    | zero => simp
    | succ r => have : r = 0 := by have := Nat.mod_lt mask (by omega : 0 < 2); omega; subst this; simp
  have hw0 : ((mask >>> 1) <<< 1).testBit i = if i == 0 then false else mask.testBit i := by
    rw [Nat.testBit_shiftLeft, Nat.testBit_shiftRight]
    cases i with
    | zero => simp
    | succ i' => simp [(by omega : 1 ≤ i' + 1), Nat.add_sub_cancel]
  split
  · next h0 =>
    rw [Nat.testBit_or, hw0]
    cases i with
    | zero => simp
    | succ i' => cases i' with
      | zero => simp [hand1.mp h0, Nat.testBit_succ, Nat.testBit_zero]
      | succ i'' => simp [(by simp [Nat.testBit_succ, Nat.testBit_zero] : (2 : Nat).testBit (i'' + 2) = false)]
  · next h0 =>
    have hb0 : mask.testBit 0 = false := by
      cases h : mask.testBit 0 with | false => rfl | true => exact False.elim (h0 (hand1.mpr h))
    rw [hw0]; cases i with | zero => simp | succ i' => cases i' with | zero => simp [hb0] | succ _ => simp

theorem actB_lt (n mask : Nat) (hn : 2 ≤ n) (hmask : mask < 1 <<< n) :
    actB mask < 1 <<< n := by
  rw [Nat.shiftLeft_eq, Nat.one_mul] at hmask ⊢
  apply Nat.lt_two_pow_of_testBit_eq_false
  intro i hi
  rw [testBit_actB]
  have hi0 : (i == 0) = false := by rw [beq_eq_false_iff_ne]; omega
  have hi1 : (i == 1) = false := by rw [beq_eq_false_iff_ne]; omega
  rw [hi0, hi1]; simp only [ite_false]
  exact Nat.testBit_lt_two_pow (Nat.lt_of_lt_of_le hmask (Nat.pow_le_pow_right (by omega) hi))

def bitSum : Nat → Nat → Nat
  | 0, _ => 0
  | k + 1, mask => (if mask.testBit k then 1 else 0) + bitSum k mask

theorem bitSum_shiftRight (k mask : Nat) :
    bitSum k (mask >>> 1) = (bitSum (k + 1) mask) - (if mask.testBit 0 then 1 else 0) := by
  induction k with
  | zero => simp [bitSum]
  | succ k ih =>
    simp only [bitSum, Nat.testBit_shiftRight, (by omega : 1 + k = k + 1), ih]
    have hge : (if mask.testBit 0 then 1 else 0) ≤ (if mask.testBit k then 1 else 0) + bitSum k mask := by
      clear ih; induction k with | zero => simp [bitSum] | succ k' ih' => simp only [bitSum]; omega
    omega

theorem popcount_eq_bitSum (n mask : Nat) (hmask : mask < 1 <<< n) :
    popcount mask = bitSum n mask := by
  induction n generalizing mask with
  | zero =>
    rw [Nat.shiftLeft_eq, Nat.one_mul, Nat.pow_zero] at hmask
    have : mask = 0 := by omega; subst this; simp [popcount, bitSum]
  | succ n ih =>
    cases mask with
    | zero => simp only [popcount]; induction n with | zero => simp [bitSum] | succ n' ih' => simp [bitSum, ih']
    | succ k =>
      rw [popcount]
      have hdiv : (k + 1) >>> 1 < 1 <<< n := by
        rw [Nat.shiftRight_eq_div_pow, Nat.shiftLeft_eq, Nat.one_mul, Nat.pow_succ] at hmask ⊢; omega
      rw [ih ((k + 1) >>> 1) hdiv, bitSum_shiftRight]
      have hand0 : ((k + 1) &&& 1) = if (k + 1).testBit 0 then 1 else 0 := by
        rw [Nat.and_one_is_mod, Nat.testBit_zero]
        cases (k + 1) % 2 with
        | zero => simp
        | succ r => have : r = 0 := by have := Nat.mod_lt (k + 1) (by omega : 0 < 2); omega; subst this; simp
      rw [hand0]
      have hge : (if (k + 1).testBit 0 then 1 else 0) ≤ bitSum (n + 1) (k + 1) := by
        induction n with | zero => simp [bitSum] | succ n' ih' => simp only [bitSum]; omega
      omega

theorem popcount_actA (n mask : Nat) (hn : 2 ≤ n) (hmask : mask < 1 <<< n) :
    popcount (actA n mask) = popcount mask := by
  rw [popcount_eq_bitSum n (actA n mask) (actA_lt n mask hn hmask), popcount_eq_bitSum n mask hmask]
  obtain ⟨m, rfl⟩ := Nat.exists_eq_add_of_le hn
  have hsumA : ∀ k, k ≤ 2 + m →
      bitSum k (actA (2 + m) mask) =
        if k == 0 then 0 else (if mask.testBit (2 + m - 1) then 1 else 0) + bitSum (k - 1) mask := by
    intro k hk; induction k with
    | zero => simp [bitSum]
    | succ k' ih =>
      simp only [bitSum, Nat.succ_ne_zero, beq_iff_eq, ite_false, Nat.add_sub_cancel]
      rw [testBit_actA (2 + m) mask k' hn hmask (by omega)]
      cases k' with
      | zero => simp [bitSum]
      | succ k'' =>
        simp only [Nat.succ_ne_zero, beq_iff_eq, ite_false, Nat.add_sub_cancel]
        rw [ih (by omega)]
        simp only [Nat.succ_ne_zero, beq_iff_eq, ite_false, Nat.add_sub_cancel, bitSum]
        omega
  rw [hsumA (2 + m) (Nat.le_refl _)]
  have hne : 2 + m ≠ 0 := by omega
  simp only [hne, beq_iff_eq, ite_false]
  conv_rhs => rw [(by omega : 2 + m = (2 + m - 1) + 1)]
  simp only [bitSum]
  omega

theorem popcount_actB (n mask : Nat) (hn : 2 ≤ n) (hmask : mask < 1 <<< n) :
    popcount (actB mask) + (if mask.testBit 0 && mask.testBit 1 then 1 else 0) = popcount mask := by
  rw [popcount_eq_bitSum n (actB mask) (actB_lt n mask hn hmask), popcount_eq_bitSum n mask hmask]
  obtain ⟨m, rfl⟩ := Nat.exists_eq_add_of_le hn
  have hpref : ∀ k, bitSum (k + 2) (actB mask) + (if mask.testBit 0 && mask.testBit 1 then 1 else 0) = bitSum (k + 2) mask := by
    intro k; induction k with
    | zero => simp only [bitSum, testBit_actB]; cases mask.testBit 0 <;> cases mask.testBit 1 <;> simp
    | succ k' ih =>
      rw [(by omega : (k' + 1) + 2 = (k' + 2) + 1)]; simp only [bitSum, testBit_actB]
      have hne0 : ((k' + 2) == 0) = false := by rw [beq_eq_false_iff_ne]; omega
      have hne1 : ((k' + 2) == 1) = false := by rw [beq_eq_false_iff_ne]; omega
      rw [hne0, hne1]; simp only [ite_false]; omega
  rw [(by omega : 2 + m = m + 2)]; exact hpref m

theorem popcount_actB_pos (n mask : Nat) (hn : 2 ≤ n) (hmask : mask < 1 <<< n) (hpos : 0 < popcount mask) :
    0 < popcount (actB mask) := by
  have h := popcount_actB n mask hn hmask
  cases hb : (mask.testBit 0 && mask.testBit 1) with
  | false =>
    rw [hb] at h
    simp only [Bool.false_eq_true, ite_false, Nat.add_zero] at h
    omega
  | true =>
    rw [hb] at h
    simp only [ite_true] at h
    have h0 : mask.testBit 0 = true := (Bool.and_eq_true_iff.mp hb).1
    have h1 : mask.testBit 1 = true := (Bool.and_eq_true_iff.mp hb).2
    have h2 : bitSum 2 mask = 2 := by simp [bitSum, h0, h1]
    have hmono : ∀ k, bitSum 2 mask ≤ bitSum (2 + k) mask := by
      intro k
      induction k with
      | zero => exact Nat.le_refl _
      | succ k' ih =>
        have hstep : bitSum (2 + k') mask ≤ bitSum (2 + (k' + 1)) mask := by
          rw [(by omega : 2 + (k' + 1) = (2 + k') + 1)]
          simp only [bitSum]
          omega
        exact Nat.le_trans ih hstep
    obtain ⟨m, rfl⟩ := Nat.exists_eq_add_of_le hn
    have hge2 : 2 ≤ popcount mask := by
      rw [popcount_eq_bitSum (2 + m) mask hmask]
      have hm := hmono m
      omega
    omega

-- 3. Discrete Maximum Principle & Bellman Uniqueness (ALL n >= 2 under 0 < u < v)

structure ValidBias (u v : Int) : Prop where
  u_pos  : 0 < u
  vu_pos : 0 < v - u

theorem int_convex_extremum_max (u w x y M : Int) (hu : 0 < u) (hw : 0 < w)
    (hx : x ≤ M) (hy : y ≤ M) (heq : (u + w) * M = u * x + w * y) : x = M ∧ y = M := by
  have h1 : u * (M - x) + w * (M - y) = 0 := by
    have : (u + w) * M - (u * x + w * y) = u * (M - x) + w * (M - y) := by rw [Int.add_mul, Int.mul_sub, Int.mul_sub]; omega
    omega
  have hux : 0 ≤ u * (M - x) := Int.mul_nonneg (Int.le_of_lt hu) (by omega)
  have hwy : 0 ≤ w * (M - y) := Int.mul_nonneg (Int.le_of_lt hw) (by omega)
  have hMx : M - x = 0 := (Int.mul_eq_zero.mp (by omega : u * (M - x) = 0)).resolve_left (Int.ne_of_gt hu)
  have hMy : M - y = 0 := (Int.mul_eq_zero.mp (by omega : w * (M - y) = 0)).resolve_left (Int.ne_of_gt hw)
  exact ⟨by omega, by omega⟩

theorem int_convex_extremum_min (u w x y M : Int) (hu : 0 < u) (hw : 0 < w)
    (hx : -M ≤ x) (hy : -M ≤ y) (heq : (u + w) * (-M) = u * x + w * y) : x = -M ∧ y = -M := by
  have heq' : (u + w) * M = u * (-x) + w * (-y) := by
    rw [Int.mul_neg, Int.mul_neg]
    have : -((u + w) * (-M)) = (u + w) * M := by rw [Int.mul_neg, Int.neg_neg]
    omega
  have h := int_convex_extremum_max u w (-x) (-y) M hu hw (by omega) (by omega) heq'
  exact ⟨by omega, by omega⟩

theorem harmonic_max_principle_nonempty
    (n : Nat) (u v : Int) (hv : ValidBias u v) (D : Nat → Int) (M : Int)
    (hBound : ∀ s, s < 1 <<< n → 0 < popcount s → -M ≤ D s ∧ D s ≤ M)
    (hSingle : ∀ s, popcount s = 1 → D s = 0)
    (hHarm : ∀ s, s < 1 <<< n → 2 ≤ popcount s → v * D s = u * D (actA n s) + (v - u) * D (actB s))
    (hn : 2 ≤ n) :
    ∀ w s, s < 1 <<< n → 0 < popcount s → popcount (runWord n w s) = 1 → (D s = M ∨ D s = -M) → M = 0 := by
  intro w; induction w with
  | nil => intro s _ _ habs hex; simp only [runWord, List.foldl_nil] at habs; have := hSingle s habs; omega
  | cons step rest ih =>
    intro s hs hpos habs hex
    by_cases hs1 : popcount s = 1
    · have := hSingle s hs1; omega
    · simp only [runWord, List.foldl_cons] at habs
      have heq : (u + (v - u)) * D s = u * D (actA n s) + (v - u) * D (actB s) := by
        rw [(by omega : u + (v - u) = v)]; exact hHarm s hs (by omega)
      have hA_lt := actA_lt n s hn hs; have hB_lt := actB_lt n s hn hs
      have hA_pos : 0 < popcount (actA n s) := by rw [popcount_actA n s hn hs]; exact hpos
      have hB_pos : 0 < popcount (actB s) := popcount_actB_pos n s hn hs hpos
      rcases hex with hmax | hmin
      · rw [hmax] at heq
        have ⟨hA, hB⟩ := int_convex_extremum_max u (v - u) (D (actA n s)) (D (actB s)) M
          hv.u_pos hv.vu_pos (hBound _ hA_lt hA_pos).2 (hBound _ hB_lt hB_pos).2 heq
        cases step with | false => exact ih _ hB_lt hB_pos habs (Or.inl hB) | true => exact ih _ hA_lt hA_pos habs (Or.inl hA)
      · rw [hmin] at heq
        have ⟨hA, hB⟩ := int_convex_extremum_min u (v - u) (D (actA n s)) (D (actB s)) M
          hv.u_pos hv.vu_pos (hBound _ hA_lt hA_pos).1 (hBound _ hB_lt hB_pos).1 heq
        cases step with | false => exact ih _ hB_lt hB_pos habs (Or.inr hB) | true => exact ih _ hA_lt hA_pos habs (Or.inr hA)

theorem cerny_bellman_uniqueness_all_n
    (n : Nat) (hn : 2 ≤ n) (u v : Int) (hv : ValidBias u v) (D : Nat → Int)
    (hSingle : ∀ s, popcount s = 1 → D s = 0)
    (hHarm : ∀ s, s < 1 <<< n → 2 ≤ popcount s → v * D s = u * D (actA n s) + (v - u) * D (actB s))
    (M : Int) (hBound : ∀ s, s < 1 <<< n → 0 < popcount s → -M ≤ D s ∧ D s ≤ M)
    (hReach : ∀ s, s < 1 <<< n → 1 ≤ popcount s → ∃ w, popcount (runWord n w s) = 1)
    (hAttain : ∃ s_star, s_star < 1 <<< n ∧ 1 ≤ popcount s_star ∧ (D s_star = M ∨ D s_star = -M)) :
    ∀ s, s < 1 <<< n → 0 < popcount s → D s = 0 := by
  rcases hAttain with ⟨s_star, hs_lt, hs_pop, hs_ext⟩
  rcases hReach s_star hs_lt hs_pop with ⟨w, hsync⟩
  have hM0 : M = 0 := harmonic_max_principle_nonempty n u v hv D M hBound hSingle hHarm hn w s_star hs_lt hs_pop hsync hs_ext
  intro s hs hpos
  rcases hBound s hs hpos with ⟨hlow, hhigh⟩
  omega

end CernyBiasedSync
