
# backend/api/finance.py
from fastapi import APIRouter, Query
from datetime import date
from ..services.finance.statements import (
    build_income_statement, build_balance_sheet, build_cash_flow_direct
)
from traceback import format_exc
from ..services.finance.ledger_store import get_ledger

router = APIRouter(prefix="/finance", tags=["finance"])

@router.get("/diag/trial_balance")
def diag_trial_balance():
    L = get_ledger()
    # each acct: code, name, debit_total, credit_total, balance
    tb = []
    for acct in L.accounts.values():
        tb.append({
            "code": acct.code,
            "name": getattr(acct, "name", ""),
            "debits": round(acct.debit_total, 2),
            "credits": round(acct.credit_total, 2),
            "balance": round(acct.balance(), 2)
        })
    tb.sort(key=lambda x: x["code"])
    return {"trial_balance": tb}


@router.get("/statements")
def get_statements(as_of: date, prev: date | None = None):
    try:
        L = get_ledger()
        is_ = build_income_statement(L, as_of)
        bs_ = build_balance_sheet(L, as_of)
        if prev is None:
            prev = date(as_of.year, 1, 1)
        # Ensure prev < as_of
        if prev >= as_of:
            raise ValueError(f"'prev' must be before 'as_of' (prev={prev}, as_of={as_of})")

        cf_ = build_cash_flow_direct(L, prev, as_of)

        return {
            "income_statement": is_.__dict__,
            "balance_sheet": {
                "assets": bs_.assets,
                "liabilities": bs_.liabilities,
                "equity": bs_.equity,
                "total_assets": bs_.total_assets,
                "total_liabilities_and_equity": bs_.total_liab_equity
            },
            "cash_flow_direct": {
                "cfo": cf_.cfo, "cfi": cf_.cfi, "cff": cf_.cff,
                "net_change_cash": cf_.net_change_cash, "ending_cash": cf_.ending_cash
            }
        }
    except Exception:
        return {"error": "statements_failed", "trace": format_exc()}

