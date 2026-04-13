# High-Lift System Sizing Script

## Overview

This MATLAB script sizes trailing-edge Fowler flaps and leading-edge slats for an airliner wing using a modified Roskam Part VI methodology. It takes clean wing aerodynamic data from OpenVSP (VSPAERO) and wing geometry from a DegenGeom export, then overlays empirical high-lift device increments onto the spanwise loading distribution to determine which flap/slat deflection combinations meet takeoff and landing lift requirements.

## Method

The approach computes the 2D airfoil lift increment from Roskam's empirical equations, corrects for sweep, scales by the local chord ratio, and adds it to the clean spanwise loading curve from VSPAERO. The modified curve is then integrated to get the new total wing CL. This is repeated for a sweep of flap and slat deflection angles to map out which combinations produce enough lift.

### Core Equation

At each spanwise station in the flapped/slatted region:

```
[cl * c/cref]_mod = [cl * c/cref]_clean + Δcl * cos(Λ) * c(η)/cref
```

Where:
- Δcl for Fowler flaps comes from Roskam Eq. 8.6: `Δcl = cl_α * α_δ * (c'/c) * δ_f`
- Δcl for slats comes from Roskam Eq. 8.15: `Δcl = cl_δ * δ_f * (c'/c)`
- cos(Λ_HL) corrects flap effectiveness for hinge-line sweep
- cos(Λ_LE) corrects slat effectiveness for leading-edge sweep
- c(η)/cref scales the 2D increment to match the loading curve units

### Equations Used

| Equation | Source | Purpose |
|----------|--------|---------|
| Δcl = cl_α · α_δ · (c'/c) · δ_f | Roskam Eq. 8.6 | 2D Fowler flap lift increment |
| Δcl = cl_δ · δ_f · (c'/c) | Roskam Eq. 8.15 | 2D slat lift increment |
| CL = (b·cref/Sref) · ∫ [cl·c/cref] dη | Definition | Wing CL from loading curve |
| CL_req = 2W / (ρV²Sref·cosα) | Force balance | Required CL at flight condition |
| c'/c = 1 + (cf/c)·cos(δ_f) | Geometry | Fowler chord extension ratio |
| x_HL = x_LE + (1 - cf/c)·c | Geometry | Hinge line position |
| Λ_HL = atan2(Δx_HL, Δy) | Geometry | Hinge line sweep angle |

## Files

| File | Purpose |
|------|---------|
| `flaplift.m` | Main script — runs the entire analysis |
| `ReadFileAero.m` | Parses VSPAERO polar CSV for loading data |
| `ReadFileGeom.m` | Parses DegenGeom CSV for wing LE positions |
| `ComputeEta.m` | Converts spanwise position to normalized η = 2y/b |
| `ComputeCL.m` | Integrates loading curve to get wing CL |
| `CLtoWeight.m` | Computes required CL from weight/speed/density |
| `DeltaCL.m` | Computes deficit between required and clean CL |
| `ModifiedCLDistro.m` | Adds flap/slat increments to the loading curve |

## Inputs

### From OpenVSP

- **VSPAERO polar CSV** — run at two AOAs (takeoff and landing). Provides spanwise loading `cl*c/cref`, station locations `Yavg`, chord `Chord`, and reference values `FC_Cref_`, `FC_Sref_`, `FC_Bref_`.
- **DegenGeom CSV** — provides leading edge x-position `lex` and spanwise location `ley` from the STICK_NODE section of the wing component. Used for accurate sweep angle computation.

### User-Defined Parameters

- `cfOverCFlapDesignIndex` — selects flap chord ratio cf/c from empirical data (e.g., index 3 = 0.25)
- `cfOverCSlatDesignIndex` — selects slat chord ratio cf/c from interpolated data (e.g., index 11 = 0.10)
- `ComplexSectionsSpan` — span of each wing section in your multi-section wing (feet)
- `clAlphaDistro` — 2D lift curve slope for the airfoil at each wing section (per radian)
- `aileronLength` — aileron span as fraction of semi-span (flaps end before aileron)
- `aoaTO`, `aoaLD` — operating angles of attack for takeoff and landing (degrees)
- `VLOF`, `VAPP` — liftoff and approach speeds (knots, converted internally to ft/s)
- `WTO`, `WLD` — takeoff and landing weights (lbs)
- `airDensity` — air density (slug/ft³, sea level = 0.002378)

### Empirical Data

- **Figure 8.17** (Roskam Part VI) — α_δ vs flap deflection for different cf/c, digitized into `alphaDeltaTable`
- **Figure 8.26** (Roskam Part VI) — cl_δ vs leading-edge chord ratio, digitized into `clDeltaSlats`

## Steps

1. **Read Data** — Load VSPAERO loading distributions at TO and LD AOAs, and DegenGeom wing geometry. Interpolate LE x-positions onto VSPAERO stations.

2. **Compute Clean CL** — Integrate the clean spanwise loading: `CL = (b·cref/Sref) · trapz(η, cl·c/cref)`

3. **Compute Required CL** — From weight, speed, density, and AOA: `CL_req = 2W / (ρV²Sref·cosα)`. Speeds are converted from knots to ft/s.

4. **Compute Deficit** — `ΔCL = CL_req - CL_clean` for both TO and LD.

5. **Compute Δcl** — For each combination of flap deflection (0–40°) and slat deflection (0–40°), compute the 2D lift increments from Roskam equations using pre-looked-up empirical values.

6. **Modify Loading Curve** — At each spanwise station, if it falls within the flapped or slatted region, add the Δcl increment corrected for local sweep and chord ratio.

7. **Integrate** — Compute new wing CL from the modified loading curve.

8. **Check** — Compare new CL to required CL for both TO and LD. Record pass/fail.

## Outputs

- **Console table** — every flap/slat deflection combination with resulting CL and pass/fail
- **Heat maps** — contour plots of CL vs flap and slat deflection, with required CL contour line overlaid
- **Loading curve plots** — clean vs modified spanwise loading for the best TO and LD configurations
- **Best configuration** — smallest deflection angles that meet requirements (lowest drag)

## Assumptions and Limitations

- Sref, cref, and b are fixed reference values (clean wing) and do not change with flap deployment
- The Fowler chord extension effect is captured through the c'/c term, not through changing Sref
- Linear superposition of flap/slat increments onto the clean loading (valid in linear aerodynamic regime)
- Sweep correction uses simple cos(Λ) theory (infinite swept wing assumption)
- 2D empirical data from Roskam applied station-by-station (no 3D correction factor applied, but comparison with Roskam Eq. 8.27 shows agreement within 1-3%)
- cl_alpha is currently set to 2π for all sections — can be updated with XFOIL results per airfoil
- Does not include viscous effects, flow separation at high deflections, or slot gap optimization
- This is a preliminary design sizing tool, not a replacement for CFD

## Units

All units are English: lbs, ft, slug/ft³, knots (converted to ft/s internally). Angles are in degrees externally, converted to radians where equations require it.

---

## Future Work: Integration of 3D Flap Effectiveness Corrections

### Current Approach

The current implementation computes the lift increment from flaps and slats using Roskam Part VI 2D airfoil-level equations (Eq. 8.6 for Fowler flaps, Eq. 8.15 for leading edge slats). The 2D section increment $\Delta c_l$ is added directly to the clean spanwise loading curve from VSPAERO over the flapped/slatted span stations, with a $\cos\Lambda_{HL}$ sweep correction applied. The modified loading curve is then re-integrated using trapezoidal integration to obtain the wing-level $\Delta C_L$.

This approach replaces Roskam's flap span factor $K_b$ (Figure 8.52) with a direct spanwise integration, which is arguably more accurate for the multi-section complex wing planform used in this project since $K_b$ was derived for simple trapezoidal wings. The clean-wing VSPAERO loading already contains 3D finite wing effects (induced downwash, tip effects, planform shape), so the baseline is physically correct.

### What Is Assumed

The current method assumes that the incremental effect of deploying a flap or slat can be treated as a 2D perturbation applied on top of a 3D baseline loading. Specifically, it assumes:

1. The 2D flap effectiveness parameter $\alpha_\delta$ (Figure 8.17) applies directly at each spanwise station without correction for 3D mutual induction between flapped and unflapped wing sections.
2. The 2D airfoil lift curve slope $c_{l_\alpha}$ is used in the flap equations without adjusting for the reduced lift curve slope of the finite wing.
3. Local flow at each section responds to the flap deflection the same way a pure 2D airfoil would, neglecting spanwise flow and vortex interactions at the flap edges.

For a high-aspect-ratio transport wing where the flow is predominantly two-dimensional at each section away from the tips, these are reasonable preliminary design assumptions. However, they result in a slight overestimation of flap effectiveness.

### Proposed Improvement

Roskam Eq. 8.27 provides the formal 2D-to-3D conversion:

$$\Delta C_{L_W} = K_b \cdot (\Delta c_l) \cdot \frac{C_{L_{\alpha_W}}}{c_{l_\alpha}} \cdot \frac{(\alpha_\delta)_{C_L}}{(\alpha_\delta)_{c_l}}$$

Rather than adopting this equation wholesale (which would replace the spanwise integration with $K_b$, a step backward for the complex wing), two correction factors from Eq. 8.27 can be selectively integrated into the current method:

**1. Lift Curve Slope Ratio** $C_{L_{\alpha_W}} / c_{l_\alpha}$

This ratio corrects for the fact that a finite wing has a lower lift curve slope than its 2D airfoil sections due to induced downwash. The 2D value $c_{l_\alpha} \approx 2\pi$ rad$^{-1}$ is currently used uncorrected. The 3D wing lift curve slope $C_{L_{\alpha_W}}$ can be computed from Helmbold's equation or extracted directly from VSPAERO results (slope of $C_L$ vs. $\alpha$ in the linear region). For the aspect ratio of this aircraft, the ratio is expected to be approximately 0.85--0.92. This correction requires no additional chart digitization — both values are already available from existing data.

**2. 3D Flap Effectiveness Ratio** $(\alpha_\delta)_{C_L} / (\alpha_\delta)_{c_l}$

This ratio accounts for the reduction in flap effectiveness caused by 3D effects: spanwise flow, mutual induction between flapped and unflapped sections, and tip vortex interactions at flap edges. It is obtained from Roskam Figure 8.53 as a function of aspect ratio and inboard/outboard flap span ratios. Implementing this correction requires digitizing Figure 8.53 into a 2D interpolation table (similar to what was done for Figures 8.17 and 8.26), after which it becomes a single `interp2` call per configuration in the trade study loop.

### Implementation

The corrected section-level increment applied at each spanwise station would become:

$$\Delta c_l^{corrected} = \Delta c_l^{2D} \cdot \frac{C_{L_{\alpha_W}}}{c_{l_\alpha}} \cdot \frac{(\alpha_\delta)_{C_L}}{(\alpha_\delta)_{c_l}} \cdot \cos\Lambda_{HL}$$

This preserves the direct spanwise integration (superior to $K_b$ for the complex wing) while incorporating the two physics corrections that the current method omits. The net effect is expected to reduce the predicted $\Delta C_L$ by approximately 8--15%, yielding a more conservative and physically accurate result. Configurations that still meet $C_{L,req}$ after applying these corrections carry stronger design confidence.

### References

- Roskam, J. *Airplane Design Part VI: Preliminary Calculation of Aerodynamic, Thrust and Power Characteristics.* Section 8.1.4.1, Eq. 8.27, Figures 8.52--8.53.

---

## Future Work: Closing the Stall Speed–$C_{L,max}$ Loop

### Current Approach

The script computes the required lift coefficient for takeoff and landing using the FAR Part 25 regulatory speed margins applied to assumed stall speeds:

$$V_{LOF} = 1.1 \, V_{S,TO}, \qquad V_{APP} = 1.23 \, V_{S,L}$$

$$C_{L,req} = \frac{2W}{\rho \, V^2 \, S_{ref} \, \cos\alpha}$$

The 1.1 and 1.23 multipliers are not aircraft-size dependent — they are fixed regulatory minimums from FAR 25.107(e) and FAR 25.125/25.143 respectively, applicable to all transport category aircraft regardless of size class. The current implementation assumes fixed stall speeds of approximately 140 knots (takeoff) and 130 knots (landing), from which the operational speeds $V_{LOF}$ and $V_{APP}$ are derived.

### What Is Assumed

The stall speed itself depends on $C_{L,max}$:

$$V_S = \sqrt{\frac{2W}{\rho \, S_{ref} \, C_{L,max}}}$$

The current script assumes stall speeds independently of the high-lift system configuration being evaluated. This introduces a circularity: the stall speeds used to compute $C_{L,req}$ depend on $C_{L,max}$, which in turn depends on the flap and slat configuration the script is trying to size. If the assumed stall speed does not correspond to the $C_{L,max}$ that the selected configuration actually produces, the computed $C_{L,req}$ is inconsistent with the flight condition being analyzed.

For preliminary design this is acceptable — the assumed stall speeds are representative of the aircraft class and the resulting $C_{L,req}$ values are in the correct range. However, it means the trade study results carry an implicit assumption that the final configuration will produce a $C_{L,max}$ consistent with those stall speeds.

### VSPAERO Run Conditions

The choice of AOA and speed for the VSPAERO clean-wing analysis is coupled to this assumption. The current settings are:

- **Takeoff:** AOA = 10°, representing the aircraft at rotation/liftoff. This is the high end of realistic rotation AOA for a transport aircraft, meaning the clean wing contributes its maximum lift at this phase. The deficit remaining after the clean contribution is what the flaps must provide.
- **Landing:** AOA = 5°, representing a stabilized approach. This is the low end of approach AOA, which is conservative for the high-lift system since the clean wing contributes less lift, demanding more from the flaps and slats at their higher (30–35°) deflection angles.

The Reynolds number for each VSPAERO run should correspond to the operational speed at that phase ($V_{LOF}$ or $V_{APP}$), computed using sea-level ISA conditions and the mean aerodynamic chord.

### Proposed Improvement

The stall speed–$C_{L,max}$ circularity can be resolved by iterating within the trade study loop. For each candidate flap/slat configuration:

1. Estimate $C_{L,max}$ from the modified loading curve (the maximum integrated $C_L$ before any section exceeds its local $c_{l,max}$, or from the empirical $\Delta c_{l,max}$ method using Roskam Eq. 8.18–8.19).
2. Back-calculate the stall speed from $C_{L,max}$: $V_S = \sqrt{2W / (\rho \, S_{ref} \, C_{L,max})}$.
3. Recompute the operational speed ($V_{LOF} = 1.1 \, V_S$ or $V_{APP} = 1.23 \, V_S$) and the corresponding $C_{L,req}$.
4. Check whether the configuration meets the updated $C_{L,req}$.
5. Repeat until $V_S$ converges.

This closes the loop and ensures that every configuration in the trade study is evaluated against a $C_{L,req}$ that is self-consistent with the $C_{L,max}$ it actually produces. Configurations that pass this converged check are guaranteed to meet the FAR 25 speed margins at their true stall speed, rather than at an assumed one.

### References

- Federal Aviation Administration. *14 CFR Part 25 — Airworthiness Standards: Transport Category Airplanes.* Sections 25.107, 25.125, 25.143.
- Roskam, J. *Airplane Design Part VI.* Chapter 8, Sections 8.1.2–8.1.3 (empirical $\Delta c_{l,max}$ methods).

---
 
## Future Work: Drag Estimation for High-Lift Configurations
 
### Current Limitation
 
The current trade study evaluates candidate flap/slat configurations solely on whether they produce sufficient $C_L$ to meet the takeoff and landing requirements. No drag estimate is computed. This means a configuration can pass the $C_L$ check but produce so much drag that the aircraft cannot meet the FAR 25.111 second-segment climb gradient requirement after takeoff, or that landing field length becomes excessive. Without drag, the trade study cannot distinguish between configurations that produce the same $C_L$ but at different drag penalties — and it cannot verify climb performance.
 
### What Is Needed
 
Roskam Part VI Section 4.6 (Eq. 4.70) decomposes the total drag increment due to flap deflection into three components:
 
$$\Delta C_{D,flap} = \Delta C_{D_{p,flap}} + \Delta C_{D_{i,flap}} + \Delta C_{D_{int,flap}}$$
 
Each component requires its own estimation method:
 
**1. Profile Drag Increment** $\Delta C_{D_{p,flap}}$
 
This is the increase in pressure and friction drag from the deflected flap surfaces. Roskam Eq. 4.71 gives:
 
$$\Delta C_{D_{p,flap}} = \Delta c_{d_p} \cdot \frac{S_{w_f}}{S_{ref}} \cdot K_{\Lambda}$$
 
where $\Delta c_{d_p}$ is the 2D section profile drag increment, $S_{w_f}/S_{ref}$ is the flapped wing area ratio, and $K_{\Lambda}$ is a sweep correction. The 2D increment depends on flap type and deflection angle, obtained from empirical charts: Figure 4.44 (plain flaps), Figure 4.45 (split flaps), Figure 4.46 (single-slotted flaps), and Figure 4.47 (Fowler flaps). For the Fowler flap used in this project, Figure 4.47 provides $\Delta c_{d_p}$ as a function of $\delta_f$ and $c_f/c$.
 
Implementation would follow the same pattern as the lift estimation: digitize the relevant figure into a MATLAB interpolation table and look up $\Delta c_{d_p}$ for each configuration in the trade study loop. The flapped area ratio $S_{w_f}/S_{ref}$ can be computed from the same spanwise flap extent already defined in the script.
 
**2. Induced Drag Increment** $\Delta C_{D_{i,flap}}$
 
Deploying partial-span flaps distorts the spanwise loading away from the elliptical distribution, increasing induced drag beyond what the simple $C_L^2 / (\pi \cdot AR \cdot e)$ formula predicts for the clean wing. The induced drag increment can be estimated from:
 
$$\Delta C_{D_{i,flap}} = \frac{(\Delta C_L)^2}{\pi \cdot AR \cdot e_{flap}}$$
 
where $e_{flap}$ is the Oswald efficiency factor with flaps deployed, which is lower than the clean-wing value due to the non-elliptical loading. Roskam Section 4.6.2 provides methods to estimate this. Alternatively, since the script already constructs the modified spanwise loading curve, $e_{flap}$ could be computed directly from the Fourier decomposition of the modified circulation distribution — though this adds complexity.
 
A simpler approach for preliminary design is to use the total modified $C_L$ (already computed) with a reduced Oswald factor. Typical values for $e_{flap}$ are 0.5–0.7 for partial-span Fowler flaps versus 0.75–0.85 clean. The difference in induced drag between the flapped and clean loading gives $\Delta C_{D_{i,flap}}$.
 
**3. Interference Drag Increment** $\Delta C_{D_{int,flap}}$
 
This accounts for drag from the gaps between the slat and wing leading edge, and between the wing trailing edge and flap. For slotted flaps and slats, the slot geometry creates local flow acceleration and mixing losses. Roskam Section 4.6.3 provides empirical corrections for this, though it is typically the smallest of the three components. For preliminary design, it can be approximated as a fraction of the profile drag increment or absorbed into the profile drag empirical data, which already includes some slot effects for slotted flap types.
 
### Why This Matters: Climb Gradient Check
 
FAR 25.111 requires a minimum second-segment climb gradient with one engine inoperative, landing gear retracted, and takeoff flaps deployed. For a twin-engine aircraft:
 
$$\gamma_{min} = 0.024 \quad (2.4\%)$$
 
The climb gradient is:
 
$$\gamma = \frac{T_{OEI}}{W} - \frac{C_D}{C_L}$$
 
where $T_{OEI}$ is the thrust available with one engine inoperative (approximately 50% of total takeoff thrust) and $C_D = C_{D,clean} + \Delta C_{D,flap}$. A configuration that meets $C_{L,req}$ but produces excessive flap drag may fail this climb requirement — particularly at higher deflection angles where profile drag grows rapidly with $\delta_f$.
 
Adding the drag estimate to the trade study enables a combined check: each configuration must simultaneously meet the $C_L$ requirement *and* the climb gradient requirement. This would filter out high-deflection configurations that produce enough lift but too much drag, and would shift the optimal design point toward lower deflection angles with larger chord ratios — consistent with the Fowler flap philosophy of gaining lift through chord extension rather than excessive deflection.
 
### Implementation
 
For each configuration in the existing trade study loop:
 
1. Look up $\Delta c_{d_p}$ from the digitized Fowler flap profile drag chart (Figure 4.47) at the current $c_f/c$ and $\delta_f$.
2. Compute $\Delta C_{D_{p,flap}}$ using the flapped area ratio and sweep correction.
3. Compute $\Delta C_{D_{i,flap}}$ from $\Delta C_L$ and an estimated $e_{flap}$.
4. Sum the drag increments and add to the clean-wing $C_{D,0}$ (from VSPAERO or a separate drag buildup).
5. Compute $L/D$ and the climb gradient $\gamma$.
6. Check $\gamma \geq 0.024$ (twin-engine) in addition to the existing $C_L \geq C_{L,req}$ check.
 
This requires digitizing one additional chart (Figure 4.47) and obtaining a clean-wing $C_{D,0}$ estimate, but otherwise integrates directly into the existing loop structure. The output table would then include $\Delta C_D$, $L/D$, and the climb gradient for each configuration, enabling a fully informed design selection.
 
### References
 
- Roskam, J. *Airplane Design Part VI: Preliminary Calculation of Aerodynamic, Thrust and Power Characteristics.* Section 4.6, Eq. 4.70–4.73, Figures 4.44–4.47.
- Federal Aviation Administration. *14 CFR Part 25 — Airworthiness Standards: Transport Category Airplanes.* Section 25.111 (Climb: one-engine-inoperative).
