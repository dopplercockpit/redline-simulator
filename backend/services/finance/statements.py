
# backend/services/finance/statements.py
from __future__ import annotations
from dataclasses import dataclass
from datetime import date
from typing import Dict
from ...models.accounts import COA, AcctType
from ...models.journal import Ledger

@dataclass
class IncomeStatement:
    revenue: float
    cogs: float
    gross_profit: float
    opex: float
    operating_income: float
    other_income: float
    other_expense: float
    interest: float
    pretax_income: float
    tax: float
    net_income: float

@dataclass
class BalanceSheet:
    assets: Dict[str, float]
    liabilities: Dict[str, float]
    equity: Dict[str, float]
    total_assets: float
    total_liab_equity: float

@dataclass
class CashFlowDirect:
    cfo: Dict[str, float]
    cfi: Dict[str, float]
    cff: Dict[str, float]
    net_change_cash: float
    ending_cash: float

def _sum_by_type(tb: Dict[str, float], acct_type: AcctType) -> float:
    total = 0.0
    for code, bal in tb.items():
        if COA[code].type == acct_type:
            # Conventions: debit-positive balances for assets/expenses,
            # credit-negative for liabilities/equity/revenue.
            # For IS numbers, we want natural signs: revenue positive, expenses positive.
            if acct_type in (AcctType.REV,):
                total += -bal  # credits increase revenue => negative in TB => flip sign
            elif acct_type in (AcctType.COGS, AcctType.OPEX, AcctType.OTHER_EXP, AcctType.INTEREST, AcctType.TAX):
                total += bal   # expenses are debits => positive in TB
            else:
                total += bal
    return round(total, 2)

def build_income_statement(ledger: Ledger, end: date) -> IncomeStatement:
    tb = ledger.trial_balance(end)
    revenue = _sum_by_type(tb, AcctType.REV)
    cogs = _sum_by_type(tb, AcctType.COGS)
    gp = revenue - cogs
    opex = _sum_by_type(tb, AcctType.OPEX)
    op_inc = gp - opex
    other_inc = _sum_by_type(tb, AcctType.OTHER_INC)
    other_exp = _sum_by_type(tb, AcctType.OTHER_EXP)
    interest = _sum_by_type(tb, AcctType.INTEREST)
    pretax = op_inc + other_inc - other_exp - interest
    tax = _sum_by_type(tb, AcctType.TAX)
    ni = pretax - tax
    return IncomeStatement(revenue, cogs, gp, opex, op_inc, other_inc, other_exp, interest, pretax, tax, ni)

def build_balance_sheet(ledger: Ledger, as_of: date) -> BalanceSheet:
    tb = ledger.trial_balance(as_of)
    assets, liab, eq = {}, {}, {}
    for code, bal in tb.items():
        a = COA[code]
        if a.type in (AcctType.ASSET, AcctType.CONTRA_ASSET):
            assets[a.name] = round(bal, 2)
        elif a.type == AcctType.LIABILITY:
            liab[a.name] = round(-bal, 2)  # liability natural credit → positive display
        elif a.type == AcctType.EQUITY:
            # equity natural credit → positive display, except retained earnings we will recompute
            if a.code != "3200":
                eq[a.name] = round(-bal, 2)

    # Retained Earnings derived: plug to balance assets = L+E
    total_assets = round(sum(assets.values()), 2)
    total_liab = round(sum(liab.values()), 2)
    non_re_eq = round(sum(v for k, v in eq.items()), 2)
    retained = round(total_assets - (total_liab + non_re_eq), 2)
    eq["Retained Earnings"] = retained

    total_le = round(total_liab + non_re_eq + retained, 2)
    return BalanceSheet(assets, liab, eq, total_assets, total_le)

def build_cash_flow_direct(ledger: Ledger, start: date, end: date) -> CashFlowDirect:
    """Direct method: uses delta TB and cash_flow_hint on accounts to classify.
    Also computes ending cash to reconcile."""
    delta = ledger.delta_tb(start, end)
    cfo, cfi, cff = {}, {}, {}
    for code, change in delta.items():
        acct = COA[code]
        hint = acct.cash_flow_hint
        if hint == "CFO":
            cfo[acct.name] = round(change * -1, 2)  # TB deltas are debit-positive; invert for cash sign
        elif hint == "CFI":
            cfi[acct.name] = round(change * -1, 2)
        elif hint == "CFF":
            cff[acct.name] = round(change * -1, 2)

    net = round(sum(cfo.values()) + sum(cfi.values()) + sum(cff.values()), 2)
    ending_cash = round(ledger.trial_balance(end)["1000"], 2)
    return CashFlowDirect(cfo, cfi, cff, net, ending_cash)
