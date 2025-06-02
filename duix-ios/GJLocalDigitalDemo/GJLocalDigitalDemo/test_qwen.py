import requests
import json

api_key = "sk-b590c8399ade4b6d9af342d091fb3869"
url = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"

headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json"
}

payload = {
    "model": "qwen2.5-0.5b-instruct",
    "messages": [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "你是谁？"}
    ],
    "stream": True
}


buffer = ""
with requests.post(url, headers=headers, json=payload, stream=True) as response:
    if response.status_code == 200:
        for line in response.iter_lines():
            if line:
                try:
                    line_str = line.decode('utf-8').strip()
                    if line_str.startswith("data: "):
                        line_str = line_str[len("data: "):]
                    if line_str == "[DONE]":
                        break  # 正常结束

                    data = json.loads(line_str)
                    delta = data.get("choices", [{}])[0].get("delta", {})
                    content = delta.get("content")
                    for i, chunk in enumerate(content):
                        buffer += chunk
                        if chunk in "，。！？" and len(buffer) > 10:
                            print(buffer)
                            # tts(buffer)  # 触发 TTS 合成调用，伪代码
                            buffer = ""
                except Exception as e:
                    print(f"\n[解析异常]: {e}")
    else:
        print(f"请求失败，状态码: {response.status_code}")
        print(response.text)


# 最后加上这个
if buffer.strip():
    # tts(buffer)  # 触发 TTS 合成调用，伪代码
    pass