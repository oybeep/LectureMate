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

# 6. 사용자 프로필 및 계정 관리 스키마
class UserProfileBase(BaseModel):
    name: str
    email: str

class UserProfileResponse(UserProfileBase):
    id: int

    class Config:
        from_attributes = True

class UserProfileUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None


# 7. 앱 설정 (AI & 학습 서비스 및 토글) 스키마
class AppSettingsBase(BaseModel):
    auto_summary_enabled: bool = True       # 녹음 완료 후 자동 AI 요약
    push_notification_enabled: bool = True  # 요약 완료 알림
    dark_mode_enabled: bool = False         # 다크 모드
    language: str = "ko"                    # 언어 설정 (ko, en 등)

class AppSettingsResponse(AppSettingsBase):
    id: int
    user_id: int

    class Config:
        from_attributes = True

class AppSettingsUpdate(BaseModel):
    auto_summary_enabled: Optional[bool] = None
    push_notification_enabled: Optional[bool] = None
    dark_mode_enabled: Optional[bool] = None
    language: Optional[str] = None

