#!/usr/bin/env python3
import json
import os
import time
import requests

BASE_URL = f"http://127.0.0.1:{os.getenv('LITELLM_PORT', '4000')}/v1/chat/completions"
MODELS = [
    "chat_fast",
    "chat_balanced",
    "reasoning_deep",
    "coding_primary",
    "coding_fast",
    "summary_economy",
]

PROMPTS = {
    "chat_fast": "用一句话介绍你自己。",
    "chat_balanced": "请用三点总结 LiteLLM 的作用。",
    "reasoning_deep": "比较本地代理路由和直接调用多个 API 的优缺点，输出五点。",
    "coding_primary": "写一个 Python 函数，返回 1 到 n 中的质数列表。",
    "coding_fast": "写一个 bash 命令，统计当前目录下 .py 文件数量。",
    "summary_economy": "把这句话压缩成 8 个字：LiteLLM is a local model gateway."
}

def run_one(model):
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": PROMPTS[model]}],
        "temperature": 0.2,
        "max_tokens": 180,
    }
    t0 = time.time()
    r = requests.post(BASE_URL, json=payload, timeout=120)
    elapsed = time.time() - t0
    result = {
        "model": model,
        "status_code": r.status_code,
        "elapsed_sec": round(elapsed, 3),
        "ok": False,
    }
    try:
        data = r.json()
    except Exception:
        result["error"] = r.text[:500]
        return result

    if r.status_code != 200:
        result["error"] = json.dumps(data)[:500]
        return result

    usage = data.get("usage", {}) or {}
    total_tokens = usage.get("total_tokens")
    output_tokens = usage.get("completion_tokens")
    result["ok"] = True
    result["total_tokens"] = total_tokens
    result["completion_tokens"] = output_tokens
    result["approx_total_tok_per_sec"] = round(total_tokens / elapsed, 2) if total_tokens and elapsed > 0 else None
    result["approx_output_tok_per_sec"] = round(output_tokens / elapsed, 2) if output_tokens and elapsed > 0 else None
    try:
        result["preview"] = data["choices"][0]["message"]["content"][:120]
    except Exception:
        result["preview"] = "<no preview>"
    return result

def main():
    print("=== LiteLLM Bench ===")
    rows = [run_one(m) for m in MODELS]
    print(json.dumps(rows, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
