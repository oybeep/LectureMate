from src.rag.vector_store import VectorDBManager
from src.rag.embedding import LectureNoteEmbedder
from src.rag.search import LectureSearchService

def run_25day_test():
    db_manager = VectorDBManager()
    
    # 1. 이전 테스트용 데이터 컬렉션 초기화 (기존 오검색 데이터 삭제)
    collection_name = "lecture_ai_engineering"
    try:
        db_manager.client.delete_collection(name=collection_name)
        print("기존 테스트 데이터 초기화 완료!")
    except Exception:
        pass

    embedder = LectureNoteEmbedder(db_manager)
    search_service = LectureSearchService(db_manager)

    subject = "AI_Engineering"
    lecture_title = "Lesson_04_Optimization"

    # 테스트 문장 (2문장 -> 2개 Chunk 생성 예정)
    stt_transcript = (
        "학습률(Learning Rate)은 경사하강법에서 매개변수를 얼마나 크게 업데이트할지 결정하는 하이퍼파라미터입니다. "
        "모멘텀(Momentum) 기법은 기울기에 관성을 부여하여 오실레이션을 줄이고 빠르게 최적점에 도달하도록 돕습니다."
    )
    
    # 각 문장별 타임스탬프
    sample_timestamps = ["05:20", "12:45"]

    # 2. 새로운 데이터 저장
    embedder.process_and_store_lecture(
        subject=subject,
        lecture_title=lecture_title,
        stt_transcript=stt_transcript,
        timestamps=sample_timestamps
    )

    # 3. 타임스탬프 검색 실행
    query = "관성을 적용해서 빠르게 수렴하는 기법이 뭐야?"
    res = search_service.search_lecture_with_timestamp(subject, query)

    print("\n⏱️ [타임스탬프 검색 결과]")
    if res:
        print(f"질문: {query}")
        print(f"답변: {res['answer']}")
        print(f"타임스탬프: {res['timestamp']}")
        print(f"안내: {res['display_text']}")

if __name__ == "__main__":
    run_25day_test()