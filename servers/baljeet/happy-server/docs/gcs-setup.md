# Google Cloud Storage Setup for Happy-Server

Happy-server uses Google Cloud Storage (GCS) with S3-compatible API for image uploads.

## Prerequisites

- Google Cloud Project
- `gcloud` CLI installed and authenticated
- Billing enabled on GCP project

## One-Time Setup

### 1. Create GCS Bucket

```bash
# Set your preferred region (us-central1, europe-west1, etc.)
REGION="us-central1"
BUCKET_NAME="happy-server-$(whoami)"
GCP_PROJECT="your-gcp-project-id"

# Create bucket
gsutil mb -p "$GCP_PROJECT" -c STANDARD -l "$REGION" "gs://${BUCKET_NAME}"
```

### 2. Enable Public Read Access

This allows uploaded images to be accessed via direct URLs:

```bash
gsutil iam ch allUsers:objectViewer "gs://${BUCKET_NAME}"
```

**Security Note:** This makes all uploaded images publicly readable. For private deployments, configure application-level authentication instead.

### 3. Generate HMAC Keys

HMAC keys allow happy-server to use GCS via S3-compatible API.

**Via Console:**
1. Go to [Cloud Storage > Settings > Interoperability](https://console.cloud.google.com/storage/settings;tab=interoperability)
2. Click "Create a key for a service account"
3. Select service account or create new one
4. Copy the **Access Key** and **Secret**

**Via gcloud:**
```bash
# Create service account
gcloud iam service-accounts create happy-server-storage \
    --display-name="Happy Server Storage Access"

# Grant storage admin permissions
gcloud projects add-iam-policy-binding "$GCP_PROJECT" \
    --member="serviceAccount:happy-server-storage@${GCP_PROJECT}.iam.gserviceaccount.com" \
    --role="roles/storage.objectAdmin"

# Generate HMAC key
gcloud storage hmac create happy-server-storage@${GCP_PROJECT}.iam.gserviceaccount.com
```

**Save the output** - you'll need it for `.env` configuration.

### 4. Configure .env

Add to `servers/baljeet/happy-server/.env`:

```bash
S3_ACCESS_KEY=GOOG1E...  # From HMAC generation
S3_SECRET_KEY=...         # From HMAC generation
S3_BUCKET=happy-server-yourname
S3_PUBLIC_URL=https://storage.googleapis.com/happy-server-yourname
```

## Verification

### Test Upload (Optional)

```bash
# Create test file
echo "Hello from happy-server" > test.txt

# Upload using gsutil
gsutil cp test.txt "gs://${BUCKET_NAME}/"

# Test public access
curl "https://storage.googleapis.com/${BUCKET_NAME}/test.txt"

# Clean up
gsutil rm "gs://${BUCKET_NAME}/test.txt"
```

Expected: `curl` returns "Hello from happy-server"

## Cost Management

### Free Tier (Always Free)
- 5 GB storage
- 1 GB network egress to North America per month
- 5,000 Class A operations
- 50,000 Class B operations

For personal use (2-3 devices), you'll likely stay within free tier.

### Monitoring Usage

```bash
# Check bucket size
gsutil du -sh "gs://${BUCKET_NAME}"

# List all objects
gsutil ls -r "gs://${BUCKET_NAME}"
```

### Cost Estimate
- Average image: 500KB
- 10 images/day × 30 days = 150MB/month
- **Stays within 5GB free tier**

## Backup Strategy

**No manual backups needed!**

GCS provides:
- 99.999999999% (11 nines) annual durability
- Automatic redundancy across multiple availability zones
- Versioning available (optional)

Images stored in GCS are more durable than local backups.

## Troubleshooting

### HMAC Key Errors

```bash
# List existing HMAC keys
gcloud storage hmac list

# Delete invalid key
gcloud storage hmac delete ACCESS_KEY_ID
```

### Permission Denied

```bash
# Check bucket IAM policy
gsutil iam get "gs://${BUCKET_NAME}"

# Re-add public read
gsutil iam ch allUsers:objectViewer "gs://${BUCKET_NAME}"
```

### Bucket Not Found

```bash
# List all buckets in project
gsutil ls -p "$GCP_PROJECT"

# Verify bucket name in .env matches actual bucket
```

## Security Best Practices

1. **Rotate HMAC keys periodically** (every 90 days)
2. **Use service account** instead of user account for HMAC
3. **Enable audit logging** for storage access
4. **Consider bucket versioning** for accidental deletion protection
5. **Monitor costs** via GCP billing dashboard

## Alternative: Private Images

To make images private (requires authentication):

```bash
# Remove public access
gsutil iam ch -d allUsers:objectViewer "gs://${BUCKET_NAME}"

# Generate signed URLs in application code
# (Requires code changes to happy-server)
```

---

**Reference:** See `docker-compose.yml` and `.env.template` for integration configuration.
