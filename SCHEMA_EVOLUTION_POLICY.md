# Schema Evolution Policy 📋

## Purpose
This policy ensures notebook schema changes don't break downstream Power BI reports that depend on our data models.

---

## The Problem We're Solving

**Before this policy:**
- Data scientist changes `customers_with_churn` table (removes `email` column)
- Commits to GitHub → merges to DEV → deploys to TEST → deploys to PROD
- 12 Power BI reports break on Monday morning ❌
- Customer executives can't see dashboards
- 3 hours to identify issue, 6 hours to rollback and fix

**After this policy:**
- Data scientist changes `customers_with_churn` table (removes `email` column)
- GitHub Actions detects breaking change → **blocks PR** 🚨
- Clear message: "Column 'email' removal will break 3 Power BI reports"
- Data scientist adds deprecation warning instead
- Zero downtime ✅

---

## Schema Change Classification

### 🚨 BREAKING CHANGES (Will Block PR)
These changes **WILL break existing Power BI reports** and require approval:

| Change Type | Example | Impact |
|-------------|---------|--------|
| **Column Removed** | Deleting `email` column | Power BI visuals show `#ERROR` |
| **Type Changed** | `lifetime_value` (double → int) | Precision loss, calculations wrong |
| **Made Nullable** | `customer_id` (required → optional) | COUNT() calculations incorrect |

### ✅ SAFE CHANGES (Auto-Approved)
These changes are **backward compatible** and won't break reports:

| Change Type | Example | Impact |
|-------------|---------|--------|
| **Column Added** | Adding `phone_number` column | Existing reports unaffected |
| **Made Non-Nullable** | `email` (optional → required) | Safer, no report changes needed |

---

## How to Annotate Your Notebooks

### Step 1: Add Schema Comments (30 seconds)
When your notebook outputs a table/dataframe that Power BI uses, add this:

```python
# SCHEMA: customers_with_churn
# COLUMNS: customer_id (string), customer_name (string), email (string), lifetime_value (double), churn_risk (string)

# Your existing code
df = spark.sql("""
    SELECT 
        customer_id,
        customer_name,
        email,
        lifetime_value,
        churn_risk
    FROM customers
""")
```

### Step 2: Commit and Push
```bash
git add model_training.Notebook/notebook-content.py
git commit -m "Add churn prediction model"
git push origin feature/churn-model
```

### Step 3: GitHub Actions Runs Automatically
- ✅ If no schema changes → PR approved
- ✅ If safe changes (added columns) → PR approved  
- 🚨 If breaking changes → PR blocked with clear message

---

## Breaking Change Process

### Option 1: Revert the Breaking Change (Fastest) ✅
If you accidentally removed a column:
```python
# BEFORE (Breaking)
# SCHEMA: customers_with_churn
# COLUMNS: customer_id (string), customer_name (string), lifetime_value (double)
# ❌ email column removed - breaks 3 Power BI reports!

# AFTER (Fixed)
# SCHEMA: customers_with_churn
# COLUMNS: customer_id (string), customer_name (string), email (string), lifetime_value (double)
# ✅ email column restored
```

### Option 2: Deprecate Then Remove (30-Day Window) 📅
If you need to remove a column that Power BI uses:

**Week 1:** Add deprecation warning
```python
# SCHEMA: customers_with_churn
# COLUMNS: customer_id (string), customer_name (string), email (string, DEPRECATED), lifetime_value (double)
# DEPRECATION: email column will be removed on 2024-03-15. Use contact_email instead.

df = df.withColumn("email", 
    when(col("contact_email").isNotNull(), col("contact_email"))
    .otherwise(lit("DEPRECATED - Use contact_email")))
```

**Weeks 2-4:** Notify Power BI report owners
- Post in Teams: "customers_with_churn.email deprecating March 15"
- Send email to Power BI developers with migration guide
- Update documentation

**Week 4:** Remove column
```python
# SCHEMA: customers_with_churn
# COLUMNS: customer_id (string), customer_name (string), contact_email (string), lifetime_value (double)
# MIGRATION: email column removed. Use contact_email instead.
```

### Option 3: Request Breaking Change Approval 🎫
For urgent business needs requiring immediate breaking changes:

1. **Create Change Ticket** in ServiceNow/Jira:
   - Title: "BREAKING: Remove email column from customers_with_churn"
   - Business justification
   - List of affected Power BI reports (GitHub Actions tells you which ones)
   - Rollback plan

2. **Get Approvals:**
   - Manager approval
   - Power BI team lead approval
   - Data governance approval

3. **Add Override Label:**
   ```bash
   gh pr edit --add-label "schema-override-approved"
   ```
   (This bypasses the GitHub Actions check)

4. **Update All Reports BEFORE Merging:**
   - Fix 3 affected Power BI reports
   - Test in DEV environment
   - Get sign-off from report owners

5. **Merge PR** (only after reports updated)

---

## Examples

### Example 1: Adding a New Feature Column ✅
```python
# SCHEMA: customers_with_churn
# COLUMNS: customer_id (string), customer_name (string), email (string), lifetime_value (double), churn_risk (string), customer_segment (string)
# ADDED: customer_segment column for market segmentation analysis

# Safe change - existing Power BI reports will continue working
df = df.withColumn("customer_segment", 
    when(col("lifetime_value") > 10000, "Premium")
    .when(col("lifetime_value") > 5000, "Standard")
    .otherwise("Basic"))
```

**GitHub Actions Output:**
```
✅ Safe schema changes detected:
   ✓ Column 'customer_segment' was added to table 'customers_with_churn'
   
   Existing Power BI reports will continue working.
   Report developers can now use this new column in visuals.
```

### Example 2: Accidentally Removing a Column 🚨
```python
# SCHEMA: customers_with_churn
# COLUMNS: customer_id (string), customer_name (string), lifetime_value (double), churn_risk (string)
# ❌ email column accidentally removed

df = spark.sql("""
    SELECT 
        customer_id,
        customer_name,
        -- email,  ← Commented out by mistake!
        lifetime_value,
        churn_risk
    FROM customers
""")
```

**GitHub Actions Output:**
```
🚨 BREAKING SCHEMA CHANGES DETECTED!

   ❌ Column 'email' was removed from table 'customers_with_churn'
   
   This will BREAK the following Power BI reports:
   • Customer 360 Dashboard (uses email in contact card visual)
   • Marketing Campaign Report (filters by email domain)
   • Customer Support Metrics (groups by email status)
   
   Please either:
   1. ✅ Restore the 'email' column
   2. 📅 Add deprecation warning (30-day notice)
   3. 🎫 Request breaking change approval (requires manager sign-off)
```

### Example 3: Changing Data Type 🚨
```python
# SCHEMA: customers_with_churn
# COLUMNS: customer_id (string), customer_name (string), email (string), lifetime_value (int), churn_risk (string)
# ⚠️ lifetime_value changed from double to int

# This loses precision! $12,450.75 becomes $12,450
df = df.withColumn("lifetime_value", col("lifetime_value").cast("int"))
```

**GitHub Actions Output:**
```
🚨 BREAKING SCHEMA CHANGES DETECTED!

   ❌ Column 'lifetime_value' data type changed from 'double' to 'int'
   
   This will cause:
   • Precision loss ($12,450.75 → $12,450)
   • Incorrect revenue calculations in Power BI
   • Mismatched totals vs. source systems
   
   Affected Power BI reports:
   • Revenue Dashboard (SUM and AVG calculations will be wrong)
   • Customer Lifetime Value Analysis (precision required)
```

---

## Power BI Report Impact Tracking

### How GitHub Actions Knows Which Reports Break
We maintain a mapping file: `powerbi-dependencies.json`

```json
{
  "customers_with_churn": {
    "reports": [
      {
        "name": "Customer 360 Dashboard",
        "owner": "sarah.chen@company.com",
        "workspace": "Sales Analytics",
        "columns_used": ["customer_id", "customer_name", "email", "lifetime_value", "churn_risk"]
      },
      {
        "name": "Marketing Campaign Report", 
        "owner": "john.smith@company.com",
        "workspace": "Marketing",
        "columns_used": ["customer_id", "email", "churn_risk"]
      }
    ]
  }
}
```

### Keeping Dependencies Updated
When you create a new Power BI report using a notebook's data:

1. Add entry to `powerbi-dependencies.json`
2. List which columns your report uses
3. Commit and push

This ensures future schema changes notify you automatically.

---

## FAQ

### Q1: "I just want to rename a column. Is that breaking?"
**A:** Yes! Renaming is seen as:
1. Remove old column (BREAKING)
2. Add new column (SAFE)

Use column aliasing instead:
```python
# Keep old name for Power BI compatibility
df = df.withColumnRenamed("new_column_name", "old_column_name")
```

### Q2: "Can I temporarily disable schema checking for a hotfix?"
**A:** Yes, add label `schema-override-approved` to PR. But you MUST:
- Get manager approval
- Update affected Power BI reports FIRST
- Document in change ticket

### Q3: "What if I don't know which Power BI reports use my table?"
**A:** GitHub Actions tells you! It reads `powerbi-dependencies.json` and shows exactly which reports break.

If no reports listed, it will say:
```
⚠️ Warning: No Power BI dependencies tracked for 'customers_with_churn'
   Add them to powerbi-dependencies.json to prevent future breakage.
```

### Q4: "How long does the deprecation window need to be?"
**A:** Standard: **30 days** minimum
- Week 1: Add deprecation warning
- Weeks 2-3: Notify report owners, give them time to update
- Week 4: Remove column after confirming all reports updated

For urgent business needs: Get approval to shorten (minimum 7 days).

### Q5: "What if I add a column with the same name but different type?"
**A:** That's TWO breaking changes:
1. Remove old `email (string)`
2. Add new `email (int)` ← Wrong type!

GitHub Actions will flag this as:
```
🚨 Column 'email' data type changed from 'string' to 'int'
   This is almost always a mistake. Did you mean to:
   • Create a new column 'email_id'?
   • Keep 'email' as string?
```

---

## Enforcement

### Automated Checks ✅
- Every PR runs `scripts/detect_schema_changes.py`
- Breaking changes → PR blocked
- Safe changes → PR approved
- No schema annotations → Warning (not blocked)

### Team Responsibilities
**Data Scientists:**
- Add schema annotations to notebooks
- Follow deprecation process for breaking changes
- Update `powerbi-dependencies.json` when creating reports

**Power BI Developers:**
- Register reports in `powerbi-dependencies.json`
- Subscribe to schema change notifications
- Test reports in DEV after notebook changes

**Managers:**
- Approve breaking change requests
- Balance business urgency vs. technical debt
- Sign off on deprecation timeline exceptions

---

## Schema Change Checklist

Before committing notebook changes:

- [ ] Schema annotations added/updated
- [ ] Breaking changes identified (GitHub Actions will tell you)
- [ ] If breaking:
  - [ ] Option 1: Reverted breaking change ✅
  - [ ] Option 2: Added 30-day deprecation notice 📅
  - [ ] Option 3: Change ticket created + approvals obtained 🎫
- [ ] `powerbi-dependencies.json` updated (if new reports created)
- [ ] Affected report owners notified (if breaking)
- [ ] PR passes all validation checks

---

## Contact

**Questions?** 
- Slack: #data-science-help
- Email: data-governance@company.com
- Wiki: [Schema Evolution Best Practices](https://wiki.company.com/schema-evolution)

**Tool Issues?**
- GitHub: [sautalwar/nvrfabricdemo1/issues](https://github.com/sautalwar/nvrfabricdemo1/issues)
- On-call: Data Platform Team (PagerDuty)

---

**Last Updated:** December 2024  
**Policy Owner:** Data Governance Team  
**Review Cycle:** Quarterly
