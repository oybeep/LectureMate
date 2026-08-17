import os
import re
from typing import Optional
from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from openai import AsyncOpenAI
from sqlalchemy.orm import Session

# DB 및 모델 모듈
import models
from database import SessionLocal, get_db

load_dotenv()  # .env 로드

router = APIRouter(prefix="/notes", tags=["AI Note Customization"])

# API 키 기본값 안심 설정
api_key = os.environ.get("OPENAI_API_KEY") or "dummy_key"
client = AsyncOpenAI(api_key=api_key)

# ---------------------------------------------------------------------------
# 📝 5가지 학습용 프롬프트 템플릿
# ---------------------------------------------------------------------------
PROMPT_TEMPLATES = {
    "cornell": """
당신은 최고의 학습 멘토입니다. 아래 강의 내용을 바탕으로 대학생 학습용 '코넬식 노트(Cornell Notes)'를 작성해주세요.
반드시 아래 3개 영역을 Markdown 형식으로 명확히 구분하여 작성하세요:

# 📌 코넬 노트 (Cornell Notes)

## 1. 큐 영역 (Cue / 핵심 키워드 & 복습 질문)
- 강의의 핵심 키워드와 복습할 때 스스로 답해볼 수 있는 질문 3~5개를 작성하세요.

## 2. 노트 영역 (Notes / 세부 필기 내용)
- 강의 핵심 개념, 원리, 주요 설명을 논리적이고 체계적으로 정리하세요.

## 3. 요약 영역 (Summary / 최종 요약)
- 강의 전체를 관통하는 핵심 결론을 2~3문장으로 간결하게 요약하세요.
""",

    "exam": """
당신은 시험 적중률 100% 족집게 강사입니다. 아래 강의 내용을 바탕으로 '시험 대비 핵심 요약 노트'를 작성해주세요.
반드시 아래 항목을 Markdown 형식으로 작성하세요:

# 🎯 시험 대비 핵심 노트

## 1. 🔥 빈출 & 교수님 강조 핵심 개념
- 시험에 반드시 출제될 만한 필수 이론 및 정의 정리

## 2. ⚠️ 헷갈리기 쉬운 함정 및 필수 암기 포인트
- 오답률이 높거나 시험 직전 반드시 외워야 할 핵심 암기 사항

## 3. 📝 실전 예상 시험 문제 (3문항)
- 객관식 또는 서술형 예상 문제와 함께 **[정답 및 상세 해설]**을 함께 제공하세요.
""",

    "outline": """
당신은 정보 구조화 전문가입니다. 아래 강의 내용을 '아웃라인(계층형 개조식) 노트' 형식으로 체계화해주세요.

# 🌳 아웃라인 구조화 노트

- 대주제(I, II, ...), 중주제(A, B, ...), 소주제(1, 2, ...), 세부 내용(-)의 위계(Hierarchy)를 명확히 들여쓰기하여 정리하세요.
- 전체적인 개념 흐름과 포함 관계가 한눈에 보이도록 Markdown 목록 형태로 작성하세요.
""",

    "flashcard": """
당신은 암기 학습 전문가입니다. 아래 강의 내용 중 가장 중요한 핵심 개념 5~7개를 선별하여 '플래시카드(Flashcards)' 형식으로 작성해주세요.

# 🗂️ 핵심 복습 플래시카드

아래 형식을 반복하여 작성하세요:
---
### Card [번호]: [핵심 키워드/질문]
- **[앞면 질문]**: 해당 개념에 대한 핵심 질문 또는 빈칸 채우기
- **[뒷면 정답]**: 직관적이고 명확한 설명과 정답
---
""",

    "feynman": """
당신은 물리학자 리처드 파인만입니다. 아래 강의 내용의 핵심 개념을 '파인만 테크닉(Feynman Technique)'으로 쉽게 설명해주세요.

# 💡 파인만 설명 노트 (누구나 이해하는 쉬운 해설)

- 복잡한 전문 용어나 어려운 수식을 최대한 배제하세요.
- 비전공자나 중학생도 단번에 이해할 수 있도록 **일상 속 쉬운 비유와 직관적인 예시**를 적극적으로 활용하세요.
- 친근하고 이해하기 쉬운 구어체 어조로 설명하세요.
"""
}

# ---------------------------------------------------------------------------
# 요청 / 응답 모델
# ---------------------------------------------------------------------------
class CustomFormatRequest(BaseModel):
    stt_text: str
    format_type: str                    # cornell, exam, outline, flashcard, feynman
    lecture_id: Optional[int] = None    # 선택적 입력 처리

class CleanSTTRequest(BaseModel):
    stt_text: str
    lecture_id: Optional[int] = None    # 선택적 입력 처리


# ---------------------------------------------------------------------------
# API 엔드포인트
# ---------------------------------------------------------------------------

# 1. 5대 맞춤 학습노트 생성 (즉시 결과 반환)
@router.post("/generate-custom")
async def generate_custom_note(
    req: CustomFormatRequest, 
    db: Session = Depends(get_db)
):
    if req.format_type not in PROMPT_TEMPLATES:
        raise HTTPException(status_code=400, detail=f"지원하지 않는 노트 형식입니다: {req.format_type}")

    if not req.stt_text or req.stt_text.strip() == "":
        raise HTTPException(status_code=400, detail="STT 텍스트가 비어 있습니다.")

    try:
        system_prompt = PROMPT_TEMPLATES[req.format_type]
        user_content = f"--- [강의 내용 / STT 원문] ---\n{req.stt_text}"

        response = await client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_content}
            ],
            temperature=0.3,
        )
        result_content = response.choices[0].message.content

        # lecture_id가 함께 전달된 경우 DB 자동 저장
        if req.lecture_id:
            lecture = db.query(models.Lecture).filter(models.Lecture.id == req.lecture_id).first()
            if lecture:
                lecture.custom_note = result_content
                db.commit()
                print(f"✅ Lecture ID={req.lecture_id} | 맞춤노트({req.format_type}) DB 저장 완료")
            else:
                print(f"⚠️ Lecture ID={req.lecture_id} 해당 강의를 찾을 수 없습니다.")
        else:
            print(f"ℹ️ lecture_id 미전달 | 맞춤노트({req.format_type}) 생성 후 즉시 응답만 반환")

        return {
            "status": "success",
            "content": result_content,
            "custom_note": result_content,
            "format_type": req.format_type,
            "lecture_id": req.lecture_id
        }

    except Exception as e:
        print(f"❌ [맞춤노트 생성 실패]: {e}")
        raise HTTPException(status_code=500, detail=f"AI 노트 생성 중 오류가 발생했습니다: {str(e)}")


# 2. STT 가독성 정제본 생성 (즉시 결과 반환)
@router.post("/clean-stt")
async def clean_stt_transcript(
    req: CleanSTTRequest, 
    db: Session = Depends(get_db)
):
    if not req.stt_text or req.stt_text.strip() == "":
        raise HTTPException(status_code=400, detail="STT 텍스트가 비어있습니다.")

    try:
        system_prompt = """
당신은 대학 강의 STT 스크립트 전문 윤문 AI입니다.
입력된 STT는 발화 단위로 짧게 쪼개져 있거나 음성 인식 오류/반복 환각이 섞여 있습니다.
학생이 한 편의 읽기 좋은 강의록으로 읽을 수 있도록 자연스러운 문단 형태로 재구성하세요.

[교정 규칙]
1. 짧게 끊어진 문장들을 문맥에 맞게 이어 붙여 3~5문장 단위의 매끄러운 단락(Paragraph)으로 만드세요.
2. 강의 시작 전 잡담, 단순 반복 추임새, 무의미한 환각 단어는 깨끗이 삭제합니다.
3. 2~3분 단위의 주요 흐름 전환 지점에만 소제목(예: ## 📌 [주제명])을 추가하세요.
4. 전공 용어 및 수학 기호 오인식(예: 'z퀄' -> 'z =', 'x제곱' -> 'x²')을 바르게 교정하세요.
5. 마크다운 형식으로 가독성 높게 출력하세요.
"""
        response = await client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"--- [원문 STT 텍스트] ---\n{req.stt_text}"}
            ],
            temperature=0.2,
        )
        cleaned_text = response.choices[0].message.content

        # lecture_id가 함께 전달된 경우 DB 자동 저장
        if req.lecture_id:
            lecture = db.query(models.Lecture).filter(models.Lecture.id == req.lecture_id).first()
            if lecture:
                lecture.cleaned_transcript = cleaned_text
                db.commit()
                print(f"✅ Lecture ID={req.lecture_id} | STT 정제본 DB 저장 완료")
            else:
                print(f"⚠️ Lecture ID={req.lecture_id} 해당 강의를 찾을 수 없습니다.")
        else:
            print("ℹ️ lecture_id 미전달 | STT 정제본 생성 후 즉시 응답만 반환")

        return {
            "status": "success",
            "content": cleaned_text,
            "cleaned_transcript": cleaned_text,
            "lecture_id": req.lecture_id
        }

    except Exception as e:
        print(f"❌ [STT 정제 실패]: {e}")
        raise HTTPException(status_code=500, detail=f"STT 정제 중 오류가 발생했습니다: {str(e)}")