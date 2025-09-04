def test_summary_grid_shape():
    from backend.main import app
    from fastapi.testclient import TestClient
    c = TestClient(app)
    r = c.get("/finance/report/summary", params={"start":"2025-01-01","end":"2025-01-31","view":"grid"})
    assert r.status_code == 200
    j = r.json()
    assert "headline_rows" in j
    assert isinstance(j["headline_rows"], list)

def test_export_summary_csv_download():
    from backend.main import app
    from fastapi.testclient import TestClient
    c = TestClient(app)
    r = c.get("/finance/report/export/summary.csv", params={"start":"2025-01-01","end":"2025-01-31"})
    assert r.status_code == 200
    assert "text/csv" in r.headers.get("content-type","")
