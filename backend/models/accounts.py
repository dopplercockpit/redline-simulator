# accounts.py
# backend/models/accounts.py
from enum import Enum
from dataclasses import dataclass

class AcctType(str, Enum):
    ASSET = "ASSET"
    LIABILITY = "LIABILITY"
    EQUITY = "EQUITY"
    REV = "REV"
    COGS = "COGS"
    OPEX = "OPEX"
    OTHER_INC = "OTHER_INC"
    OTHER_EXP = "OTHER_EXP"
    INTEREST = "INTEREST"
    TAX = "TAX"
    CONTRA_ASSET = "CONTRA_ASSET"  # e.g., Allowance for Doubtful Accounts, Accum. Depreciation

@dataclass(frozen=True)
class Account:
    code: str
    name: str
    type: AcctType
    cash_flow_hint: str | None = None  # "CFO","CFI","CFF" for direct method classification

# Minimal COA to produce full statements; extend as we integrate modules.
COA: dict[str, Account] = {
    # Assets
    "1000": Account("1000", "Cash", AcctType.ASSET, "CFO"),
    "1100": Account("1100", "Accounts Receivable", AcctType.ASSET, "CFO"),
    "1200": Account("1200", "Inventory", AcctType.ASSET, "CFO"),
    "1210": Account("1210", "WIP", AcctType.ASSET, "CFO"),
    "1300": Account("1300", "Prepaid Expenses", AcctType.ASSET, "CFO"),
    "1500": Account("1500", "Property, Plant & Equipment", AcctType.ASSET, "CFI"),
    "1590": Account("1590", "Accumulated Depreciation", AcctType.CONTRA_ASSET, None),

    # Liabilities
    "2000": Account("2000", "Accounts Payable", AcctType.LIABILITY, "CFO"),
    "2100": Account("2100", "Accrued Expenses", AcctType.LIABILITY, "CFO"),
    "2200": Account("2200", "Deferred Revenue", AcctType.LIABILITY, "CFO"),
    "2500": Account("2500", "Short-term Debt", AcctType.LIABILITY, "CFF"),
    "2600": Account("2600", "Long-term Debt", AcctType.LIABILITY, "CFF"),
    "2690": Account("2690", "Interest Payable", AcctType.LIABILITY, "CFO"),
    "2700": Account("2700", "Income Taxes Payable", AcctType.LIABILITY, "CFO"),

    # Equity
    "3000": Account("3000", "Common Stock", AcctType.EQUITY, "CFF"),
    "3100": Account("3100", "Additional Paid-in Capital", AcctType.EQUITY, "CFF"),
    "3200": Account("3200", "Retained Earnings", AcctType.EQUITY, None),  # derived at period end

    # Revenue & Expenses
    "4000": Account("4000", "Revenue", AcctType.REV, None),
    "4100": Account("4100", "Sales Returns & Allowances", AcctType.REV, None),  # negative to REV

    "5000": Account("5000", "COGS", AcctType.COGS, None),

    "6000": Account("6000", "SG&A Expense", AcctType.OPEX, None),
    "6100": Account("6100", "R&D Expense", AcctType.OPEX, None),
    "6200": Account("6200", "Marketing Expense", AcctType.OPEX, None),
    "6300": Account("6300", "Depreciation Expense", AcctType.OPEX, None),

    "7000": Account("7000", "Other Income", AcctType.OTHER_INC, None),
    "7100": Account("7100", "Other Expense", AcctType.OTHER_EXP, None),
    "7200": Account("7200", "Interest Expense", AcctType.INTEREST, None),
    "7300": Account("7300", "Income Tax Expense", AcctType.TAX, None),
}
