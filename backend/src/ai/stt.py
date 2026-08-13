import os
import io
import re
import asyncio
from typing import List
from dotenv import load_dotenv
from openai import AsyncOpenAI
from pydub import AudioSegment

load_dotenv()


class STTService:
    def __init__(self):
        api_key = os.getenv("OPENAI_API_KEY")
        self.client = AsyncOpenAI(api_key=api_key)

    def _format_timestamp(self, seconds: float) -> str:
        """초 단위 시간을 [MM:SS] 형식의 문자열로 변환"""
        mins = int(seconds // 60)
        secs = int(seconds % 60)
        return f"[{mins:02d}:{secs:02d}]"

    def _clean_hallucinations(self, text: str) -> str:
        """단어/구 단위 반복 및 자모/문자 도배 환각 정제"""
        if not text:
            return ""
        # 1. 2~40글자 길이의 어구/문장이 연속 반복되는 경우 1회만 남김 (예: "문재인 대통령님. 문재인 대통령님.")
        text = re.sub(r'(.{2,40}?)(?:\s*\1){2,}', r'\1', text)
        # 2. 단일 단어 반복 제거 (예: "안녕 안녕 안녕")
        text = re.sub(r'(\b\w+\b)(?:\s+\1){2,}', r'\1', text)
        # 3. 동일 문자 4회 이상 연속 나열 축소 (예: "ㅋㅋㅋㅋㅋ" -> "ㅋ")
        text = re.sub(r'(\w)\1{3,}', r'\1', text)
        # 4. 알파벳/특수문자 나열 환각 제거
        text = re.sub(r'([A-Za-z],\s*){4,}', '', text)
        return text.strip()

    async def _transcribe_chunk(self, chunk_bytes: bytes, idx: int, time_offset_sec: float) -> str:
        """개별 오디오 청크를 전사하고 무음 환각을 필터링하여 30초 단위 문단 구성"""
        try:
            audio_file = (f"chunk_{idx}.mp3", chunk_bytes, "audio/mp3")

            # 특정 과목에 국한되지 않는 범용 표준 강의 맥락 프롬프트
            lecture_context_prompt = (
                "이 녹음은 대학교 수업 강의입니다. "
                "교수님의 이론 설명과 질의응답 내용이 포함되어 있습니다. "
                "표준어와 맞춤법에 맞춰 정확하게 기록합니다."
            )

            response = await self.client.audio.transcriptions.create(
                model="whisper-1",
                file=audio_file,
                language="ko",
                prompt=lecture_context_prompt,
                response_format="verbose_json",
                temperature=0.0
            )

            if hasattr(response, 'segments') and response.segments:
                formatted_paragraphs = []
                current_time_str = ""
                current_buffer = []
                last_start = -1.0

                for seg in response.segments:
                    no_speech_prob = getattr(seg, 'no_speech_prob', 0.0)
                    compression_ratio = getattr(seg, 'compression_ratio', 1.0)

                    # 무음 확률이 60% 이상이거나 비정상 반복 압축률(2.2 초과) 세그먼트 드롭
                    if no_speech_prob > 0.6 or compression_ratio > 2.2:
                        continue

                    actual_start = seg.start + time_offset_sec
                    raw_text = seg.text.strip()
                    cleaned_seg_text = self._clean_hallucinations(raw_text)

                    if not cleaned_seg_text:
                        continue

                    # 30초 간격으로 문단 분리
                    if last_start < 0 or (actual_start - last_start) >= 30.0:
                        if current_buffer:
                            paragraph = self._clean_hallucinations(' '.join(current_buffer))
                            if paragraph:
                                formatted_paragraphs.append(f"{current_time_str} {paragraph}")
                            current_buffer = []
                        current_time_str = self._format_timestamp(actual_start)
                        last_start = actual_start

                    current_buffer.append(cleaned_seg_text)

                if current_buffer:
                    paragraph = self._clean_hallucinations(' '.join(current_buffer))
                    if paragraph:
                        formatted_paragraphs.append(f"{current_time_str} {paragraph}")

                return "\n\n".join(formatted_paragraphs)

            # 세그먼트 정보가 없을 경우 fallback
            fallback_text = response.text if hasattr(response, 'text') else str(response)
            return self._clean_hallucinations(fallback_text)

        except Exception as e:
            print(f"⚠️ [STT] Chunk #{idx} 변환 실패: {e}")
            return ""

    async def transcribe_audio_bytes_async(self, audio_bytes: bytes, filename: str = "temp_audio.wav") -> str:
        """전체 오디오 바이트를 분할 처리하여 비동기 병렬 전사 수행"""
        if not audio_bytes:
            return ""

        try:
            # 1. 오디오 로드
            audio = AudioSegment.from_file(io.BytesIO(audio_bytes))

            # 2. 10분(600,000ms) 단위 분할
            chunk_length_ms = 10 * 60 * 1000
            tasks = []

            for i, start_ms in enumerate(range(0, len(audio), chunk_length_ms)):
                chunk = audio[start_ms : start_ms + chunk_length_ms]
                time_offset_sec = start_ms / 1000.0  # 누적 시작 시간(초)

                buffer = io.BytesIO()
                chunk.export(buffer, format="mp3", bitrate="64k")

                tasks.append(self._transcribe_chunk(buffer.getvalue(), i, time_offset_sec))

            print(f"⚡ [STT] 총 {len(tasks)}개 조각 병렬 변환 시작")

            # 3. 비동기 동시 처리
            results = await asyncio.gather(*tasks)
            full_text = "\n\n".join([res for res in results if res.strip()])

            # 4. 전체 텍스트 최종 환각 정제
            final_cleaned_text = self._clean_hallucinations(full_text)

            return final_cleaned_text

        except Exception as e:
            print(f"❌ [STT] 대용량 비동기 STT 변환 실패: {e}")
            return ""