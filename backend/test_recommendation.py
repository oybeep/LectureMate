from src.ai.recommendation import ReviewRecommendationService

def run_26day_test():
    service = ReviewRecommendationService()

    # 테스트용 가상 학습 기록
    sample_user_data = [
        {"subject": "인공지능공학", "lecture_title": "경사하강법과 최적화", "days_ago": 8, "review_count": 1},
        {"subject": "인공지능공학", "lecture_title": "모멘텀 및 손실함수", "days_ago": 1, "review_count": 2},
        {"subject": "데이터사이언스", "lecture_title": "데이터 전처리 기초", "days_ago": 4, "review_count": 0},
    ]

    recommendations = service.get_review_recommendations(sample_user_data)

    print("🧠 [AI 복습 추천 리스트]")
    for rank, rec in enumerate(recommendations, 1):
        print(f"\n{rank}순위: [{rec['subject']}] {rec['lecture_title']}")
        print(f" - 우선순위 점수: {rec['priority_score']}점 (상태: {rec['status']})")
        print(f" - AI 추천 메시지: {rec['message']}")

if __name__ == "__main__":
    run_26day_test()