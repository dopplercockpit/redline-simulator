# backend/reqmodels.py

from pydantic import BaseModel
from datetime import date

class CashReceiptRequest(BaseModel):
    receipt_id: str
    customer_id: str
    receipt_date: date
    amount_invoice: float
    amount_received: float
    discount_taken: float = 0.0

class SupplierBillRequest(BaseModel):
    bill_id: str
    supplier_id: str
    bill_date: date
    amount: float
    description: str = ""

class SupplierPaymentRequest(BaseModel):
    payment_id: str
    supplier_id: str
    payment_date: date
    amount_invoice: float
    amount_paid: float
    discount_taken: float = 0.0
