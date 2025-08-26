from fastapi import FastAPI
from backend.api import finance, revenue, orders, admin
from backend import ar, ap   # absolute imports for local modules

app = FastAPI(title="Redline Simulator")

@app.get("/")
def read_root():
    return {"msg": "Redline backend running 🚗💨"}

@app.get("/healthz")
def health_check():
    return {"status": "ok"}

# API routers
app.include_router(finance.router)
app.include_router(revenue.router)
app.include_router(orders.router)
app.include_router(admin.router)

# Subledgers
app.include_router(ar.router)
app.include_router(ap.router)
