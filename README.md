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
