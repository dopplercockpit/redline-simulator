from __future__ import annotations

import json
import os
from typing import Any, Optional

from openai import OpenAI


class OpenAIClient:
    def __init__(self, api_key: Optional[str] = None, model: Optional[str] = None) -> None:
        self.api_key = api_key or os.getenv("OPENAI_API_KEY")
        self.model = model or os.getenv("OPENAI_MODEL", "gpt-4.1-mini")
        self._client = OpenAI(api_key=self.api_key) if self.api_key else None

    @property
    def available(self) -> bool:
        return self._client is not None

    def responses_json(
        self,
        *,
        schema: dict[str, Any],
        system_prompt: str,
        user_prompt: str,
        temperature: float = 0.2,
    ) -> dict[str, Any]:
        if not self._client:
            raise RuntimeError("OpenAI client is not configured.")

        response = self._client.responses.create(
            model=self.model,
            input=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=temperature,
            response_format={
                "type": "json_schema",
                "json_schema": {
                    "name": "strict_response",
                    "schema": schema,
                    "strict": True,
                },
            },
        )

        raw_text = getattr(response, "output_text", None)
        if not raw_text:
            raw_text = response.output[0].content[0].text
        return json.loads(raw_text)
