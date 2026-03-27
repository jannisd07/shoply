#!/bin/bash
# Deploy Premium Subscription System to Supabase
# Run this script to deploy all SQL functions

echo "🚀 Deploying Premium Subscription System to Supabase..."
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo -e "${YELLOW}⚠️  Supabase CLI not found.${NC}"
    echo ""
    echo "Please deploy manually:"
    echo "1. Go to: https://supabase.com/dashboard/project/rtwzzerhgieyxsijemsd/sql/new"
    echo "2. Copy the contents of: database/migrations/premium_subscription_system.sql"
    echo "3. Paste and click 'Run'"
    echo ""
    echo "Or install Supabase CLI:"
    echo "  npm install -g supabase"
    echo ""
    exit 1
fi

# Deploy the migration
echo "📤 Pushing migration to Supabase..."
supabase db push

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Migration deployed successfully!${NC}"
    echo ""
    echo "Verifying functions..."
    
    # Verify functions exist
    supabase db remote --execute "SELECT routine_name FROM information_schema.routines WHERE routine_name IN ('activate_subscription', 'activate_trial', 'is_premium_user');"
    
    echo ""
    echo -e "${GREEN}✅ All done! Your premium subscription system is ready.${NC}"
else
    echo -e "${RED}❌ Deployment failed. Please deploy manually.${NC}"
    echo ""
    echo "Manual steps:"
    echo "1. Go to: https://supabase.com/dashboard/project/rtwzzerhgieyxsijemsd/sql/new"
    echo "2. Copy contents of: database/migrations/premium_subscription_system.sql"
    echo "3. Paste and click 'Run'"
    exit 1
fi
