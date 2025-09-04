
# backend/api/finance.py
from fastapi import APIRouter, Query
from datetime import date
from ..services.finance.statements import (
    build_income_statement, build_balance_sheet, build_cash_flow_direct
)
from traceback import format_exc
from ..services.finance.ledger_store import get_ledger


router = APIRouter(prefix="/finance", tags=["finance"])

# =========================
# Reporting Endpoints (Step 3)
# =========================
from datetime import date
from fastapi import Query
from ..services.finance.ledger_store import get_ledger

def _sum_codes(tb: dict, prefix_range: tuple[int, int]) -> float:
    """
    Sum TB balances for accounts whose numeric code falls within [start, end], inclusive.
    TB uses debit-positive / credit-negative convention.
    """
    start, end = prefix_range
    total = 0.0
    for code, val in tb.items():
        try:
            n = int(code)
        except Exception:
            continue
        if start <= n <= end:
            total += float(val)
    return total

@router.get("/report/trial_balance")
def api_trial_balance(as_of: date = Query(..., description="As-of date (YYYY-MM-DD)")):
    """
    Raw Trial Balance snapshot at 'as_of'.
    NOTE: debit=positive, credit=negative.
    """
    L = get_ledger()
    tb = L.trial_balance(as_of)
    # Optional convenience totals by major buckets
    assets     = _sum_codes(tb, (1000, 1999))
    liabs      = _sum_codes(tb, (2000, 2999))
    equity     = _sum_codes(tb, (3000, 3999))
    revenue    = _sum_codes(tb, (4000, 4999))
    cogs       = _sum_codes(tb, (5000, 5999))
    opex       = _sum_codes(tb, (6000, 6999))
    other      = _sum_codes(tb, (7000, 7999))
    check      = round(assets + liabs + equity + revenue + cogs + opex + other, 2)
    return {
        "as_of": str(as_of),
        "trial_balance": tb,
        "totals": {
            "assets_1xxx": assets,
            "liabilities_2xxx": liabs,
            "equity_3xxx": equity,
            "revenue_4xxx": revenue,
            "cogs_5xxx": cogs,
            "opex_6xxx": opex,
            "other_7xxx": other,
            "balance_check_sum": check  # should be 0.00 if the universe still makes sense
        }
    }

@router.get("/report/pl")
def api_profit_and_loss(
    start: date = Query(..., description="Start date inclusive (YYYY-MM-DD)"),
    end:   date = Query(..., description="End date inclusive (YYYY-MM-DD)")
):
    """
    Income Statement (period flow): uses delta TB (debit + / credit -).
    Net Revenue = -(sum 4xxx)  -> credits become positive revenue, 4100 debits reduce it automatically.
    Gross Profit = Net Revenue - COGS (5xxx)
    Operating Income = Gross Profit - OPEX (6xxx)
    Pre-tax Income = Operating Income + Other (7xxx) [note: 7xxx credits show as negative; adding them increases income]
    Net Income = sum of all P&L buckets with correct signs
    """
    L = get_ledger()
    delta = L.delta_tb(start, end)

    # Build a fake TB-like dict from delta for easy reuse of _sum_codes
    # (Same sign convention: debits +, credits -)
    tb = {k: float(v) for k, v in delta.items()}

    rev_sum   = _sum_codes(tb, (4000, 4999))   # negative typically (credits)
    cogs_sum  = _sum_codes(tb, (5000, 5999))   # positive typically (debits)
    opex_sum  = _sum_codes(tb, (6000, 6999))   # positive typically (debits)
    other_sum = _sum_codes(tb, (7000, 7999))   # could be +/- depending on accounts

    net_revenue     = -rev_sum                 # flip sign so revenue is positive
    gross_profit    = net_revenue - cogs_sum
    operating_inc   = gross_profit - opex_sum
    pre_tax_income  = operating_inc + (-other_sum)  # if 7xxx are expenses (debit +) other_sum>0 reduces; if income (credit -), -other_sum adds
    # Simpler: net_income = ( -sum(4xxx) ) - sum(5xxx) - sum(6xxx) + ( -sum(7xxx) )
    net_income      = net_revenue - cogs_sum - opex_sum + (-other_sum)

    return {
        "period": {"start": str(start), "end": str(end)},
        "sections": {
            "revenue_4xxx_raw_sum": rev_sum,      # negative number typically
            "cogs_5xxx_raw_sum": cogs_sum,
            "opex_6xxx_raw_sum": opex_sum,
            "other_7xxx_raw_sum": other_sum
        },
        "statement": {
            "net_revenue": round(net_revenue, 2),
            "gross_profit": round(gross_profit, 2),
            "operating_income": round(operating_inc, 2),
            "pre_tax_income": round(pre_tax_income, 2),
            "net_income": round(net_income, 2)
        }
    }

@router.get("/report/bs")
def api_balance_sheet(
    as_of: date = Query(..., description="As-of date (YYYY-MM-DD)"),
    include_period_net_income: bool = Query(True, description="If true, derives RE by rolling period NI into equity for display")
):
    """
    Balance Sheet (as-of): uses Trial Balance snapshot at 'as_of'.
    Displays Assets and Liabilities+Equity as positive numbers.
    If include_period_net_income=True, we 'virtually close' the P&L into equity for display sanity.
    """
    L = get_ledger()
    tb = L.trial_balance(as_of)

    assets  = _sum_codes(tb, (1000, 1999))               # usually + (debits)
    liabs   = _sum_codes(tb, (2000, 2999))               # usually - (credits)
    equity  = _sum_codes(tb, (3000, 3999))               # usually - (credits)
    # P&L buckets present in TB if you haven't actually closed books:
    rev_sum = _sum_codes(tb, (4000, 4999))               # credits (negative)
    cogs    = _sum_codes(tb, (5000, 5999))               # debits (positive)
    opex    = _sum_codes(tb, (6000, 6999))               # debits (positive)
    other   = _sum_codes(tb, (7000, 7999))               # +/- depending

    # Derived NI from TB (if not closed)
    net_revenue = -rev_sum
    ni_from_tb  = net_revenue - cogs - opex + (-other)

    # Display formatting: make both sides positive for human brains
    total_assets = round(assets, 2)
    total_leq_tb = round(-(liabs + equity + rev_sum + cogs + opex + other), 2)  # L+E+(unclosed P&L)

    if include_period_net_income:
        # Virtually close P&L into equity for display purposes
        leq_closed = -(liabs + equity + 0.0 + 0.0 + 0.0 + 0.0 + 0.0 + ( -ni_from_tb ))  # subtract NI from the negative sum
        # simpler: Liab+Equity (closed) = -(liabs + equity) + NI
        total_leq_display = round( -(liabs + equity) + ni_from_tb, 2 )
    else:
        total_leq_display = total_leq_tb

    return {
        "as_of": str(as_of),
        "snapshots": {
            "assets_1xxx_tb_sum": round(assets, 2),
            "liabilities_2xxx_tb_sum": round(liabs, 2),     # usually negative
            "equity_3xxx_tb_sum": round(equity, 2),         # usually negative
            "unclosed_pl_buckets": {
                "revenue_4xxx_tb_sum": round(rev_sum, 2),   # negative if credit
                "cogs_5xxx_tb_sum": round(cogs, 2),
                "opex_6xxx_tb_sum": round(opex, 2),
                "other_7xxx_tb_sum": round(other, 2)
            },
            "derived_net_income_from_tb": round(ni_from_tb, 2)
        },
        "display": {
            "total_assets": total_assets,
            "total_liabilities_plus_equity_tb": total_leq_tb,
            "total_liabilities_plus_equity_display": total_leq_display
        },
        "checks": {
            "tb_equation_sum": round(assets + liabs + equity + rev_sum + cogs + opex + other, 2)  # should be 0.00
        }
    }


from fastapi import APIRouter, Query
from datetime import date
from ..services.finance.ledger_store import get_ledger

router = APIRouter(prefix="/finance", tags=["finance"])

@router.get("/diag/ar_audit")
def api_ar_audit(
    start: date = Query(..., description="Start YYYY-MM-DD"),
    end:   date = Query(..., description="End YYYY-MM-DD"),
):
    L = get_ledger()
    tb_end = L.trial_balance(end)     # ending balances by account
    delta  = L.delta_tb(start, end)   # period movement by account

    def g(code, d): return round(float(d.get(code, 0.0)), 2)

    return {
        "period": {"start": str(start), "end": str(end)},
        "ending_balances": {
            "AR_1100": g("1100", tb_end),
            "Cash_1000": g("1000", tb_end),
            "Revenue_4000": g("4000", tb_end),
            "Returns_4100": g("4100", tb_end),
        },
        "period_deltas": {
            "AR_1100": g("1100", delta),
            "Cash_1000": g("1000", delta),
            "Revenue_4000": g("4000", delta),
            "Returns_4100": g("4100", delta),
        }
    }


@router.get("/diag/journal_dump")
def api_journal_dump():
    L = get_ledger()
    out = []
    for je in getattr(L, "entries", []):
        out.append({
            "je_id": je.je_id,
            "date": str(je.je_date),
            "memo": getattr(je, "memo", None),
            "lines": [{"account": ln.account, "debit": ln.debit, "credit": ln.credit} for ln in je.lines]
        })
    return {"entries": out, "count": len(out)}


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

