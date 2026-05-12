# GIF Curator — Remote Deployment

Deploy the GIF Curator to the cloud for remote access.

## Option 1: Render (Recommended — Free Tier)

1. **Commit & push to GitHub**
   ```bash
   git add .
   git commit -m "Add GIF curator deployment config"
   git push origin main
   ```

2. **Create Render account**
   - Go to https://dashboard.render.com
   - Sign in with GitHub

3. **Create Web Service**
   - Click "New +"
   - Select "Web Service"
   - Connect your GitHub repo
   - Fill in:
     - **Name**: `geometry-dash-gif-curator`
     - **Root Directory**: `geometry-dash-godot/gif_server`
     - **Runtime**: `Python 3`
     - **Build Command**: `pip install -r requirements.txt`
     - **Start Command**: `python server.py`
     - **Instance Type**: Free

4. **Add Environment Variables**
   - Go to Service Settings → Environment
   - Add from `geometry-dash-godot/gif_server/.env`:
     - `GIPHY_API_KEY=aF1iBxvFatX4YJGWEyx5TtP8tJSrGkR8`
     - `GOOGLE_CLIENT_ID=980009407381-5rfqnen4o3mg5m6ufaab8b1iljqprh3s.apps.googleusercontent.com`
     - `GOOGLE_CLIENT_SECRET=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`

5. **Deploy**
   - Render will auto-deploy on next push
   - Your app will be live at: `https://geometry-dash-gif-curator.onrender.com`

## Option 2: GitHub Codespaces (Easier, Temporary)

1. **Open in Codespaces**
   - Go to your GitHub repo
   - Click "Code" → "Codespaces" → "Create codespace on main"

2. **VS Code will open in browser**
   - Terminal auto-installs dependencies (see `.devcontainer/devcontainer.json`)
   - Run task: **Run GIF Curator** (Shift+Cmd+B)
   - Port 8080 is auto-forwarded

3. **Access remotely**
   - Click port forwarding notification
   - Share the forwarded URL

## Environment Variables

Never commit `.env` to GitHub. Instead:

1. **Add `geometry-dash-godot/gif_server/.env` to `.gitignore`** (already done)
2. **Keep `.env.example` in the repo** for reference
3. **Set vars in your cloud service dashboard** (Render, Codespaces, etc.)

## Local Development

To run locally:
```bash
cd geometry-dash-godot/gif_server
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install -r requirements.txt
python server.py
```

Then open http://localhost:8080 in your browser.

## Troubleshooting

- **Port 8080 already in use?**
  ```bash
  lsof -ti:8080 | xargs kill -9
  ```

- **Missing GIPHY key?**
  Check `.env` is set in cloud service environment variables

- **rembg slow on free tier?**
  Subject extraction (background removal) is CPU-intensive. Upgrade instance if needed.

## Next Steps

- [ ] Commit to GitHub
- [ ] Sign up for Render
- [ ] Create Web Service and deploy
- [ ] Test at remote URL
- [ ] Share remote link with others
