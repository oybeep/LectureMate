from pydantic import BaseModel
from typing import List, Optional

# 과목 관련 스키마
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

# 강의 요약 요청/응답 스키마
class LectureSummaryResponse(BaseModel):
    lecture_id: int
    title: str
    summary_3lines: List[str]
    key_concepts: List[str]

# Q&A / 검색 스키마
class QueryRequest(BaseModel):
    question: str

class QueryResponse(BaseModel):
    answer: str
    timestamp: Optional[str] = None