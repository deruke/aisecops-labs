# AISecOps Labs

Docker-based lab environment for the **Attacking, Defending, and Leveraging AI** class.

Integrates the [BHIS AI-CTF](https://github.com/blackhillsinfosec/AI-CTF) (11 prompt injection challenges) with 9 hands-on Jupyter lab notebooks and an automated LLM red-teaming container.

## Quick Start

```bash
git clone --recurse-submodules https://github.com/yourorg/aisecops-labs.git
cd aisecops-labs
./setup.sh
```

The setup script will:
1. Check prerequisites (Docker, Git)
2. Ask whether to use OpenAI or Ollama as the LLM backend
3. Optionally configure DeepTeam for automated red-teaming
4. Detect GPU availability
5. Generate `.env` and start all services

## What's Included

### CTF Challenges (via AI-CTF)
11 prompt injection challenges of increasing difficulty, served through Open WebUI:

| Challenge | Defense |
|-----------|---------|
| 1 | No protections |
| 2 | System prompt protection |
| 3 | Input filtering |
| 4 | Output filtering |
| 5 | LLM Prompt Guard |
| 6 | All defenses combined |
| 7 | Code interpreter |
| 8 | Agent (calculator tool) |
| 9 | RAG (knowledge base) |
| 10 | Email summarizer |
| 11 | Multi-modal (vision) |

### Lab Notebooks
9 hands-on Jupyter notebooks covering ML security topics:

| Lab | Topic |
|-----|-------|
| 1 | ML Phishing URL Classification |
| 2 | Transformer Attention Visualization |
| 3 | Prompt Injection Attacks |
| 5 | DeepTeam LLM Security Assessment |
| 6 | Building & Breaking Guardrails |
| 7 | RAG Poisoning & Exfiltration |
| 8 | MCP Security & Tool Poisoning |
| 9 | Security Agent Tool Calling |
| 10 | Embedding Space Adversarial Attacks |

> Lab 4 (Abliteration) is a standalone exercise, not included in this Docker environment.

### DeepTeam (Optional)
Automated LLM red-teaming container pre-configured to target the CTF challenges. Requires an OpenAI API key.

## Access URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| CTF (Open WebUI) | http://localhost:4242 | `ctf@ctf.local` / `Hellollmworld!` |
| CTF Admin | http://localhost:4242 | `admin@ctf.local` / `ctf_admin_password` |
| CTF Jupyter | http://localhost:8888 | Token: `AntiSyphonBlackHillsTrainingFtw!` |
| Lab Notebooks | http://localhost:8889 | Token: `aisecops2026` |
| Ollama API | http://localhost:11435 | (Ollama mode only) |

## OpenAI vs Ollama Mode

| | OpenAI | Ollama |
|---|--------|--------|
| **Cost** | Pay per token | Free |
| **Speed** | Fast | Depends on hardware |
| **Disk** | Minimal | ~11GB for models |
| **RAM** | Minimal | ~8GB recommended |
| **GPU** | Not needed | Optional (faster) |
| **Models** | gpt-4.1-mini | llama3.1:8b + llama3.2-vision:11b |

## GPU Support

If you have an NVIDIA GPU, the setup script will detect it and offer GPU acceleration. This speeds up Ollama inference and enables GPU-accelerated notebook workloads.

You can also manually enable it:
```bash
docker compose -f docker-compose.yml -f docker-compose.gpu.yml --profile ollama up -d
```

## Services

| Container | Purpose | Port |
|-----------|---------|------|
| `ollama` | LLM inference (Ollama mode) | 11435 |
| `open-webui` | CTF challenge UI | 4242 |
| `pipelines` | LLM Guard, email summarizer | 9099 |
| `ctf-jupyter` | Code execution for CTF challenges 7/8 | 8888 |
| `ctf-setup` | One-shot CTF initialization | none |
| `notebooks` | Lab notebooks (1-10) | 8889 |
| `deepteam` | LLM red-teaming CLI | none |

## Updating from Upstream AI-CTF

The AI-CTF is tracked as a git submodule. To pull the latest changes:

```bash
cd AI-CTF
git pull origin main
cd ..
docker compose build ctf-setup open-webui ctf-jupyter
docker compose up -d
```

## Troubleshooting

**CTF challenges not loading:**
- Wait for the `ctf-setup` container to finish: `docker compose logs -f ctf-setup`
- It needs Open WebUI to be healthy before it can configure challenges

**Ollama model download slow:**
- First startup downloads ~11GB of models
- Check progress: `docker compose logs -f ollama`

**Port conflicts:**
- Edit `.env` to change port assignments
- Default ports: 4242, 8888, 8889, 9099, 11435

**Open WebUI not starting:**
- Check if another service is using port 4242: `lsof -i :4242`
- Check logs: `docker compose logs open-webui`

**Notebooks missing packages:**
- The notebooks container includes common ML/AI packages
- For additional packages: `docker exec -it notebooks pip install <package>`

**Reset everything:**
```bash
docker compose down -v
./setup.sh
```
