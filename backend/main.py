from fastapi import FastAPI
from backend.api import finance
from backend.api import revenue
from backend.api import orders     # <<< add

app = FastAPI(title="Redline Simulator")

@app.get("/")
def read_root():
    return {"msg": "Redline backend running 🚗💨"}

@app.get("/healthz")
def health_check():
    return {"status": "ok"}

app.include_router(finance.router)
app.include_router(revenue.router)
app.include_router(orders.router)  # <<< add
