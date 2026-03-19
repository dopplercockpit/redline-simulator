import os

import pytest

os.environ.setdefault("ACADEMY_DB_URL", "sqlite:///./academy_test.db")

from backend.academy.app.db import init_db


@pytest.fixture(scope="session", autouse=True)
def _init_academy_db() -> None:
    init_db()
