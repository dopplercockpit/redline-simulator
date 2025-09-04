
# backend/services/finance/ledger_store.py
from .seed import seed_ledger
from ...models.journal import Ledger
from datetime import date


_ledger: Ledger | None = None

def get_ledger() -> Ledger:
    global _ledger
    if _ledger is None:
        _ledger = seed_ledger()
    return _ledger

def account_delta(code: str, start: date, end: date) -> float:
    """Return signed movement for an account between start..end inclusive.
       Uses the same sign convention as delta_tb (debit + / credit -)."""
    L = get_ledger()
    delta = L.delta_tb(start, end)
    return float(delta.get(code, 0.0))

def reset_ledger():
    global _ledger
    _ledger = seed_ledger()

# --- Admin helpers: JSON export/import/state ---

from datetime import date
from decimal import Decimal, ROUND_HALF_UP
from ...models.journal import JournalEntry, JournalLine


TWOPLACES = Decimal("0.01")

def _q(x: float) -> Decimal:
    # centralize rounding to 2dp
    return Decimal(str(x)).quantize(TWOPLACES, rounding=ROUND_HALF_UP)

def post_balanced_je(je_id: str, je_date: date, memo: str, lines: list[dict]):
    """
    Convenience poster that takes simple dict lines:
    [{"account":"1100","debit":100.0},{"account":"4000","credit":100.0}]
    Applies 2dp rounding, constructs JournalEntry, and posts it.
    """
    L = get_ledger()
    jl = []
    for l in lines:
        jl.append(JournalLine(
            account=l["account"],
            debit=float(_q(l.get("debit", 0.0))),
            credit=float(_q(l.get("credit", 0.0))),
        ))
    je = JournalEntry(je_id=je_id, je_date=je_date, memo=memo, lines=jl)
    L.post(je)
    return je_id


def export_ledger_json() -> dict:
    """
    Serialize the in-memory Ledger to a JSON-friendly dict.
    Structure:
    {
      "entries": [
         {"je_id": "...", "je_date": "YYYY-MM-DD", "memo": "...",
          "lines": [{"account":"1000","debit":123.45,"credit":0.0}, ...]
         },
         ...
      ],
      "count": N
    }
    """
    L = get_ledger()
    payload = {"entries": [], "count": 0}
    # NOTE: Ledger keeps entries in order posted; preserve that order.
    for je in getattr(L, "entries", []):
        payload["entries"].append({
            "je_id": je.je_id,
            "je_date": str(je.je_date),
            "memo": getattr(je, "memo", None),
            "lines": [
                {"account": ln.account, "debit": float(ln.debit), "credit": float(ln.credit)}
                for ln in je.lines
            ],
        })
    payload["count"] = len(payload["entries"])
    return payload

def import_ledger_json(data: dict) -> dict:
    """
    Replace the in-memory Ledger with entries from a JSON dict
    (same structure as export_ledger_json). Validates balance on post().
    Returns a small report {"imported": N}.
    """
    global _ledger
    newL = Ledger()
    entries = data.get("entries", [])
    for e in entries:
        # Build JournalEntry and post
        je_date = e.get("je_date")
        if isinstance(je_date, str):
            # Minimal parse: YYYY-MM-DD
            parts = [int(x) for x in je_date.split("-")]
            je_dt = date(parts[0], parts[1], parts[2])
        else:
            je_dt = je_date  # assume already a date (unlikely via FastAPI)
        lines = []
        for l in e.get("lines", []):
            lines.append(JournalLine(
                account=l["account"],
                debit=float(l.get("debit", 0.0)),
                credit=float(l.get("credit", 0.0)),
            ))
        je = JournalEntry(
            je_id=e.get("je_id"),
            je_date=je_dt,
            memo=e.get("memo"),
            lines=lines
        )
        newL.post(je)  # will assert balance and valid accounts
    _ledger = newL
    return {"imported": len(entries)}

def ledger_state() -> dict:
    """
    Lightweight diagnostics: count, first/last dates if present.
    """
    L = get_ledger()
    entries = getattr(L, "entries", [])
    n = len(entries)
    first = str(entries[0].je_date) if n > 0 else None
    last  = str(entries[-1].je_date) if n > 0 else None
    return {"count": n, "first_date": first, "last_date": last}
