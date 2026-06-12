import json
import os
from src.utils.fetcher import MovieDetailFetcher

class XiakanPipelineEngine:
    def __init__(self, llm_client):
        """
        llm_client 应当对齐您当前 github 仓库中已有的大模型调用实例（例如 OpenAI/Gemini 封装）
        """
        self.llm = llm_client
        self.skills_dir = "skills/xiakan"

    def _get_prompt(self, filename: str) -> str:
        with open(os.path.join(self.skills_dir, filename), "r", encoding="utf-8") as f:
            return json.load(f)["system_prompt"]

    def process_factory(self, title: str) -> list:
        # 1. 深度抓取
        context = MovieDetailFetcher().fetch_by_title(title)

        # 2. 链式调用 LLM (Chain of Thought)
        print("[Factory] ⚙️ 正在执行阶段 1：注入 [Character_Profiler] 转换人物...")
        char_prompt = self._get_prompt("character.json")
        characters = self.llm.ask(system=char_prompt, prompt=context) # 假设 ask 是您仓库里的基础方法

        print("[Factory] ⚙️ 正在执行阶段 2：注入 [Narrative_Subversion] 置换时空...")
        narrative_prompt = self._get_prompt("narrative.json")
        subverted_plot = self.llm.ask(system=narrative_prompt, prompt=f"原图景: {context}\n重构角色: {characters}")

        print("[Factory] ⚙️ 正在执行阶段 3：注入 [Deadpan_Linguistic] 雕刻冷面滑稽文本（进行文本3倍扩写）...")
        deadpan_prompt = self._get_prompt("deadpan.json")
        final_script = self.llm.ask(system=deadpan_prompt, prompt=subverted_plot)

        print("[Factory] ⚙️ 正在执行阶段 4：注入 [Audio_Visual_Director] 编排卡点JSON...")
        director_prompt = self._get_prompt("director.json")
        
        schema_instruction = "请必须输出标准的JSON数组，不允许包含任何 Markdown 代码块包裹（如 ```json）。" \
                             "数组内每个元素必须包含字段: [timestamp, voiceover, bgm_selection, bgm_action, video_effect]。\n" \
                             f"待处理文本：\n{final_script}"
                             
        raw_json_timeline = self.llm.ask(system=director_prompt, prompt=schema_instruction)

        # 3. 严格的 JSON 稳定性清洗器 (Sanitizer)
        try:
            # 清理可能存在的代码块残留
            clean_json = raw_json_timeline.replace("```json", "").replace("```", "").strip()
            timeline_data = json.loads(clean_json)
            return timeline_data
        except json.JSONDecodeError:
            print("[Error] AI未按标准Schema输出，启动强制降级适配...")
            return [{"timestamp": "00:00", "voiceover": final_script, "bgm_selection": "爱的供养", "bgm_action": "Play", "video_effect": "None"}]
