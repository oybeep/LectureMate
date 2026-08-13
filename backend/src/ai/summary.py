import json
import os
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
            "주어진 강의 텍스트의 분량, 난이도, 다루는 주제의 범위를 분석하여 "
            "가장 이상적인 학습 노트가 되도록 유연하고 체계적인 JSON 형태로 정리해 주세요.\n\n"
            "[작성 원칙 및 JSON 구조]\n"
            "1. summary: 강의의 핵심 흐름과 최종 학습 목표를 명확하게 관통하는 2~3문장의 총평 개요문\n"
            "2. detailed_summary: 강의에서 다룬 핵심 소주제별 세부 정리 리스트\n"
            "   - 각 소주제 객체 구조: title, points (2개 이상의 상세 설명 문장 리스트)\n"
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

            return {
                "status": "success",
                "data": parsed_data,
                "raw_response": result_text
            }

        except Exception as e:
            print(f"❌ [AI Summary] OpenAI API 호출 에러: {e}")
            return {
                "status": "error",
                "message": str(e)
            }