import random
import time
import requests
import os

BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:8000")
lap = 1

while True:
    speed = random.randint(250, 320)
    rpm = random.randint(9500, 11500)
    gear = random.randint(6, 8)
    throttle = random.randint(70, 100)
    brake = random.randint(0, 20)

    telemetry = {
        "car": "CAR-44",
        "lap": lap,
        "speed": speed,
        "rpm": rpm,
        "gear": gear,
        "throttle": throttle,
        "brake": brake,
        "fuel": round(random.uniform(35, 45), 1),
        "front_left_tire": random.randint(85, 100),
        "front_right_tire": random.randint(85, 100),
        "rear_left_tire": random.randint(82, 98),
        "rear_right_tire": random.randint(82, 98),
    }

    try:
        response = requests.post(
            f"{BACKEND_URL}/telemetry",
            json=telemetry,
            timeout=2,
        )

        print(
            f"[SIMULATOR] "
            f"Lap {lap} | "
            f"{speed} km/h | "
            f"RPM {rpm} | "
            f"Backend {response.json().get('instance')}"
        )

    except Exception as e:
        print(f"[SIMULATOR] Backend unavailable: {e}")

    if random.random() < 0.03:
        lap += 1

    time.sleep(0.5)