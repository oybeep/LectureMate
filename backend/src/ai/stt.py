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

    async def _transcribe_chunk(self, chunk_bytes: bytes, idx: int) -> str:
        try:
            audio_file = (f"chunk_{idx}.mp3", chunk_bytes, "audio/mp3")
            response = await self.client.audio.transcriptions.create(
                model="whisper-1",
                file=audio_file,
                language="ko",
                prompt="대학 전공 강의 내용입니다. 전문 용어와 개념 설명이 포함되어 있습니다."
            )
            return response.text
        except Exception as e:
            print(f"⚠️ [STT] Chunk #{idx} 변환 실패: {e}")
            return ""

    async def transcribe_audio_bytes_async(self, audio_bytes: bytes, filename: str = "temp_audio.wav") -> str:
        if not audio_bytes:
            return ""

        try:
            # 1. 오디오 로드
            audio = AudioSegment.from_file(io.BytesIO(audio_bytes))

            # 2. 15분(900,000ms) 단위 분할 (API 호출 횟수 감축으로 속도 향상)
            chunk_length_ms = 15 * 60 * 1000
            tasks = []

            for i, start_ms in enumerate(range(0, len(audio), chunk_length_ms)):
                chunk = audio[start_ms : start_ms + chunk_length_ms]
                
                buffer = io.BytesIO()
                # fast-export: 이미 모노/샘플레이트 조정된 데이터를 빠르게 추출
                chunk.export(buffer, format="mp3", bitrate="64k")
                
                # 생성 직후 곧바로 비동기 태스크에 등록
                tasks.append(self._transcribe_chunk(buffer.getvalue(), i))

            print(f"⚡ [STT] 총 {len(tasks)}개 조각 병렬 변환 시작")

            # 3. 비동기 동시 처리
            results = await asyncio.gather(*tasks)
            full_text = " ".join(results)

            # 4. 환각/반복 도배 텍스트 즉시 정규식 보정
            cleaned_text = re.sub(r'(\w)\1{4,}', r'\1', full_text)
            cleaned_text = re.sub(r'(\b\w+\b)( \1){3,}', r'\1', cleaned_text)

            return cleaned_text.strip()

        except Exception as e:
            print(f"❌ [STT] 대용량 비동기 STT 변환 실패: {e}")
            return ""