import json
import os
import re
from pathlib import Path
from dotenv import load_dotenv
from openai import AsyncOpenAI

env_path = Path(__file__).resolve().parent.parent.parent / ".env"
load_dotenv(dotenv_path=env_path)


class AISummaryService:
    def __init__(self):
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY가 .env 파일에 설정되지 않았습니다.")
        self.client = AsyncOpenAI(api_key=api_key)

    async def generate_lecture_summary(self, subject: str, lecture_title: str, transcript: str) -> dict:
        system_prompt = (
            "당신은 대학생을 위한 전문 AI 학습 보조 시스템입니다.\n"
            "주어진 강의 텍스트를 분석하여 가장 이상적인 학습 노트가 되도록 체계적인 JSON 형태로 정리해 주세요.\n\n"
            "[작성 원칙 및 JSON 구조]\n"
            "1. summary: 강의의 핵심 흐름과 최종 학습 목표를 명확하게 관통하는 2~3문장의 총평 개요문\n"
            "2. detailed_summary: 강의에서 다룬 핵심 소주제별 세부 정리 리스트\n"
            "   - 각 소주제 객체 구조:\n"
            "     {\n"
            "       \"title\": \"📌 [소주제명]\",\n"
            "       \"details\": [\n"
            "         \"첫 번째 세부 설명 문장\",\n"
            "         \"두 번째 세부 설명 문장\",\n"
            "         \"세 번째 세부 설명 문장\"\n"
            "       ]\n"
            "     }\n"
            "   - ⚠️ [필수 규칙] 'details' 배열 내의 문장들을 절대로 가운데 점(•)이나 기호를 사용해 한 줄로 이어 붙이지 마세요.\n"
            "   - 각 세부 문장은 반드시 하나씩 완전하게 분리된 배열(List) 원소(String)로 작성해야 합니다.\n"
            "3. key_concepts: 강의를 대표하는 핵심 용어 및 개념 키워드 리스트\n"
            "4. quiz_questions: 복습용 객관식 퀴즈 리스트 (question, options, answer_index, answer, explanation)\n\n"
            "반드시 Valid JSON 객체만 반환해 주세요."
        )

        user_prompt = f"과목: {subject}\n강의 제목: {lecture_title}\n\n강의 내용:\n{transcript[:10000]}"

        try:
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                response_format={"type": "json_object"},
                temperature=0.3
            )

            result_text = response.choices[0].message.content
            parsed_data = json.loads(result_text)

            # ------------------------------------------------------------------
            # 💡 [후처리] 혹시라도 details 내부나 points에 '•'로 뭉쳐진 경우 분리 보완
            # ------------------------------------------------------------------
            if "detailed_summary" in parsed_data and isinstance(parsed_data["detailed_summary"], list):
                sanitized_detailed = []
                for item in parsed_data["detailed_summary"]:
                    if isinstance(item, dict):
                        # details 또는 points 키 호환
                        raw_details = item.get("details") or item.get("points") or []
                        cleaned_details = []

                        if isinstance(raw_details, str):
                            # 문자열로 들어온 경우 '•' 또는 줄바꿈으로 분리
                            split_items = re.split(r"[•\n]+", raw_details)
                            cleaned_details = [s.strip() for s in split_items if s.strip()]
                        elif isinstance(raw_details, list):
                            for sub_item in raw_details:
                                sub_str = str(sub_item)
                                if "•" in sub_str:
                                    split_items = [s.strip() for s in sub_str.split("•") if s.strip()]
                                    cleaned_details.extend(split_items)
                                else:
                                    if sub_str.strip():
                                        cleaned_details.append(sub_str.strip())

                        sanitized_detailed.append({
                            "title": item.get("title", "📌 주요 내용"),
                            "details": cleaned_details,
                            "points": cleaned_details  # 앱 호환성을 위해 둘 다 저장
                        })
                parsed_data["detailed_summary"] = sanitized_detailed

            return {
                "status": "success",
                "data": parsed_data,
                "raw_response": json.dumps(parsed_data, ensure_ascii=False)
            }

        except Exception as e:
            print(f"❌ [AI Summary] OpenAI API 호출 에러: {e}")
            return {
                "status": "error",
                "message": str(e)
            }