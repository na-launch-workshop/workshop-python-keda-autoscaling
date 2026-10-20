import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app import config
from app.consumer import KafkaEventConsumer
from app.status import LagReporter

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)-5s %(name)s : %(message)s")

consumer = KafkaEventConsumer()
lag_reporter = LagReporter()


@asynccontextmanager
async def lifespan(app: FastAPI):
    consumer.start()
    yield
    consumer.stop()
    lag_reporter.close()


app = FastAPI(title="Event-Driven Autoscaling with KEDA", lifespan=lifespan)


@app.get("/status")
def status() -> dict:
    return lag_reporter.status()


app.mount("/", StaticFiles(directory=Path(__file__).parent / "static", html=True), name="static")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=config.PORT)
