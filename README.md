# Anchor — your personal LLM layer on AWS

The always-on brain of your setup. It runs on a small AWS Lightsail server and has three parts:

- **Gateway**: your own [llm_routing_server](https://github.com/KushGrandhi/llm_routing_server).
  - Gives every app, device and Jarvis one OpenAI-compatible endpoint.
  - Adds fallbacks, cost tracking, usage logs and hot-reload.
- **Open WebUI**: a Claude-style chat UI you can open from your phone or laptop.
- **Redis**: stores the gateway's cache and rate-limit state.

Nothing is exposed to the public internet. Your devices reach the anchor through **Tailscale**.

```
Mac / iPhone / Jarvis Pi ──Tailscale──▶ anchor (Lightsail)
                                          ├─ Open WebUI          :443
                                          └─ llm_routing_server  :8443 ──▶ Claude API (now)
                                                                       └─▶ GPU nodes (later, via Tailscale)
```

The anchor **does not modify** your gateway repo:
- `bootstrap.sh` clones the repo into `gateway-src/`.
- The anchor mounts its own model list from `gateway/models.yaml`.

Gateway improvements happen in your repo. To deploy them:

```bash
cd gateway-src && git pull && cd .. && docker compose up -d --build gateway
```

---

## Part 1 — AWS account (one time, ~15 min)

1. **Sign up** at aws.amazon.com and choose the **Paid plan**, not the Free plan.
   - The Paid plan still includes the sign-up credits.
   - A Free-plan account closes automatically after 6 months, and this server would go with it.
2. **Protect the root account:** go to IAM → Security credentials and enable MFA.
3. **Set up a billing alarm:**
   - Go to Billing → Budgets → Create budget → Monthly cost budget.
   - Set the budget to **$15**, with email alerts at 80% and 100%.
4. **Create a user for daily use:**
   - Go to IAM → Users → Create user, attach `AdministratorAccess`, and turn on MFA.
   - Sign in as this user from now on, and leave root locked away.

## Part 2 — Create the server (~5 min)

1. In the **Lightsail console**, click **Create instance** and choose:
   - **Region:** Oregon (`us-west-2`), the closest to the Bay Area.
   - **Platform:** Linux/Unix, **Blueprint:** OS Only → **Ubuntu 24.04 LTS**.
   - **Plan:** the **$12/mo (2 GB RAM, dual-stack)** plan. Check that it shows the 3-months-free badge.
   - **Name:** `anchor`.
2. In the instance's **Networking** tab:
   - Click **Attach static IP**. It's free while attached to a running instance.
   - In the IPv4 firewall, **delete the HTTP (80) rule**. Keep SSH (22) for now.
3. Click **Connect using SSH** to open a browser terminal.

> **Billing gotcha:** a *stopped* Lightsail instance still bills. Delete it to stop paying.

## Part 3 — Install (~10 min)

First, get this folder onto the server. The easiest route is to push it to a **private** GitHub repo, then clone it on the server:

```bash
git clone https://github.com/<you>/aws-anchor.git
cd aws-anchor
```

Run the bootstrap script. It installs Docker, Tailscale and swap, and clones your gateway:

```bash
sudo bash scripts/bootstrap.sh
```

The script prints a Tailscale login URL. Open it in your browser and approve the machine. Then:

- Install **Tailscale** on your Mac and iPhone, and sign in with the same account.
- In the **Tailscale admin console → DNS**, turn on **MagicDNS** and **HTTPS Certificates**.

**Log out and back in** so Docker works without sudo. Then start everything:

```bash
cd aws-anchor
bash scripts/gen-env.sh            # creates .env with gateway keys; prints your personal key
nano .env                          # paste your ANTHROPIC_API_KEY
docker compose up -d --build       # first build takes a few minutes
docker compose ps                  # gateway, open-webui and redis should be running
bash scripts/expose.sh             # prints your private HTTPS URLs
```

Next, open the printed **Chat UI** URL on your phone.
- The first account you create becomes the admin.
- Then go to **Admin Panel → Settings → General** and **turn off new sign-ups**.

## Part 4 — Close the last public port

Check that you can reach the server over Tailscale from your Mac:

```bash
ssh ubuntu@anchor        # Tailscale SSH, no key needed
```

Once that works, delete the **SSH (22)** rule in the Lightsail firewall. The server now has **zero public ports**.

## Test the gateway

```bash
GW=https://anchor.<your-tailnet>.ts.net:8443
KEY=<your personal gateway key>

curl $GW/v1/models -H "Authorization: Bearer $KEY"

curl $GW/v1/chat/completions \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"model":"claude-haiku","messages":[{"role":"user","content":"hello from my own infra"}]}'

curl "$GW/v1/usage?days=7" -H "Authorization: Bearer $KEY"    # spend + token totals
```

Any OpenAI-compatible tool can use `$GW/v1` as its base URL, including Jarvis, scripts and editors.

---

## Growing it: add a GPU node

A GPU node can be a rented GPU (Vast.ai / RunPod) today, or your home GPU box later. The steps are the same either way:

1. On the GPU machine, run:
   ```bash
   sudo TS_HOSTNAME=gpu-home bash scripts/join-gpu-node.sh qwen3:8b
   ```
2. Paste the block it prints into `gateway/models.yaml` on the anchor.
3. Hot-reload the model list. No restart is needed:
   ```bash
   curl -X POST http://127.0.0.1:5000/v1/models/reload -H "Authorization: Bearer $KEY"
   ```

The new model appears in the chat UI and on the gateway. If the node goes offline, requests fall back to Claude Haiku automatically.

On rented marketplace GPUs, use verified or datacenter hosts for anything personal. Community hosts are other people's machines.

## Day-to-day

| Task | Command |
|---|---|
| Change models | edit `gateway/models.yaml`, then `POST /v1/models/reload` |
| Deploy gateway changes | `cd gateway-src && git pull && cd .. && docker compose up -d --build gateway` |
| Update the UI | `docker compose pull open-webui && docker compose up -d` |
| Logs | `docker compose logs -f gateway` |
| Recent requests | `curl http://127.0.0.1:5000/v1/usage/recent -H "Authorization: Bearer $KEY"` |
| Memory check | `free -h` |
| Backup | Lightsail console → Snapshots → Create snapshot (small storage charge) |

If the server feels sluggish, check `free -h`. The fix is to snapshot it and launch the snapshot on the **4 GB** plan.

## AWS learning path from here

1. **Lightsail.** You are here.
2. **S3:** nightly backups of the gateway's SQLite usage DB and the chat history.
3. **CloudWatch:** alarms on CPU and disk.
4. **EC2 + VPC + IAM roles:** export a Lightsail snapshot to EC2 and rebuild it properly.
5. **Terraform:** define the whole thing as code.
