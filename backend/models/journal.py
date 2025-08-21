
# backend/models/journal.py
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import date
from typing import List, Dict
from .accounts import COA, AcctType

@dataclass
class JournalLine:
    account: str  # COA code
    debit: float = 0.0
    credit: float = 0.0

@dataclass
class JournalEntry:
    je_id: str
    je_date: date
    memo: str
    lines: List[JournalLine] = field(default_factory=list)

    def is_balanced(self) -> bool:
        total_debits = sum(l.debit for l in self.lines)
        total_credits = sum(l.credit for l in self.lines)
        return round(total_debits - total_credits, 2) == 0.0

class Ledger:
    """In-memory ledger for V1. Later we back this with Postgres."""
    def __init__(self):
        self.entries: list[JournalEntry] = []

    def post(self, entry: JournalEntry):
        assert entry.is_balanced(), f"Unbalanced JE {entry.je_id}"
        for line in entry.lines:
            assert line.account in COA, f"Unknown account {line.account}"
        self.entries.append(entry)

    def trial_balance(self, up_to: date) -> Dict[str, float]:
        """Returns account -> balance (debit positive, credit negative)."""
        tb: Dict[str, float] = {code: 0.0 for code in COA.keys()}
        for je in self.entries:
            if je.je_date <= up_to:
                for l in je.lines:
                    tb[l.account] += l.debit
                    tb[l.account] -= l.credit
        return tb

    def delta_tb(self, start: date, end: date) -> Dict[str, float]:
        tb_start = self.trial_balance(start)
        tb_end   = self.trial_balance(end)
        return {k: round(tb_end.get(k,0.0)-tb_start.get(k,0.0),2) for k in COA.keys()}
