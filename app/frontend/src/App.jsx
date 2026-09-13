import { useEffect, useState } from "react";
import "./App.css";

function App() {
  const [telemetry, setTelemetry] = useState(null);
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    const WS_URL =
      import.meta.env.VITE_WS_URL ||
      "ws://localhost:8000/ws";

    const ws = new WebSocket(WS_URL);

    ws.onopen = () => setConnected(true);

    ws.onmessage = (event) => {
      try {
        setTelemetry(JSON.parse(event.data));
      } catch (error) {
        console.error("Invalid telemetry:", error);
      }
    };

    ws.onclose = () => setConnected(false);

    return () => ws.close();
  }, []);

  const data = telemetry || {
    speed: 0,
    rpm: 0,
    gear: 0,
    throttle: 0,
    brake: 0,
    lap: 0,
    fuel: 0,
    front_left_tire: 0,
    front_right_tire: 0,
    rear_left_tire: 0,
    rear_right_tire: 0,
    processed_by: "Waiting...",
  };

  return (
    <div className="dashboard">
      <header>
        <div>
          <h1>APEX<span>TELEMETRY</span></h1>
          <p>FORMULA 1 • LIVE RACE TELEMETRY</p>
        </div>

        <div className={`status ${connected ? "online" : "offline"}`}>
          <span className="dot"></span>
          {connected ? "LIVE" : "OFFLINE"}
        </div>
      </header>

      <section className="instance">
        <span>PROCESSING INSTANCE</span>
        <strong>{data.processed_by}</strong>
      </section>

      <main>
        <div className="card speed">
          <label>SPEED</label>
          <strong>{data.speed}</strong>
          <span>KM/H</span>
        </div>

        <div className="card">
          <label>RPM</label>
          <strong>{data.rpm.toLocaleString()}</strong>
          <span>REV/MIN</span>
        </div>

        <div className="card">
          <label>GEAR</label>
          <strong>{data.gear}</strong>
          <span>TRANSMISSION</span>
        </div>

        <div className="card">
          <label>LAP</label>
          <strong>{data.lap}</strong>
          <span>RACE LAP</span>
        </div>

        <div className="card wide">
          <label>THROTTLE</label>
          <div className="bar">
            <div style={{ width: `${data.throttle}%` }}></div>
          </div>
          <strong>{data.throttle}%</strong>
        </div>

        <div className="card wide">
          <label>BRAKE</label>
          <div className="bar">
            <div style={{ width: `${data.brake}%` }}></div>
          </div>
          <strong>{data.brake}%</strong>
        </div>

        <div className="card">
          <label>FUEL</label>
          <strong>{data.fuel}</strong>
          <span>% REMAINING</span>
        </div>

        <div className="card tyres">
          <label>TYRE CONDITION</label>

          <div className="tyres-grid">
            <div>FL <strong>{data.front_left_tire}%</strong></div>
            <div>FR <strong>{data.front_right_tire}%</strong></div>
            <div>RL <strong>{data.rear_left_tire}%</strong></div>
            <div>RR <strong>{data.rear_right_tire}%</strong></div>
          </div>
        </div>
      </main>

      <footer>
        <span>CAR-44</span>
        <span>APEX TELEMETRY SYSTEM</span>
        <span>{connected ? "WEBSOCKET CONNECTED" : "CONNECTION LOST"}</span>
      </footer>
    </div>
  );
}

export default App;