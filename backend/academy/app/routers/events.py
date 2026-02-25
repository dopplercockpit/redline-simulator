from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..db import Event, get_db
from ..schemas import EventIn, EventOut

router = APIRouter()


@router.post("", response_model=EventOut)
def create_event(event: EventIn, db: Session = Depends(get_db)) -> EventOut:
    row = Event(event_type=event.event_type, payload=event.payload)
    db.add(row)
    db.commit()
    db.refresh(row)
    return EventOut(id=row.id, event_type=row.event_type, payload=row.payload, created_at=row.created_at)
