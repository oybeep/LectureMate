from src.rag.vector_store import VectorDBManager
import uuid

class LectureNoteEmbedder:
    def __init__(self, db_manager: VectorDBManager, chunk_size: int = 300, overlap: int = 50):
        self.db_manager = db_manager
        self.chunk_size = chunk_size
        self.overlap = overlap

    def _split_text(self, text: str) -> list:
        """langchain 없이 텍스트를 일정 길이로 나누는 분할 로직"""
        chunks = []
        start = 0
        text_length = len(text)

        while start < text_length:
            end = start + self.chunk_size
            chunk = text[start:end]
            chunks.append(chunk)
            start += self.chunk_size - self.overlap

        return chunks

    def process_and_store_lecture(
        self, 
        subject: str, 
        lecture_title: str, 
        stt_transcript: str, 
        timestamps: list = None
    ):
        """
        STT 텍스트를 Chunk 단위로 분할하여 ChromaDB에 저장합니다.
        """
        # 1. 자체 텍스트 청킹
        chunks = self._split_text(stt_transcript)
        
        ids = []
        documents = []
        metadatas = []

        # 2. 메타데이터 구성 및 저장할 데이터 가공
        for idx, chunk in enumerate(chunks):
            doc_id = f"{subject}_{lecture_title}_{uuid.uuid4().hex[:8]}"
            
            # 임시 타임스탬프 매핑
            timestamp = timestamps[idx] if timestamps and idx < len(timestamps) else "00:00"

            ids.append(doc_id)
            documents.append(chunk)
            metadatas.append({
                "subject": subject,
                "lecture_title": lecture_title,
                "chunk_index": idx,
                "timestamp": timestamp
            })

        # 3. Collection 이름 산출
        collection_name = f"lecture_{subject}".lower().replace(" ", "_")

        # 4. Vector DB 저장
        self.db_manager.add_documents(
            collection_name=collection_name,
            ids=ids,
            documents=documents,
            metadatas=metadatas
        )

        print(f"[{subject} - {lecture_title}] 총 {len(chunks)}개 Chunk 저장 완료!")
        return len(chunks)