from fastapi import FastAPI, UploadFile, File
from typing import List
from schemas import Subject, SubjectCreate, LectureSummaryResponse, QueryRequest, QueryResponse

app = FastAPI(title="Lecture Agent API")

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

# 3. AI 강의 검색 & 타임스탬프 질의
@app.post("/lectures/search", response_model=QueryResponse)
def search_lecture(query: QueryRequest):
    # 테스트용 임시 응답
    return {
        "answer": "해당 강의 34분 20초 부분에서 설명된 내용입니다.",
        "timestamp": "00:34:20"
    }