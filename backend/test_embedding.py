from src.rag.vector_store import VectorDBManager
from src.rag.embedding import LectureNoteEmbedder

def run_23day_test():
    db_manager = VectorDBManager()
    embedder = LectureNoteEmbedder(db_manager)

    # 샘플 STT 강의 노트 데이터
    sample_stt_text = (
        "오늘 수업에서는 머신러닝의 핵심 최적화 알고리즘인 경사하강법에 대해 알아보겠습니다. "
        "경사하강법은 손실 함수의 기울기를 구하여 매개변수를 반복적으로 업데이트하는 방식입니다. "
        "학습률이 너무 크면 발산할 수 있고, 너무 작으면 최적점에 도달하는 시간이 오래 걸립니다. "
        "다음으로 오차역전파법(Backpropagation)은 신경망의 가중치를 효율적으로 업데이트하기 위해 "
        "연쇄 법칙을 이용해 градиент를 전달하는 핵심 메커니즘입니다."
    )

    subject = "AI_Engineering"
    lecture_title = "Lesson_03_Gradient_Descent"

    # 임베딩 저장 실행
    stored_chunks = embedder.process_and_store_lecture(
        subject=subject,
        lecture_title=lecture_title,
        stt_transcript=sample_stt_text
    )

    print(f"\n성공적으로 {stored_chunks}개 단락 저장 완료!")

if __name__ == "__main__":
    run_23day_test()