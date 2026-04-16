import { useState } from "react";

// --- Data extracted from the MATLAB codebase ---
const aircraftConfig = {
  wing: {
    AR: 15,
    Lambda_c4: 31.0,
    sectionSpans: [6.35, 6.49, 12.98, 19.47, 19.47, 6.49],
    aileronSpan: 0.15,
    get totalSemispan() { return this.sectionSpans.reduce((a, b) => a + b, 0); },
  },
  airfoils: {
    names: ["0612", "0612", "0612", "0610", "0606", "0404"],
    tc_pct: [12, 12, 12, 10, 6, 4],
    clAlpha: [6.2832, 6.2832, 6.2832, 6.2832, 6.2832, 6.2832],
    clMax: [1.6581, 1.6581, 1.6581, 1.5252, 0.9342, 0.8204],
  },
  weights: {
    WTO: 163800,
    get WLD() { return 163800 - 0.9 * 31600; },
    fuelBurn: 31600,
    fuelFrac: 0.9,
  },
  atmo: { density: 0.002378, densityUnit: "slug/ft³" },
  flap: { cfOverC: 0.25, fig817_index: 3, type: "Fowler" },
  slat: { cfOverC: 0.10, fig826_index: 11, type: "LE Slat" },
  aoa: { takeoff: 10, landing: 5 },
};

const sectionEta = (() => {
  const spans = aircraftConfig.wing.sectionSpans;
  const semi = spans.reduce((a, b) => a + b, 0);
  let cum = 0;
  return spans.map(s => { cum += s; return +(cum / semi).toFixed(4); });
})();

const roskamRefs = [
  { fig: "Fig 8.17", desc: "Fowler flap α_δ vs deflection", eq: "Eq 8.6", usage: "dcl = cl_α · α_δ · c'/c · δ_f" },
  { fig: "Fig 8.26", desc: "Slat cl_δ vs cf/c", eq: "Eq 8.15", usage: "dcl = cl_δ · δ_s · c'/c" },
  { fig: "Fig 8.31", desc: "Base Δcl_max vs t/c", eq: "Eq 8.18", usage: "Δcl_max = k₁·k₂·k₃·(Δcl_max)_base" },
  { fig: "Fig 8.32", desc: "k₁ correction for cf/c", eq: "Eq 8.18", usage: "k₁(cf/c)" },
  { fig: "Fig 8.33", desc: "k₂ correction for δ_f", eq: "Eq 8.18", usage: "k₂(δ_f)" },
  { fig: "Fig 8.34", desc: "k₃ correction for δ/δ_ref", eq: "Eq 8.18", usage: "k₃(δ_f/40°)" },
  { fig: "Fig 8.35", desc: "LE slat cl_δ_max vs cf/c", eq: "Eq 8.19", usage: "Δcl_max = cl_δ_max · η_max · η_δ · δ_s · c'/c" },
  { fig: "Fig 8.36", desc: "η_max vs LE radius parameter", eq: "Eq 8.19", usage: "η_max(LER/tc)" },
  { fig: "Fig 8.37", desc: "η_δ vs slat deflection", eq: "Eq 8.19", usage: "η_δ(δ_s)" },
  { fig: "Fig 8.53", desc: "3D correction (α_δ)_CL/(α_δ)_cl vs AR", eq: "Eq 8.27", usage: "2D→3D effectiveness ratio" },
  { fig: "Fig 8.55", desc: "K_Δ sweep correction on CL_max", eq: "—", usage: "K_Δ = (1−0.08cos²Λ)·cos^(3/4)Λ" },
];

const computedValues = {
  KDelta: ((L) => (1 - 0.08 * Math.cos(L * Math.PI / 180) ** 2) * Math.cos(L * Math.PI / 180) ** 0.75)(31.0),
  cPrimeOverC_flap_0: 1 + 0.25 * Math.cos(0),
  cPrimeOverC_flap_30: 1 + 0.25 * Math.cos(30 * Math.PI / 180),
  cPrimeOverC_slat_0: 1 + 0.10 * Math.cos(0),
  cPrimeOverC_slat_30: 1 + 0.10 * Math.cos(30 * Math.PI / 180),
};

const equations = {
  CL_integration: "C_L = (b · c_ref / S_ref) · ∫ [cl·(c/c_ref)] dη",
  CL_required: "C_L_req = 2W / (ρ · V² · S_ref · cos(θ))",
  VS: "V_S = √(2W / (ρ · S_ref · CL_max))",
  VLOF: "V_LOF = 1.1 · V_S",
  VAPP: "V_APP = 1.23 · V_S",
  dcl_flap: "Δcl_flap = cl_α · α_δ · (c'/c) · δ_f · (CL_α_W/cl_α) · (α_δ)_CL/(α_δ)_cl",
  dcl_slat: "Δcl_slat = cl_δ · δ_s · (c'/c) · (CL_α_W/cl_α) · (α_δ)_CL/(α_δ)_cl",
  dclmax_TE: "Δcl_max_TE = k₁ · k₂ · k₃ · (Δcl_max)_base",
  dclmax_LE: "Δcl_max_LE = cl_δ_max · η_max · η_δ · δ_s · (c'/c)",
  CLmax: "CL_max = CL_max_W + ΔCL_max_TE + ΔCL_max_LE",
  KDelta: "K_Δ = (1 − 0.08·cos²Λ_c/4) · cos^(3/4)(Λ_c/4)",
  eta: "η = 2y / b",
  cPrimeOverC: "c'/c = 1 + (cf/c)·cos(δ)  [Fowler extension]",
};

// --- Styles ---
const palette = {
  bg: "#0c1117",
  card: "#151c25",
  cardBorder: "#1e2a38",
  cardHover: "#1a2433",
  accent: "#4fc3f7",
  accentDim: "#2a7da8",
  warn: "#ffb74d",
  pass: "#66bb6a",
  fail: "#ef5350",
  text: "#d8dee9",
  textDim: "#7b8ca3",
  textBright: "#eceff4",
  eqBg: "#111820",
  eqBorder: "#1a2636",
  tagBg: "#162030",
};

function App() {
  const [activeTab, setActiveTab] = useState("overview");

  const tabs = [
    { id: "overview", label: "Overview" },
    { id: "geometry", label: "Wing Geometry" },
    { id: "airfoils", label: "Airfoils" },
    { id: "devices", label: "High-Lift Devices" },
    { id: "equations", label: "Equations" },
    { id: "roskam", label: "Roskam References" },
    { id: "methodology", label: "Methodology" },
  ];

  return (
    <div style={{
      fontFamily: "'IBM Plex Mono', 'JetBrains Mono', 'Fira Code', monospace",
      background: palette.bg,
      color: palette.text,
      minHeight: "100vh",
      padding: "0",
    }}>
      <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@300;400;500;600&family=IBM+Plex+Sans:wght@300;400;500;600;700&display=swap" rel="stylesheet" />

      {/* Header */}
      <div style={{
        background: `linear-gradient(135deg, ${palette.card} 0%, #0f1922 100%)`,
        borderBottom: `1px solid ${palette.cardBorder}`,
        padding: "28px 32px 20px",
      }}>
        <div style={{ display: "flex", alignItems: "baseline", gap: 16, marginBottom: 6 }}>
          <span style={{
            fontFamily: "'IBM Plex Sans', sans-serif",
            fontSize: 22,
            fontWeight: 700,
            color: palette.textBright,
            letterSpacing: "-0.02em",
          }}>High-Lift System Sizing</span>
          <span style={{
            fontSize: 11,
            color: palette.accentDim,
            background: palette.tagBg,
            padding: "3px 10px",
            borderRadius: 4,
            border: `1px solid ${palette.cardBorder}`,
            letterSpacing: "0.05em",
            textTransform: "uppercase",
          }}>Roskam Part VI Ch. 8</span>
        </div>
        <p style={{
          fontFamily: "'IBM Plex Sans', sans-serif",
          fontSize: 13,
          color: palette.textDim,
          margin: 0,
          fontWeight: 300,
        }}>
          Fowler Flaps + Leading Edge Slats · OpenVSP baseline · Trade study over δ_f × δ_s
        </p>
      </div>

      {/* Tab Bar */}
      <div style={{
        display: "flex",
        gap: 0,
        borderBottom: `1px solid ${palette.cardBorder}`,
        background: palette.card,
        overflowX: "auto",
      }}>
        {tabs.map(t => (
          <button
            key={t.id}
            onClick={() => setActiveTab(t.id)}
            style={{
              fontFamily: "'IBM Plex Sans', sans-serif",
              fontSize: 12,
              fontWeight: activeTab === t.id ? 600 : 400,
              color: activeTab === t.id ? palette.accent : palette.textDim,
              background: "transparent",
              border: "none",
              borderBottom: activeTab === t.id ? `2px solid ${palette.accent}` : "2px solid transparent",
              padding: "12px 18px",
              cursor: "pointer",
              whiteSpace: "nowrap",
              transition: "all 0.15s",
            }}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Content */}
      <div style={{ padding: "24px 28px", maxWidth: 960, margin: "0 auto" }}>
        {activeTab === "overview" && <OverviewTab />}
        {activeTab === "geometry" && <GeometryTab />}
        {activeTab === "airfoils" && <AirfoilsTab />}
        {activeTab === "devices" && <DevicesTab />}
        {activeTab === "equations" && <EquationsTab />}
        {activeTab === "roskam" && <RoskamTab />}
        {activeTab === "methodology" && <MethodologyTab />}
      </div>
    </div>
  );
}

// --- Reusable components ---

function Card({ title, children, style }) {
  return (
    <div style={{
      background: palette.card,
      border: `1px solid ${palette.cardBorder}`,
      borderRadius: 8,
      padding: "20px 24px",
      marginBottom: 16,
      ...style,
    }}>
      {title && (
        <div style={{
          fontFamily: "'IBM Plex Sans', sans-serif",
          fontSize: 14,
          fontWeight: 600,
          color: palette.textBright,
          marginBottom: 14,
          paddingBottom: 10,
          borderBottom: `1px solid ${palette.cardBorder}`,
        }}>{title}</div>
      )}
      {children}
    </div>
  );
}

function Stat({ label, value, unit, note, color }) {
  return (
    <div style={{ marginBottom: 12 }}>
      <div style={{ fontSize: 11, color: palette.textDim, marginBottom: 3, textTransform: "uppercase", letterSpacing: "0.04em" }}>{label}</div>
      <div style={{ display: "flex", alignItems: "baseline", gap: 6 }}>
        <span style={{ fontSize: 18, fontWeight: 600, color: color || palette.accent, fontFamily: "'IBM Plex Mono', monospace" }}>{value}</span>
        {unit && <span style={{ fontSize: 11, color: palette.textDim }}>{unit}</span>}
      </div>
      {note && <div style={{ fontSize: 11, color: palette.textDim, marginTop: 2, fontStyle: "italic" }}>{note}</div>}
    </div>
  );
}

function EqBlock({ eq, label }) {
  return (
    <div style={{
      background: palette.eqBg,
      border: `1px solid ${palette.eqBorder}`,
      borderRadius: 6,
      padding: "12px 16px",
      marginBottom: 10,
      fontFamily: "'IBM Plex Mono', monospace",
      fontSize: 13,
      color: palette.accent,
      overflowX: "auto",
    }}>
      {label && <div style={{ fontSize: 10, color: palette.textDim, marginBottom: 6, textTransform: "uppercase", letterSpacing: "0.05em" }}>{label}</div>}
      <code>{eq}</code>
    </div>
  );
}

function DataTable({ headers, rows, highlightCol }) {
  return (
    <div style={{ overflowX: "auto" }}>
      <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 12 }}>
        <thead>
          <tr>
            {headers.map((h, i) => (
              <th key={i} style={{
                textAlign: "left",
                padding: "8px 12px",
                borderBottom: `1px solid ${palette.cardBorder}`,
                color: palette.textDim,
                fontSize: 10,
                textTransform: "uppercase",
                letterSpacing: "0.05em",
                fontWeight: 500,
                whiteSpace: "nowrap",
              }}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, ri) => (
            <tr key={ri} style={{ background: ri % 2 === 0 ? "transparent" : `${palette.cardBorder}22` }}>
              {row.map((cell, ci) => (
                <td key={ci} style={{
                  padding: "7px 12px",
                  borderBottom: `1px solid ${palette.cardBorder}33`,
                  color: ci === highlightCol ? palette.accent : palette.text,
                  fontWeight: ci === highlightCol ? 500 : 400,
                  fontFamily: typeof cell === "number" || (typeof cell === "string" && /^[\d.]+$/.test(cell)) ? "'IBM Plex Mono', monospace" : "'IBM Plex Sans', sans-serif",
                  whiteSpace: "nowrap",
                }}>{cell}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Tag({ children, color }) {
  return (
    <span style={{
      fontSize: 10,
      padding: "2px 8px",
      borderRadius: 3,
      background: (color || palette.accentDim) + "22",
      color: color || palette.accent,
      border: `1px solid ${(color || palette.accentDim)}44`,
      textTransform: "uppercase",
      letterSpacing: "0.04em",
      fontWeight: 500,
    }}>{children}</span>
  );
}

// --- Tabs ---

function OverviewTab() {
  const ac = aircraftConfig;
  return (
    <>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
        <Card title="Weight Conditions">
          <Stat label="Takeoff Weight (WTO)" value={ac.weights.WTO.toLocaleString()} unit="lb" />
          <Stat label="Landing Weight (WLD)" value={ac.weights.WLD.toLocaleString()} unit="lb" note={`WTO − ${(ac.weights.fuelFrac * 100).toFixed(0)}% × ${ac.weights.fuelBurn.toLocaleString()} lb fuel`} />
          <Stat label="Fuel Capacity" value={ac.weights.fuelBurn.toLocaleString()} unit="lb" />
        </Card>
        <Card title="Flight Conditions">
          <Stat label="Takeoff AoA" value={ac.aoa.takeoff} unit="deg" />
          <Stat label="Landing AoA" value={ac.aoa.landing} unit="deg" />
          <Stat label="Air Density (ρ)" value={ac.atmo.density} unit={ac.atmo.densityUnit} note="Sea level standard" />
        </Card>
      </div>

      <Card title="Wing Planform">
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 16 }}>
          <Stat label="Aspect Ratio" value={ac.wing.AR} />
          <Stat label="Quarter-Chord Sweep (Λ_c/4)" value={ac.wing.Lambda_c4 + "°"} />
          <Stat label="Aileron Span" value={(ac.wing.aileronSpan * 100).toFixed(0) + "%"} unit="of semispan" />
        </div>
      </Card>

      <Card title="High-Lift Device Configuration">
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
          <div>
            <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 10 }}>
              <Tag>Trailing Edge</Tag>
              <span style={{ fontSize: 13, fontWeight: 500, color: palette.textBright, fontFamily: "'IBM Plex Sans', sans-serif" }}>{ac.flap.type} Flap</span>
            </div>
            <Stat label="Chord Ratio (cf/c)" value={ac.flap.cfOverC} />
            <Stat label="Fig 8.17 Row Index" value={ac.flap.fig817_index} note="cf/c = [0.15, 0.20, 0.25, 0.30, 0.40]" />
          </div>
          <div>
            <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 10 }}>
              <Tag>Leading Edge</Tag>
              <span style={{ fontSize: 13, fontWeight: 500, color: palette.textBright, fontFamily: "'IBM Plex Sans', sans-serif" }}>{ac.slat.type}</span>
            </div>
            <Stat label="Chord Ratio (cf/c)" value={ac.slat.cfOverC} />
            <Stat label="Fig 8.26 Index" value={ac.slat.fig826_index} note="Into 0.00:0.01:0.50 interpolated table" />
          </div>
        </div>
      </Card>

      <Card title="Computed Correction Factors">
        <EqBlock eq={equations.KDelta} label="Sweep correction on ΔCL_max (Fig 8.55)" />
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 16, marginTop: 12 }}>
          <Stat label="K_Δ" value={computedValues.KDelta.toFixed(4)} note={`Λ_c/4 = ${ac.wing.Lambda_c4}°`} />
          <Stat label="c'/c Flap @ δ=0°" value={computedValues.cPrimeOverC_flap_0.toFixed(4)} />
          <Stat label="c'/c Flap @ δ=30°" value={computedValues.cPrimeOverC_flap_30.toFixed(4)} />
        </div>
        <EqBlock eq={equations.cPrimeOverC} label="Fowler chord extension" />
      </Card>

      <Card title="Speed Definitions">
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
          <div>
            <EqBlock eq={equations.VS} label="Stall speed" />
            <EqBlock eq={equations.VLOF} label="Liftoff speed" />
          </div>
          <div>
            <EqBlock eq={equations.VAPP} label="Approach speed" />
            <EqBlock eq={equations.CL_required} label="Required CL" />
          </div>
        </div>
        <div style={{ fontSize: 12, color: palette.textDim, marginTop: 8, fontFamily: "'IBM Plex Sans', sans-serif" }}>
          V_S is computed from CL_max (including device increments). V_LOF and V_APP set the required CL for each flight phase. The pitch angle cos(θ) correction accounts for the component of weight in the lift direction.
        </div>
      </Card>
    </>
  );
}

function GeometryTab() {
  const ac = aircraftConfig;
  const spans = ac.wing.sectionSpans;
  const semi = spans.reduce((a, b) => a + b, 0);

  let cumSpan = 0;
  const sectionRows = spans.map((s, i) => {
    cumSpan += s;
    const eta = cumSpan / semi;
    return [
      i + 1,
      ac.airfoils.names[i],
      s.toFixed(2) + " ft",
      cumSpan.toFixed(2) + " ft",
      eta.toFixed(4),
      ac.airfoils.tc_pct[i] + "%",
    ];
  });

  const flapBegin = sectionEta[1];
  const flapEnd = sectionEta[sectionEta.length - 2] - ac.wing.aileronSpan;
  const slatBegin = sectionEta[1];
  const slatEnd = sectionEta[sectionEta.length - 2];

  return (
    <>
      <Card title="Wing Section Breakdown">
        <DataTable
          headers={["Section", "Airfoil", "Span", "Cumulative", "η Breakpoint", "t/c"]}
          rows={sectionRows}
          highlightCol={4}
        />
        <div style={{ fontSize: 11, color: palette.textDim, marginTop: 12, fontFamily: "'IBM Plex Sans', sans-serif" }}>
          Semispan = {semi.toFixed(2)} ft · η = 2y/b normalized from root (0) to tip (1). Section breakpoints define where airfoil properties and device coverage change.
        </div>
      </Card>

      <Card title="Device Spanwise Extent">
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
          <div>
            <div style={{ fontSize: 12, fontWeight: 500, color: palette.textBright, marginBottom: 8, fontFamily: "'IBM Plex Sans', sans-serif" }}>Fowler Flap Coverage</div>
            <Stat label="η_begin" value={flapBegin.toFixed(4)} note="Starts at section 2 boundary" />
            <Stat label="η_end" value={flapEnd.toFixed(4)} note={`Section ${spans.length - 1} boundary − ${(ac.wing.aileronSpan * 100)}% aileron`} />
            <Stat label="Coverage" value={((flapEnd - flapBegin) * 100).toFixed(1) + "%"} unit="of semispan" />
          </div>
          <div>
            <div style={{ fontSize: 12, fontWeight: 500, color: palette.textBright, marginBottom: 8, fontFamily: "'IBM Plex Sans', sans-serif" }}>LE Slat Coverage</div>
            <Stat label="η_begin" value={slatBegin.toFixed(4)} note="Starts at section 2 boundary" />
            <Stat label="η_end" value={slatEnd.toFixed(4)} note={`Section ${spans.length - 1} boundary (full)`} />
            <Stat label="Coverage" value={((slatEnd - slatBegin) * 100).toFixed(1) + "%"} unit="of semispan" />
          </div>
        </div>
      </Card>

      {/* Spanwise bar visualization */}
      <Card title="Spanwise Device Layout">
        <div style={{ position: "relative", height: 90, marginTop: 8 }}>
          {/* Wing bar */}
          <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: 20, background: palette.eqBg, borderRadius: 4, border: `1px solid ${palette.cardBorder}` }}>
            <span style={{ position: "absolute", left: 4, top: 2, fontSize: 9, color: palette.textDim }}>ROOT η=0</span>
            <span style={{ position: "absolute", right: 4, top: 2, fontSize: 9, color: palette.textDim }}>TIP η=1</span>
          </div>
          {/* Flap */}
          <div style={{
            position: "absolute", top: 28, left: `${flapBegin * 100}%`, width: `${(flapEnd - flapBegin) * 100}%`,
            height: 22, background: `${palette.accent}33`, borderRadius: 3, border: `1px solid ${palette.accent}88`,
            display: "flex", alignItems: "center", justifyContent: "center",
          }}>
            <span style={{ fontSize: 10, color: palette.accent, fontWeight: 500 }}>FOWLER FLAP</span>
          </div>
          {/* Slat */}
          <div style={{
            position: "absolute", top: 56, left: `${slatBegin * 100}%`, width: `${(slatEnd - slatBegin) * 100}%`,
            height: 22, background: `${palette.warn}33`, borderRadius: 3, border: `1px solid ${palette.warn}88`,
            display: "flex", alignItems: "center", justifyContent: "center",
          }}>
            <span style={{ fontSize: 10, color: palette.warn, fontWeight: 500 }}>LE SLAT</span>
          </div>
          {/* Section dividers */}
          {sectionEta.map((e, i) => (
            <div key={i} style={{
              position: "absolute", top: 0, left: `${e * 100}%`, height: 84,
              borderLeft: `1px dashed ${palette.cardBorder}`, zIndex: 1,
            }}>
              <span style={{ position: "absolute", bottom: -14, left: -8, fontSize: 8, color: palette.textDim }}>{e.toFixed(2)}</span>
            </div>
          ))}
        </div>
      </Card>
    </>
  );
}

function AirfoilsTab() {
  const ac = aircraftConfig;
  const rows = ac.airfoils.names.map((n, i) => [
    i + 1,
    `NACA ${n}`,
    ac.airfoils.tc_pct[i] + "%",
    ac.airfoils.clAlpha[i].toFixed(4) + " /rad",
    (ac.airfoils.clAlpha[i] * 180 / Math.PI).toFixed(4) + " /deg",
    ac.airfoils.clMax[i].toFixed(4),
  ]);

  return (
    <>
      <Card title="Section Airfoil Properties">
        <DataTable
          headers={["Section", "Airfoil", "t/c", "cl_α (/rad)", "cl_α (/deg)", "cl_max"]}
          rows={rows}
          highlightCol={5}
        />
        <div style={{ fontSize: 11, color: palette.textDim, marginTop: 12, fontFamily: "'IBM Plex Sans', sans-serif" }}>
          All sections use cl_α = 2π/rad (thin airfoil theory). cl_max values are section-specific and determine the local stall angle at each spanwise station via Roskam Sec. 8.1.3.4.
        </div>
      </Card>

      <Card title="Stall Angle Computation (per station)">
        <EqBlock eq="α_stall_local = α_TO + (cl_max(η) − cl_TO(η)) / (CL_α_W · π/180)" label="Roskam Sec. 8.1.3.4 — local stall angle" />
        <div style={{ fontSize: 12, color: palette.textDim, marginTop: 8, fontFamily: "'IBM Plex Sans', sans-serif" }}>
          The wing stall angle is the minimum of all local stall angles. The code currently hardcodes α_stall = 13° (see <code style={{color: palette.accent}}>ComputeCleanWing.m</code> line 48). The station where stall first occurs (η_stall) identifies the critical spanwise location.
        </div>
      </Card>

      <Card title="Thickness-to-Chord Progression">
        <div style={{ display: "flex", alignItems: "flex-end", gap: 12, height: 100, padding: "10px 0" }}>
          {ac.airfoils.tc_pct.map((tc, i) => (
            <div key={i} style={{ display: "flex", flexDirection: "column", alignItems: "center", flex: 1 }}>
              <span style={{ fontSize: 10, color: palette.accent, marginBottom: 4 }}>{tc}%</span>
              <div style={{
                width: "100%",
                height: `${(tc / 14) * 70}px`,
                background: `linear-gradient(to top, ${palette.accent}44, ${palette.accent}11)`,
                borderRadius: "4px 4px 0 0",
                border: `1px solid ${palette.accent}44`,
                borderBottom: "none",
              }} />
              <div style={{ fontSize: 9, color: palette.textDim, marginTop: 4 }}>§{i + 1}</div>
            </div>
          ))}
        </div>
        <div style={{ fontSize: 11, color: palette.textDim, marginTop: 4, textAlign: "center", fontFamily: "'IBM Plex Sans', sans-serif" }}>
          Inboard → Outboard (root to tip)
        </div>
      </Card>
    </>
  );
}

function DevicesTab() {
  const ac = aircraftConfig;

  const deflections = [0, 5, 10, 15, 20, 25, 30, 35, 40];
  const alphaDelta_025 = [0.52, 0.52, 0.51, 0.50, 0.49, 0.48, 0.46, 0.43, 0.39];

  const cPrime = deflections.map(d => (1 + ac.flap.cfOverC * Math.cos(d * Math.PI / 180)).toFixed(4));
  const cPrimeSlat = deflections.map(d => (1 + ac.slat.cfOverC * Math.cos(d * Math.PI / 180)).toFixed(4));

  return (
    <>
      <Card title="Fowler Flap: α_δ vs Deflection (Fig 8.17, cf/c = 0.25)">
        <DataTable
          headers={["δ_f (deg)", ...deflections.map(d => d + "°")]}
          rows={[
            ["α_δ", ...alphaDelta_025.map(v => v.toFixed(2))],
            ["c'/c (Fowler)", ...cPrime],
          ]}
        />
        <div style={{ fontSize: 11, color: palette.textDim, marginTop: 10, fontFamily: "'IBM Plex Sans', sans-serif" }}>
          α_δ decreases with deflection (effectiveness loss). c'/c increases from Fowler extension, adding chord area. These compete: more deflection = less effective per degree but more extension.
        </div>
      </Card>

      <Card title="LE Slat: Effectiveness">
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
          <div>
            <Stat label="cl_δ (Fig 8.26)" value="Interpolated at cf/c = 0.10" />
            <Stat label="Source" value="per radian" note="Converted from per-degree digitized data × (180/π)" />
          </div>
          <div>
            <Stat label="c'/c Slat @ δ=0°" value={computedValues.cPrimeOverC_slat_0.toFixed(4)} />
            <Stat label="c'/c Slat @ δ=30°" value={computedValues.cPrimeOverC_slat_30.toFixed(4)} />
          </div>
        </div>
      </Card>

      <Card title="TE Δcl_max Correction Factors (Eq 8.18)">
        <EqBlock eq={equations.dclmax_TE} />
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 12, marginTop: 12 }}>
          <div style={{ background: palette.eqBg, padding: 12, borderRadius: 6, border: `1px solid ${palette.eqBorder}` }}>
            <div style={{ fontSize: 10, color: palette.textDim, marginBottom: 4, textTransform: "uppercase" }}>k₁ (Fig 8.32)</div>
            <div style={{ fontSize: 12, color: palette.text, fontFamily: "'IBM Plex Sans', sans-serif" }}>Linear from cf/c%: [0→0, 28→1.2]</div>
            <div style={{ fontSize: 11, color: palette.accent, marginTop: 4 }}>At cf/c=25%: k₁ ≈ {(25 / 28 * 1.2).toFixed(3)}</div>
          </div>
          <div style={{ background: palette.eqBg, padding: 12, borderRadius: 6, border: `1px solid ${palette.eqBorder}` }}>
            <div style={{ fontSize: 10, color: palette.textDim, marginBottom: 4, textTransform: "uppercase" }}>k₂ (Fig 8.33)</div>
            <div style={{ fontSize: 12, color: palette.text, fontFamily: "'IBM Plex Sans', sans-serif" }}>Increases with δ_f, saturates at ~35°</div>
            <div style={{ fontSize: 11, color: palette.accent, marginTop: 4 }}>k₂(40°) = 1.000</div>
          </div>
          <div style={{ background: palette.eqBg, padding: 12, borderRadius: 6, border: `1px solid ${palette.eqBorder}` }}>
            <div style={{ fontSize: 10, color: palette.textDim, marginBottom: 4, textTransform: "uppercase" }}>k₃ (Fig 8.34)</div>
            <div style={{ fontSize: 12, color: palette.text, fontFamily: "'IBM Plex Sans', sans-serif" }}>Ratio δ_f/δ_ref, δ_ref = 40°</div>
            <div style={{ fontSize: 11, color: palette.accent, marginTop: 4 }}>k₃(1.0) ≈ 0.995</div>
          </div>
        </div>
      </Card>

      <Card title="LE Δcl_max Correction Factors (Eq 8.19)">
        <EqBlock eq={equations.dclmax_LE} />
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 12, marginTop: 12 }}>
          <div style={{ background: palette.eqBg, padding: 12, borderRadius: 6, border: `1px solid ${palette.eqBorder}` }}>
            <div style={{ fontSize: 10, color: palette.textDim, marginBottom: 4, textTransform: "uppercase" }}>cl_δ_max (Fig 8.35)</div>
            <div style={{ fontSize: 12, color: palette.text, fontFamily: "'IBM Plex Sans', sans-serif" }}>Theoretical max lift effectiveness vs cf/c</div>
            <div style={{ fontSize: 11, color: palette.accent, marginTop: 4 }}>At cf/c=0.10 → interpolated</div>
          </div>
          <div style={{ background: palette.eqBg, padding: 12, borderRadius: 6, border: `1px solid ${palette.eqBorder}` }}>
            <div style={{ fontSize: 10, color: palette.textDim, marginBottom: 4, textTransform: "uppercase" }}>η_max (Fig 8.36)</div>
            <div style={{ fontSize: 12, color: palette.text, fontFamily: "'IBM Plex Sans', sans-serif" }}>LER/tc = 0.0447 + (tc%−4)·0.01394</div>
            <div style={{ fontSize: 11, color: palette.accent, marginTop: 4 }}>Per-section from airfoil t/c</div>
          </div>
          <div style={{ background: palette.eqBg, padding: 12, borderRadius: 6, border: `1px solid ${palette.eqBorder}` }}>
            <div style={{ fontSize: 10, color: palette.textDim, marginBottom: 4, textTransform: "uppercase" }}>η_δ (Fig 8.37)</div>
            <div style={{ fontSize: 12, color: palette.text, fontFamily: "'IBM Plex Sans', sans-serif" }}>Drops sharply above δ_s ≈ 15°</div>
            <div style={{ fontSize: 11, color: palette.accent, marginTop: 4 }}>η_δ(0°)=1.0, η_δ(40°)=0.206</div>
          </div>
        </div>
      </Card>

      <Card title="3D Correction (Fig 8.53 + Eq 8.27)">
        <EqBlock eq="Correction = (CL_α_W / cl_α) × (α_δ)_CL / (α_δ)_cl" label="Applied to both flap and slat Δcl" />
        <div style={{ fontSize: 12, color: palette.textDim, marginTop: 8, fontFamily: "'IBM Plex Sans', sans-serif" }}>
          The Fig 8.53 lookup uses AR = {ac.wing.AR} and the device's cf/c to get (α_δ)_CL/(α_δ)_cl. At AR = 15, this ratio is very close to 1.0 (asymptotic behavior for high AR wings). The CL_α_W/cl_α ratio accounts for the finite-wing lift curve slope reduction.
        </div>
        <div style={{ fontSize: 12, color: palette.warn, marginTop: 8, fontFamily: "'IBM Plex Sans', sans-serif" }}>
          ⚠ AR = 15 exceeds the original Roskam digitized data range (max ~10). The code uses extrapolation via <code style={{color: palette.accent}}>linspace(1, 20, 100)</code> in LoadRoskamData.m.
        </div>
      </Card>
    </>
  );
}

function EquationsTab() {
  const groups = [
    {
      title: "CL Integration (from OpenVSP spanwise loading)",
      eqs: [
        { eq: equations.CL_integration, note: "Trapezoidal integration of cl·(c/c_ref) over η. Implemented in ComputeCL.m." },
        { eq: equations.eta, note: "Non-dimensional span coordinate. Implemented in ComputeEta.m." },
      ]
    },
    {
      title: "Required CL at Flight Phases",
      eqs: [
        { eq: equations.CL_required, note: "cos(θ) correction for pitch angle at takeoff/landing. Implemented in CLtoWeight.m." },
        { eq: equations.VS, note: "Stall speed from CLmax including device increments." },
        { eq: equations.VLOF, note: "FAR Part 25 takeoff safety margin." },
        { eq: equations.VAPP, note: "FAR Part 25 approach safety margin." },
      ]
    },
    {
      title: "Flap/Slat Lift Increments (per station)",
      eqs: [
        { eq: equations.dcl_flap, note: "Roskam Eq 8.6 with 3D corrections from Eq 8.27. Applied where η_begin_flap ≤ η ≤ η_end_flap. Multiplied by cos(Λ_HL) and c/c_ref. Implemented in ModifiedCLDistro.m." },
        { eq: equations.dcl_slat, note: "Roskam Eq 8.15 with 3D corrections. Applied where η_begin_slat ≤ η ≤ η_end_slat. Multiplied by cos(Λ_LE) and c/c_ref. Implemented in ModifiedCLDistro.m." },
      ]
    },
    {
      title: "CLmax with Devices",
      eqs: [
        { eq: equations.dclmax_TE, note: "TE flap Δcl_max from Roskam Eq 8.18. Mapped to stations, multiplied by c/c_ref, integrated, then scaled by K_Δ." },
        { eq: equations.dclmax_LE, note: "LE slat Δcl_max from Roskam Eq 8.19. Same integration process." },
        { eq: equations.CLmax, note: "Total CLmax = clean + ΔCL_max_TE + ΔCL_max_LE. Both increments scaled by K_Δ for sweep." },
        { eq: equations.KDelta, note: `K_Δ = ${computedValues.KDelta.toFixed(4)} at Λ = ${aircraftConfig.wing.Lambda_c4}°. Roskam Fig 8.55, p.263.` },
      ]
    },
    {
      title: "Fowler Extension",
      eqs: [
        { eq: equations.cPrimeOverC, note: "c'/c > 1 means the flap adds chord area, increasing the effective lifting surface." },
      ]
    },
  ];

  return (
    <>
      {groups.map((g, gi) => (
        <Card key={gi} title={g.title}>
          {g.eqs.map((e, ei) => (
            <div key={ei} style={{ marginBottom: ei < g.eqs.length - 1 ? 16 : 0 }}>
              <EqBlock eq={e.eq} />
              <div style={{ fontSize: 11, color: palette.textDim, marginTop: 4, paddingLeft: 4, fontFamily: "'IBM Plex Sans', sans-serif" }}>{e.note}</div>
            </div>
          ))}
        </Card>
      ))}
    </>
  );
}

function RoskamTab() {
  return (
    <>
      <Card title="Roskam Part VI Chapter 8 — Figure & Table References">
        <DataTable
          headers={["Figure", "Description", "Equation", "Usage in Code"]}
          rows={roskamRefs.map(r => [r.fig, r.desc, r.eq, r.usage])}
          highlightCol={0}
        />
      </Card>

      <Card title="Data Provenance">
        <div style={{ fontSize: 12, color: palette.text, lineHeight: 1.7, fontFamily: "'IBM Plex Sans', sans-serif" }}>
          All empirical data is digitized from Roskam Part VI Chapter 8 figures and stored in <code style={{color: palette.accent}}>LoadRoskamData.m</code>. Interpolation to design conditions happens in <code style={{color: palette.accent}}>ComputeHighLiftIncrements.m</code>. The Fig 8.53 3D correction grid is built by resampling all 9 α_δ_cl curves (0.1–0.9) onto a common AR vector using <code style={{color: palette.accent}}>linspace(1, 20, 100)</code> and clamping ratios below 1.0.
        </div>
      </Card>

      <Card title="File → Function Map">
        <DataTable
          headers={["File", "Purpose", "Key Outputs"]}
          rows={[
            ["AircraftConfig.m", "All aircraft parameters in one place", "ac struct"],
            ["LoadRoskamData.m", "Digitized empirical charts", "roskam struct"],
            ["ReadFileAero.m", "Parse OpenVSP polar CSV", "VSP struct (cl distributions, geometry)"],
            ["ReadFileGeom.m", "Parse DegenGeom CSV for LE positions", "degenData struct"],
            ["ComputeEta.m", "η = 2y/b", "ndEtaScaling"],
            ["ComputeCL.m", "Trapezoidal CL integration", "CLwholeWing"],
            ["CLtoWeight.m", "CL_req from weight & speed", "CL"],
            ["DeltaCL.m", "Gap: CL_req − CL_clean", "CLdiff"],
            ["ComputeCleanWing.m", "Clean wing analysis", "CL_TO, CL_LD, CLalpha_W, CLmax_W, α_stall"],
            ["ComputeHighLiftIncrements.m", "Precompute all device arrays", "hl struct (sweep, c'/c, Δcl_max tables)"],
            ["ModifiedCLDistro.m", "Add flap+slat Δcl to spanwise loading", "Modified cl·c/c_ref distribution"],
            ["RunTradeSweep.m", "41×41 δ_f × δ_s grid evaluation", "CL grids, best configurations"],
            ["PlotResults.m", "Heat maps + spanwise loading plots", "Figures"],
            ["flaplift.m", "Main entry point", "Orchestrates all steps 1–8"],
          ]}
          highlightCol={0}
        />
      </Card>
    </>
  );
}

function MethodologyTab() {
  const steps = [
    {
      num: 1,
      title: "Load Configuration",
      desc: "Aircraft geometry, airfoil properties, weights, and file paths are defined in AircraftConfig.m. Roskam empirical data is loaded and pre-interpolated in LoadRoskamData.m.",
      files: ["AircraftConfig.m", "LoadRoskamData.m"],
    },
    {
      num: 2,
      title: "Read OpenVSP Data",
      desc: "The VSPAERO polar CSV is parsed for cl·(c/c_ref) distributions at the takeoff and landing AoA. Chord, span, and reference values are extracted. The DegenGeom CSV provides LE x-positions for sweep computation.",
      files: ["ReadFileAero.m", "ReadFileGeom.m"],
    },
    {
      num: 3,
      title: "Compute Section η Breakpoints",
      desc: "Cumulative section spans are normalized by semispan to create η breakpoints. These define where airfoil properties change and where devices begin/end.",
      files: ["flaplift.m (Step 3)"],
    },
    {
      num: 4,
      title: "Clean Wing Analysis",
      desc: "CL is integrated at TO and LD angles. The lift curve slope CL_α_W is computed from the difference. Local stall angles are found per Roskam Sec. 8.1.3.4 by comparing cl_max(η) against the local loading. CLmax_W comes from the spanwise loading at the stall angle.",
      files: ["ComputeCleanWing.m"],
      note: "α_stall is currently hardcoded to 13° — see line 48.",
    },
    {
      num: 5,
      title: "Precompute High-Lift Increments",
      desc: "Everything that doesn't depend on the (δ_f, δ_s) loop indices is computed once: hinge-line and LE sweep distributions, c'/c arrays for all deflections, α_δ rows, cl_δ for the slat, 3D correction factors, K_Δ, and the full (nStations × nDeflections) Δcl_max tables for both TE flaps and LE slats.",
      files: ["ComputeHighLiftIncrements.m"],
    },
    {
      num: 6,
      title: "Trade Study Sweep",
      desc: "A 41×41 grid (δ_f = 0°:1°:40°, δ_s = 0°:1°:40°) is evaluated. For each combination: CLmax is computed with device increments → V_S, V_LOF, V_APP → CL_req at reference speeds → modified spanwise loading is built and integrated → pass/fail determined. The first passing configuration is stored.",
      files: ["RunTradeSweep.m", "ModifiedCLDistro.m", "ComputeCL.m", "CLtoWeight.m"],
    },
    {
      num: 7,
      title: "Results & Plotting",
      desc: "Heat maps show (CL − CL_req) over the δ_f × δ_s grid with the zero-contour (pass/fail boundary) highlighted. Spanwise loading plots compare clean vs. modified distributions for the best configuration.",
      files: ["PlotResults.m"],
    },
  ];

  return (
    <>
      <Card title="Execution Pipeline">
        {steps.map((s, i) => (
          <div key={i} style={{
            display: "flex",
            gap: 16,
            marginBottom: i < steps.length - 1 ? 20 : 0,
            paddingBottom: i < steps.length - 1 ? 20 : 0,
            borderBottom: i < steps.length - 1 ? `1px solid ${palette.cardBorder}` : "none",
          }}>
            <div style={{
              minWidth: 36, height: 36, borderRadius: "50%",
              background: `${palette.accent}22`, border: `1px solid ${palette.accent}55`,
              display: "flex", alignItems: "center", justifyContent: "center",
              fontSize: 14, fontWeight: 600, color: palette.accent,
              flexShrink: 0,
            }}>{s.num}</div>
            <div style={{ flex: 1 }}>
              <div style={{
                fontSize: 14, fontWeight: 600, color: palette.textBright,
                fontFamily: "'IBM Plex Sans', sans-serif", marginBottom: 4,
              }}>{s.title}</div>
              <div style={{
                fontSize: 12, color: palette.text, lineHeight: 1.6,
                fontFamily: "'IBM Plex Sans', sans-serif", marginBottom: 6,
              }}>{s.desc}</div>
              <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
                {s.files.map((f, fi) => <Tag key={fi}>{f}</Tag>)}
              </div>
              {s.note && (
                <div style={{
                  fontSize: 11, color: palette.warn, marginTop: 6,
                  fontFamily: "'IBM Plex Sans', sans-serif",
                }}>⚠ {s.note}</div>
              )}
            </div>
          </div>
        ))}
      </Card>

      <Card title="Key Design Decisions & Assumptions">
        <div style={{ fontSize: 12, lineHeight: 1.8, fontFamily: "'IBM Plex Sans', sans-serif" }}>
          {[
            { label: "3D Method", text: "Spanwise integration of modified cl·(c/c_ref) replaces Roskam's K_b partial-span factor. The OpenVSP baseline already has 3D effects, so we modify the loading directly rather than using the simplified Eq 8.27 wholesale." },
            { label: "3D Corrections", text: "Two factors from Eq 8.27 are selectively applied: the lift curve slope ratio (CL_α_W/cl_α) and the Fig 8.53 effectiveness ratio. These improve accuracy without losing the spanwise integration approach." },
            { label: "Sweep", text: "Local hinge-line sweep (TE) and LE sweep are computed from DegenGeom x-positions, not the global Λ_c/4. The cos(Λ_local) correction is applied per station." },
            { label: "Stall Angle", text: "Currently hardcoded at 13°. The computed minimum of local stall angles (Roskam Sec. 8.1.3.4) is commented out in ComputeCleanWing.m." },
            { label: "cl_α = 2π", text: "All sections use thin airfoil theory. Real airfoils may have slightly different values depending on thickness and camber." },
            { label: "Fowler Extension", text: "c'/c = 1 + (cf/c)·cos(δ) models the chord increase from Fowler translation. This is a simplification — actual Fowler mechanisms have more complex kinematics." },
            { label: "AR Extrapolation", text: "The Fig 8.53 grid extends to AR = 20 via linear extrapolation from digitized data that only goes to ~10. At AR = 15, the correction ratio is near 1.0, so the extrapolation error is small." },
          ].map((item, i) => (
            <div key={i} style={{
              marginBottom: 12, paddingLeft: 12,
              borderLeft: `2px solid ${palette.accentDim}44`,
            }}>
              <span style={{ color: palette.accent, fontWeight: 600 }}>{item.label}: </span>
              <span style={{ color: palette.text }}>{item.text}</span>
            </div>
          ))}
        </div>
      </Card>

      <Card title="Trade Study Grid">
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
          <div>
            <Stat label="Flap Deflection Range" value="0° to 40°" note="1° increments (41 points)" />
            <Stat label="Slat Deflection Range" value="0° to 40°" note="1° increments (41 points)" />
            <Stat label="Total Evaluations" value="1,681" note="41 × 41 grid" />
          </div>
          <div>
            <Stat label="Pass Criteria (TO)" value="CL_TO ≥ CL_req_TO" note="At V_LOF = 1.1·V_S" />
            <Stat label="Pass Criteria (LD)" value="CL_LD ≥ CL_req_LD" note="At V_APP = 1.23·V_S" />
            <Stat label="Selection" value="First passing" note="Lowest δ_f, then lowest δ_s" />
          </div>
        </div>
      </Card>
    </>
  );
}

export default App;
