import json
import os
from pathlib import Path
from dotenv import load_dotenv
from openai import OpenAI

# backend 폴더 내부의 .env 경로를 명시적으로 로드
env_path = Path(__file__).resolve().parent.parent.parent / ".env"
load_dotenv(dotenv_path=env_path)

class AISummaryService:
    def __init__(self):
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY가 .env 파일에 설정되지 않았습니다.")
        self.client = OpenAI(api_key=api_key)

    def generate_lecture_summary(self, subject: str, lecture_title: str, transcript: str) -> dict:
        system_prompt = (
            "당신은 대학생을 위한 AI 학습 보조 시스템입니다.\n"
            "제공된 강의 노트 텍스트를 분석하여 아래 JSON 구조에 완벽히 맞게 응답해 주세요.\n\n"
            "[JSON 요구사항 및 구조]\n"
            "1. summary: 강의 전체 내용을 요약하는 한 줄 내지 두 줄의 총평 개요문\n"
            "2. detailed_summary: 강의의 핵심 주제별 세부 설명 리스트 (3~5개)\n"
            "   각 항목 객체 구조:\n"
            "   - title: 핵심 소주제 제목 (예: '복소수 Z와 W의 사상 관계')\n"
            "   - points: 해당 주제에 대한 상세 설명 불렛포인트 문자열 리스트 (2~3개 문장)\n"
            "3. key_concepts: 핵심 개념 키워드 리스트 (3~5개)\n"
            "4. quiz_questions: 복습용 객관식 퀴즈 리스트 (3문제)\n"
            "   - question: 질문 내용\n"
            "   - options: 4개의 선택지 리스트\n"
            "   - answer_index: 정답 인덱스 숫자 (0~3)\n"
            "   - answer: 정답 텍스트\n"
            "   - explanation: 정답 상세 해설\n\n"
            "반드시 Valid JSON 객체만 반환해 주세요."
        )

        user_prompt = f"과목: {subject}\n강의 제목: {lecture_title}\n\n강의 내용:\n{transcript[:10000]}"

        try:
            response = self.client.chat.completions.create(
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
            print(f"OpenAI API 호출 에러: {e}")
            return {
                "status": "error",
                "message": str(e)
            }