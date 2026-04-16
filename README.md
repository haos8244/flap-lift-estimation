# High-Lift System Sizing

**A MATLAB toolkit for sizing Fowler flaps and leading-edge slats on transport-category aircraft, built on Roskam *Airplane Design — Part VI*, Chapter 8, and coupled to 3D aerodynamic data from OpenVSP / VSPAERO.**

---

## Table of Contents

1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Methodology](#methodology)
   - [Phase 1 — Clean-Wing Analysis](#phase-1--clean-wing-analysis)
   - [Phase 2 — High-Lift Increment Pre-computation](#phase-2--high-lift-increment-pre-computation)
   - [Phase 3 — Flap/Slat Trade Sweep](#phase-3--flapslat-trade-sweep)
4. [Project Structure](#project-structure)
5. [Prerequisites](#prerequisites)
6. [Required Input Data](#required-input-data)
7. [Aircraft Configuration](#aircraft-configuration)
8. [Running the Analysis](#running-the-analysis)
9. [Understanding the Output](#understanding-the-output)
10. [Example Results](#example-results)
11. [Customization](#customization)
12. [Assumptions & Limitations](#assumptions--limitations)
13. [References](#references)

---

## Overview

This program takes a clean-wing aerodynamic baseline produced in **OpenVSP / VSPAERO**, applies the semi-empirical high-lift corrections from **Roskam Part VI, Ch. 8**, and sweeps the full **flap-deflection × slat-deflection** design space to find the minimum-deflection configuration that satisfies both **speed constraints** and **positive stall margin** at takeoff and landing.

For every point in the grid, the code:

1. Computes $C_{L_{\max}}$ with devices deployed (spanwise integration of $\Delta c_{l_{\max}}$).
2. Derives $V_S$, $V_{LOF}=1.1\,V_S$, and $V_{APP}=1.23\,V_S$.
3. Back-solves the operating lift coefficient from wing-only $L=W$.
4. **Bisects to find the operating angle of attack** such that the integrated, device-modified spanwise loading equals that operating $C_L$.
5. **Constructs the deployed stall AOA** using Roskam's Fig. 8.58 Step 4 geometric construction combined with Eq. 8.28 for the flapped lift-curve slope.
6. Flags the configuration pass / fail against **both** the user's speed limits and positive stall margin for takeoff and landing.

The best takeoff and landing configurations — selected by minimum total deflection among passing cells — are reported, plotted, and returned to the MATLAB workspace for further inspection.

> **Scope note — wing-only lift balance, not full trim.** The "$\alpha$-solve" inside the sweep enforces $L_{wing}(\alpha) = W$ at a given speed. It does **not** enforce pitch-moment equilibrium, tail download, or elevator trim drag. For a high-lift sizing study this is the right scope — those are downstream problems handled by a separate trim analysis. The variable names `alphaTrim*` are retained for backward compatibility; they represent the operating AOA at which the wing's integrated lift balances weight.

---

## Key Features

| Capability | Notes |
|---|---|
| 3D aerodynamic baseline | Uses VSPAERO spanwise $c_l\cdot c/c_{ref}$ distributions, not strip-theory guesses |
| Full Roskam Ch. 8 stack | Figures 8.17, 8.26, 8.31–8.37, 8.53, 8.55, 8.58 digitized, interpolated, or directly implemented |
| Per-section airfoil data | Multi-segment wings with different $c_{l_{\max}}$, $t/c$, and $c_{l\alpha}$ per panel |
| Operating-AOA solver | Physically consistent AOA for each $(\delta_f, \delta_s)$ via bisection on wing $L=W$ |
| Deployed-stall construction | Per-cell $\alpha_{stall}^\delta$ from Roskam Fig. 8.58 Step 4 + Eq. 8.28 flapped slope |
| Dual pass/fail | Both speed limits **and** positive stall margin must hold; separate masks stored for diagnostics |
| Winglet exclusion | Stall search automatically ignores non-lifting winglet stations |
| Velocity-constraint filtering | User sets $V_{LOF}^{max}$ and $V_{APP}^{max}$ in knots |
| Rich plotting | Speed heat maps, feasibility overlay, $C_{L_{\max}}$ surface, stall-margin maps, spanwise loadings |
| Config inspector | `PlotConfig(tradeResults, VSP, ac, clean, df, ds)` — drill into any cell after the fact |

---

## Methodology

The pipeline is organized into three clean phases.

### Phase 1 — Clean-Wing Analysis

Two VSPAERO runs at different angles of attack are the only 3D inputs the program needs. Call these $\alpha_{low}$ and $\alpha_{high}$ (the **vspLow** and **vspHigh** fields in the config).

**Wing lift-curve slope**

$$
C_{L_\alpha}^{W} \;=\; \frac{C_L(\alpha_{high}) - C_L(\alpha_{low})}{\alpha_{high} - \alpha_{low}}
$$

where each $C_L$ comes from integrating the spanwise loading:

$$
C_L \;=\; \frac{b\,c_{ref}}{S_{ref}} \int_0^1 \left[c_l\cdot\tfrac{c}{c_{ref}}\right]\,d\eta
\qquad\text{with}\quad \eta = \tfrac{2y}{b}
$$

**Local stall angle at each spanwise station** (Roskam §8.1.3.4)

$$
\alpha_{stall}^{local}(\eta_i)
\;=\;
\alpha_{high}
\;+\;
\frac{\,c_{l_{\max}}(\eta_i) - c_l(\eta_i)\,}{\,C_{L_\alpha}^{W}\cdot\pi/180\,}
$$

The wing's **$\alpha_{stall}$** is the minimum of these local values, restricted to lifting stations (winglet sections, identified by having $\eta$ beyond the outboard wing break, are excluded).

**Clean-wing $C_{L_{\max}}$** is then obtained by projecting each station's $c_l$ to $\alpha_{stall}$ via the wing slope and re-integrating — the tangency condition on the $c_{l_{\max}}$ envelope.

---

### Phase 2 — High-Lift Increment Pre-computation

Everything that depends on geometry + Roskam data but **not** on the trade-sweep indices is precomputed once and cached.

#### Fowler flap spanwise lift increment (Eq. 8.6)

$$
\Delta c_l^{flap}
\;=\;
c_{l_\alpha}\;\alpha_\delta\;\frac{c'}{c}\;\delta_f
\cdot
\underbrace{\frac{C_{L_\alpha}^{W}}{c_{l_\alpha}}}_{\text{2D → 3D slope}}
\cdot
\underbrace{\frac{(\alpha_\delta)_{C_L}}{(\alpha_\delta)_{c_l}}}_{\text{Fig. 8.53 ratio}}
$$

Applied to the loading distribution with sweep + chord scaling:

$$
\Delta\!\left[c_l\cdot\tfrac{c}{c_{ref}}\right]_{flap}
\;=\;
\Delta c_l^{flap}\;\cos\Lambda_{HL}(\eta)\;\frac{c(\eta)}{c_{ref}}
$$

| Symbol | Source |
|---|---|
| $\alpha_\delta$ | Roskam **Fig. 8.17**, interpolated on $c_f/c$ and $\delta_f$ |
| $c'/c$ | Fowler extension: $1 + (c_f/c)\cos\delta_f$ |
| $(\alpha_\delta)_{C_L}/(\alpha_\delta)_{c_l}$ | Roskam **Fig. 8.53**, bilinear $(AR, c_f/c)$ |
| $\Lambda_{HL}$ | Per-station hinge-line sweep, computed from OpenVSP DegenGeom |

#### Leading-edge slat lift increment (Eq. 8.15)

$$
\Delta c_l^{slat}
\;=\;
c_{l_\delta}\;\delta_s\;\frac{c'}{c}
\cdot
\frac{C_{L_\alpha}^{W}}{c_{l_\alpha}}
\cdot
\frac{(\alpha_\delta)_{C_L}}{(\alpha_\delta)_{c_l}}
$$

with $c_{l_\delta}$ from **Fig. 8.26** and $\Lambda_{LE}$ replacing $\Lambda_{HL}$ in the projection onto the loading.

#### Maximum-lift increments (Eq. 8.18, 8.19)

**Trailing-edge flap:**

$$
\Delta c_{l_{\max}}^{TE}
\;=\;
k_1\,k_2\,k_3\;\bigl(\Delta c_{l_{\max}}\bigr)_{base}
$$

from Roskam Figures 8.31 (base vs $t/c$), 8.32 ($k_1$ vs $c_f/c$), 8.33 ($k_2$ vs $\delta_f$), and 8.34 ($k_3$ vs $\delta_f/\delta_{ref}$).

**Leading-edge slat:**

$$
\Delta c_{l_{\max}}^{LE}
\;=\;
c_{l_{\delta,\max}}\;\eta_{\max}\;\eta_\delta\;\delta_s\;\frac{c'}{c}
$$

from Figures 8.35 (theoretical limit vs $c_f/c$), 8.36 ($\eta_{\max}$ vs LER/$t$·$c$), and 8.37 ($\eta_\delta$ vs $\delta_s$).

Wing-level $\Delta C_{L_{\max}}$ is the span integral of those station increments, scaled by the sweep correction $K_\Delta$ from **Fig. 8.55**:

$$
K_\Delta \;=\; \bigl(1 - 0.08\cos^2\Lambda_{c/4}\bigr)\cos^{3/4}\Lambda_{c/4}
$$

#### Flapped lift-curve slope (Eq. 8.28)

$$
(C_{L_\alpha}^{W})_\delta
\;=\;
C_{L_\alpha}^{W}\;\Bigl[\,1 + \bigl(\tfrac{c'}{c} - 1\bigr)\tfrac{S_{W_f}}{S}\,\Bigr]
$$

The flapped wing area fraction $S_{W_f}/S$ is computed by integrating the chord distribution over the flap spanwise extent; $c'/c$ is the Fowler extension for the current $\delta_f$. This slope is used downstream in the stall-AOA construction. Slats are not included in this slope correction per Roskam §8.1.4.2 — Eq. 8.28 captures the TE-flap chord extension; the slat's contribution enters through the $\Delta C_{L_w}$ term below.

---

### Phase 3 — Flap/Slat Trade Sweep

For every $(\delta_f, \delta_s)$ on the grid (default 41 × 41 = **1,681** configurations):

1. **$C_{L_{\max}}$ with devices** — integrate the TE and LE $\Delta c_{l_{\max}}$ tables and add the sweep-corrected result to the clean-wing $C_{L_{\max}}$.

2. **Reference speeds**

$$
V_S = \sqrt{\frac{2W}{\rho\,S_{ref}\,C_{L_{\max}}}}
\qquad
V_{LOF} = 1.1\,V_S
\qquad
V_{APP} = 1.23\,V_S
$$

3. **Operating $C_L$** required at those speeds (wing-only $L=W$)

$$
C_{L,op}^{TO} \;=\; \frac{2\,W_{TO}}{\rho\,V_{LOF}^{2}\,S_{ref}}
\qquad
C_{L,op}^{LD} \;=\; \frac{2\,W_{LD}}{\rho\,V_{APP}^{2}\,S_{ref}}
$$

4. **Operating-AOA solve (bisection)** — Find $\alpha_{op}$ such that the integrated, device-modified spanwise loading equals $C_{L,op}$. The baseline loading between the two VSP samples is linearly interpolated in $\alpha$; device increments are evaluated at the trial $\alpha$. Convergence tolerance: $|C_L - C_{L,op}| < 10^{-5}$ or $\Delta\alpha < 10^{-4}$ deg.

5. **Deployed stall AOA — Roskam Fig. 8.58 Step 4.** The key observation: flaps and slats don't just add lift, they shift the $C_L$–$\alpha$ curve in characteristically different ways. Slats push $\alpha_{stall}$ *up*; flaps pull it *down*. The geometric construction in Fig. 8.58 lets you locate the new stall point from three ingredients already computed:

$$
\boxed{\;\alpha_{stall}^{\delta}
\;=\;
\alpha_{stall}^{clean}
\;+\;
\frac{\Delta C_{L_{\max}} - \Delta C_{L_w}}{(C_{L_\alpha}^{W})_\delta}\;}
$$

| Term | Source | Sign effect |
|---|---|---|
| $\alpha_{stall}^{clean}$ | Phase 1 | Baseline |
| $\Delta C_{L_{\max}}$ | Integrated TE + LE $\Delta c_{l_{\max}}$ tables | Raises the curve's peak |
| $\Delta C_{L_w}$ | Vertical shift at operating AOA: $C_{L,flapped}(\alpha_{op}) - C_{L,clean}(\alpha_{op})$ | Raises the curve uniformly |
| $(C_{L_\alpha}^{W})_\delta$ | Eq. 8.28 (precomputed) | Steepens the curve with flaps |

When $\Delta C_{L_{\max}} > \Delta C_{L_w}$ (slat-dominated) the numerator is positive and $\alpha_{stall}^{\delta} > \alpha_{stall}^{clean}$. When $\Delta C_{L_{\max}} < \Delta C_{L_w}$ (flap-dominated) the numerator is negative and $\alpha_{stall}^{\delta} < \alpha_{stall}^{clean}$. Mixed configurations land wherever the two effects net out. The $\Delta C_{L_w}$ term is essentially $\alpha$-independent (device increments in `ModifiedCLDistro` don't depend on $\alpha$), so it's evaluated once per cell using the takeoff integration.

6. **Stall margins**

$$
\text{margin}^{TO} = \alpha_{stall}^{\delta} - \alpha_{op}^{TO}
\qquad
\text{margin}^{LD} = \alpha_{stall}^{\delta} - \alpha_{op}^{LD}
$$

7. **Pass/fail filter** — A configuration passes for takeoff if **both** $V_{LOF} \le V_{LOF}^{max}$ **and** $\text{margin}^{TO} > 0$. Landing similarly with $V_{APP}$ and $\text{margin}^{LD}$. Separate grids (`TOpassV_Grid`, `TOpassA_Grid`, etc.) are stored so you can diagnose which constraint is binding for any given cell.

8. **Best configuration** — Among passing cells, pick the one with **minimum $\delta_f + \delta_s$**; ties broken by smaller $\delta_f$. This rewards aerodynamically clean designs that meet the spec with the least deflection.

---

## Project Structure

```
high-lift-sizing/
├── main.m                         ← Entry point
├── flaplift.m                     ← Orchestrator: loads, analyzes, reports, plots
│
├── AircraftConfig.m               ← All aircraft-specific inputs
├── LoadRoskamData.m               ← Digitized Roskam figures
│
├── ReadFileAero.m                 ← Parses VSPAERO polar .csv
├── ReadFileGeom.m                 ← Parses DegenGeom .csv for LE coordinates
│
├── ComputeCleanWing.m             ← α_stall, CL_α, CL_max (clean)
├── ComputeHighLiftIncrements.m    ← Cached Roskam arrays + Eq 8.28 flapped slope
├── ModifiedCLDistro.m             ← Applies flap + slat Δcl to the loading
├── ComputeCL.m                    ← Spanwise integration
├── ComputeEta.m                   ← 2y/b
├── CLtoWeight.m                   ← CL = 2W/(ρV²S)
├── DeltaCL.m                      ← Utility
│
├── RunTradeSweep.m                ← The (δf, δs) sweep + operating-AOA solver
│                                    + Fig 8.58 Step 4 stall construction
│
├── PlotResults.m                  ← Design-space & stall-margin plots
├── PlotConfig.m                   ← Inspector for a single (δf, δs)
│
└── test/
    ├── BAAT4_polar.csv                           ← VSPAERO output
    └── BAAT3_FuselageWingChanged_DegenGeom.csv   ← DegenGeom output
```

Bundled `test/` data was generated from a wing-only VSP model at M = 0.24, Re_crit = 2×10⁷, with $\alpha = 5°$ and $10°$ samples — these must match `ac.aoa.vspLow` / `ac.aoa.vspHigh`.

---

## Prerequisites

- **MATLAB R2020b or newer** — uses `readlines`, `readtable`, and string-concatenation syntax.
- **OpenVSP 3.x with VSPAERO** — to produce the required `.csv` inputs.
- No toolbox dependencies.

---

## Required Input Data

Two OpenVSP exports must be placed in the directory referenced by `ac.files.directory`:

### 1. VSPAERO polar file (e.g. `BAAT4_polar.csv`)

Must contain **at least two angle-of-attack sweeps** in a `VSPAERO_Load` block — one at `ac.aoa.vspLow`, one at `ac.aoa.vspHigh`. The parser looks for these fields per block:

| Field (`Results_Name` row) | What it is |
|---|---|
| `FC_AoA_` | Angle of attack selector |
| `cl*c/cref` | Spanwise loading distribution |
| `Yavg` | Station $y$-coordinates |
| `Xavg` | Station $x$-coordinates |
| `Chord` | Local chord |
| `cl` | Local section lift coefficient |
| `FC_Bref_`, `FC_Sref_`, `FC_Cref_` | Reference wingspan / area / chord |

### 2. DegenGeom file (e.g. `BAAT3_...DegenGeom.csv`)

Used to extract leading-edge $(x, y)$ coordinates along the wing, from which hinge-line and LE sweep distributions are computed. Set `ac.files.wingCompName` to your VSP component name (it must match exactly — the parser searches for `componentName + ",0,"`).

---

## Aircraft Configuration

All user-editable inputs live in **`AircraftConfig.m`**. Edit this file to match your aircraft.

### Wing planform

| Field | Units | Description |
|---|---|---|
| `wing.AR` | — | Aspect ratio |
| `wing.Lambda_c4` | deg | Quarter-chord sweep |
| `wing.sectionSpans` | ft | Panel span lengths, inboard → outboard |
| `wing.aileronSpan` | — (frac) | Aileron fraction of semispan (subtracted from flap span) |

### Airfoils (per section, inboard → outboard)

| Field | Description |
|---|---|
| `airfoils.names` | Cell array of airfoil names (for logs only) |
| `airfoils.tc_pct` | Thickness ratio in percent |
| `airfoils.clAlpha` | 2D lift-curve slope, per radian |
| `airfoils.clMax` | 2D maximum lift coefficient |

> All four arrays **must** have one entry per wing section.

### Weights & atmosphere

| Field | Units | Description |
|---|---|---|
| `weights.WTO` | lb | Takeoff weight |
| `weights.WLD` | lb | Landing weight |
| `atmo.density` | slug/ft³ | Design-point air density |

### High-lift devices

| Field | Description |
|---|---|
| `flap.cfOverC` | Fowler flap chord ratio |
| `flap.fig817_index` | Row in Roskam Fig. 8.17 (`[0.15, 0.20, 0.25, 0.30, 0.40]`) |
| `slat.cfOverC` | Slat chord ratio |
| `slat.fig826_index` | Index into the 0.00–0.50 table for Fig. 8.26 |

### VSP sample angles

| Field | Description |
|---|---|
| `aoa.vspLow` | Lower $\alpha$ in the VSPAERO polar (e.g. 5°) |
| `aoa.vspHigh` | Upper $\alpha$ in the VSPAERO polar (e.g. 10°) |

> `aoa.takeoff` / `aoa.landing` are **not design angles** — they're aliases for the VSP sample points. The true operating angle is computed per-configuration.

### Speed constraints

| Field | Units | Description |
|---|---|---|
| `spdcnst.VLOFcnst` | kt | Maximum allowable $V_{LOF}$ |
| `spdcnst.VAPPcnst` | kt | Maximum allowable $V_{APP}$ |

### File paths

| Field | Description |
|---|---|
| `files.directory` | Folder containing the two VSP CSV files |
| `files.aeroFile` | VSPAERO polar filename |
| `files.degenFile` | DegenGeom filename |
| `files.wingCompName` | Exact OpenVSP component name for the wing |

---

## Running the Analysis

From the MATLAB command window in the project directory:

```matlab
>> main
```

That's it. `main.m` clears the workspace and calls `flaplift()`, which returns four structs into the base workspace:

| Variable | Contents |
|---|---|
| `tradeResults` | Every grid computed: $C_{L_{\max}}$, $V_S$, $V_{LOF}$, $V_{APP}$, $\alpha_{op}$, $\alpha_{stall}^{\delta}$, stall margins, pass/fail masks, modified loadings, best configs |
| `VSP` | Parsed OpenVSP data |
| `ac` | The config struct that was used |
| `clean` | Clean-wing results ($\alpha_{stall}$, $C_{L_{\max}}^{clean}$, etc.) |

Key per-cell fields on `tradeResults`:

| Field | Description |
|---|---|
| `CLmaxGrid` | $C_{L_{\max}}$ with devices deployed |
| `alphaTrimTO_grid`, `alphaTrimLD_grid` | Operating AOA (wing $L=W$) |
| `alphaStallGrid` | Deployed stall AOA from Fig. 8.58 Step 4 |
| `stallMarginTO_grid`, `stallMarginLD_grid` | $\alpha_{stall}^{\delta} - \alpha_{op}$ in degrees |
| `deltaCLw_grid` | Vertical $C_L$ shift from devices at operating AOA |
| `CLalphaFlappedGrid` | Eq. 8.28 flapped slope per cell |
| `TOpassGrid`, `LDpassGrid` | Combined speed + AOA pass masks |
| `TOpassV_Grid`, `TOpassA_Grid` | Speed-only and AOA-only pass masks (for diagnostics) |

### Inspecting a specific cell after the sweep

```matlab
>> PlotConfig(tradeResults, VSP, ac, clean, 20, 25)
```

opens a three-panel view of the $\delta_f=20°, \delta_s=25°$ configuration: takeoff spanwise loading, landing spanwise loading, and the $C_L$–$\alpha$ curve with operating points annotated.

---

## Understanding the Output

### Console banner

A running table is printed for every $(\delta_f, \delta_s)$ pair:

```
  df  ds  | CLmax   a_st*  V_S   V_LOF  V_APP | a_TO    CL_op_TO CL_TO   margin TO | a_LD    CL_op_LD CL_LD   margin LD
  --- --- | ------- ------ ----- ------ ----- | ------- -------- ------- ------- -- | ------- -------- ------- ------- --
  11  15  | 1.9218  +16.73 136.3 150.0  167.7 | +12.73  1.5882   1.5882  +4.01  1  |  +6.11  1.0497   1.0497  +10.62  0
```

- **`a_st*`** = deployed stall AOA (Fig. 8.58 Step 4) in degrees.
- **`CL_op`** = target (from wing $L=W$).
- **`CL_TO`** / **`CL_LD`** = achieved by integration of the operating-$\alpha$ modified loading. They should match `CL_op` to 4 decimals — that's the bisection convergence.
- **`margin`** = $\alpha_{stall}^{\delta} - \alpha_{op}$ in degrees; positive is good.
- Trailing **`1`** / **`0`** = pass/fail (both speed AND margin must hold).

### Plots

Running `flaplift()` generates four figures by default:

| Figure | Panels |
|---|---|
| **1 — Design Space** | (a) $V_{LOF}$ heat map with constraint contour · (b) $V_{APP}$ heat map · (c) feasibility map (fails-both / TO-only / LD-only / both-pass) · (d) $C_{L_{\max}}$ surface with best markers |
| **2 — Best-Config Loadings** | Spanwise $c_l\cdot c/c_{ref}$ for the best TO and LD cells, with flap and slat regions shaded |
| **3 — $C_{L_{\max}}$ Heat Map** | Standalone $C_{L_{\max}}$ surface with labeled contours |
| **4 — Stall Margins** | Side-by-side TO and LD stall-margin heat maps at their natural scales |

---

## Example Results

With the default `AircraftConfig.m` (163,800 lb transport, AR = 15, $\Lambda_{c/4}$ = 31°, $c_f/c_{flap}$ = 0.25, $c_f/c_{slat}$ = 0.10, $V_{LOF}^{max}=V_{APP}^{max}=150$ kt):

**Clean wing**

| Quantity | Value |
|---|---|
| $C_{L_\alpha}^{W}$ | 4.6616 /rad (0.08136 /deg) |
| $\alpha_{stall}$ | 15.48° at $\eta$ ≈ 0.37 |
| $C_{L_{\max}}^{clean}$ | 1.5127 |
| $V_S$ (clean) | 153.7 kt |

**Best takeoff configuration**

| Quantity | Value |
|---|---|
| Flap deflection $\delta_f$ | **11°** |
| Slat deflection $\delta_s$ | **15°** |
| $C_{L_{\max}}$ with devices | 1.9218 |
| $V_S$ | 136.3 kt |
| $V_{LOF}$ | 150.0 kt *(at the constraint)* |
| $\alpha_{op}$ | 12.73° |
| $\alpha_{stall}^{\delta}$ | 16.73° *(slat-dominated — pushed up from 15.48° clean)* |
| Stall margin | **+4.01°** |

**Best landing configuration**

| Quantity | Value |
|---|---|
| Flap deflection $\delta_f$ | **35°** |
| Slat deflection $\delta_s$ | **18°** |
| $C_{L_{\max}}$ with devices | 2.4052 |
| $V_S$ | 121.9 kt |
| $V_{APP}$ | 149.9 kt *(at the constraint)* |
| $\alpha_{op}$ | 3.75° |
| $\alpha_{stall}^{\delta}$ | 17.06° *(flap camber pulls down, slat pushes up — net positive)* |
| Stall margin | **+13.31°** |

**Feasibility statistics** (1,681 configurations)

| Constraint | Passing |
|---|---|
| $V_{LOF}\le 150$ kt | 1,133 / 1,681 (67.4%) |
| $V_{APP}\le 150$ kt | 118 / 1,681 (7.0%) |
| **Both (speed + stall margin)** | 118 / 1,681 (7.0%) |

> In this design the AOA-margin constraint is never binding — every speed-passing cell also passes stall margin. That's a design outcome, not a given; run a heavier aircraft or a slower $V_{LOF}$ target and the stall margin becomes the active constraint for low-slat configurations.

---

## Customization

### Change the deflection grid

`ComputeHighLiftIncrements.m`, line ~24:

```matlab
hl.deltaSweep = 0:1:40;   % default: 0 → 40° in 1° steps
```

Coarser sweep ⇒ faster run; finer ⇒ smoother heat maps.

### Change the best-config selection metric

`RunTradeSweep.m` → `pickMinDeflection(...)` currently minimizes $\delta_f + \delta_s$. Replace the ranking criterion to optimize for, e.g., maximum $C_{L_{\max}}$, maximum stall margin, or a weighted combination.

### Override the Roskam data

Open `LoadRoskamData.m` and replace any digitized array with your own values (or a different figure's). All downstream code just uses the struct fields.

### Add drag bookkeeping

The current code is lift-only. A drag polar for the deployed configuration could be added by plugging a model (e.g., DATCOM/ESDU increments) into `ComputeHighLiftIncrements.m` and surfacing it alongside $C_L$ in `RunTradeSweep.m`.

---

## Assumptions & Limitations

- **Incompressible, low-Mach methodology.** Roskam Part VI Ch. 8 is built for subsonic high-lift design; no compressibility corrections are applied.
- **Linear-in-α baseline interpolation.** Between the two VSP sample angles, $C_L$ is assumed linear in $\alpha$. The two samples should bracket the expected operating $\alpha$ (the bisection will extrapolate if needed, but accuracy degrades).
- **Wing-only lift balance — not full trim.** The operating-AOA solve enforces $L_{wing}=W$ only. Pitching moment, tail download, elevator trim drag, and flight-path angle effects are not modeled. This is intentional scoping for a high-lift sizing study — downstream trim analysis should handle those.
- **Fig. 8.58 Step 4 construction is geometric.** The deployed $\alpha_{stall}^{\delta}$ comes from a linear construction on the $C_L$–$\alpha$ diagram (slope + vertical shift + peak shift). It inherits the accuracy of the underlying $\Delta C_{L_{\max}}$ and Eq. 8.28 models. Expect a degree or two of uncertainty; this is a conceptual-design tool, not a CFD surrogate.
- **Rigid geometry.** Aeroelastic loading and flap-tab interactions are ignored.
- **Roskam data is digitized.** Curves are read from chart images; expect a few percent of reading error. Re-digitize into `LoadRoskamData.m` if you need tighter fidelity.
- **Ground effect is excluded.** Reference speeds are out-of-ground-effect $V_S$ values.
- **Winglet stations** with $\eta$ beyond the outboard wing break are excluded from the stall search — if your outermost `sectionSpans` entry is *not* a winglet, edit `ComputeCleanWing.m` accordingly.

---

## References

1. **Roskam, J.** *Airplane Design, Part VI: Preliminary Calculation of Aerodynamic, Thrust and Power Characteristics.* DARcorporation.
   - §8.1.3 — Clean-wing stall and $C_{L_{\max}}$ (wing-station tangency method, Fig. 8.48)
   - §8.1.4 — Flap lift and max-lift increments (Eqs. 8.6, 8.18, Figs. 8.17, 8.31–8.34, 8.53)
   - §8.1.4 — Slat/LE device lift and max-lift increments (Eqs. 8.15, 8.19, Figs. 8.26, 8.35–8.37)
   - §8.1.4.3 — 3D corrections and sweep effects (Figs. 8.53, 8.55)
   - §8.1.4.4 — Flapped lift-curve slope (Eq. 8.28) and Flaps-Down Wing Lift Curve construction (Fig. 8.58)

2. **OpenVSP documentation** — [openvsp.org](https://openvsp.org) — VSPAERO panel-method solver and DegenGeom exports.

---

*Built for aircraft conceptual-design coursework; extensible to any subsonic, swept, multi-panel wing with trailing-edge Fowler flaps and leading-edge slats.*