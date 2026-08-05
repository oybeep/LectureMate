from datetime import datetime, timedelta

class ReviewRecommendationService:
    def __init__(self):
        pass

    def calculate_priority_score(self, last_studied_days_ago: int, review_count: int) -> float:
        """
        망각 곡선 원리 적용:
        - 경과 일수(last_studied_days_ago)가 길수록 우선순위 상승
        - 복습 횟수(review_count)가 많을수록 망각 속도가 느려지므로 우선순위 약간 감소
        """
        base_score = last_studied_days_ago * 1.5
        retention_factor = 1.0 / (review_count + 1)
        return round(base_score + (retention_factor * 10), 2)

    def get_review_recommendations(self, user_study_data: list):
        """
        학습 기록 데이터를 바탕으로 복습 우선순위 리스트 반환
        """
        recommendations = []

        for item in user_study_data:
            subject = item.get("subject")
            lecture_title = item.get("lecture_title")
            days_ago = item.get("days_ago", 0)
            review_count = item.get("review_count", 0)

            score = self.calculate_priority_score(days_ago, review_count)

            # 복습 추천 이유 및 상태 메시지 생성
            if days_ago >= 7:
                status = "URGENT"
                message = f"수강한 지 {days_ago}일이 지났습니다. 장기 기억 전환을 위해 오늘 복습을 권장합니다!"
            elif days_ago >= 3:
                status = "RECOMMENDED"
                message = f"3일 이상 지난 내용입니다. 핵심 개념 위주로 가볍게 훑어보세요."
            else:
                status = "GOOD"
                message = f"최근에 학습한 내용입니다. 주기적인 복습 상태가 양호합니다."

            recommendations.append({
                "subject": subject,
                "lecture_title": lecture_title,
                "days_ago": days_ago,
                "review_count": review_count,
                "priority_score": score,
                "status": status,
                "message": message
            })

        # Priority Score 기준 내림차순 정렬 (높은 점수 = 복습 시급)
        recommendations.sort(key=lambda x: x["priority_score"], reverse=True)
        return recommendations