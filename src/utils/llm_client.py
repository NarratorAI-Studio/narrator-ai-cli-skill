import os
from openai import OpenAI

class XiakanLLMClient:
    def __init__(self):
        # OpenClaw 激活插件时，会自动把 settings 里的值注入到环境变量中
        self.api_key = os.getenv("LLM_API_KEY", "your-api-key-here")
        self.base_url = os.getenv("LLM_BASE_URL", "https://api.deepseek.com/v1")
        self.model = os.getenv("LLM_MODEL", "deepseek-chat")

        self.client = OpenAI(api_key=self.api_key, base_url=self.base_url)

    def ask(self, system: str, prompt: str) -> str:
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,
                presence_penalty=0.6,
            )
            return response.choices[0].message.content
        except Exception as e:
            print(f"[LLM Error] 调用失败: {e}")
            raise e

    def validate_connection(self) -> bool:
        """
        专门给 OpenClaw 安装时调用的 API 验证器
        """
        try:
            # 发送一个极其廉价和快速的请求来测活
            self.client.chat.completions.create(
                model=self.model,
                messages=[{"role": "user", "content": "ping"}],
                max_tokens=5
            )
            return True
        except Exception as e:
            print(f"❌ API 验证失败，请检查配置参数。错误信息: {e}")
            return False
