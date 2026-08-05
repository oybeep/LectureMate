from fastapi import FastAPI, UploadFile, File, HTTPException
from typing import List
from schemas import Subject, SubjectCreate, LectureSummaryResponse, QueryRequest, QueryResponse
from fastapi.middleware.cors import CORSMiddleware

# RAG 관련 모듈 불러오기
from src.rag.vector_store import VectorDBManager
from src.rag.search import LectureSearchService
from src.ai.recommendation import ReviewRecommendationService

app = FastAPI(title="Lecture Agent API")

# Vector DB 및 검색 서비스 객체 초기화
db_manager = VectorDBManager()
search_service = LectureSearchService(db_manager)

# Flutter 통신 허용을 위한 CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health_check():
    return {"status": "ok", "message": "Lecture Agent Server Running"}

# 1. 과목 목록 조회 & 추가
@app.get("/subjects", response_model=List[Subject])
def get_subjects():
    # TODO: DB 연결 후 실제 데이터 반환
    return [{"id": 1, "title": "인공지능 개론", "instructor": "김교수", "time_slot": "월 10:00"}]

@app.post("/subjects", response_model=Subject)
def create_subject(subject: SubjectCreate):
    return {"id": 2, **subject.model_dump()}

# 2. 음성 파일 업로드 및 요약 요청
@app.post("/lectures/upload")
async def upload_audio(file: UploadFile = File(...)):
    return {"filename": file.filename, "status": "processing"}

# 3. AI 강의 검색 & 타임스탬프 질의 (RAG 연동)
@app.post("/lectures/search", response_model=QueryResponse)
def search_lecture(query: QueryRequest):
    """
    사용자의 질문(query.question 또는 query.query)과 과목(query.subject) 정보를 받아
    Vector DB에서 관련 강의 노트를 검색합니다.
    """
    # QueryRequest 스키마 필드명에 맞춰 추출 (subject 및 query/question 필드 대응)
    subject_name = getattr(query, "subject", "AI_Engineering")
    search_text = getattr(query, "query", getattr(query, "question", ""))

    if not search_text:
        raise HTTPException(status_code=400, detail="검색할 질문 내용을 입력해 주세요.")

    # Vector DB 유사도 검색 수행 (Top 1 추출)
    results = search_service.search_lecture_notes(
        subject=subject_name,
        query=search_text,
        top_k=1
    )

    if not results:
        return {
            "answer": "관련된 강의 내용을 찾을 수 없습니다.",
            "timestamp": "00:00:00"
        }

    top_result = results[0]
    matched_content = top_result["content"]
    matched_timestamp = top_result["metadata"].get("timestamp", "00:00:00")

    return {
        "answer": matched_content,
        "timestamp": matched_timestamp
    }

@app.get("/api/ai/review-recommendations")
def get_review_recommendations():
    """
    홈 화면 및 AI 복습 탭에 전달할 맞춤형 복습 추천 카드 데이터 반환
    """
    # 임시 사용자 학습 데이터 (추후 DB 연동)
    mock_user_history = [
        {"subject": "AI_Engineering", "lecture_title": "Lesson_03_Gradient_Descent", "days_ago": 8, "review_count": 1},
        {"subject": "AI_Engineering", "lecture_title": "Lesson_04_Optimization", "days_ago": 2, "review_count": 3},
        {"subject": "Data_Science", "lecture_title": "Lesson_01_Data_Preprocessing", "days_ago": 5, "review_count": 0},
    ]

    results = recommend_service.get_review_recommendations(mock_user_history)
    return {
        "status": "success",
        "recommendations": results
    }