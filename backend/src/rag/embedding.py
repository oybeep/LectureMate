import uuid
import re
from src.rag.vector_store import VectorDBManager

class LectureNoteEmbedder:
    def __init__(self, db_manager: VectorDBManager):
        self.db_manager = db_manager

    def _split_text(self, text: str) -> list:
        """마침표(.) 및 줄바꿈 단위로 분할하여 문장별 Chunk 생성"""
        raw_sentences = text.replace("\n", ". ").split(".")
        sentences = [s.strip() + "." for s in raw_sentences if s.strip()]
        return sentences if sentences else [text]

    def _get_safe_collection_name(self, subject: str) -> str:
        """ChromaDB 규격에 맞는 안전한 collection 이름 생성 (영문/숫자/언더스코어)"""
        clean_subject = re.sub(r'[^a-zA-Z0-9]', '_', subject)
        clean_subject = clean_subject.strip('_')
        if not clean_subject:
            clean_subject = "common"
        return f"lecture_{clean_subject}".lower()

    def process_and_store_lecture(
        self, 
        subject: str, 
        lecture_title: str, 
        stt_transcript: str, 
        timestamps: list = None,
        summary: str = None
    ):
        chunks = self._split_text(stt_transcript)
        
        # 요약본이 있으면 검색 정확도를 높이기 위해 첫번째 Chunk로 추가
        if summary:
            chunks.insert(0, f"[강의 핵심 요약] {summary}")

        ids = []
        documents = []
        metadatas = []

        for idx, chunk in enumerate(chunks):
            doc_id = f"{subject}_{lecture_title}_{uuid.uuid4().hex[:8]}"
            
            if summary and idx == 0:
                timestamp = "00:00"
            else:
                ts_idx = idx - 1 if summary else idx
                timestamp = timestamps[ts_idx] if timestamps and ts_idx < len(timestamps) else "00:00"

            ids.append(doc_id)
            documents.append(chunk)
            metadatas.append({
                "subject": subject,
                "lecture_title": lecture_title,
                "chunk_index": idx,
                "timestamp": timestamp
            })

        # 안전한 Collection 이름 생성
        collection_name = self._get_safe_collection_name(subject)

        self.db_manager.add_documents(
            collection_name=collection_name,
            ids=ids,
            documents=documents,
            metadatas=metadatas
        )

        print(f"[{subject} - {lecture_title}] 총 {len(chunks)}개 Chunk가 Collection '{collection_name}'에 저장 완료!")
        return len(chunks)