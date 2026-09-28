# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "laya>=0.3.6",
#   "fastapi>=0.110",
#   "uvicorn[standard]>=0.30",
# ]
# ///
"""Thin HTTP wrapper around laya's Router (github.com/NandhaKishorM/laya), so local
processes without a Python env of their own (opencode, shell scripts, curl) can reach
it over HTTP the same way they reach ollama on :11434. This script is not part of
laya itself -- laya ships no server, just an importable library (laya.router.Router).
"""
import argparse
from typing import Any, Dict, List, Optional, Union

from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="laya-server")
router = None  # built at startup, kept warm for the process lifetime


class PredictRequest(BaseModel):
    state: Union[str, Dict[str, Any], List[Any]]
    questions: Dict[str, Any]
    model: Optional[str] = None
    task: Optional[str] = None
    lang: Optional[str] = None


class RouteRequest(BaseModel):
    state: Union[str, Dict[str, Any], List[Any], None] = None
    questions: Optional[Dict[str, Any]] = None
    model: Optional[str] = None
    task: Optional[str] = None
    lang: Optional[str] = None


@app.on_event("startup")
def _load_router():
    global router
    from laya import Router
    # preload=True keeps every checkpoint resident so routing is free (per laya's own
    # docs) -- right for a long-lived server; the library default (max_loaded=1) is
    # meant for one-off scripts and would reload on every language switch.
    router = Router(preload=True)


@app.get("/health")
def health():
    if router is None:
        return {"status": "loading"}
    return {"status": "ok", "loaded": router.loaded}


@app.post("/route")
def route(req: RouteRequest):
    decision = router.route(req.state, req.questions, model=req.model, task=req.task, lang=req.lang)
    return dict(decision)


@app.post("/predict")
def predict(req: PredictRequest):
    return router.predict(req.state, req.questions, model=req.model, task=req.task, lang=req.lang)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=11436)
    args = parser.parse_args()
    uvicorn.run(app, host=args.host, port=args.port)


if __name__ == "__main__":
    main()
