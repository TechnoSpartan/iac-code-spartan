# Migration Guide: OpenProject → Redmine

This guide helps you migrate from OpenProject to Redmine while preserving your project data.

## Why Migrate?

| Issue | OpenProject | Redmine |
|-------|-------------|---------|
| **Memory Usage** | 1.2GB+ (app only) | 512MB (app only) |
| **CPU Usage** | 1.5 cores | 0.5 cores |
| **Restarts** | Frequent (resource exhaustion) | Stable |
| **Alerts** | Constant memory/CPU alerts | Minimal alerts |
| **Resource Savings** | Baseline | **55% reduction** |

## Migration Options

### Option 1: Fresh Start (Recommended for Small Datasets)

**Best for:** Small teams, few projects, starting fresh

**Steps:**
1. Deploy Redmine alongside OpenProject (different subdomain)
2. Manually recreate projects and structure in Redmine
3. Export critical data from OpenProject (CSV exports)
4. Import into Redmine
5. Verify and test
6. Decommission OpenProject

**Pros:**
- Clean start
- No data corruption risk
- Opportunity to reorganize
- Simple process

**Cons:**
- Manual work required
- History not preserved

### Option 2: API-Based Migration (Recommended for Large Datasets)

**Best for:** Many projects, extensive history, complex data

**Steps:**
1. Use migration scripts to export/import via APIs
2. Preserve work packages, issues, relationships
3. Migrate users and roles
4. Verify data integrity
5. Switch domains

**Pros:**
- Automated process
- Preserves relationships
- Maintains history (partial)

**Cons:**
- Requires scripting
- Data model differences
- Time-consuming

### Option 3: Database Migration (Advanced)

**Best for:** Power users, identical data structure needs

**Warning:** OpenProject and Redmine have different database schemas. Direct database migration is complex and error-prone.

**Not recommended** unless you have database expertise.

## Step-by-Step: Fresh Start Migration

### Phase 1: Deploy Redmine (Parallel to OpenProject)

1. **Add DNS Record** for Redmine:
   ```bash
   # In Hetzner DNS, add:
   Type: A
   Name: redmine
   Value: 91.98.137.217
   ```

2. **Add GitHub Secrets**:
   ```
   REDMINE_POSTGRES_PASSWORD=<generate with: openssl rand -hex 16>
   REDMINE_SECRET_KEY_BASE=<generate with: openssl rand -hex 64>
   REDMINE_SMTP_PASSWORD=<same as OpenProject>
   REDMINE_HOSTNAME=redmine.codespartan.cloud
   ```

3. **Deploy Redmine**:
   ```bash
   # Push to trigger GitHub Actions
   git add codespartan/apps/codespartan-cloud/redmine/
   git commit -m "feat: Deploy Redmine as OpenProject replacement"
   git push

   # Or manually trigger:
   # GitHub → Actions → Deploy Redmine → Run workflow
   ```

4. **Wait 5 minutes** for initial setup

5. **Access Redmine**:
   - URL: https://redmine.codespartan.cloud
   - Login: `admin` / `admin`
   - **Change password immediately**

### Phase 2: Export Data from OpenProject

1. **Export Projects**:
   - Navigate to each project in OpenProject
   - Administration → Export
   - Download as CSV

2. **Export Work Packages**:
   - Open project
   - Click "Work packages"
   - Click "..." menu → Export → CSV
   - Save file

3. **Export Users** (if needed):
   - Administration → Users
   - Export list manually or via screenshot

4. **Document Custom Fields**:
   - Note all custom fields and their types
   - Will recreate in Redmine

### Phase 3: Import Data into Redmine

1. **Create Users**:
   ```
   Administration → Users → New user
   ```
   - Add all users from OpenProject
   - Assign roles

2. **Create Projects**:
   ```
   Administration → Projects → New project
   ```
   - Recreate project structure
   - Enable Gantt module
   - Set up project roles

3. **Create Custom Fields**:
   ```
   Administration → Custom fields → New custom field
   ```
   - Recreate custom fields from OpenProject
   - Match types (text, list, date, etc.)

4. **Import Issues**:

   **Option A: Manual CSV Import (Built-in)**
   ```
   Project → Settings → Import
   Select CSV file from OpenProject
   Map fields to Redmine fields
   Import
   ```

   **Option B: Redmine Importer Plugin**
   ```bash
   # Install Redmine Importer plugin
   ssh leonidas@91.98.137.217
   cd /opt/codespartan/apps/codespartan-cloud/redmine

   docker exec redmine-app sh -c 'cd /usr/src/redmine/plugins && \
     git clone https://github.com/leovitch/redmine_importer.git'

   docker exec redmine-app bundle install
   docker exec redmine-app bundle exec rake redmine:plugins:migrate RAILS_ENV=production
   docker compose restart app
   ```

5. **Recreate Gantt Structure**:
   - Set start/end dates on issues
   - Create parent/child relationships
   - Add dependencies (precedes/follows)
   - Verify Gantt chart displays correctly

### Phase 4: Verification

1. **Verify Projects**:
   - [ ] All projects created
   - [ ] Correct hierarchy
   - [ ] Modules enabled

2. **Verify Issues**:
   - [ ] All issues imported
   - [ ] Correct assignees
   - [ ] Correct statuses
   - [ ] Correct priorities

3. **Verify Gantt**:
   - [ ] Start/end dates correct
   - [ ] Dependencies preserved
   - [ ] Critical path visible

4. **Verify Users**:
   - [ ] All users created
   - [ ] Correct roles
   - [ ] Can login

5. **Test Functionality**:
   - [ ] Create new issue
   - [ ] Update existing issue
   - [ ] Add comment
   - [ ] Upload attachment
   - [ ] Gantt chart updates

### Phase 5: Switch Domains (Optional)

If you want Redmine to use `project.codespartan.cloud` instead of `redmine.codespartan.cloud`:

1. **Stop OpenProject**:
   ```bash
   ssh leonidas@91.98.137.217
   cd /opt/codespartan/apps/codespartan-cloud/project
   docker compose down
   ```

2. **Update Redmine DNS**:
   - Update GitHub Secret `REDMINE_HOSTNAME=project.codespartan.cloud`
   - Update `.env`: `TRAEFIK_HOSTNAME=project.codespartan.cloud`

3. **Redeploy Redmine**:
   ```bash
   cd /opt/codespartan/apps/codespartan-cloud/redmine
   docker compose down
   docker compose up -d
   ```

4. **Test**:
   - Access: https://project.codespartan.cloud
   - Verify SSL certificate
   - Verify login

### Phase 6: Decommission OpenProject

**Only after verifying Redmine works perfectly!**

1. **Backup OpenProject Data** (just in case):
   ```bash
   ssh leonidas@91.98.137.217

   # Backup database
   docker exec openproject-db pg_dump -U openproject openproject > \
     ~/openproject_final_backup_$(date +%Y%m%d).sql

   # Backup volumes
   docker run --rm \
     -v openproject-data:/data \
     -v openproject-attachments:/attachments \
     -v ~/:/backup \
     alpine tar czf /backup/openproject_volumes_$(date +%Y%m%d).tar.gz /data /attachments
   ```

2. **Stop and Remove OpenProject**:
   ```bash
   cd /opt/codespartan/apps/codespartan-cloud/project
   docker compose down
   ```

3. **Remove Volumes** (after confirming backup):
   ```bash
   docker volume rm openproject-db-data
   docker volume rm openproject-data
   docker volume rm openproject-attachments
   ```

4. **Remove Network**:
   ```bash
   docker network rm openproject_internal
   ```

5. **Archive Configuration** (optional):
   ```bash
   mv /opt/codespartan/apps/codespartan-cloud/project \
      /opt/codespartan/apps/codespartan-cloud/project.backup_$(date +%Y%m%d)
   ```

## Data Mapping

| OpenProject | Redmine Equivalent |
|-------------|-------------------|
| Work Package | Issue |
| Phase | Milestone / Version |
| Project | Project |
| Member | User |
| Role | Role |
| Custom Field | Custom Field |
| Relation (precedes) | Issue Relation (precedes) |
| Relation (follows) | Issue Relation (follows) |
| Gantt Chart | Gantt Chart |
| Timeline | Gantt Chart |

## Common Issues

### Issue: CSV Import Fails

**Solution:**
- Ensure CSV is UTF-8 encoded
- Remove special characters
- Split large files into smaller batches
- Use Redmine Importer plugin for better compatibility

### Issue: Gantt Not Showing

**Solution:**
- Verify "Gantt" module is enabled: Project → Settings → Modules
- Check issues have start/end dates
- Verify issue status is not "Closed"

### Issue: Dependencies Not Working

**Solution:**
- Create issue relations: Issue → Relations → Add relation → "precedes" or "follows"
- Ensure both issues have dates

### Issue: Email Notifications Not Working

**Solution:**
- Check SMTP settings in `.env`
- Test email: Administration → Settings → Email notifications → Send test email
- Verify Hostinger credentials

## Migration Checklist

- [ ] Redmine deployed and accessible
- [ ] Admin password changed
- [ ] DNS configured
- [ ] Projects created
- [ ] Users created
- [ ] Custom fields configured
- [ ] Issues imported
- [ ] Gantt charts working
- [ ] Email notifications working
- [ ] Team tested and approved
- [ ] OpenProject backed up
- [ ] OpenProject decommissioned

## Rollback Plan

If migration fails:

1. **Keep OpenProject Running**:
   ```bash
   cd /opt/codespartan/apps/codespartan-cloud/project
   docker compose up -d
   ```

2. **Stop Redmine**:
   ```bash
   cd /opt/codespartan/apps/codespartan-cloud/redmine
   docker compose down
   ```

3. **Restore DNS**:
   - Point back to OpenProject
   - Remove Redmine DNS

4. **Debug Issues**:
   - Review logs
   - Check data export/import
   - Consult Redmine community

## Timeline Estimate

| Phase | Time Estimate |
|-------|---------------|
| Deploy Redmine | 10 minutes |
| Export OpenProject data | 1-2 hours |
| Import to Redmine | 2-4 hours |
| Verification | 1-2 hours |
| Team testing | 1-2 days |
| Decommission OpenProject | 30 minutes |
| **Total** | **1-2 days + testing** |

## Resources

- **Redmine Import Guide**: https://www.redmine.org/projects/redmine/wiki/RedmineImport
- **Redmine REST API**: https://www.redmine.org/projects/redmine/wiki/Rest_api
- **CSV Import**: https://www.redmine.org/projects/redmine/wiki/RedmineIssuesCsvImport
- **Migration Tools**: https://github.com/search?q=openproject+redmine+migration

## Support

If you encounter issues during migration:

1. Check logs: `docker logs redmine-app`
2. Consult Redmine forums: https://www.redmine.org/projects/redmine/boards
3. Stack Overflow: https://stackoverflow.com/questions/tagged/redmine
4. Consider professional migration services if data is critical

---

**Remember:** Run both systems in parallel during migration. Only decommission OpenProject after thorough testing!
