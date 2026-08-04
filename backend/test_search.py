from src.rag.vector_store import VectorDBManager
from src.rag.search import LectureSearchService

def run_24day_test():
    db_manager = VectorDBManager()
    search_service = LectureSearchService(db_manager)

    subject = "AI_Engineering"
    
    # 1. 테스트 질문 입력
    queries = [
        "경사하강법이 뭐야?",
        "신경망 가중치는 어떻게 업데이트해?"
    ]

    for q in queries:
        print(f"\n🔍 질문: '{q}'")
        results = search_service.search_lecture_notes(subject, q, top_k=2)
        
        if not results:
            print("검색 결과가 없습니다.")
            continue

        for res in results:
            print(f"  [{res['rank']}위] 내용: {res['content']}")
            print(f"       메타데이터: {res['metadata']}")

if __name__ == "__main__":
    run_24day_test()