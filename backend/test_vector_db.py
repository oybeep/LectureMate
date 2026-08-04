from src.rag.vector_store import VectorDBManager

def run_test():
    db = VectorDBManager()
    collection_name = "test_lectures"

    print("--- 1. 강의 노트 데이터 저장 (Create) ---")
    sample_ids = ["doc1", "doc2"]
    sample_docs = [
        "경사하강법(Gradient Descent)은 손실 함수를 최소화하기 위해 모델의 매개변수를 반복적으로 조정하는 최적화 알고리즘입니다.",
        "RAG(Retrieval-Augmented Generation) 시스템은 외부 지식베이스를 검색하여 LLM의 생성 정확도를 높여줍니다."
    ]
    sample_metadatas = [
        {"subject": "머신러닝기초", "timestamp": "05:20"},
        {"subject": "인공지능특론", "timestamp": "12:10"}
    ]
    
    db.add_documents(collection_name, sample_ids, sample_docs, sample_metadatas)
    print("저장 완료!")

    print("\n--- 2. 유사도 검색 (Read) ---")
    query = "파라미터 최적화하는 방법"
    search_results = db.query_similar(collection_name, query, n_results=1)
    print(f"질문: '{query}'")
    print(f"검색 결과: {search_results['documents'][0][0]}")
    print(f"메타데이터: {search_results['metadatas'][0][0]}")

    print("\n--- 3. 데이터 삭제 (Delete) ---")
    db.delete_document(collection_name, "doc1")
    print("doc1 삭제 완료")

if __name__ == "__main__":
    run_test()