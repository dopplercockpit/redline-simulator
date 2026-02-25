from __future__ import annotations

from fastapi import APIRouter

from ..schemas import RgmPricingTestRequest, RgmPricingTestResult

router = APIRouter()


@router.post("/test", response_model=RgmPricingTestResult)
def pricing_test(request: RgmPricingTestRequest) -> RgmPricingTestResult:
    price_change_pct = (request.variant_price - request.baseline_price) / request.baseline_price
    volume_variant = request.baseline_volume * (1 + request.elasticity * price_change_pct)
    revenue_base = request.baseline_price * request.baseline_volume
    revenue_variant = request.variant_price * volume_variant

    congestion_penalty = 0.0
    risk_flags = []
    if volume_variant > request.capacity:
        over = (volume_variant - request.capacity) / request.capacity
        congestion_penalty = revenue_variant * request.congestion_penalty_pct * over
        revenue_variant -= congestion_penalty
        risk_flags.append("congestion")
        if over > 0.1:
            risk_flags.append("severe_congestion")

    return RgmPricingTestResult(
        volume_variant=round(volume_variant, 2),
        revenue_variant=round(revenue_variant, 2),
        revenue_base=round(revenue_base, 2),
        congestion_penalty=round(congestion_penalty, 2),
        risk_flags=risk_flags,
    )
