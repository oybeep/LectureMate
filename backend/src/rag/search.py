from src.rag.vector_store import VectorDBManager

class LectureSearchService:
    def __init__(self, db_manager: VectorDBManager):
        self.db_manager = db_manager

    def search_lecture_notes(self, subject: str, query: str, top_k: int = 3):
        """
        자연어 질문으로 Vector DB에서 관련 강의 노트 Top-K를 검색합니다.
        """
        collection_name = f"lecture_{subject}".lower().replace(" ", "_")
        
        try:
            results = self.db_manager.query_similar(
                collection_name=collection_name,
                query_text=query,
                n_results=top_k
            )
            
            search_results = []
            if results and results.get("documents"):
                documents = results["documents"][0]
                metadatas = results["metadatas"][0]
                
                for idx, doc in enumerate(documents):
                    search_results.append({
                        "rank": idx + 1,
                        "content": doc,
                        "metadata": metadatas[idx]
                    })
                    
            return search_results

        except Exception as e:
            print(f"검색 중 오류 발생: {e}")
            return []