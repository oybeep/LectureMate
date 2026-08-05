from src.rag.vector_store import VectorDBManager

class LectureSearchService:
    def __init__(self, db_manager: VectorDBManager):
        self.db_manager = db_manager

    def _format_timestamp(self, seconds: float) -> str:
        """초 단위 숫자를 'HH:MM:SS' 또는 'MM:SS' 형식 문장으로 변환"""
        hrs = int(seconds // 3600)
        mins = int((seconds % 3600) // 60)
        secs = int(seconds % 60)
        if hrs > 0:
            return f"{hrs:02d}:{mins:02d}:{secs:02d}"
        return f"{mins:02d}:{secs:02d}"

    def search_lecture_with_timestamp(self, subject: str, query: str, top_k: int = 1):
        """
        질문과 가장 유사한 강의 내용 및 타임스탬프 반환
        """
        collection_name = f"lecture_{subject}".lower().replace(" ", "_")
        
        try:
            results = self.db_manager.query_similar(
                collection_name=collection_name,
                query_text=query,
                n_results=top_k
            )
            
            if not results or not results.get("documents") or not results["documents"][0]:
                return None

            top_doc = results["documents"][0][0]
            top_meta = results["metadatas"][0][0]

            # 메타데이터에서 타임스탬프 정보 추출
            raw_timestamp = top_meta.get("timestamp", "00:00")
            lecture_title = top_meta.get("lecture_title", "강의 노트")

            return {
                "answer": f"[{lecture_title}] '{top_doc}'",
                "timestamp": raw_timestamp,
                "display_text": f"해당 개념은 강의 {raw_timestamp} 구간에서 설명되었습니다."
            }

        except Exception as e:
            print(f"타임스탬프 검색 오류: {e}")
            return None