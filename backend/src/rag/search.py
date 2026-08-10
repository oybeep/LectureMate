import os
import re
from pathlib import Path
from dotenv import load_dotenv
from openai import OpenAI
from src.rag.vector_store import VectorDBManager

env_path = Path(__file__).resolve().parent.parent.parent / ".env"
load_dotenv(dotenv_path=env_path)

class LectureSearchService:
    def __init__(self, db_manager: VectorDBManager):
        self.db_manager = db_manager
        api_key = os.getenv("OPENAI_API_KEY")
        if api_key:
            self.client = OpenAI(api_key=api_key)
        else:
            self.client = None

    def _get_safe_collection_name(self, subject: str) -> str:
        """embedding.py와 동일한 규격의 collection 이름 생성"""
        clean_subject = re.sub(r'[^a-zA-Z0-9]', '_', subject)
        clean_subject = clean_subject.strip('_')
        if not clean_subject:
            clean_subject = "common"
        return f"lecture_{clean_subject}".lower()

    def search_lecture_with_timestamp(self, subject: str, query: str, top_k: int = 5):
        """질문과 관련된 강의 내용을 Vector DB에서 검색한 뒤 GPT로 답변 생성"""
        collection_names_to_try = []
        if subject:
            collection_names_to_try.append(self._get_safe_collection_name(subject))
            collection_names_to_try.append(f"lecture_{subject}".lower().replace(" ", "_"))
        else:
            # 전체 과목 검색 시 기본 collections 탐색 (필요 시 수정)
            collection_names_to_try.append("lecture_common")

        results = None
        for col_name in collection_names_to_try:
            try:
                # 💡 top_k를 기존 3에서 5로 늘려 검색 범위를 확대
                results = self.db_manager.query_similar(
                    collection_name=col_name,
                    query_text=query,
                    n_results=top_k
                )
                if results and results.get("documents") and results["documents"][0]:
                    break
            except Exception:
                continue

        # 검색 결과가 아예 없는 경우
        if not results or not results.get("documents") or not results["documents"][0]:
            return {
                "answer": "저장된 강의 노트 및 STT 기록에서 질문과 관련된 내용을 찾을 수 없습니다.",
                "lecture_title": None,
                "display_text": "저장된 강의 노트 및 STT 기록에서 관련 내용을 찾지 못했습니다."
            }

        docs = results["documents"][0]
        metas = results["metadatas"][0]

        # Context 구성 및 대표 강의 제목 추출
        context_lines = []
        for doc in docs:
            context_lines.append(f"- {doc}")

        lecture_title = metas[0].get("lecture_title", "강의 노트")
        context_text = "\n".join(context_lines)

        # GPT 답변 생성
        if self.client:
            try:
                # 💡 프롬프트를 '강의 노트 맥락 최우선 해석' 방식으로 강화
                system_prompt = (
                    f"당신은 '{subject if subject else '수강 과목'}'의 AI 학습 보조 시스템입니다.\n\n"
                    "[답변 지침]\n"
                    "1. 아래 제공된 [강의 내용 및 요약 노트]에 적힌 내용을 최우선으로 사용하여 학생의 질문에 답변하세요.\n"
                    "2. 키워드나 개념이 정확히 일치하지 않더라도, 강의 요약이나 문맥상 의미가 통하면 해당 맥락을 바탕으로 정확히 설명해 주세요.\n"
                    "3. [강의 내용 및 요약 노트]에서 언급된 개념이라면 절대 '언급이 없다'고 말하지 마세요."
                )
                user_prompt = f"[강의 내용 및 요약 노트]\n{context_text}\n\n[학생 질문]\n{query}"

                response = self.client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt}
                    ],
                    temperature=0.2  # 💡 환각 방지를 위해 0.2로 낮춤
                )
                generated_answer = response.choices[0].message.content
            except Exception as e:
                print(f"GPT 답변 생성 실패: {e}")
                generated_answer = f"관련 강의 내용을 찾았습니다: {docs[0]}"
        else:
            generated_answer = docs[0]

        return {
            "answer": generated_answer,
            "lecture_title": lecture_title,
            "display_text": f"[{lecture_title}] 강의 기록을 바탕으로 작성된 답변입니다."
        }