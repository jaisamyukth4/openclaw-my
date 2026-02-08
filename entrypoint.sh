#!/bin/bash

# --- CONFIGURATION ---
MEMORY_FILE="rook_brain.zip"
DATA_DIR="/app/data"  # Internal storage path
UPLOAD_URL="$SUPABASE_URL/storage/v1/object/$SUPABASE_BUCKET/$MEMORY_FILE"

echo "🧪 [ROOK SYSTEM] Initializing Mad Scientist Protocol..."

# --- RESTORE FUNCTION ---
restore_memory() {
    echo "🧠 Checking for brain backup..."
    # Check if file exists in Supabase (HTTP 200 = Yes)
    status_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $SUPABASE_KEY" $UPLOAD_URL)

    if [ "$status_code" -eq 200 ]; then
        echo "📥 Downloading memory..."
        curl -s -H "Authorization: Bearer $SUPABASE_KEY" -o $MEMORY_FILE $UPLOAD_URL
        
        echo "xxxx Unpacking memory..."
        # Unzip into the data directory, forcing overwrite
        unzip -o $MEMORY_FILE -d /
        rm $MEMORY_FILE
        echo "✅ Memory Restored."
    else
        echo "✨ No backup found. Starting fresh."
    fi
}

# --- BACKUP LOOP (Background Process) ---
start_backup_loop() {
    while true; do
        sleep 300 # Wait 5 minutes
        
        echo "💾 Saving memory to cloud..."
        # Zip the data folder (quietly)
        zip -r -q $MEMORY_FILE $DATA_DIR
        
        # Upload to Supabase
        curl -X POST "$UPLOAD_URL" \
            -H "Authorization: Bearer $SUPABASE_KEY" \
            -H "Content-Type: application/zip" \
            -H "x-upsert: true" \
            --data-binary "@$MEMORY_FILE"
            
        rm $MEMORY_FILE
        echo "✅ Save Complete."
    done
}

# --- EXECUTION ---
# 1. Install dependencies if missing (Try/Catch for permission errors)
if ! command -v zip &> /dev/null; then
    echo "🛠 Installing system tools..."
    apt-get update && apt-get install -y zip curl unzip
fi

# 2. Run Restore
restore_memory

# 3. Start Backup Loop in Background
start_backup_loop &

# 4. Launch the App (Passes any command from Dockerfile)
echo "🚀 Launching Rook..."
exec "$@"
