
# backend/services/finance/ledger_store.py
from .seed import seed_ledger
from ...models.journal import Ledger

_ledger: Ledger | None = None

def get_ledger() -> Ledger:
    global _ledger
    if _ledger is None:
        _ledger = seed_ledger()
    return _ledger

def reset_ledger():
    global _ledger
    _ledger = seed_ledger()
