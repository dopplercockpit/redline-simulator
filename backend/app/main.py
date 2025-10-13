from fastapi import FastAPI
from backend.api import finance, revenue, orders, admin
from backend import ar, ap   # absolute imports for local modules
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.openapi.docs import get_swagger_ui_html
from swagger_ui_bundle import swagger_ui_path

from backend.app.routes import midterm



app = FastAPI(title="Redline Simulator")

# Serve Swagger UI assets locally to avoid CDN issues
app.mount("/_swagger", StaticFiles(directory=swagger_ui_path), name="swagger")

@app.get("/docs", include_in_schema=False)
def custom_swagger_ui():
    return get_swagger_ui_html(
        openapi_url=app.openapi_url,
        title=f"{app.title} - Swagger UI",
        swagger_js_url="/_swagger/swagger-ui-bundle.js",
        swagger_css_url="/_swagger/swagger-ui.css",
        swagger_favicon_url="/_swagger/favicon-32x32.png",
    )


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # allow all origins (simplest for now)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"msg": "Redline backend running 🚗💨"}

@app.get("/healthz")
def health_check():
    return {"status": "ok"}

# API routers
# app.include_router(finance.router)
# app.include_router(revenue.router)
# app.include_router(orders.router)
# app.include_router(admin.router)

# Subledgers
# app.include_router(ar.router)
# app.include_router(ap.router)

app.include_router(midterm.router)
