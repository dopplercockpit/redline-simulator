# backend/api/finance.py
# Redline Simulator — Finance API
# Full-file replacement (Sprint 4 · Step 3, Reporting)
# Notes for code history:
# - #//# comments below mark removals/changes compared to previous iterations,
#   to respect your "comment-out, don't delete" rule.

from __future__ import annotations

from datetime import date
from enum import Enum
from typing import Dict, List

from fastapi import APIRouter, Query

from fastapi.responses import StreamingResponse
import io, csv


#//# removed: duplicate imports and mid-file re-imports previously found here
# from enum import Enum
# from typing import List, Dict
# from datetime import date
# from fastapi import Query

from ..services.finance.ledger_store import get_ledger

# ----------------------------
# Router (single instance only)
# ----------------------------
router = APIRouter(prefix="/finance", tags=["finance"])

#//# removed: duplicate router assignment previously present below which
#//# would shadow routes declared above and lead to missing endpoints.
# router = APIRouter(prefix="/finance", tags=["finance"])

# ----------------------------
# Helpers
# ----------------------------

def _r(x: float | int) -> float:
    """Robust round to 2 decimals."""
    try:
        return round(float(x), 2)
    except Exception:
        return 0.0


def _sum_codes(tb: Dict[str, float], start: int, end: int) -> float:
    """
    Sum balances for account codes in inclusive numeric range [start..end].

    IMPORTANT: Uses TB sign convention (debit = +, credit = −).
    """
    total = 0.0
    for k, v in tb.items():
        try:
            n = int(k)
        except Exception:
            continue
        if start <= n <= end:
            total += float(v)
    return _r(total)


#//# removed: prior duplicate version of _sum_codes(tb, (start,end)) which
#//# conflicted at call-time with this 3-arg signature.
# def _sum_codes(tb: Dict[str, float], prefix_range: tuple[int, int]) -> float:
#     ...


def _pl_from_delta(delta: Dict[str, float]) -> Dict[str, float]:
    """
    Build a simple PL from delta trial balance for a given period.
    - 4xxx (revenue) are credits (negative in TB) → flip sign to positive.
    - 5xxx COGS, 6xxx Opex are debits (positive).
    - 7xxx split for other income/expense as example ranges.
    - 72xx interest, 73xx tax (adjust to your COA if needed).
    """
    net_revenue = -_sum_codes(delta, 4000, 4999)  # flip credits to +
    cogs        =  _sum_codes(delta, 5000, 5999)
    opex        =  _sum_codes(delta, 6000, 6999)

    other_inc   = -_sum_codes(delta, 7000, 7099)
    other_exp   =  _sum_codes(delta, 7100, 7199)
    interest    =  _sum_codes(delta, 7200, 7299)
    tax         =  _sum_codes(delta, 7300, 7399)

    gross_profit   = _r(net_revenue - cogs)
    operating_inc  = _r(gross_profit - opex)
    pretax_income  = _r(operating_inc + other_inc - other_exp - interest)
    net_income     = _r(pretax_income - tax)

    return {
        "net_revenue": net_revenue,
        "cogs": cogs,
        "gross_profit": gross_profit,
        "opex": opex,
        "operating_income": operating_inc,
        "other_income": other_inc,
        "other_expense": other_exp,
        "interest_expense": interest,
        "income_tax": tax,
        "net_income": net_income,
    }


def _kpis_from_pl(pl: Dict[str, float]) -> Dict[str, float]:
    """CFO-friendly KPIs derived from PL."""
    rev = pl.get("net_revenue", 0.0) or 0.0
    gp  = pl.get("gross_profit", 0.0) or 0.0
    op  = pl.get("operating_income", 0.0) or 0.0
    ni  = pl.get("net_income", 0.0) or 0.0

    gm_pct = _r((gp / rev * 100.0) if rev else 0.0)
    om_pct = _r((op / rev * 100.0) if rev else 0.0)
    nm_pct = _r((ni / rev * 100.0) if rev else 0.0)

    return {
        "gross_margin_pct": gm_pct,
        "operating_margin_pct": om_pct,
        "net_margin_pct": nm_pct,
    }


# ----------------------------
# Endpoints
# ----------------------------

@router.get("/report/export/summary.csv")
def export_summary_csv(
    start: date = Query(...),
    end: date = Query(...),
    accounts: List[str] = Query(default=["1000","1100","4000","4100"]),
):
    L = get_ledger()
    tb_end = L.trial_balance(end)
    delta  = L.delta_tb(start, end)

    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(["period_start","period_end","account","ending_balance","period_delta"])
    for a in accounts:
        w.writerow([str(start), str(end), a, _r(tb_end.get(a, 0.0)), _r(delta.get(a, 0.0))])

    buf.seek(0)
    return StreamingResponse(
        io.BytesIO(buf.getvalue().encode("utf-8")),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="summary_{start}_{end}.csv"'}
    )


@router.get("/report/trial_balance")
def api_trial_balance(
    as_of: date = Query(..., description="As-of date (YYYY-MM-DD)")
):
    """
    Trial Balance snapshot with headline totals by major ranges.
    NOTE: TB is debit=+, credit=−.
    """
    L = get_ledger()
    tb = L.trial_balance(as_of)

    totals = {
        "assets_1xxx": _sum_codes(tb, 1000, 1999),
        "liabilities_2xxx": _sum_codes(tb, 2000, 2999),
        "equity_3xxx": _sum_codes(tb, 3000, 3999),
        "revenue_4xxx": _sum_codes(tb, 4000, 4999),
        "cogs_5xxx": _sum_codes(tb, 5000, 5999),
        "opex_6xxx": _sum_codes(tb, 6000, 6999),
        "other_7xxx": _sum_codes(tb, 7000, 7999),
    }

    # Balance check: Assets - Liab - Equity should be 0 when including income flows.
    balance_check_sum = _r(
        totals["assets_1xxx"]
        - (totals["liabilities_2xxx"] + totals["equity_3xxx"])
        + totals["revenue_4xxx"]  # revenue is negative; adding keeps sign visible
        + totals["cogs_5xxx"]
        + totals["opex_6xxx"]
        + totals["other_7xxx"]
    )

    return {
        "as_of": str(as_of),
        "trial_balance": tb,
        "totals": totals,
        "balance_check_sum": balance_check_sum,
    }

@router.get("/metadata/accounts")
def metadata_accounts():
    """
    Minimal COA metadata so the UI can render pickers.
    Extend this later with names, cash_flow_hint, and display groups.
    """
    return {
        "ranges": [
            {"range":"1000-1999","label":"Assets"},
            {"range":"2000-2999","label":"Liabilities"},
            {"range":"3000-3999","label":"Equity"},
            {"range":"4000-4999","label":"Revenue"},
            {"range":"5000-5999","label":"COGS"},
            {"range":"6000-6999","label":"Opex"},
            {"range":"7000-7999","label":"Other"},
        ],
        "defaults": ["1000","1100","4000","4100"]
    }


@router.get("/report/pl")
def api_profit_and_loss(
    start: date = Query(..., description="Start date inclusive (YYYY-MM-DD)"),
    end:   date = Query(..., description="End date inclusive (YYYY-MM-DD)"),
):
    """
    Period Profit & Loss using delta TB.
    Returns positive revenue/negative expenses in standard PL display terms.
    """
    L = get_ledger()
    delta = L.delta_tb(start, end)
    pl = _pl_from_delta(delta)
    return {
        "period": {"start": str(start), "end": str(end)},
        **pl,
        "kpis": _kpis_from_pl(pl),
    }


@router.get("/report/bs")
def api_balance_sheet(
    as_of: date = Query(..., description="As-of date (YYYY-MM-DD)")
):
    """
    Naive Balance Sheet rollup by ranges (positive numbers for readability).
    Adjust ranges to your COA as needed.
    """
    L = get_ledger()
    tb = L.trial_balance(as_of)

    assets  = -_sum_codes(tb, 1000, 1999) * -1  # present as positive
    liabs   =  _sum_codes(tb, 2000, 2999) * -1  # liabilities are credits (negative in TB)
    equity  =  _sum_codes(tb, 3000, 3999) * -1  # equity credits (negative in TB)

    return {
        "as_of": str(as_of),
        "assets": _r(assets),
        "liabilities": _r(liabs),
        "equity": _r(equity),
        "total_assets": _r(assets),
        "total_liabilities_and_equity": _r(liabs + equity),
    }


class ReportStyle(str, Enum):
    compact = "compact"    # KPIs + headline accounts
    full    = "full"       # + PL/BS payloads
    teaching= "teaching"   # + explanations/tooltips
    dev     = "dev"        # + raw tb_end and delta


@router.get("/report/summary")
def api_report_summary(
    start: date = Query(..., description="Start date inclusive YYYY-MM-DD"),
    end:   date = Query(..., description="End date inclusive YYYY-MM-DD"),
    style: ReportStyle = Query(ReportStyle.compact, description="compact|full|teaching|dev"),
        view: str = Query("cards", description="cards|grid (grid returns tidy rows)"),

    accounts: List[str] = Query(
        default=["1000", "1100", "4000", "4100"],
        description="Account codes to surface as headline balances"
    ),
):
    """
    Dynamic summary for classroom + CFO views.
    - compact   => KPIs + selected accounts (end + delta)
    - full      => + PL and BS payloads
    - teaching  => compact + explanations
    - dev       => compact + raw tb_end/delta for debugging
    """
    L = get_ledger()
    tb_end: Dict[str, float] = L.trial_balance(end)
    delta:  Dict[str, float] = L.delta_tb(start, end)

    pl = _pl_from_delta(delta)
    kpis = _kpis_from_pl(pl)

    ending_balances = { f"A_{a}": _r(tb_end.get(a, 0.0)) for a in accounts }
    period_deltas   = { f"A_{a}": _r(delta.get(a, 0.0))  for a in accounts }

    resp: Dict[str, object] = {
        "period": {"start": str(start), "end": str(end)},
        "kpis": kpis,
        "ending_balances": ending_balances,
        "period_deltas": period_deltas,
    }

    if style in (ReportStyle.full, ReportStyle.teaching):
        # Build PL & BS inline to avoid any decorator/.__wrapped__ shenanigans
        # PL: we already computed as `pl` above
        pl_payload = {
            "period": {"start": str(start), "end": str(end)},
            **pl,
            "kpis": kpis,
        }

        # BS: compute from tb_end with positive presentation
        assets  = (-_sum_codes(tb_end, 1000, 1999)) * -1  # present as +
        liabs   =  (_sum_codes(tb_end, 2000, 2999)) * -1  # credits -> +
        equity  =  (_sum_codes(tb_end, 3000, 3999)) * -1  # credits -> +

        bs_payload = {
            "as_of": str(end),
            "assets": _r(assets),
            "liabilities": _r(liabs),
            "equity": _r(equity),
            "total_assets": _r(assets),
            "total_liabilities_and_equity": _r(liabs + equity),
        }

        resp["statements"] = {
            "pl": pl_payload,
            "bs": bs_payload,
        }

    if style == ReportStyle.teaching:
        resp["explain"] = {
            "kpis": {
                "gross_margin_pct": "Gross Profit ÷ Net Revenue × 100",
                "operating_margin_pct": "Operating Income ÷ Net Revenue × 100",
                "net_margin_pct": "Net Income ÷ Net Revenue × 100",
            },
            "signs": (
                "TB uses debit=+ and credit=−. Revenue (4xxx) is credit (negative) "
                "in TB but flipped to positive for KPIs/PL display."
            ),
            "accounts": (
                "Change the headline set with repeated accounts[]=... parameters "
                "(e.g., accounts=1000&accounts=1100&accounts=2000)."
            ),
        }

    if style == ReportStyle.dev:
        resp["dev"] = {"tb_end": tb_end, "delta": delta}

    if view == "grid":
        # turn headline balances into tidy rows
        rows = []
        for a in accounts:
            rows.append({
                "account": a,
                "ending_balance": _r(tb_end.get(a, 0.0)),
                "period_delta": _r(delta.get(a, 0.0)),
            })
        resp["headline_rows"] = rows

    return resp

@router.post("/dev/seed/january_2025")
def dev_seed_january_2025(confirm: bool = Query(False, description="Must be true")):
    if not confirm:
        return {"error":"confirm_required","hint":"Pass ?confirm=true to run seeding"}
    from ..services.finance.seed_journal import seed_january_2025
    seed_january_2025()
    return {"ok": True, "message": "Seeded January 2025 demo data"}



@router.get("/report/diag")
def api_report_diag(
    as_of: date = Query(..., description="As-of date for TB check (YYYY-MM-DD)")
):
    """
    Diagnostic: basic integrity numbers.
    """
    L = get_ledger()
    tb = L.trial_balance(as_of)
    s_assets = _sum_codes(tb, 1000, 1999)
    s_liabs  = _sum_codes(tb, 2000, 2999)
    s_equity = _sum_codes(tb, 3000, 3999)
    s_income = _sum_codes(tb, 4000, 7999)

    return {
        "as_of": str(as_of),
        "sum_assets_1xxx": _r(s_assets),
        "sum_liabilities_2xxx": _r(s_liabs),
        "sum_equity_3xxx": _r(s_equity),
        "sum_income_4xxx_7xxx": _r(s_income),
        "sum_all": _r(sum(tb.values())),
    }
