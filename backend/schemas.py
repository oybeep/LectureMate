from pydantic import BaseModel
from typing import List, Optional


# 1. 과목 관련 스키마
class SubjectBase(BaseModel):
    title: str
    instructor: Optional[str] = None
    time_slot: Optional[str] = None

class SubjectCreate(SubjectBase):
    pass

class Subject(SubjectBase):
    id: int

    class Config:
        from_attributes = True


# 2. [1단계] STT 전사 응답 스키마
class STTResponse(BaseModel):
    stt_text: str


# 3. [2단계] 온디맨드 AI 요약 요청/응답 스키마
class SummaryRequest(BaseModel):
    stt_text: str
    subject: Optional[str] = None

class LectureSummaryResponse(BaseModel):
    summary_3lines: List[str]
    key_concepts: List[str]
    lecture_id: Optional[int] = None
    title: Optional[str] = None


# 4. [3단계] 온디맨드 AI 노트 정리 요청/응답 스키마 (STT 원문으로 직접 생성)
class AINotesRequest(BaseModel):
    stt_text: str
    subject: Optional[str] = None

class AINotesResponse(BaseModel):
    notes: str  # 마크다운 형태의 구조화된 학습 노트


# 5. Q&A / 검색 스키마
class QueryRequest(BaseModel):
    question: str

class QueryResponse(BaseModel):
    answer: str
    timestamp: Optional[str] = None
