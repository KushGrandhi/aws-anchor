# Anchor — your personal LLM layer on AWS

The always-on brain of your setup. It runs on a small AWS Lightsail server and holds three things:

- **LiteLLM gateway**: one OpenAI-compatible endpoint for every app, device and Jarvis.
- **Open WebUI**: a Claude-style chat UI you can open from your phone or laptop.
- **Postgres**: stores keys, usage and spend tracking.

Nothing is exposed to the public internet. Your devices reach the anchor through **Tailscale**.

```
Mac / iPhone / Jarvis Pi ──Tailscale──▶ anchor (Lightsail)
                                          ├─ Open WebUI  :443
                                          └─ LiteLLM     :8443 ──▶ Claude API (now)
                                                                └─▶ GPU nodes (later, via Tailscale)
```

---

## Part 1 — AWS account (one time, ~15 min)

1. **Sign up** at aws.amazon.com and choose the **Paid plan**, not the Free plan.
   - The Paid plan still includes the sign-up credits.
   - A Free-plan account auto-closes after 6 months, and that would take this server with it.
2. **Secure the root account:** go to IAM → Security credentials and enable MFA.
3. **Set a billing alarm:**
   - Go to Billing → Budgets → Create budget → Monthly cost budget.
   - Set the amount to **$15**, with email alerts at 80% and 100%.
4. **Create a daily-use user:**
   - Go to IAM → Users → Create user, attach `AdministratorAccess`, and enable MFA.
   - Sign in as this user from now on, and keep the root account locked away.

## Part 2 — Create the server (~5 min)

1. Open the **Lightsail console**, then click **Create instance**.
   - **Region:** Oregon (`us-west-2`). It's the closest to the Bay Area.
   - **Platform:** Linux/Unix. **Blueprint:** OS Only → **Ubuntu 24.04 LTS**.
   - **Plan:** the **$12/mo (2 GB RAM, dual-stack)** plan. Check that it shows the 3-months-free badge.
   - **Name:** `anchor`.
2. In the instance's **Networking** tab:
   - Click **Attach static IP**. It's free while attached to a running instance.
   - In the IPv4 firewall, **delete the HTTP (80) rule**. Keep SSH (22) for now.
3. Click **Connect using SSH** to open a browser terminal.

> **Billing gotcha:** a *stopped* Lightsail instance still bills. Delete it to stop paying.

## Part 3 — Install (~10 min)

Get this folder onto the server. The cleanest way is to push it to a **private** GitHub repo from your Mac and clone it on the server:

```bash
git clone https://github.com/<you>/aws-anchor.git
cd aws-anchor
```

Install Docker, Tailscale and swap:

```bash
sudo bash scripts/bootstrap.sh
```

The script prints a Tailscale login URL. Open it in your browser and approve the machine.

Then do two things on your other devices:
- Install **Tailscale** on your Mac and iPhone, and sign in with the same account.
- In the **Tailscale admin console → DNS**, turn on **MagicDNS** and **HTTPS Certificates**.

Back on the server, **log out and back in**, then run:

```bash
cd aws-anchor
bash scripts/gen-env.sh            # creates .env with random secrets
nano .env                          # paste your ANTHROPIC_API_KEY
docker compose up -d
docker compose ps                  # all three should be "running"
bash scripts/expose.sh             # prints your private HTTPS URLs
```

Open the printed **Chat UI** URL on your phone. The first account you create becomes the admin.

Then go to **Admin Panel → Settings → General** and **turn off new sign-ups**.

## Part 4 — Close the last public port

Once this works from your Mac:

```bash
ssh ubuntu@anchor        # Tailscale SSH, no key needed
```

delete the **SSH (22)** rule in the Lightsail firewall. The server now has **zero public ports**, and only your tailnet can reach it.

## Test the gateway

```bash
curl https://anchor.<your-tailnet>.ts.net:8443/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-haiku","messages":[{"role":"user","content":"hello from my own infra"}]}'
```

Any OpenAI-compatible tool can point at this URL, including Jarvis, your scripts, and editors.

---

## Growing it: add a GPU node

You can add a rented GPU (Vast.ai / RunPod) today, or your home GPU box later. The steps are the same:

1. On the GPU machine:
   ```bash
   sudo TS_HOSTNAME=gpu-home bash scripts/join-gpu-node.sh qwen3:8b
   ```
2. Paste the snippet it prints into `litellm/config.yaml` on the anchor.
3. Restart the gateway:
   ```bash
   docker compose restart litellm
   ```

The new model appears in the chat UI and on the gateway. Nothing else changes.

On rented marketplace GPUs, use verified or datacenter hosts for anything personal. Community hosts are other people's machines.

## Day-to-day

| Task | Command |
|---|---|
| Update everything | `docker compose pull && docker compose up -d` |
| Logs | `docker compose logs -f litellm` |
| Restart after config change | `docker compose restart litellm` |
| Memory check | `free -h` |
| Backup | Lightsail console → Snapshots → Create snapshot (small storage charge) |

If it feels sluggish, check `free -h`. The fix is to snapshot the server and launch the snapshot on the **4 GB** plan.

## AWS learning path from here

1. **Lightsail.** You are here.
2. **S3:** nightly `pg_dump` and chat backups.
3. **CloudWatch:** alarms on CPU and disk.
4. **EC2 + VPC + IAM roles:** export a Lightsail snapshot to EC2 and rebuild it properly.
5. **Terraform:** define the whole setup as code.
