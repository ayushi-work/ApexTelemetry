import os
import json
from datetime import datetime

from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
import redis.asyncio as redis


app = FastAPI(title="ApexTelemetry")

INSTANCE_ID = os.getenv("INSTANCE_ID", "telemetry-local")
REDIS_HOST = os.getenv("REDIS_HOST", "localhost")

redis_client = redis.Redis(
    host=REDIS_HOST,
    port=6379,
    decode_responses=True,
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "instance": INSTANCE_ID,
        "timestamp": datetime.utcnow().isoformat(),
    }


@app.post("/telemetry")
async def receive_telemetry(data: dict):
    data["processed_by"] = INSTANCE_ID
    data["received_at"] = datetime.utcnow().isoformat()

    await redis_client.set(
        "latest_telemetry",
        json.dumps(data),
    )

    return {
        "status": "accepted",
        "instance": INSTANCE_ID,
    }


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()

    while True:
        try:
            data = await redis_client.get("latest_telemetry")

            if data:
                await websocket.send_text(data)

            import asyncio
            await asyncio.sleep(0.2)

        except Exception:
            break