import requests
import wave

intro = "Hi, I’m zhangliang. I love oranges and enjoy the outdoors"
avatar_id = "Zhang075-1925967372432748545"
voice_id = "Zhang075-1925967372432748545"
audio_path = "audio.wav"


# 非流式
req = {
    'text': intro,
    'reference_id': voice_id,
    'format': 'wav',
    'streaming': False,
    'use_memory_cache': 'on',
    "seed": 1
}
try:
    res = requests.post(
        "http://3.236.225.202:7860/v1/tts",
        json=req,
        headers={"content-type": "application/json"},
    )
    res.raise_for_status()
    with open(audio_path, "wb") as f:
        f.write(res.content)
    print("save audio done.")
except Exception as e:
    print(f"save audio failed: {e}")
    raise


# 流式
req = {
    'text': intro,
    'reference_id': voice_id,
    'format': 'wav',  # 虽然填了 wav，但服务返回的是 raw PCM
    'streaming': True,
    'use_memory_cache': 'on',
    "seed": 1
}

url = "http://3.236.225.202:7860/v1/tts"
audio_path = "audio_stream.wav"
# 假设的音频参数（必须跟服务端一致）
sample_rate = 44100
num_channels = 1
sample_width = 2  # 16-bit = 2 bytes

try:
    res = requests.post(url, json=req, stream=True)
    res.raise_for_status()

    pcm_data = bytearray()
    for chunk in res.iter_content(chunk_size=4096):
        if chunk:
            pcm_data.extend(chunk)

    # 写入带头的合法 WAV 文件
    with wave.open(audio_path, 'wb') as wf:
        wf.setnchannels(num_channels)
        wf.setsampwidth(sample_width)
        wf.setframerate(sample_rate)
        wf.writeframes(pcm_data)

    print("Audio saved with WAV header successfully.")

except Exception as e:
    print(f"Error: {e}")