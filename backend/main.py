import os
import sys
from dotenv import load_dotenv

load_dotenv()

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import asyncio
import json
import re
from datetime import datetime
from typing import Any, Dict, List, Optional

from fastapi import BackgroundTasks, Depends, FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy.orm import Session

# DB 연동 모듈 임포트
import models
import schemas
from database import SessionLocal, engine, get_db

# RAG & AI 서비스 모듈 임포트
from src.ai.ai_notes import router as ai_notes_router
from src.ai.audio import process_audio_volume
from src.ai.recommendation import ReviewRecommendationService
from src.ai.stt import STTService
from src.ai.summary import AISummaryService
from src.rag.embedding import LectureNoteEmbedder
from src.rag.search import LectureSearchService
from src.rag.vector_store import VectorDBManager

# 💡 DB 테이블 자동 생성
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Lecture Agent API", version="1.0.0")

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# AI 맞춤 노트 라우터 등록
app.include_router(ai_notes_router)

# AI 서비스 싱글톤 객체 생성
db_manager = VectorDBManager()
embedder = LectureNoteEmbedder(db_manager)
search_service = LectureSearchService(db_manager)
recommend_service = ReviewRecommendationService()
summary_service = AISummaryService()
stt_service = STTService()


# --- Pydantic Request/Response 스키마 ---
class QueryRequest(BaseModel):
    subject: str
    query: str


# 💡 Flutter에서 들어올 수 있는 다양한 필드명 호환 수용
class LectureUpdatePayload(BaseModel):
    title: Optional[str] = None
    cleaned_transcript: Optional[str] = None
    cleaned_stt: Optional[str] = None
    content: Optional[str] = None
    custom_note: Optional[str] = None
    custom_content: Optional[str] = None


class SubjectUpdatePayload(BaseModel):
    title: Optional[str] = None
    instructor: Optional[str] = None
    time_slot: Optional[str] = None


class SummaryRequestPayload(BaseModel):
    lecture_id: int
    subject: Optional[str] = "일반 강의"
    lecture_title: Optional[str] = "강의 녹음"
    stt_text: str


# Helper Function
def format_lecture_response(lecture: models.Lecture, subject_name: str = "") -> Dict[str, Any]:
    created_date = lecture.created_at.strftime("%Y-%m-%d %H:%M") if lecture.created_at else datetime.now().strftime("%Y-%m-%d %H:%M")
    
    # 💡 요약/퀴즈 존재 여부에 따라 상태 전달 (processing vs completed)
    is_processed = bool(lecture.summary or lecture.detailed_summary)
    
    return {
        "id": lecture.id,
        "subject_id": lecture.subject_id,
        "subject": subject_name,
        "lecture_title": lecture.title,
        "title": lecture.title,
        "filename": lecture.title,
        "created_at": created_date,
        "date": created_date,
        "status": "completed" if is_processed else "processing",
        "transcript": lecture.stt_text or "",
        "stt_transcript": lecture.stt_text or "",
        "stt_text": lecture.stt_text or "",
        "cleaned_transcript": lecture.cleaned_transcript,
        "cleaned_stt": lecture.cleaned_transcript,
        "custom_note": lecture.custom_note,
        "custom_content": lecture.custom_note,
        "summary": lecture.summary or "",
        "detailed_summary": lecture.detailed_summary,
        "detail_summary": lecture.detailed_summary,
        "details": lecture.detailed_summary,
        "keywords": lecture.keywords,
        "key_concepts": lecture.keywords,
        "quiz": lecture.quiz,
        "quizzes": lecture.quiz,
        "quiz_questions": lecture.quiz,
    }


# ---------------------------------------------------------------------------
# ⚙️ 백그라운드 AI 처리 로직 (화면 나가도 끝까지 동작)
# ---------------------------------------------------------------------------
async def task_summarize_lecture(lecture_id: int, subject: str, lecture_title: str, stt_text: str):
    db = SessionLocal()
    try:
        ai_result = await summary_service.generate_lecture_summary(
            subject, lecture_title, stt_text
        )

        parsed_data = {}
        if ai_result.get("status") == "success" and "raw_response" in ai_result:
            raw_text = ai_result["raw_response"]
            
            # 💡 정규식으로 가장 외곽의 { ... } JSON 객체만 정확히 추출
            match = re.search(r'\{.*\}', raw_text, re.DOTALL)
            if match:
                try:
                    parsed_data = json.loads(match.group(0))
                except Exception as json_err:
                    print(f"⚠️ 백그라운드 요약 JSON 파싱 실패: {json_err}")
                    parsed_data = {}
            else:
                parsed_data = {}

        summary_text = parsed_data.get("summary", "강의 요약 내용을 성공적으로 생성했습니다.")
        detailed_summary_list = parsed_data.get("detailed_summary") or parsed_data.get("detail_summary") or parsed_data.get("details") or []
        keywords = parsed_data.get("key_concepts") or parsed_data.get("keywords") or ["강의 핵심", "AI 요약"]
        raw_quizzes = parsed_data.get("quiz_questions") or parsed_data.get("quiz") or parsed_data.get("quizzes") or []

        formatted_quizzes = []
        if isinstance(raw_quizzes, list):
            for idx, item in enumerate(raw_quizzes):
                if isinstance(item, dict):
                    q_text = item.get("question", "강의 관련 퀴즈")
                    raw_opts = item.get("options") or item.get("choices") or []
                    opts = [str(o) for o in raw_opts] if (isinstance(raw_opts, list) and len(raw_opts) >= 2) else [str(item.get("answer", "정답")), "해당하지 않는 내용", "잘못된 개념 설명", "언급되지 않은 조건"]
                    correct_idx = item.get("answer_index")
                    try: 
                        correct_idx = int(correct_idx)
                    except (ValueError, TypeError):
                        try:
                            correct_idx = opts.index(str(item.get("answer", "")))
                        except ValueError:
                            correct_idx = 0

                    formatted_quizzes.append({
                        "id": idx + 1,
                        "question": q_text,
                        "answer": correct_idx,
                        "correctIndex": correct_idx,
                        "answerIndex": correct_idx,
                        "answer_text": item.get("answer", opts[correct_idx] if correct_idx < len(opts) else ""),
                        "options": opts,
                        "choices": opts,
                        "explanation": item.get("explanation", "강의 핵심 내용을 참고해 보세요.")
                    })

        # DB 업데이트
        lecture = db.query(models.Lecture).filter(models.Lecture.id == lecture_id).first()
        if lecture:
            lecture.summary = summary_text
            lecture.detailed_summary = detailed_summary_list
            lecture.keywords = keywords
            lecture.quiz = formatted_quizzes
            db.commit()
            print(f"✅ [백그라운드 요약 완료]: Lecture ID={lecture_id} DB 저장 완")

        # Vector DB 인덱싱
        try:
            await asyncio.to_thread(
                embedder.process_and_store_lecture,
                subject,
                lecture_title,
                stt_text,
                summary_text
            )
        except Exception as vec_err:
            print(f"⚠️ [Vector DB 인덱싱 실패]: {vec_err}")

    except Exception as e:
        print(f"❌ [백그라운드 요약 생성 실패]: {e}")
    finally:
        db.close()


# --- API 엔드포인트 ---

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "message": "Lecture Agent Server Running (SQLite DB Connected)"
    }


# 1. AI 강의 검색 & 타임스탬프 질의
@app.post("/api/lectures/search")
@app.post("/qa/ask")
def search_lecture(req: QueryRequest):
    target_subject = req.subject.strip() if req.subject else ""
    if target_subject in ["전체 과목", "전체", "All", "all", ""]:
        target_subject = ""

    res = search_service.search_lecture_with_timestamp(
        subject=target_subject, 
        query=req.query
    )
    if not res:
        return {
            "status": "not_found",
            "answer": "관련된 강의 내용을 찾을 수 없습니다.",
            "lecture_title": None,
            "display_text": "저장된 강의 노트 및 STT 기록에서 관련 내용을 찾지 못했습니다."
        }
        
    return {
        "status": "success",
        "answer": res.get("answer", ""),
        "lecture_title": res.get("lecture_title"),
        "timestamp": res.get("timestamp"),
        "display_text": res.get("display_text", "")
    }


# 2. AI 복습 추천
@app.get("/api/ai/review-recommendations")
def get_review_recommendations(db: Session = Depends(get_db)):
    subjects = db.query(models.Subject).all()
    mock_history = []
    
    for sub in subjects:
        lectures = db.query(models.Lecture).filter(models.Lecture.subject_id == sub.id).all()
        for lec in lectures:
            mock_history.append({
                "subject": sub.title,
                "lecture_title": lec.title,
                "days_ago": 1,
                "review_count": 0,
                "professor": sub.instructor or "교수 미지정",
                "instructor": sub.instructor or "교수 미지정",
                "time": sub.time_slot or "시간 미정",
                "time_slot": sub.time_slot or "시간 미정"
            })

    recommendations = recommend_service.get_review_recommendations(mock_history)
    return {
        "status": "success",
        "count": len(recommendations),
        "data": recommendations
    }


# 3. 과목 CRUD
@app.get("/subjects")
@app.get("/api/subjects")
def get_subjects(db: Session = Depends(get_db)):
    subjects = db.query(models.Subject).all()
    sanitized = []
    for sub in subjects:
        sanitized.append({
            "id": sub.id,
            "name": sub.title,
            "title": sub.title,
            "subject_name": sub.title,
            "code": f"SUB{sub.id:03d}",
            "professor": sub.instructor,
            "professor_name": sub.instructor,
            "instructor": sub.instructor,
            "time": sub.time_slot,
            "lecture_time": sub.time_slot,
            "schedule": sub.time_slot,
            "time_slot": sub.time_slot
        })
    return sanitized


@app.post("/subjects")
@app.post("/api/subjects")
async def create_subject(request: Request, db: Session = Depends(get_db)):
    try:
        body = await request.json()
    except Exception:
        body = {}

    sub_name = body.get("title") or body.get("name") or body.get("subject_name") or "새 수강 과목"
    prof_name = body.get("instructor") or body.get("professor") or body.get("professor_name") or "미지정"
    time_slot = body.get("time_slot") or body.get("time") or body.get("schedule") or "시간 미정"

    new_subject = models.Subject(
        title=str(sub_name),
        instructor=str(prof_name),
        time_slot=str(time_slot)
    )
    db.add(new_subject)
    db.commit()
    db.refresh(new_subject)

    return {
        "id": new_subject.id,
        "name": new_subject.title,
        "title": new_subject.title,
        "subject_name": new_subject.title,
        "code": f"SUB{new_subject.id:03d}",
        "professor": new_subject.instructor,
        "professor_name": new_subject.instructor,
        "instructor": new_subject.instructor,
        "time": new_subject.time_slot,
        "lecture_time": new_subject.time_slot,
        "schedule": new_subject.time_slot,
        "time_slot": new_subject.time_slot
    }


@app.delete("/subjects/{subject_id}")
@app.delete("/api/subjects/{subject_id}")
def delete_subject(subject_id: int, db: Session = Depends(get_db)):
    target_sub = db.query(models.Subject).filter(models.Subject.id == subject_id).first()
    if not target_sub:
        raise HTTPException(status_code=404, detail="해당 과목을 찾을 수 없습니다.")

    db.delete(target_sub)
    db.commit()
    return {"status": "success", "message": "과목이 삭제되었습니다.", "deleted_id": subject_id}


@app.put("/subjects/{subject_id}")
@app.put("/api/subjects/{subject_id}")
def update_subject(subject_id: int, payload: SubjectUpdatePayload, db: Session = Depends(get_db)):
    target_sub = db.query(models.Subject).filter(models.Subject.id == subject_id).first()
    if not target_sub:
        raise HTTPException(status_code=404, detail="해당 과목을 찾을 수 없습니다.")

    if payload.title and payload.title.strip():
        target_sub.title = payload.title.strip()
    if payload.instructor and payload.instructor.strip():
        target_sub.instructor = payload.instructor.strip()
    if payload.time_slot and payload.time_slot.strip():
        target_sub.time_slot = payload.time_slot.strip()

    db.commit()
    db.refresh(target_sub)

    return {
        "status": "success",
        "message": "과목 정보가 수정되었습니다.",
        "subject": {
            "id": target_sub.id,
            "title": target_sub.title,
            "instructor": target_sub.instructor,
            "time_slot": target_sub.time_slot
        }
    }


# 4. 강의 목록 및 단일 강의 조회
@app.get("/subjects/{subject_id}/lectures")
@app.get("/api/subjects/{subject_id}/lectures")
@app.get("/lectures/subject/{subject_id}")
@app.get("/api/lectures/subject/{subject_id}")
def get_lectures_by_subject(subject_id: int, db: Session = Depends(get_db)):
    subject = db.query(models.Subject).filter(models.Subject.id == subject_id).first()
    sub_name = subject.title if subject else ""
    
    lectures = db.query(models.Lecture).filter(models.Lecture.subject_id == subject_id).order_by(models.Lecture.id.desc()).all()
    return [format_lecture_response(lec, sub_name) for lec in lectures]


# 💡 단일 강의 상세 데이터 리로드 조회용 API
@app.get("/lectures/{lecture_id}")
@app.get("/api/lectures/{lecture_id}")
def get_single_lecture(lecture_id: int, db: Session = Depends(get_db)):
    lecture = db.query(models.Lecture).filter(models.Lecture.id == lecture_id).first()
    if not lecture:
        raise HTTPException(status_code=404, detail="해당 강의를 찾을 수 없습니다.")

    subject = db.query(models.Subject).filter(models.Subject.id == lecture.subject_id).first()
    sub_name = subject.title if subject else ""

    return format_lecture_response(lecture, sub_name)


# 💡 프론트엔드 /notes/{note_id} 호환 엔드포인트 (404 해결)
@app.get("/notes/{note_id}")
@app.get("/api/notes/{note_id}")
def get_note_by_id(note_id: int, db: Session = Depends(get_db)):
    lecture = db.query(models.Lecture).filter(models.Lecture.id == note_id).first()
    if not lecture:
        raise HTTPException(status_code=404, detail=f"ID가 {note_id}인 노트를 찾을 수 없습니다.")

    subject = db.query(models.Subject).filter(models.Subject.id == lecture.subject_id).first()
    sub_name = subject.title if subject else ""

    return format_lecture_response(lecture, sub_name)


# 4-1. 강의 정보 수정 API (💡 유연한 파라미터 수용 처리)
@app.patch("/lectures/{lecture_id}")
@app.patch("/api/lectures/{lecture_id}")
@app.put("/lectures/{lecture_id}")
@app.put("/api/lectures/{lecture_id}")
def update_lecture(lecture_id: int, payload: LectureUpdatePayload, db: Session = Depends(get_db)):
    lecture = db.query(models.Lecture).filter(models.Lecture.id == lecture_id).first()
    if not lecture:
        raise HTTPException(status_code=404, detail=f"ID가 {lecture_id}인 강의 노트를 찾지 못했습니다.")

    if payload.title is not None and payload.title.strip():
        lecture.title = payload.title.strip()

    # 💡 cleaned_transcript, cleaned_stt, content 중 존재하는 값을 DB에 업데이트
    target_cleaned = payload.cleaned_transcript or payload.cleaned_stt or payload.content
    if target_cleaned is not None:
        lecture.cleaned_transcript = target_cleaned

    # 💡 custom_note, custom_content 중 존재하는 값을 DB에 업데이트
    target_custom = payload.custom_note or payload.custom_content
    if target_custom is not None:
        lecture.custom_note = target_custom

    db.commit()
    db.refresh(lecture)

    subject = db.query(models.Subject).filter(models.Subject.id == lecture.subject_id).first()
    sub_name = subject.title if subject else ""

    return {
        "status": "success",
        "message": "노트 정보가 성공적으로 업데이트되었습니다.",
        "data": format_lecture_response(lecture, sub_name)
    }


# 4-2. 강의 노트 삭제 API
@app.delete("/lectures/{lecture_id}")
@app.delete("/api/lectures/{lecture_id}")
def delete_lecture_note(lecture_id: int, db: Session = Depends(get_db)):
    lecture = db.query(models.Lecture).filter(models.Lecture.id == lecture_id).first()
    if not lecture:
        raise HTTPException(status_code=404, detail=f"ID가 {lecture_id}인 강의 노트를 찾을 수 없습니다.")

    db.delete(lecture)
    db.commit()

    return {
        "status": "success",
        "message": "노트가 삭제되었습니다.",
        "deleted_id": lecture_id
    }


# 5-1. STT 전사 전용 엔드포인트
@app.post("/api/stt/transcribe")
@app.post("/api/lectures/upload-stt-only")
async def upload_audio_stt_only(
    file: Optional[UploadFile] = File(None),
    audio: Optional[UploadFile] = File(None),
    subject_id: Optional[str] = Form(None),
    subject: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    try:
        target_file = file or audio
        raw_sub_id = subject_id or subject or "1"
        try:
            target_sub_id = int(raw_sub_id)
        except ValueError:
            target_sub_id = 1

        sub_obj = db.query(models.Subject).filter(models.Subject.id == target_sub_id).first()
        selected_subject_name = sub_obj.title if sub_obj else "기본 과목"
        file_name = target_file.filename if target_file else f"lecture_{datetime.now().strftime('%m%d_%H%M')}.m4a"

        audio_bytes = await target_file.read() if target_file else b""

        if audio_bytes and len(audio_bytes) > 20 * 1024 * 1024:
            audio_bytes = await asyncio.to_thread(process_audio_volume, audio_bytes, -16.0)

        stt_transcript = await stt_service.transcribe_audio_bytes_async(audio_bytes, file_name)
        if not stt_transcript.strip():
            stt_transcript = "음성 파일에서 텍스트를 추출하지 못했습니다."

        # DB 저장
        new_lecture = models.Lecture(
            subject_id=target_sub_id,
            title=file_name,
            stt_text=stt_transcript
        )
        db.add(new_lecture)
        db.commit()
        db.refresh(new_lecture)

        formatted = format_lecture_response(new_lecture, selected_subject_name)
        return {"status": "success", **formatted}

    except Exception as e:
        print(f"❌ [STT 전사 실패]: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 5-2. 온디맨드 AI 요약 엔드포인트 (백그라운드 비동기 처리)
@app.post("/api/ai/summarize")
async def summarize_lecture_on_demand(
    req: SummaryRequestPayload, 
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    if not req.stt_text.strip():
        raise HTTPException(status_code=400, detail="STT 텍스트가 비어 있습니다.")

    # 💡 백그라운드 작업으로 즉시 등록
    background_tasks.add_task(
        task_summarize_lecture,
        req.lecture_id,
        req.subject,
        req.lecture_title,
        req.stt_text
    )

    return {
        "status": "processing",
        "message": "AI 요약 생성이 백그라운드에서 시작되었습니다.",
        "lecture_id": req.lecture_id
    }

# 5. 올인원 업로드 엔드포인트
@app.api_route("/lectures/upload", methods=["POST", "PUT"])
@app.api_route("/api/lectures/upload", methods=["POST", "PUT"])
@app.api_route("/upload", methods=["POST", "PUT"])
@app.api_route("/api/upload", methods=["POST", "PUT"])
async def handle_audio_upload_universal(
    request: Request,
    background_tasks: BackgroundTasks,
    file: Optional[UploadFile] = File(None),
    audio: Optional[UploadFile] = File(None),
    subject_id: Optional[str] = Form(None),
    subject: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    try:
        target_file = file or audio
        raw_sub_id = subject_id or subject or "1"
        try:
            target_sub_id = int(raw_sub_id)
        except ValueError:
            target_sub_id = 1

        sub_obj = db.query(models.Subject).filter(models.Subject.id == target_sub_id).first()
        selected_subject_name = sub_obj.title if sub_obj else "기본 과목"
        file_name = target_file.filename if target_file else f"lecture_{datetime.now().strftime('%m%d_%H%M')}.m4a"

        audio_bytes = await target_file.read() if target_file else b""

        if audio_bytes and len(audio_bytes) > 20 * 1024 * 1024:
            audio_bytes = await asyncio.to_thread(process_audio_volume, audio_bytes, -16.0)

        # 1. STT 전사 먼저 완료
        stt_transcript = await stt_service.transcribe_audio_bytes_async(audio_bytes, file_name)
        if not stt_transcript.strip():
            stt_transcript = "음성 파일에서 텍스트를 추출하지 못했습니다."

        # 2. DB에 레코드 기본 생성
        new_lecture = models.Lecture(
            subject_id=target_sub_id,
            title=file_name,
            stt_text=stt_transcript
        )
        db.add(new_lecture)
        db.commit()
        db.refresh(new_lecture)

        # -------------------------------------------------------------
        # 💡 [수정] await 제거 -> background_tasks에 작업 등록
        # -------------------------------------------------------------
        background_tasks.add_task(
            task_summarize_lecture,
            new_lecture.id,
            selected_subject_name,
            file_name,
            stt_transcript
        )

        # 4. 즉시 응답 반환 (status는 format_lecture_response에 의해 'processing'으로 전달됨)
        formatted = format_lecture_response(new_lecture, selected_subject_name)
        return {
            "status": "processing",
            "message": f"'{file_name}' 파일 전사 완료. AI 요약이 백그라운드에서 진행 중입니다.",
            **formatted
        }

    except Exception as e:
        print(f"❌ Upload handling error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- 사용자 프로필 & 앱 설정 API 엔드포인트 ---

# 1. 프로필 조회
@app.get("/users/me", response_model=schemas.UserProfileResponse)
@app.get("/api/v1/users/me", response_model=schemas.UserProfileResponse)
def get_user_profile(db: Session = Depends(get_db)):
    # TODO: 인증 토큰 연동 시 현재 로그인된 유저 조회 처리
    user = db.query(models.User).first()
    if not user:
        # DB에 유저가 없을 경우 기본 테스트 유저 생성 후 반환
        user = models.User(name="홍길동", email="user@lecturemate.com")
        db.add(user)
        db.commit()
        db.refresh(user)
    return user


# 2. 프로필 정보 수정
@app.patch("/users/me", response_model=schemas.UserProfileResponse)
@app.patch("/api/v1/users/me", response_model=schemas.UserProfileResponse)
def update_user_profile(payload: schemas.UserProfileUpdate, db: Session = Depends(get_db)):
    user = db.query(models.User).first()
    if not user:
        raise HTTPException(status_code=404, detail="사용자 정보를 찾을 수 없습니다.")

    if payload.name is not None and payload.name.strip():
        user.name = payload.name.strip()
    if payload.email is not None and payload.email.strip():
        user.email = payload.email.strip()

    db.commit()
    db.refresh(user)
    return user


# 3. 앱 서비스 설정 조회
@app.get("/settings", response_model=schemas.AppSettingsResponse)
@app.get("/api/v1/settings", response_model=schemas.AppSettingsResponse)
def get_app_settings(db: Session = Depends(get_db)):
    user = db.query(models.User).first()
    user_id = user.id if user else 1

    settings = db.query(models.AppSettings).filter(models.AppSettings.user_id == user_id).first()
    if not settings:
        # 기본 설정 레코드 생성
        settings = models.AppSettings(
            user_id=user_id,
            auto_summary_enabled=True,
            push_notification_enabled=True,
            dark_mode_enabled=False,
            language="ko"
        )
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings


# 4. 앱 서비스 설정 부분 업데이트 (토글 등)
@app.patch("/settings", response_model=schemas.AppSettingsResponse)
@app.patch("/api/v1/settings", response_model=schemas.AppSettingsResponse)
def update_app_settings(payload: schemas.AppSettingsUpdate, db: Session = Depends(get_db)):
    user = db.query(models.User).first()
    user_id = user.id if user else 1

    settings = db.query(models.AppSettings).filter(models.AppSettings.user_id == user_id).first()
    if not settings:
        settings = models.AppSettings(user_id=user_id)
        db.add(settings)

    if payload.auto_summary_enabled is not None:
        settings.auto_summary_enabled = payload.auto_summary_enabled
    if payload.push_notification_enabled is not None:
        settings.push_notification_enabled = payload.push_notification_enabled
    if payload.dark_mode_enabled is not None:
        settings.dark_mode_enabled = payload.dark_mode_enabled
    if payload.language is not None:
        settings.language = payload.language

    db.commit()
    db.refresh(settings)
    return settings


# 5. 로그아웃 API
@app.post("/auth/logout")
@app.post("/api/v1/auth/logout")
def logout():
    # 서버 측 세션/토큰 무효화 로직 위치
    return {"status": "success", "message": "성공적으로 로그아웃되었습니다."}