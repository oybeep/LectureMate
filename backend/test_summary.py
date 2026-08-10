from src.ai.summary import AISummaryService

def run_27day_test():
    service = AISummaryService()

    subject = "AI_Engineering"
    lecture_title = "Lesson_04_Optimization"
    stt_transcript = (
        "오늘 수업에서는 머신러닝 최적화 알고리즘을 배웠습니다. "
        "경사하강법은 손실함수의 기울기를 구해 파라미터를 업데이트하는 기본 기법입니다. "
        "학습률이 너무 크면 발산하고 너무 작으면 최적점에 도달하는 속도가 느립니다. "
        "모멘텀 기법은 기울기에 관성을 부여하여 오실레이션을 줄이고 수렴 속도를 높여줍니다."
    )

    print("🤖 OpenAI 기반 강의 요약 및 퀴즈 생성 중...")
    result = service.generate_lecture_summary(subject, lecture_title, stt_transcript)

    print("\n📝 [AI 생성 결과]")
    if result.get("status") == "success":
        print(result["raw_response"])
    else:
        print(f"실패 원인: {result.get('message')}")

if __name__ == "__main__":
    run_27day_test()