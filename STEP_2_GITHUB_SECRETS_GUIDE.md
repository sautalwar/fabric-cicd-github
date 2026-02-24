# 🔐 Step 2: Configure GitHub Secrets - Complete Guide

This guide shows you exactly where to find all the Azure credentials needed for the CI/CD pipeline.

---

## 📋 Required Secrets

You need to add **6 secrets** to GitHub:

| Secret Name | Description | Where to Find |
|-------------|-------------|---------------|
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID | Azure Portal → Subscriptions |
| `AZURE_TENANT_ID` | Your Azure AD tenant ID | Azure Portal → Microsoft Entra ID |
| `AZURE_CLIENT_ID` | Service Principal app ID | Azure Portal → App Registrations |
| `AZURE_CLIENT_SECRET` | Service Principal secret | Azure Portal → App Registrations → Certificates & secrets |
| `FABRIC_DEV_WORKSPACE_ID` | DEV Fabric workspace ID | Fabric Portal URL |
| `FABRIC_TEST_WORKSPACE_ID` | TEST Fabric workspace ID | Fabric Portal URL |
| `FABRIC_PROD_WORKSPACE_ID` | PROD Fabric workspace ID | Fabric Portal URL |

---

## 🚀 Quick Start - Using Azure CLI

Run these commands in PowerShell to get your values:

```powershell
# 1. Get Subscription ID
az account show --query id -o tsv

# 2. Get Tenant ID
az account show --query tenantId -o tsv

# 3. Create Service Principal (or use existing)
az ad sp create-for-rbac `
    --name "github-actions-fabric-cicd" `
    --role Reader `
    --scopes "/subscriptions/$(az account show --query id -o tsv)"
```

This will output:
```json
{
  "appId": "12345678-1234-1234-1234-123456789abc",      ← AZURE_CLIENT_ID
  "displayName": "github-actions-fabric-cicd",
  "password": "your-secret-password-here",              ← AZURE_CLIENT_SECRET
  "tenant": "87654321-4321-4321-4321-cba987654321"      ← AZURE_TENANT_ID (confirmation)
}
```

⚠️ **SAVE THE PASSWORD IMMEDIATELY** - You won't see it again!

---

## 📖 Detailed Steps - Using Azure Portal

### **Step 1: Get AZURE_SUBSCRIPTION_ID**

#### Method A: Azure Portal
1. Go to [portal.azure.com](https://portal.azure.com)
2. Search for **"Subscriptions"** in the top search bar
3. Click on your subscription (e.g., "Visual Studio Enterprise")
4. Copy the **Subscription ID**

#### Method B: Azure CLI
```powershell
az account show --query id -o tsv
```

**Example output**: `08608efd-deb6-42fa-8c1b-3bb2919b41cc`

---

### **Step 2: Get AZURE_TENANT_ID**

#### Method A: Azure Portal
1. Go to [portal.azure.com](https://portal.azure.com)
2. Search for **"Microsoft Entra ID"** (formerly Azure Active Directory)
3. Click on **Microsoft Entra ID**
4. On the Overview page, find **Tenant ID**
5. Copy the value

#### Method B: Azure CLI
```powershell
az account show --query tenantId -o tsv
```

**Example output**: `72f988bf-86f1-41af-91ab-2d7cd011db47`

---

### **Step 3: Create Service Principal for AZURE_CLIENT_ID**

A Service Principal is like a "robot user" that GitHub Actions will use to authenticate.

#### Option A: Using Azure CLI (Recommended - Faster)

```powershell
# Create the service principal
az ad sp create-for-rbac `
    --name "github-actions-fabric-cicd" `
    --role Reader `
    --scopes "/subscriptions/YOUR_SUBSCRIPTION_ID"
```

Replace `YOUR_SUBSCRIPTION_ID` with your actual subscription ID from Step 1.

**Output** (save all these values):
```json
{
  "appId": "12345678-1234-1234-1234-123456789abc",      ← This is AZURE_CLIENT_ID
  "displayName": "github-actions-fabric-cicd",
  "password": "ABC~def123GHI~jkl456MNO~pqr789",        ← This is AZURE_CLIENT_SECRET
  "tenant": "87654321-4321-4321-4321-cba987654321"
}
```

#### Option B: Using Azure Portal (More Control)

1. Go to **Microsoft Entra ID**
2. Click **App registrations** (left menu)
3. Click **+ New registration**
4. Fill in:
   - **Name**: `github-actions-fabric-cicd`
   - **Supported account types**: "Accounts in this organizational directory only"
   - **Redirect URI**: Leave blank
5. Click **Register**
6. On the Overview page, copy **Application (client) ID** → This is `AZURE_CLIENT_ID`

---

### **Step 4: Create AZURE_CLIENT_SECRET**

Still in the App Registration you just created:

1. Click **Certificates & secrets** (left menu)
2. Click **Client secrets** tab
3. Click **+ New client secret**
4. Fill in:
   - **Description**: `GitHub Actions Secret`
   - **Expires**: Recommended 12 months or 24 months
5. Click **Add**
6. **⚠️ CRITICAL**: Copy the **Value** field immediately!
   - You will NEVER see this value again
   - This is your `AZURE_CLIENT_SECRET`

**Example**: `ABC~def123GHI~jkl456MNO~pqr789STU~vwx012`

---

### **Step 5: Grant Permissions to Service Principal**

The service principal needs permission to access Azure and Fabric resources.

#### 5A: Azure Subscription Access (Already done if using CLI method)

1. Go to **Subscriptions**
2. Click your subscription
3. Click **Access control (IAM)** (left menu)
4. Click **+ Add** → **Add role assignment**
5. **Role** tab:
   - Select **Reader** (minimum) or **Contributor** (if deploying resources)
   - Click **Next**
6. **Members** tab:
   - Click **+ Select members**
   - Search for `github-actions-fabric-cicd`
   - Click to select it
   - Click **Select**
   - Click **Next**
7. **Review + assign** tab:
   - Click **Review + assign**

#### 5B: Fabric Workspace Access

For each workspace (DEV, TEST, PROD):

1. Go to [app.fabric.microsoft.com](https://app.fabric.microsoft.com)
2. Navigate to your workspace
3. Click workspace name → **Manage access**
4. Click **+ Add people or groups**
5. Search for `github-actions-fabric-cicd`
6. Select the app
7. Choose role: **Admin** (recommended) or **Member**
8. Click **Add**

Repeat for all three workspaces.

---

### **Step 6: Get Fabric Workspace IDs**

You need the workspace IDs for DEV, TEST, and PROD environments.

#### Method A: From Fabric Portal URL (Easiest)

1. Go to [app.fabric.microsoft.com](https://app.fabric.microsoft.com)
2. Click on your workspace (e.g., "NVR-Dev")
3. Look at the URL in your browser:
   ```
   https://app.fabric.microsoft.com/groups/a1b2c3d4-e5f6-7890-abcd-ef1234567890/...
                                            ↑________________________________↑
                                            This is your Workspace ID
   ```
4. Copy the GUID between `/groups/` and the next `/`

Repeat for all three workspaces:
- **NVR-Dev** → `FABRIC_DEV_WORKSPACE_ID`
- **NVR-Test** → `FABRIC_TEST_WORKSPACE_ID`
- **NVR-Production** → `FABRIC_PROD_WORKSPACE_ID`

#### Method B: Using PowerShell Script

```powershell
# Run the script we created
.\scripts\get-fabric-workspace-ids.ps1
```

This will list all your workspaces with their IDs.

#### Method C: Using Fabric API

```powershell
# Get token
$token = az account get-access-token --resource https://analysis.windows.net/powerbi/api --query accessToken -o tsv

# List workspaces
$headers = @{"Authorization" = "Bearer $token"}
Invoke-RestMethod -Uri "https://api.fabric.microsoft.com/v1/workspaces" -Headers $headers | 
    Select-Object -ExpandProperty value | 
    Select-Object displayName, id | 
    Format-Table -AutoSize
```

---

## 🔧 Add Secrets to GitHub

Once you have all 6 values, add them to GitHub:

### Using GitHub Web UI:

1. Go to your repository: https://github.com/sautalwar/nvrfabricdemo1
2. Click **Settings** tab
3. Click **Secrets and variables** → **Actions** (left menu)
4. Click **New repository secret**
5. For each secret:
   - **Name**: Enter secret name (e.g., `AZURE_SUBSCRIPTION_ID`)
   - **Secret**: Paste the value
   - Click **Add secret**

Repeat for all 6 secrets.

### Using GitHub CLI:

```powershell
# Set each secret (replace values with your actual values)
gh secret set AZURE_SUBSCRIPTION_ID -b "08608efd-deb6-42fa-8c1b-3bb2919b41cc"
gh secret set AZURE_TENANT_ID -b "72f988bf-86f1-41af-91ab-2d7cd011db47"
gh secret set AZURE_CLIENT_ID -b "12345678-1234-1234-1234-123456789abc"
gh secret set AZURE_CLIENT_SECRET -b "ABC~def123GHI~jkl456MNO~pqr789"
gh secret set FABRIC_DEV_WORKSPACE_ID -b "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
gh secret set FABRIC_TEST_WORKSPACE_ID -b "b2c3d4e5-f6g7-8901-bcde-fg2345678901"
gh secret set FABRIC_PROD_WORKSPACE_ID -b "c3d4e5f6-g7h8-9012-cdef-gh3456789012"
```

---

## ✅ Verify Secrets Are Set

### Using GitHub Web UI:
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. You should see all 6 secrets listed (values hidden)

### Using GitHub CLI:
```powershell
gh secret list
```

Expected output:
```
AZURE_CLIENT_ID          Updated 2026-01-06
AZURE_CLIENT_SECRET      Updated 2026-01-06
AZURE_SUBSCRIPTION_ID    Updated 2026-01-06
AZURE_TENANT_ID          Updated 2026-01-06
FABRIC_DEV_WORKSPACE_ID  Updated 2026-01-06
FABRIC_PROD_WORKSPACE_ID Updated 2026-01-06
FABRIC_TEST_WORKSPACE_ID Updated 2026-01-06
```

---

## 🧪 Test the Setup

Once secrets are configured, test the pipeline:

```powershell
# Trigger a test deployment to DEV
gh workflow run model-training-pipeline.yml `
    -f environment=dev `
    -f deployment_reason="Testing credentials setup"
```

Watch the run:
```powershell
gh run list --workflow=model-training-pipeline.yml --limit 1
```

---

## 🔒 Security Best Practices

### ✅ Do's:
- ✅ Use separate service principals for different environments (optional but recommended)
- ✅ Rotate client secrets every 6-12 months
- ✅ Use the minimum required permissions (Reader for most cases)
- ✅ Monitor service principal activity in Azure AD audit logs
- ✅ Remove access when no longer needed

### ❌ Don'ts:
- ❌ Never commit secrets to Git
- ❌ Never share client secrets via email or chat
- ❌ Don't use personal accounts for automation
- ❌ Don't grant more permissions than needed

---

## 🐛 Troubleshooting

### Issue: "Client ID not found"
**Solution**: Make sure you created the App Registration and copied the Application (client) ID, not the Object ID.

### Issue: "Invalid client secret"
**Solution**: The client secret may have expired or was copied incorrectly. Create a new one.

### Issue: "Access denied to Fabric workspace"
**Solution**: Add the service principal as Admin or Member to the Fabric workspace.

### Issue: "Subscription not found"
**Solution**: Verify you're using the correct subscription ID and the service principal has access.

---

## 📊 Summary Checklist

Before proceeding, verify you have:

- [ ] ✅ `AZURE_SUBSCRIPTION_ID` - From Azure Subscriptions
- [ ] ✅ `AZURE_TENANT_ID` - From Microsoft Entra ID
- [ ] ✅ `AZURE_CLIENT_ID` - From App Registration
- [ ] ✅ `AZURE_CLIENT_SECRET` - From App Registration → Certificates & secrets
- [ ] ✅ `FABRIC_DEV_WORKSPACE_ID` - From Fabric portal URL
- [ ] ✅ `FABRIC_TEST_WORKSPACE_ID` - From Fabric portal URL
- [ ] ✅ `FABRIC_PROD_WORKSPACE_ID` - From Fabric portal URL
- [ ] ✅ Service Principal has Reader access to Azure Subscription
- [ ] ✅ Service Principal has Admin/Member access to all 3 Fabric workspaces
- [ ] ✅ All 6 secrets added to GitHub repository
- [ ] ✅ Secrets verified in GitHub UI or CLI

---

## 🎯 Next Steps

Once all secrets are configured:

**Step 3**: [Configure Environment Protection Rules](STEP_3_ENVIRONMENT_PROTECTION.md)
- Set up approval requirements for TEST and PROD
- Configure branch protection
- Add reviewers

**Test the Pipeline**:
```powershell
# Create a test PR to see PR validation
git checkout -b test-pipeline-setup
echo "# Test" >> README.md
git add README.md
git commit -m "test: verify pipeline configuration"
git push origin test-pipeline-setup
gh pr create --title "Test Pipeline Setup" --body "Testing the CI/CD pipeline"
```

---

**Created**: January 5, 2026  
**Status**: Step 2 - Configuration Guide  
**Next**: Step 3 - Environment Protection Rules
