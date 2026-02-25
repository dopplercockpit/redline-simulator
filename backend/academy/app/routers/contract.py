from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..db import ContentCache, get_db
from ..schemas import ContractGenerateRequest, ContractMessage

router = APIRouter()


@router.post("/generate", response_model=ContractMessage)
def generate_contract(request: ContractGenerateRequest, db: Session = Depends(get_db)) -> ContractMessage:
    contract_id = str(uuid.uuid4())
    message = ContractMessage(
        contract_id=contract_id,
        title="Ground Handling Service Agreement (Stub)",
        body=(
            "This is a placeholder contract for v0. Key terms will be generated in a later release."
        ),
        clauses=["Term: 12 months", "Liability cap: TBD", "SLA: 95% on-time handling"],
    )

    db.add(
        ContentCache(
            content_type="contract",
            content_json={"contract_id": contract_id, **message.model_dump()},
        )
    )
    db.commit()

    return message
