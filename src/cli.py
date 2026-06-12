import click
import json
import os
import sys
from src.utils.llm_client import XiakanLLMClient 
from src.pipeline import XiakanPipelineEngine

@click.group()
def cli():
    pass

@cli.command(name="verify")
def verify_api():
    """
    提供给 OpenClaw 安装生命周期调用的 API 验证通道
    """
    click.echo("🔄 正在验证大模型 API 连接有效性...")
    client = XiakanLLMClient()
    if client.validate_connection():
        click.secho("✅ 大模型 API 验证通过，内容工厂准备就绪！", fg="green")
        sys.exit(0) # 退出码 0 代表成功，OpenClaw 会继续完成安装
    else:
        click.secho("❌ 验证失败，请重新确认你的 API Key 或 Base URL。", fg="red")
        sys.exit(1) # 退出码 1 代表失败，OpenClaw 捕获后会弹出安装失败提示

@cli.command(name="xiakan")
@click.option('--title', required=True, type=str, help='电影/电视剧名称')
@click.option('--out', default='./dist/timeline.json', type=str, help='输出JSON路径')
def xiakan_factory(title, out):
    click.secho(f"🚀 《瞎看什么》内容制造工厂正在排产...", fg="cyan", bold=True)
    llm_client = XiakanLLMClient()
    engine = XiakanPipelineEngine(llm_client)
    structured_data = engine.process_factory(title)

    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(structured_data, f, ensure_ascii=False, indent=2)
    click.secho(f"🎉 脚本已成功导出至：{out}", fg="green", bold=True)

if __name__ == '__main__':
    cli()