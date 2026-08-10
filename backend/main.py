import asyncio  # ✨ [필수 수정] asyncio 모듈 임포트 추가
import json
import re
from datetime import datetime
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# RAG & AI 서비스 모듈 임포트
from src.ai.audio import process_audio_volume  # ✨ 음성 증폭 전처리 모듈
from src.ai.recommendation import ReviewRecommendationService
from src.ai.stt import STTService
from src.ai.summary import AISummaryService
from src.rag.embedding import LectureNoteEmbedder
from src.rag.search import LectureSearchService
from src.rag.vector_store import VectorDBManager

app = FastAPI(title="Lecture Agent API", version="1.0.0")

# CORS 설정 (Flutter Web/App 통신용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# AI 서비스 싱글톤 객체 생성
db_manager = VectorDBManager()
embedder = LectureNoteEmbedder(db_manager)  # ✨ Vector DB 저장용 Embedder 연결
search_service = LectureSearchService(db_manager)
recommend_service = ReviewRecommendationService()
summary_service = AISummaryService()
stt_service = STTService()

# ==========================================
# 동적 데이터베이스 (메모리 저장소)
# ==========================================
SUBJECTS_DB: List[Dict[str, Any]] = []
LECTURES_DB: Dict[int, List[Dict[str, Any]]] = {}

GLOBAL_LECTURE_ID_COUNTER = 1


# Helper Function: ID로 과목 찾기
def find_subject_by_id(sub_id: int) -> Optional[Dict[str, Any]]:
    for sub in SUBJECTS_DB:
        if sub["id"] == sub_id:
            return sub
    return None


# --- Pydantic Request/Response 스키마 ---
class QueryRequest(BaseModel):
    subject: str
    query: str


class TitleUpdatePayload(BaseModel):
    title: str


class SubjectUpdatePayload(BaseModel):
    title: Optional[str] = None
    instructor: Optional[str] = None
    time_slot: Optional[str] = None


# --- API 엔드포인트 ---

@app.get("/health")
def health_check():
    """서버 상태 확인"""
    return {
        "status": "healthy",
        "message": "Lecture Agent Server Running"
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
def get_review_recommendations():
    mock_history = []
    for sub in SUBJECTS_DB:
        sub_id = sub["id"]
        sub_name = sub["name"]
        lectures = LECTURES_DB.get(sub_id, [])
        for lec in lectures:
            mock_history.append({
                "subject": sub_name,
                "lecture_title": lec.get("title", "강의"),
                "days_ago": 1,
                "review_count": 0,
                "professor": sub.get("instructor", "교수 미지정"),
                "instructor": sub.get("instructor", "교수 미지정"),
                "time": sub.get("time_slot", "시간 미정"),
                "time_slot": sub.get("time_slot", "시간 미정")
            })

    recommendations = recommend_service.get_review_recommendations(mock_history)
    return {
        "status": "success",
        "count": len(recommendations),
        "data": recommendations
    }


# 3. 과목 목록 조회 & 동적 과목 등록 / 삭제
@app.get("/subjects")
@app.get("/api/subjects")
def get_subjects():
    sanitized = []
    for sub in SUBJECTS_DB:
        item = dict(sub)
        item["id"] = int(sub["id"])
        sanitized.append(item)
    return sanitized


@app.post("/subjects")
@app.post("/api/subjects")
async def create_subject(request: Request):
    try:
        body = await request.json()
    except Exception:
        body = {}

    sub_name = body.get("title") or body.get("name") or body.get("subject_name") or "새 수강 과목"
    prof_name = body.get("instructor") or body.get("professor") or body.get("professor_name") or "미지정"
    time_slot = body.get("time_slot") or body.get("time") or body.get("schedule") or "시간 미정"

    new_id = int(len(SUBJECTS_DB) + 1)
    
    new_subject = {
        "id": new_id,
        "name": str(sub_name),
        "title": str(sub_name),
        "subject_name": str(sub_name),
        "code": body.get("code", f"SUB{new_id:03d}"),
        "professor": str(prof_name),
        "professor_name": str(prof_name),
        "instructor": str(prof_name),
        "time": str(time_slot),
        "lecture_time": str(time_slot),
        "schedule": str(time_slot),
        "time_slot": str(time_slot)
    }
    
    SUBJECTS_DB.append(new_subject)
    LECTURES_DB[new_id] = []
        
    print(f"✅ [과목 추가 완료]: ID={new_id} | 과목명={sub_name} | 교수님={prof_name} | 시간={time_slot}")
    return new_subject


# 3-1. 과목 삭제 API
@app.delete("/subjects/{subject_id}")
@app.delete("/api/subjects/{subject_id}")
def delete_subject(subject_id: int):
    global SUBJECTS_DB, LECTURES_DB
    
    target_sub = find_subject_by_id(subject_id)
    if not target_sub:
        raise HTTPException(status_code=404, detail="해당 과목을 찾을 수 없습니다.")
    
    SUBJECTS_DB = [sub for sub in SUBJECTS_DB if sub["id"] != subject_id]
    
    if subject_id in LECTURES_DB:
        del LECTURES_DB[subject_id]
        
    print(f"🗑️ [과목 삭제 완료]: ID={subject_id}")
    return {"status": "success", "message": "과목이 삭제되었습니다.", "deleted_id": subject_id}


# 과목 정보 수정 API
@app.put("/subjects/{subject_id}")
@app.put("/api/subjects/{subject_id}")
def update_subject(subject_id: int, payload: SubjectUpdatePayload):
    target_sub = find_subject_by_id(subject_id)
    if not target_sub:
        raise HTTPException(status_code=404, detail="해당 과목을 찾을 수 없습니다.")

    new_title = payload.title.strip() if payload.title else target_sub["title"]
    new_instructor = payload.instructor.strip() if payload.instructor else target_sub["instructor"]
    new_time_slot = payload.time_slot.strip() if payload.time_slot else target_sub["time_slot"]

    target_sub["title"] = new_title
    target_sub["name"] = new_title
    target_sub["subject_name"] = new_title
    target_sub["instructor"] = new_instructor
    target_sub["professor"] = new_instructor
    target_sub["professor_name"] = new_instructor
    target_sub["time_slot"] = new_time_slot
    target_sub["time"] = new_time_slot
    target_sub["schedule"] = new_time_slot

    if subject_id in LECTURES_DB:
        for lecture in LECTURES_DB[subject_id]:
            lecture["subject"] = new_title

    print(f"✏️ [과목 수정 완료]: ID={subject_id} | 새 과목명={new_title} | 교수님={new_instructor} | 시간={new_time_slot}")
    return {
        "status": "success",
        "message": "과목 정보가 수정되었습니다.",
        "subject": target_sub
    }


# 4. 특정 과목의 AI 강의 노트 목록 조회 API
@app.get("/subjects/{subject_id}/lectures")
@app.get("/api/subjects/{subject_id}/lectures")
@app.get("/lectures/subject/{subject_id}")
@app.get("/api/lectures/subject/{subject_id}")
def get_lectures_by_subject(subject_id: int):
    notes = LECTURES_DB.get(subject_id, [])
    return notes


# 4-1. 강의 노트 제목 수정 API
@app.patch("/lectures/{lecture_id}")
@app.patch("/api/lectures/{lecture_id}")
@app.put("/lectures/{lecture_id}")
@app.put("/api/lectures/{lecture_id}")
def update_lecture_title(lecture_id: int, payload: TitleUpdatePayload):
    new_title = payload.title.strip()
    if not new_title:
        raise HTTPException(status_code=400, detail="제목을 입력해야 합니다.")

    found = False
    for sub_id, lecture_list in LECTURES_DB.items():
        for lecture in lecture_list:
            if str(lecture.get("id")) == str(lecture_id):
                lecture["title"] = new_title
                lecture["lecture_title"] = new_title
                lecture["filename"] = new_title
                found = True
                break
        if found:
            break

    if not found:
        raise HTTPException(status_code=404, detail=f"ID가 {lecture_id}인 강의 노트를 찾지 못했습니다.")

    print(f"✏️ [노트 제목 변경 성공]: ID={lecture_id} -> 새 제목='{new_title}'")
    return {
        "status": "success",
        "message": "노트 제목이 수정되었습니다.",
        "id": lecture_id,
        "title": new_title
    }


# 4-2. 강의 노트 삭제 API
@app.delete("/lectures/{lecture_id}")
@app.delete("/api/lectures/{lecture_id}")
def delete_lecture_note(lecture_id: int):
    deleted = False
    
    for sub_id, lecture_list in LECTURES_DB.items():
        initial_len = len(lecture_list)
        LECTURES_DB[sub_id] = [lec for lec in lecture_list if str(lec.get("id")) != str(lecture_id)]
        
        if len(LECTURES_DB[sub_id]) < initial_len:
            deleted = True
            break

    if not deleted:
        raise HTTPException(status_code=404, detail=f"ID가 {lecture_id}인 강의 노트를 찾을 수 없습니다.")

    print(f"🗑️ [노트 삭제 완료]: ID={lecture_id}")
    return {
        "status": "success",
        "message": "노트가 삭제되었습니다.",
        "deleted_id": lecture_id
    }


# 5. 음성 파일 / 실시간 녹음 통합 업로드 엔드포인트
@app.api_route("/lectures/upload", methods=["POST", "PUT"])
@app.api_route("/api/lectures/upload", methods=["POST", "PUT"])
@app.api_route("/upload", methods=["POST", "PUT"])
@app.api_route("/api/upload", methods=["POST", "PUT"])
async def handle_audio_upload_universal(
    request: Request,
    file: Optional[UploadFile] = File(None),
    audio: Optional[UploadFile] = File(None),
    subject_id: Optional[str] = Form(None),
    subject: Optional[str] = Form(None)
):
    global GLOBAL_LECTURE_ID_COUNTER
    try:
        target_file = file or audio
        raw_sub_id = subject_id or subject or "1"
        
        try:
            target_sub_id = int(raw_sub_id)
        except ValueError:
            target_sub_id = 1

        sub_obj = find_subject_by_id(target_sub_id)
        selected_subject_name = sub_obj["title"] if sub_obj else "기본 과목"

        file_name = target_file.filename if target_file else f"lecture_{datetime.now().strftime('%m%d_%H%M')}.m4a"

        # 1. 파일 데이터 읽기
        audio_bytes = b""
        if target_file:
            audio_bytes = await target_file.read()

        # 🔊 1-1. 음성 전처리 (20MB 초과 대용량 시 비동기 스레드로 전처리 실행)
        if audio_bytes and len(audio_bytes) > 20 * 1024 * 1024:
            print(f"🔊 [음성 전처리 시작]: {file_name} 대용량 파일 감지 및 자동 압축/증폭 적용 중...")
            audio_bytes = await asyncio.to_thread(process_audio_volume, audio_bytes, -16.0)

        # 2. 비동기 Whisper STT 실행
        stt_transcript = ""
        if audio_bytes:
            stt_transcript = await stt_service.transcribe_audio_bytes_async(audio_bytes, file_name)

        if not stt_transcript.strip():
            stt_transcript = "음성 파일에서 텍스트를 추출하지 못했습니다."

        print(f"🎙️ [STT 추출 완료]: {stt_transcript[:50]}...")

        # 3. AI 요약 서비스 실행 (동기 함수이므로 별도 스레드에서 실행)
        ai_result = await asyncio.to_thread(
            summary_service.generate_lecture_summary,
            selected_subject_name, file_name, stt_transcript
        )

        parsed_data = {}
        if ai_result.get("status") == "success" and "raw_response" in ai_result:
            raw_text = ai_result["raw_response"]
            clean_json = re.sub(r"```json|```", "", raw_text).strip()
            try:
                parsed_data = json.loads(clean_json)
            except Exception:
                parsed_data = {}

        summary_text = parsed_data.get("summary", "강의 요약 내용을 성공적으로 생성했습니다.")
        keywords = parsed_data.get("key_concepts") or parsed_data.get("keywords") or ["강의 핵심", "AI 요약"]
        raw_quizzes = parsed_data.get("quiz_questions") or parsed_data.get("quiz") or parsed_data.get("quizzes") or []

# 퀴즈 데이터 포맷팅 (summary.py의 새 JSON 구조 완벽 대응)
        formatted_quizzes = []
        if isinstance(raw_quizzes, list):
            for idx, item in enumerate(raw_quizzes):
                if isinstance(item, dict):
                    q_text = item.get("question", "강의 관련 퀴즈")
                    raw_opts = item.get("options") or item.get("choices") or []
                    
                    # LLM이 생성한 보기 4개가 정상 존재할 경우 사용
                    if isinstance(raw_opts, list) and len(raw_opts) >= 2:
                        opts = [str(o) for o in raw_opts]
                    else:
                        a_text = str(item.get("answer", "정답"))
                        opts = [a_text, "해당하지 않는 내용", "잘못된 개념 설명", "언급되지 않은 조건"]

                    # 정답 인덱스 파싱 (answer_index 숫자가 반환되면 최우선 사용)
                    correct_idx = item.get("answer_index")
                    if correct_idx is None or not isinstance(correct_idx, int):
                        a_text = str(item.get("answer", ""))
                        try:
                            correct_idx = opts.index(a_text)
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

        # 4. AI 강의 노트 최상위 객체 구성
        created_date = datetime.now().strftime("%Y-%m-%d %H:%M")
        
        note_id = GLOBAL_LECTURE_ID_COUNTER
        GLOBAL_LECTURE_ID_COUNTER += 1
        
        payload_data = {
            "id": note_id,
            "subject_id": target_sub_id,
            "subject": selected_subject_name,
            "lecture_title": file_name,
            "title": file_name,
            "filename": file_name,
            "created_at": created_date,
            "date": created_date,
            "transcript": stt_transcript,
            "stt_transcript": stt_transcript,
            "stt_text": stt_transcript,
            "summary": summary_text,
            "keywords": keywords,
            "key_concepts": keywords,
            "quiz": formatted_quizzes,
            "quizzes": formatted_quizzes,
            "quiz_questions": formatted_quizzes
        }

        # 5. 과목 ID별 DB에 추가
        if target_sub_id not in LECTURES_DB:
            LECTURES_DB[target_sub_id] = []
        LECTURES_DB[target_sub_id].insert(0, payload_data)

        # 6. 완성된 요약 텍스트 및 STT 데이터를 포함하여 Vector DB 저장
        try:
            chunks_stored = await asyncio.to_thread(
                embedder.process_and_store_lecture,
                selected_subject_name,
                file_name,
                stt_transcript,
                summary_text
            )
            print(f"🧠 [Vector DB 인덱싱 완료]: 노트 ID={note_id} | 과목={selected_subject_name} | {chunks_stored}개 Chunk 저장")
        except Exception as vec_err:
            print(f"⚠️ [Vector DB 인덱싱 실패]: {vec_err}")

        print(f"🎉 [노트 저장 성공]: 노트 ID={note_id} | 과목 ID={target_sub_id} ({selected_subject_name}) | 총 {len(LECTURES_DB[target_sub_id])}개 누적됨")

        response_body = {
            "status": "success",
            "message": f"'{file_name}' 분석이 완료되었습니다.",
            **payload_data
        }
        return response_body

    except Exception as e:
        print(f"❌ Upload handling error: {e}")
        raise HTTPException(status_code=500, detail=str(e))