# Troubleshooting GitHub Actions Deployment

If your workflow isn't running, check these:

## 1. Check if Workflow File Was Pushed

```bash
git log --oneline --all -- .github/workflows/deploy-apprunner.yml
```

If you don't see it, the file wasn't pushed. Push it:
```bash
git add .github/workflows/deploy-apprunner.yml
git commit -m "Add App Runner deployment workflow"
git push origin dev  # or main, depending on your branch
```

## 2. Check GitHub Actions Tab

- Go to your GitHub repository
- Click the **Actions** tab
- You should see "Deploy Streamlit to AWS App Runner" workflow
- If it shows "This workflow has a workflow_dispatch event trigger", click "Run workflow"

## 3. Verify GitHub Secrets Are Set

Go to: **Settings → Secrets and variables → Actions**

Required secrets:
- ✅ `AWS_ACCESS_KEY_ID`
- ✅ `AWS_SECRET_ACCESS_KEY`
- ✅ `AGENT_ID` (value: `G1RWZFEZ4O`)
- ✅ `AGENT_ALIAS_ID` (value: `BW3ALCWPTJ`)

If any are missing, the workflow will fail.

## 4. Check Branch Name

The workflow triggers on `main` and `dev` branches. If you're on a different branch:
- Either merge to `main`/`dev`, or
- Update the workflow file to include your branch name

## 5. Manual Trigger

You can manually trigger the workflow:
1. Go to **Actions** tab
2. Click "Deploy Streamlit to AWS App Runner"
3. Click "Run workflow" button
4. Select your branch
5. Click "Run workflow"

## 6. Check Workflow Logs

If the workflow runs but fails:
1. Click on the failed workflow run
2. Expand each step to see error messages
3. Common issues:
   - Missing secrets
   - AWS permissions
   - Docker build errors

## Quick Fix: Force Trigger

To force a run right now:

```bash
# Make a small change to trigger the workflow
touch streamlit_app/.trigger
git add streamlit_app/.trigger
git commit -m "Trigger deployment"
git push origin dev  # or main
```

Or manually trigger via GitHub UI (Actions → Run workflow).

