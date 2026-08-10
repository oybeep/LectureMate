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
            "1. summary: 강의 핵심 내용 3줄 요약\n"
            "2. key_concepts: 핵심 개념 키워드 리스트 (3~5개)\n"
            "3. quiz_questions: 복습용 객관식 퀴즈 리스트 (3문제)\n"
            "   - question: 질문 내용\n"
            "   - options: 강의 내용에 기반한 서로 다른 4개의 객관식 선택지 리스트 [1번, 2번, 3번, 4번] (★ '오답 1', '오답 2' 같은 임시 문구 절대 금지! 매력적인 오답선지를 직접 작성할 것)\n"
            "   - answer_index: 정답 선택지의 0-based 인덱스 숫자 (0, 1, 2, 3 중 하나)\n"
            "   - answer: 정답 선택지 텍스트 (options 내 텍스트와 완벽히 일치할 것)\n"
            "   - explanation: 정답에 대한 상세 해설\n\n"
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
                response_format={"type": "json_object"},  # ✨ JSON 응답 형식 강제 지정
                temperature=0.3  # ✨ 정교한 퀴즈 생성 및 구조 준수를 위해 온도를 낮춤
            )

            result_text = response.choices[0].message.content
            return {
                "status": "success",
                "raw_response": result_text
            }

        except Exception as e:
            print(f"OpenAI API 호출 에러: {e}")
            return {
                "status": "error",
                "message": str(e)
            }