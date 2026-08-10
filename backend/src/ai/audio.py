import io
from pydub import AudioSegment

def process_audio_volume(audio_bytes: bytes, target_dbfs: float = -16.0) -> bytes:
    """
    1. Mono(1채널) 변환 및 16kHz 다운샘플링 (속도 및 STT 정확도 향상)
    2. 음량 자동 증폭 (target_dbfs)
    3. OpenAI 25MB 제한 통과를 위해 24MB 이하가 될 때까지 자동 압축 (64k -> 32k -> 16k)
    """
    if not audio_bytes:
        return audio_bytes

    try:
        # 오디오 로드
        audio = AudioSegment.from_file(io.BytesIO(audio_bytes))

        # 1. 속도 최적화: 모노(1채널) 및 16kHz 샘플링 레이트 변환
        audio = audio.set_channels(1).set_frame_rate(16000)

        # 2. 음량 증폭 (dBFS)
        current_dbfs = audio.dBFS
        gain_change = target_dbfs - current_dbfs
        gain_change = min(gain_change, 30.0)  # 과도한 노이즈 증폭 방지
        normalized_audio = audio.apply_gain(gain_change)

        # 3. OpenAI Whisper 제한 용량 (25MB = 26,214,400 bytes)
        # 안전선: 24MB (25,165,824 bytes)
        MAX_SAFE_BYTES = 24 * 1024 * 1024 

        # 비트레이트 시도 리스트 (높은 음질부터 단계별로 시도)
        bitrates = ["64k", "32k", "24k", "16k"]
        result_bytes = b""

        for br in bitrates:
            output_buffer = io.BytesIO()
            normalized_audio.export(
                output_buffer, 
                format="mp3", 
                bitrate=br,
                parameters=["-ac", "1"] # 모노 강제
            )
            result_bytes = output_buffer.getvalue()
            
            # 24MB 이하로 맞춰지면 루프 탈출
            if len(result_bytes) <= MAX_SAFE_BYTES:
                print(f"⚡ [audio.py] 전처리 및 압축 완료 (Bitrate: {br}): 크기 {len(result_bytes) / (1024*1024):.2f}MB")
                break
        else:
            print(f"⚠️ [audio.py] 최저 비트레이트(16k)로 압축 후 크기: {len(result_bytes) / (1024*1024):.2f}MB")

        return result_bytes

    except Exception as e:
        print(f"⚠️ [audio.py] 음성 전처리 중 오류 발생: {e}")
        return audio_bytes