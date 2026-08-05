from src.rag.vector_store import VectorDBManager
import uuid

class LectureNoteEmbedder:
    def __init__(self, db_manager: VectorDBManager):
        self.db_manager = db_manager

    def _split_text(self, text: str) -> list:
        """마침표(.) 단위로 분할하여 문장별 Chunk 생성"""
        raw_sentences = text.split(".")
        sentences = [s.strip() + "." for s in raw_sentences if s.strip()]
        return sentences if sentences else [text]

    def process_and_store_lecture(
        self, 
        subject: str, 
        lecture_title: str, 
        stt_transcript: str, 
        timestamps: list = None
    ):
        chunks = self._split_text(stt_transcript)
        
        ids = []
        documents = []
        metadatas = []

        for idx, chunk in enumerate(chunks):
            doc_id = f"{subject}_{lecture_title}_{uuid.uuid4().hex[:8]}"
            
            # 각 Chunk(문장)에 대응하는 타임스탬프 저장
            timestamp = timestamps[idx] if timestamps and idx < len(timestamps) else "00:00"

            ids.append(doc_id)
            documents.append(chunk)
            metadatas.append({
                "subject": subject,
                "lecture_title": lecture_title,
                "chunk_index": idx,
                "timestamp": timestamp
            })

        collection_name = f"lecture_{subject}".lower().replace(" ", "_")

        self.db_manager.add_documents(
            collection_name=collection_name,
            ids=ids,
            documents=documents,
            metadatas=metadatas
        )

        print(f"[{subject} - {lecture_title}] 총 {len(chunks)}개 Chunk 저장 완료!")
        return len(chunks)