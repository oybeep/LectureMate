import json
from sqlalchemy import Column, Integer, String, Text, ForeignKey, DateTime
from sqlalchemy.sql import func

# 💡 database.py에서 Base를 명시적으로 가져옵니다.
from database import Base


class Subject(Base):
    __tablename__ = "subjects"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    title = Column(String(255), nullable=False)
    instructor = Column(String(255), nullable=True, default="미지정")
    time_slot = Column(String(255), nullable=True, default="시간 미정")

    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Lecture(Base):
    __tablename__ = "lectures"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False)
    
    title = Column(String(255), nullable=False)
    stt_text = Column(Text, nullable=True)          # STT 원문
    summary = Column(Text, nullable=True)           # 3줄 핵심 요약
    
    detailed_summary_json = Column(Text, nullable=True)  # 상세 요약 리스트 (JSON)
    keywords_json = Column(Text, nullable=True)          # 키워드 리스트 (JSON)
    quiz_json = Column(Text, nullable=True)              # 퀴즈 객체 리스트 (JSON)
    
    cleaned_transcript = Column(Text, nullable=True)     # AI 가독성 정제본
    custom_note = Column(Text, nullable=True)            # 5대 AI 맞춤 정리노트

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    @property
    def detailed_summary(self):
        return json.loads(self.detailed_summary_json) if self.detailed_summary_json else []

    @detailed_summary.setter
    def detailed_summary(self, value):
        self.detailed_summary_json = json.dumps(value, ensure_ascii=False) if value else None

    @property
    def keywords(self):
        return json.loads(self.keywords_json) if self.keywords_json else []

    @keywords.setter
    def keywords(self, value):
        self.keywords_json = json.dumps(value, ensure_ascii=False) if value else None

    @property
    def quiz(self):
        return json.loads(self.quiz_json) if self.quiz_json else []

    @quiz.setter
    def quiz(self, value):
        self.quiz_json = json.dumps(value, ensure_ascii=False) if value else None