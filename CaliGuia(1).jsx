import { useState, useRef, useEffect } from "react";

const SYSTEM_PROMPT = `Sos "Cali Guía", el asistente turístico inteligente oficial de Santiago de Cali, Colombia. Sos experto en:

LUGARES: La Ermita, El Gato del Río, Cristo Rey, San Antonio, Galería Alameda, Bulevar de la Sexta, Teatro Municipal, Hacienda Cañasgordas, Siloé, Parque del Perro, Museo La Tertulia, Mercado de Pulgas Loma de la Cruz, Unidad Deportiva Alberto Galindo, Estadio Pascual Guerrero, Arena Cañaveralejo.

GASTRONOMÍA: Lulada, Aborrajado, Champús, Cholados, Macetas de dulce, Sancocho de gallina, Arrechón, Viche. El turista gasta 35% de su presupuesto en comida. Galería Alameda: 15,000 personas los fines de semana. Parque del Perro: 40+ establecimientos.

MOVILIDAD: MIO (bus articulado), MIO Cable a Siloé (5,000 personas/día, solo 5% turistas), 250+ puntos WiFi gratuito de la Alcaldía/Datic.

TURISMO MÉDICO: Clínicas Valle del Lili, Imbanaco, Farallones. Gasto: $250-300 USD/día.
NATURALEZA: 562 especies de aves, Farallones, Pance, Km 18, Colombia BirdFair. Gasto: $180 USD/día.
SALSA/CULTURA: Agenda nocturna, Juanchito, El Obrero, Tin Tin Deo. Gasto: $80-100 USD/día.

EVENTOS 2026: Petronio Álvarez (agosto, 350,000 visitantes, Unidad Deportiva), Feria de Cali (diciembre, 300,000, Salsódromo), Festival Mundial de Salsa (45,000), Colombia BirdFair (20,000), Semana Santa (400,000-500,000 en los cerros). Cumbre Afrodiaspórica Mundial en Petronio 2026.

SEGURIDAD: Puntos de Atención Turística (PAT) en aeropuerto, terminal y centro. Zonas seguras: San Antonio, Granada, El Peñón.

REGLAS CRÍTICAS DE TONO:
- Perfil SALSA/CULTURA: Lenguaje caleño vibrante. Usá "Oís", "vení", "tenés", "bacano". Sé cercano y emocionado.
- Perfil MÉDICO: Formal, pausado, servicial. Nada de slang.
- Perfil NATURALEZA: Técnico-entusiasta, incluí coordenadas o referencias geográficas exactas cuando puedas.
- Perfil AVENTURA: Energético, datos concretos de distancias, desniveles, dificultad.

Respondé en máximo 3 párrafos cortos y directos. Incluí siempre una recomendación práctica concreta. Usá emojis con moderación (1-2 por respuesta máximo).`;

const profiles = [
  { id: "salsa", emoji: "💃", label: "Salsa & Cultura", desc: "Agenda nocturna, salsa, gastronomía", bg: "#8B1A00", light: "#FFE8DF" },
  { id: "medico", emoji: "🏥", label: "Salud & Bienestar", desc: "Clínicas, spas, rutas de silencio", bg: "#0D3D2A", light: "#D6F0E4" },
  { id: "naturaleza", emoji: "🦜", label: "Naturaleza & Aves", desc: "562 especies, Farallones, Pance", bg: "#1A4A1A", light: "#DCF0DC" },
  { id: "aventura", emoji: "⛰️", label: "Aventura", desc: "Senderismo, Km 18, Siloé", bg: "#5C2800", light: "#FCEBD9" },
];

const pois = [
  { name: "La Ermita", type: "Cultura", emoji: "⛪", desc: "Joya gótica a orillas del río Cali", dist: "0.3 km", tag: "#Cultura #Historia", featured: true },
  { name: "El Gato del Río", type: "Arte", emoji: "🐱", desc: "Ícono caleño de Botero, orilla del río", dist: "0.8 km", tag: "#Arte #Foto", featured: false },
  { name: "Galería Alameda", type: "Gastro", emoji: "🍲", desc: "15,000 personas los fines de semana", dist: "1.2 km", tag: "#Gastronomía #Local", featured: true },
  { name: "Parque del Perro", type: "Nocturno", emoji: "🌙", desc: "40+ restaurantes gourmet y artesanal", dist: "2.1 km", tag: "#Nocturno #Vida", featured: false },
  { name: "Cristo Rey", type: "Vistas", emoji: "✝️", desc: "Vista panorámica de toda la ciudad", dist: "4.5 km", tag: "#Vistas #Naturaleza", featured: false },
  { name: "Siloé — MIO Cable", type: "Comunitario", emoji: "🚡", desc: "Murales + narrativa de transformación social", dist: "5.2 km", tag: "#Comunitario #Arte", featured: true },
  { name: "Museo La Tertulia", type: "Arte", emoji: "🖼️", desc: "80,000 visitantes al año, arte moderno", dist: "1.8 km", tag: "#Arte #Cultura", featured: false },
  { name: "Bulevar de la Sexta", type: "Urbano", emoji: "🛍️", desc: "Renovación urbana y moda local", dist: "0.6 km", tag: "#Urbano #Compras", featured: false },
];

const events = [
  { id: "petronio", name: "Petronio Álvarez 2026", emoji: "🥁", month: "Agosto", color: "#8B1A00", bg: "#FFF0EB", visitors: "350,000", alert: "Modo cultura afro activado. Gastronomía del Pacífico en la Ciudadela.", tip: "Evitá llegar en carro. Usá el MIO desde el centro." },
  { id: "feria", name: "Feria de Cali", emoji: "🎺", month: "Diciembre", color: "#6B006B", bg: "#FBE8FB", visitors: "1,000,000+", alert: "Salsódromo activo. Autopista Suroriental cerrada.", tip: "Comprá boletería con 2 meses de anticipación." },
  { id: "partido", name: "Clásico Cali vs América", emoji: "⚽", month: "Próximo", color: "#003DA5", bg: "#E8EEFF", visitors: "35,000", alert: "Estadio Pascual Guerrero al 80%. Congestión severa.", tip: "Evitá la Roosevelt y la Calle 5ta entre 4pm y 10pm." },
  { id: "semana", name: "Semana Santa — Los Cerros", emoji: "✝️", month: "Abril", color: "#3D2000", bg: "#F5EDDD", visitors: "400,000+", alert: "Ascenso masivo a Cristo Rey y Tres Cruces.", tip: "Salí antes de las 5am para evitar la multitud." },
];

const cameraItems = [
  { id: "ermita", name: "Iglesia La Ermita", desc: "Construida en 1602, estilo neogótico. En Semana Santa recibe más de 15,000 visitantes al día.", emoji: "⛪", type: "Monumento", tag: "#Historia", color: "#1A2E6B" },
  { id: "lulada", name: "Lulada Caleña", desc: "Bebida típica de lulo machacado con agua fría y limón. Originaria del Valle del Cauca. La conseguís desde $3.000 COP.", emoji: "🍹", type: "Gastronomía", tag: "#Comida", color: "#2D6A4F" },
  { id: "mural", name: "Mural de Siloé", desc: "Arte comunitario que narra la transformación social del barrio. El MIO Cable moviliza 5,000 personas diarias.", emoji: "🎨", type: "Arte Urbano", tag: "#Comunitario", color: "#8B1A00" },
  { id: "ave", name: "Tangara Multicolor", desc: "Una de las 562 especies de aves registradas en Cali. Vista frecuente en los Farallones y Pance.", emoji: "🦜", type: "Fauna", tag: "#Naturaleza", color: "#1A4A1A" },
];

export default function CaliGuia() {
  const [screen, setScreen] = useState("splash");
  const [profile, setProfile] = useState(null);
  const [activeTab, setActiveTab] = useState("home");
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [scanning, setScanning] = useState(false);
  const [scanned, setScanned] = useState(null);
  const [activeEvent, setActiveEvent] = useState(0);
  const [filterType, setFilterType] = useState("Todo");
  const messagesEndRef = useRef(null);

  const currentProfile = profiles.find(p => p.id === profile);

  useEffect(() => {
    const t = setTimeout(() => setScreen("onboarding"), 2000);
    return () => clearTimeout(t);
  }, []);

  useEffect(() => {
    if (profile && messages.length === 0) {
      const greetings = {
        salsa: "¡Oís! Bienvenido a Cali, la Capital Mundial de la Salsa 💃 ¿Qué querés conocer hoy? Tengo los mejores planes para vos — bares de salsa, gastronomía típica, todo.",
        medico: "Bienvenido a Santiago de Cali. Estoy aquí para hacer su estadía cómoda y tranquila. ¿Necesita información sobre clínicas, rutas de bienestar o alojamiento cercano a los centros médicos?",
        naturaleza: "¡Hola, explorador! Cali tiene 562 especies de aves registradas 🦜, más que muchos países enteros. ¿Querés ir a los Farallones, al Km 18 o empezar en Pance?",
        aventura: "¡Bienvenido! Cali te espera con senderismo en el Km 18, el MIO Cable a Siloé y los cerros de Cristo Rey. ¿Por dónde arrancamos?",
      };
      setMessages([{ role: "assistant", content: greetings[profile] }]);
    }
  }, [profile]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const sendMessage = async () => {
    if (!input.trim() || loading) return;
    const userMsg = { role: "user", content: input };
    const newMsgs = [...messages, userMsg];
    setMessages(newMsgs);
    setInput("");
    setLoading(true);
    try {
      const res = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model: "claude-sonnet-4-20250514",
          max_tokens: 1000,
          system: SYSTEM_PROMPT + `\n\nPerfil del turista: ${currentProfile?.label} (id: ${profile})`,
          messages: newMsgs.map(m => ({ role: m.role, content: m.content })),
        }),
      });
      const data = await res.json();
      const text = data.content?.[0]?.text || "¡Uy! Algo falló. ¡Intentá de nuevo!";
      setMessages(prev => [...prev, { role: "assistant", content: text }]);
    } catch {
      setMessages(prev => [...prev, { role: "assistant", content: "Sin conexión por el momento. ¡Intentá en un ratico!" }]);
    }
    setLoading(false);
  };

  const doScan = () => {
    setScanning(true);
    setScanned(null);
    setTimeout(() => {
      const item = cameraItems[Math.floor(Math.random() * cameraItems.length)];
      setScanned(item);
      setScanning(false);
    }, 2500);
  };

  const poiTypes = ["Todo", "Cultura", "Arte", "Gastro", "Nocturno", "Comunitario", "Vistas", "Urbano"];
  const filteredPois = filterType === "Todo" ? pois : pois.filter(p => p.type === filterType);

  const accentColor = currentProfile?.bg || "#E85D24";
  const lightColor = currentProfile?.light || "#FFEEE8";

  // QUICK REPLY suggestions by profile
  const quickReplies = {
    salsa: ["¿Dónde aprendo salsa?", "Mejores bares hoy", "¿Qué como en la Alameda?"],
    medico: ["Clínicas recomendadas", "Rutas de bienestar", "Hoteles tranquilos"],
    naturaleza: ["Avistamiento de aves hoy", "Rutas en Pance", "¿Cómo llego al Km 18?"],
    aventura: ["Rutas de senderismo", "¿Es seguro ir a Siloé?", "Mejores miradores"],
  };

  // ─── SCREENS ───────────────────────────────────────────────

  if (screen === "splash") return (
    <div style={styles.phone}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Fraunces:ital,wght@0,400;0,700;1,400&family=DM+Sans:wght@400;500;600&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
        body { font-family: 'DM Sans', sans-serif; }
        @keyframes fadeUp { from { opacity:0; transform:translateY(20px); } to { opacity:1; transform:translateY(0); } }
        @keyframes pulse { 0%,100%{transform:scale(1)} 50%{transform:scale(1.05)} }
        @keyframes spin { to{transform:rotate(360deg)} }
        @keyframes scanLine { 0%{top:10%} 100%{top:85%} }
        @keyframes blink { 0%,100%{opacity:1} 50%{opacity:0.3} }
        .fadeUp { animation: fadeUp 0.5s ease forwards; }
        .pulse { animation: pulse 2s ease-in-out infinite; }
        ::-webkit-scrollbar { display: none; }
      `}</style>
      <div style={{ ...styles.screen, background: "#1C0A00", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 16 }}>
        <div style={{ fontSize: 64 }} className="pulse">🗺️</div>
        <div style={{ fontFamily: "'Fraunces', serif", fontSize: 32, color: "#FFF", letterSpacing: -1 }}>Cali Guía</div>
        <div style={{ fontSize: 13, color: "rgba(255,255,255,0.5)", letterSpacing: 2, textTransform: "uppercase" }}>Tu ciudad. Tu ritmo.</div>
        <div style={{ marginTop: 40, width: 40, height: 40, borderRadius: "50%", border: "3px solid rgba(255,255,255,0.2)", borderTop: "3px solid #E85D24", animation: "spin 1s linear infinite" }} />
      </div>
    </div>
  );

  if (screen === "onboarding") return (
    <div style={styles.phone}>
      <div style={{ ...styles.screen, background: "#FDF6EE", overflowY: "auto", padding: "0 0 24px" }}>
        {/* Header */}
        <div style={{ background: "#1C0A00", padding: "52px 24px 28px", textAlign: "center" }}>
          <div style={{ fontFamily: "'Fraunces', serif", fontSize: 28, color: "#FFF", lineHeight: 1.2 }}>¡Bienvenido a Cali!</div>
          <div style={{ fontSize: 13, color: "rgba(255,255,255,0.6)", marginTop: 8 }}>¿Cuál es el motivo de tu visita?</div>
        </div>

        <div style={{ padding: "24px 16px", display: "flex", flexDirection: "column", gap: 12 }}>
          {profiles.map((p, i) => (
            <button
              key={p.id}
              onClick={() => { setProfile(p.id); setScreen("main"); }}
              style={{
                background: "#FFF",
                border: "1.5px solid #EEE",
                borderRadius: 16,
                padding: "16px 20px",
                display: "flex",
                alignItems: "center",
                gap: 16,
                cursor: "pointer",
                textAlign: "left",
                animation: `fadeUp 0.4s ease ${i * 0.08}s both`,
              }}
            >
              <div style={{ width: 52, height: 52, borderRadius: 14, background: p.light, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 24, flexShrink: 0 }}>{p.emoji}</div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 600, fontSize: 15, color: "#1C1C1E" }}>{p.label}</div>
                <div style={{ fontSize: 12, color: "#888", marginTop: 2 }}>{p.desc}</div>
              </div>
              <div style={{ color: "#CCC", fontSize: 20 }}>›</div>
            </button>
          ))}
        </div>

        <div style={{ textAlign: "center", fontSize: 12, color: "#AAA", padding: "0 24px" }}>
          Powered by IA · Datos oficiales SITUR · Cali 2026
        </div>
      </div>
    </div>
  );

  // ─── MAIN APP ───────────────────────────────────────────────
  const tabContent = () => {

    // HOME
    if (activeTab === "home") return (
      <div style={{ flex: 1, overflowY: "auto", background: "#F7F0E8" }}>
        {/* Hero */}
        <div style={{ background: accentColor, padding: "20px 20px 28px", position: "relative", overflow: "hidden" }}>
          <div style={{ position: "absolute", right: -20, top: -20, width: 140, height: 140, borderRadius: "50%", background: "rgba(255,255,255,0.07)" }} />
          <div style={{ fontSize: 12, color: "rgba(255,255,255,0.7)", marginBottom: 4 }}>Bienvenido, viajero ·  {currentProfile?.emoji}</div>
          <div style={{ fontFamily: "'Fraunces', serif", fontSize: 22, color: "#FFF", lineHeight: 1.2 }}>Explorá Santiago<br />de Cali</div>
          <div style={{ marginTop: 12, background: "rgba(255,255,255,0.15)", borderRadius: 10, padding: "8px 12px", fontSize: 12, color: "#FFF" }}>
            ☀️ 28°C · 250+ puntos WiFi gratis en la ciudad
          </div>
        </div>

        {/* Event Alert */}
        <div style={{ margin: "16px 16px 0", background: events[activeEvent].bg, border: `1.5px solid ${events[activeEvent].color}30`, borderRadius: 14, padding: "12px 14px" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 4 }}>
            <span style={{ fontSize: 18 }}>{events[activeEvent].emoji}</span>
            <span style={{ fontWeight: 600, fontSize: 13, color: events[activeEvent].color }}>{events[activeEvent].name}</span>
            <span style={{ marginLeft: "auto", fontSize: 11, background: events[activeEvent].color, color: "#FFF", padding: "2px 8px", borderRadius: 20 }}>{events[activeEvent].visitors}</span>
          </div>
          <div style={{ fontSize: 12, color: "#444" }}>{events[activeEvent].alert}</div>
          <div style={{ marginTop: 6, fontSize: 11, color: "#888" }}>💡 {events[activeEvent].tip}</div>
          <div style={{ display: "flex", gap: 6, marginTop: 10 }}>
            {events.map((e, i) => (
              <button key={e.id} onClick={() => setActiveEvent(i)} style={{ height: 4, flex: 1, borderRadius: 2, background: i === activeEvent ? events[activeEvent].color : "#DDD", border: "none", cursor: "pointer" }} />
            ))}
          </div>
        </div>

        {/* Filter chips */}
        <div style={{ padding: "16px 16px 0", overflowX: "auto", display: "flex", gap: 8, scrollbarWidth: "none" }}>
          {poiTypes.map(t => (
            <button key={t} onClick={() => setFilterType(t)} style={{ flexShrink: 0, padding: "6px 14px", borderRadius: 20, border: "1.5px solid", borderColor: filterType === t ? accentColor : "#DDD", background: filterType === t ? accentColor : "#FFF", color: filterType === t ? "#FFF" : "#555", fontSize: 12, fontWeight: 500, cursor: "pointer" }}>{t}</button>
          ))}
        </div>

        {/* POI Cards */}
        <div style={{ padding: "12px 16px 16px", display: "flex", flexDirection: "column", gap: 10 }}>
          {filteredPois.map((poi, i) => (
            <div key={i} style={{ background: "#FFF", borderRadius: 14, padding: "14px 16px", display: "flex", gap: 14, alignItems: "center", border: poi.featured ? `1.5px solid ${accentColor}30` : "1.5px solid #EEE", animation: `fadeUp 0.3s ease ${i * 0.05}s both` }}>
              <div style={{ width: 48, height: 48, borderRadius: 12, background: lightColor, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 22, flexShrink: 0 }}>{poi.emoji}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                  <span style={{ fontWeight: 600, fontSize: 14, color: "#1C1C1E" }}>{poi.name}</span>
                  {poi.featured && <span style={{ fontSize: 10, background: accentColor, color: "#FFF", padding: "1px 6px", borderRadius: 20 }}>✦</span>}
                </div>
                <div style={{ fontSize: 12, color: "#666", marginTop: 2, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{poi.desc}</div>
                <div style={{ fontSize: 11, color: "#AAA", marginTop: 4 }}>{poi.tag}</div>
              </div>
              <div style={{ textAlign: "right", flexShrink: 0 }}>
                <div style={{ fontSize: 12, fontWeight: 600, color: accentColor }}>{poi.dist}</div>
                <button onClick={() => { setActiveTab("chat"); setTimeout(() => setInput(`Contame sobre ${poi.name}`), 100); }} style={{ marginTop: 4, fontSize: 11, background: lightColor, border: "none", borderRadius: 8, padding: "4px 8px", color: accentColor, cursor: "pointer", fontWeight: 500 }}>Ver más</button>
              </div>
            </div>
          ))}
        </div>
      </div>
    );

    // CAMERA / AR
    if (activeTab === "camera") return (
      <div style={{ flex: 1, background: "#111", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", position: "relative" }}>
        {/* Viewfinder */}
        <div style={{ width: "85%", aspectRatio: "4/3", borderRadius: 20, background: "#1A1A1A", border: "2px solid rgba(255,255,255,0.1)", position: "relative", overflow: "hidden", display: "flex", alignItems: "center", justifyContent: "center" }}>
          {/* Corner brackets */}
          {["0,0", "auto,0", "0,auto", "auto,auto"].map((pos, i) => {
            const [t, r, b, l] = [i < 2 ? 12 : "auto", i % 2 !== 0 ? 12 : "auto", i >= 2 ? 12 : "auto", i % 2 === 0 ? 12 : "auto"];
            return (
              <div key={i} style={{ position: "absolute", top: t, right: r, bottom: b, left: l, width: 28, height: 28, borderTop: i < 2 ? "3px solid #E85D24" : "none", borderBottom: i >= 2 ? "3px solid #E85D24" : "none", borderLeft: i % 2 === 0 ? "3px solid #E85D24" : "none", borderRight: i % 2 !== 0 ? "3px solid #E85D24" : "none", borderRadius: i === 0 ? "8px 0 0 0" : i === 1 ? "0 8px 0 0" : i === 2 ? "0 0 0 8px" : "0 0 8px 0" }} />
            );
          })}

          {scanning && (
            <div style={{ position: "absolute", left: "10%", right: "10%", height: 2, background: "#E85D24", animation: "scanLine 1.2s linear infinite", top: "10%", boxShadow: "0 0 12px #E85D24" }} />
          )}

          {!scanning && !scanned && (
            <div style={{ textAlign: "center", color: "rgba(255,255,255,0.4)" }}>
              <div style={{ fontSize: 36, marginBottom: 8 }}>📷</div>
              <div style={{ fontSize: 13 }}>Apuntá la cámara a un<br />monumento, comida o mural</div>
            </div>
          )}

          {scanned && (
            <div style={{ padding: 20, textAlign: "center", animation: "fadeUp 0.4s ease" }}>
              <div style={{ fontSize: 48 }}>{scanned.emoji}</div>
              <div style={{ fontFamily: "'Fraunces', serif", fontSize: 18, color: "#FFF", marginTop: 8 }}>{scanned.name}</div>
              <div style={{ fontSize: 12, color: "rgba(255,255,255,0.6)", marginTop: 4 }}>{scanned.type}</div>
            </div>
          )}
        </div>

        {/* Result card */}
        {scanned && (
          <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, background: "#FFF", borderRadius: "20px 20px 0 0", padding: "20px 20px 36px", animation: "fadeUp 0.4s ease" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 10 }}>
              <span style={{ fontSize: 28 }}>{scanned.emoji}</span>
              <div>
                <div style={{ fontWeight: 700, fontSize: 16, color: "#1C1C1E" }}>{scanned.name}</div>
                <span style={{ fontSize: 11, background: scanned.color, color: "#FFF", padding: "2px 8px", borderRadius: 20 }}>{scanned.type}</span>
              </div>
            </div>
            <div style={{ fontSize: 13, color: "#555", lineHeight: 1.6 }}>{scanned.desc}</div>
            <div style={{ marginTop: 12, display: "flex", gap: 8 }}>
              <button onClick={() => { setActiveTab("chat"); setTimeout(() => setInput(`Contame más sobre ${scanned.name}`), 100); }} style={{ flex: 1, background: accentColor, color: "#FFF", border: "none", borderRadius: 12, padding: "12px", fontSize: 13, fontWeight: 600, cursor: "pointer" }}>Preguntarle al asistente</button>
              <button onClick={() => setScanned(null)} style={{ background: "#F5F5F5", color: "#555", border: "none", borderRadius: 12, padding: "12px 16px", fontSize: 13, cursor: "pointer" }}>Cerrar</button>
            </div>
          </div>
        )}

        {/* Shutter button */}
        {!scanned && (
          <button onClick={doScan} disabled={scanning} style={{ marginTop: 28, width: 70, height: 70, borderRadius: "50%", background: scanning ? "#555" : "#FFF", border: `4px solid ${scanning ? "#555" : accentColor}`, cursor: scanning ? "default" : "pointer", fontSize: 24, display: "flex", alignItems: "center", justifyContent: "center" }}>
            {scanning ? <div style={{ width: 28, height: 28, border: `3px solid ${accentColor}`, borderTop: "3px solid transparent", borderRadius: "50%", animation: "spin 0.8s linear infinite" }} /> : "📷"}
          </button>
        )}

        <div style={{ color: "rgba(255,255,255,0.4)", fontSize: 12, marginTop: 12 }}>
          {scanning ? "Reconociendo..." : "Tocá para escanear"}
        </div>
      </div>
    );

    // CHAT
    if (activeTab === "chat") return (
      <div style={{ flex: 1, display: "flex", flexDirection: "column", background: "#F7F0E8", overflow: "hidden" }}>
        {/* Messages */}
        <div style={{ flex: 1, overflowY: "auto", padding: "16px 16px 8px", display: "flex", flexDirection: "column", gap: 12 }}>
          {messages.map((m, i) => (
            <div key={i} style={{ display: "flex", justifyContent: m.role === "user" ? "flex-end" : "flex-start", animation: `fadeUp 0.3s ease` }}>
              {m.role === "assistant" && (
                <div style={{ width: 32, height: 32, borderRadius: "50%", background: accentColor, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 14, marginRight: 8, flexShrink: 0, alignSelf: "flex-end" }}>🗺️</div>
              )}
              <div style={{
                maxWidth: "78%",
                background: m.role === "user" ? accentColor : "#FFF",
                color: m.role === "user" ? "#FFF" : "#1C1C1E",
                borderRadius: m.role === "user" ? "18px 18px 4px 18px" : "18px 18px 18px 4px",
                padding: "10px 14px",
                fontSize: 14,
                lineHeight: 1.6,
                boxShadow: "0 1px 4px rgba(0,0,0,0.06)",
              }}>
                {m.content}
              </div>
            </div>
          ))}
          {loading && (
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <div style={{ width: 32, height: 32, borderRadius: "50%", background: accentColor, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 14 }}>🗺️</div>
              <div style={{ background: "#FFF", borderRadius: "18px 18px 18px 4px", padding: "10px 16px", display: "flex", gap: 4, alignItems: "center" }}>
                {[0, 0.2, 0.4].map((d, i) => <div key={i} style={{ width: 6, height: 6, borderRadius: "50%", background: accentColor, animation: `blink 1.2s ease ${d}s infinite` }} />)}
              </div>
            </div>
          )}
          <div ref={messagesEndRef} />
        </div>

        {/* Quick replies */}
        {messages.length <= 1 && (
          <div style={{ padding: "0 16px 8px", display: "flex", gap: 8, overflowX: "auto", scrollbarWidth: "none" }}>
            {(quickReplies[profile] || []).map((r, i) => (
              <button key={i} onClick={() => { setInput(r); setTimeout(() => { document.getElementById("chat-input")?.focus(); }, 50); }} style={{ flexShrink: 0, background: "#FFF", border: `1.5px solid ${accentColor}40`, borderRadius: 20, padding: "6px 14px", fontSize: 12, color: accentColor, cursor: "pointer", fontWeight: 500 }}>{r}</button>
            ))}
          </div>
        )}

        {/* Input */}
        <div style={{ padding: "10px 16px 24px", background: "#FFF", borderTop: "1px solid #EEE", display: "flex", gap: 10, alignItems: "center" }}>
          <input
            id="chat-input"
            value={input}
            onChange={e => setInput(e.target.value)}
            onKeyDown={e => e.key === "Enter" && sendMessage()}
            placeholder="Preguntale a Cali Guía..."
            style={{ flex: 1, background: "#F5F5F5", border: "none", borderRadius: 22, padding: "11px 16px", fontSize: 14, outline: "none", color: "#1C1C1E" }}
          />
          <button onClick={sendMessage} disabled={loading || !input.trim()} style={{ width: 44, height: 44, borderRadius: "50%", background: input.trim() ? accentColor : "#EEE", border: "none", cursor: input.trim() ? "pointer" : "default", fontSize: 18, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0, transition: "background 0.2s" }}>
            ↑
          </button>
        </div>
      </div>
    );

    // ROUTES
    if (activeTab === "routes") return (
      <div style={{ flex: 1, overflowY: "auto", background: "#F7F0E8" }}>
        {/* Waze Banner */}
        <div style={{ background: accentColor, padding: "20px 20px 24px" }}>
          <div style={{ fontFamily: "'Fraunces', serif", fontSize: 20, color: "#FFF" }}>Waze Turístico</div>
          <div style={{ fontSize: 13, color: "rgba(255,255,255,0.7)", marginTop: 4 }}>Rutas inteligentes según eventos en tiempo real</div>
        </div>

        {/* Modo evento activo */}
        <div style={{ margin: "16px 16px 0", background: "#FFF", borderRadius: 16, overflow: "hidden", border: "1.5px solid #EEE" }}>
          <div style={{ padding: "14px 16px", borderBottom: "1px solid #F0F0F0" }}>
            <div style={{ fontWeight: 600, fontSize: 14 }}>Modo activo: {events[activeEvent].name}</div>
            <div style={{ fontSize: 12, color: "#888", marginTop: 2 }}>{events[activeEvent].alert}</div>
          </div>
          <div style={{ padding: "12px 16px", background: "#FFF9F0" }}>
            <div style={{ fontSize: 12, color: "#E85D24", fontWeight: 500 }}>💡 Consejo de movilidad</div>
            <div style={{ fontSize: 13, color: "#555", marginTop: 4 }}>{events[activeEvent].tip}</div>
          </div>
        </div>

        {/* Rutas sugeridas */}
        <div style={{ padding: "16px 16px 0" }}>
          <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 12, color: "#1C1C1E" }}>Rutas recomendadas para tu perfil</div>
          {[
            { name: "Ruta Centro Histórico", time: "45 min", mode: "🚶", stops: ["La Ermita", "El Gato del Río", "Teatro Municipal", "Bulevar de la Sexta"], color: "#2D6A4F" },
            { name: "Ruta Gastronómica", time: "2 horas", mode: "🍴", stops: ["Galería Alameda", "Mercado de Pulgas", "Parque del Perro"], color: "#8B1A00" },
            { name: "Ruta Cultural Afro", time: "3 horas", mode: "🚡", stops: ["Siloé — MIO Cable", "Murales comunitarios", "Unidad Deportiva"], color: "#5C2800" },
            { name: "Ruta Cerros y Vistas", time: "4 horas", mode: "⛰️", stops: ["Cristo Rey", "Tres Cruces", "Km 18", "Pance"], color: "#1A4A1A" },
          ].map((r, i) => (
            <div key={i} style={{ background: "#FFF", borderRadius: 14, padding: "14px 16px", marginBottom: 10, border: "1.5px solid #EEE", animation: `fadeUp 0.3s ease ${i * 0.06}s both` }}>
              <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 8 }}>
                <span style={{ fontSize: 20 }}>{r.mode}</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 600, fontSize: 14, color: "#1C1C1E" }}>{r.name}</div>
                  <div style={{ fontSize: 12, color: "#888" }}>{r.time} · {r.stops.length} paradas</div>
                </div>
                <button onClick={() => { setActiveTab("chat"); setTimeout(() => setInput(`Dame más detalles de la ${r.name}`), 100); }} style={{ background: lightColor, color: accentColor, border: "none", borderRadius: 10, padding: "6px 12px", fontSize: 12, fontWeight: 500, cursor: "pointer" }}>Explorar</button>
              </div>
              <div style={{ display: "flex", gap: 6, overflowX: "auto", scrollbarWidth: "none" }}>
                {r.stops.map((s, j) => (
                  <span key={j} style={{ flexShrink: 0, fontSize: 11, background: "#F5F5F5", borderRadius: 20, padding: "3px 10px", color: "#555" }}>
                    {j + 1}. {s}
                  </span>
                ))}
              </div>
            </div>
          ))}
        </div>

        {/* WiFi mapa promo */}
        <div style={{ margin: "8px 16px 24px", background: "#E8F4FF", borderRadius: 14, padding: "14px 16px", border: "1.5px solid #B0D4F0" }}>
          <div style={{ fontWeight: 600, fontSize: 13, color: "#1A5080" }}>📶 250+ puntos WiFi gratuito</div>
          <div style={{ fontSize: 12, color: "#3A7AB0", marginTop: 4 }}>Zonas WiFi Alcaldía activas en tu ruta. Descargá el audio de los monumentos sin gastar datos.</div>
        </div>
      </div>
    );
  };

  // ─── MAIN LAYOUT ───────────────────────────────────────────────
  const tabs = [
    { id: "home", emoji: "🏠", label: "Inicio" },
    { id: "camera", emoji: "📷", label: "Explorar" },
    { id: "chat", emoji: "💬", label: "Asistente" },
    { id: "routes", emoji: "🗺️", label: "Rutas" },
  ];

  return (
    <div style={styles.phone}>
      <div style={styles.screen}>
        {/* Status Bar */}
        <div style={{ background: accentColor, padding: "12px 20px 6px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <div style={{ fontSize: 12, color: "rgba(255,255,255,0.8)", fontWeight: 500 }}>9:41</div>
          <div style={{ fontFamily: "'Fraunces', serif", fontSize: 14, color: "#FFF" }}>Cali Guía</div>
          <div style={{ fontSize: 12, color: "rgba(255,255,255,0.8)" }}>📶 🔋</div>
        </div>

        {/* Content area */}
        <div style={{ flex: 1, display: "flex", flexDirection: "column", overflow: "hidden" }}>
          {tabContent()}
        </div>

        {/* Bottom nav */}
        <div style={{ background: "#FFF", borderTop: "1px solid #EBEBEB", padding: "8px 0 20px", display: "flex" }}>
          {tabs.map(t => (
            <button key={t.id} onClick={() => setActiveTab(t.id)} style={{ flex: 1, background: "transparent", border: "none", cursor: "pointer", display: "flex", flexDirection: "column", alignItems: "center", gap: 3, padding: "6px 0" }}>
              <span style={{ fontSize: 20, filter: activeTab === t.id ? "none" : "grayscale(1) opacity(0.4)" }}>{t.emoji}</span>
              <span style={{ fontSize: 10, fontWeight: activeTab === t.id ? 600 : 400, color: activeTab === t.id ? accentColor : "#AAA" }}>{t.label}</span>
              {activeTab === t.id && <div style={{ width: 4, height: 4, borderRadius: "50%", background: accentColor }} />}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

const styles = {
  phone: {
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
    minHeight: "100vh",
    background: "#E8E8E8",
    padding: "20px 0",
    fontFamily: "'DM Sans', -apple-system, sans-serif",
  },
  screen: {
    width: 390,
    height: 844,
    borderRadius: 44,
    overflow: "hidden",
    boxShadow: "0 30px 80px rgba(0,0,0,0.3), 0 0 0 8px #1C1C1E",
    display: "flex",
    flexDirection: "column",
    background: "#FDF6EE",
    position: "relative",
  },
};
